class_name HudScene
extends CanvasLayer

## 스킬 아이콘/HP바/툴팁 등 HUD 그리기를 전담하는 독립 서브씬(scenes/ui/hud.tscn).
## game_scene.gd는 이 씬을 game.tscn에 직접 인스턴싱해 넣고, setup()으로 player/dummy
## 참조만 넘겨준 뒤 매 프레임 sync_frame()으로 카메라/타겟팅/피해텍스트 상태를 전달하고
## redraw()를 호출한다 — 그리기 로직 자체는 이 스크립트 안에서 자기완결적으로 처리된다.

var _hud: Control = null
var _font: Font   = null

var _player: Node2D = null
var _dummy: Node2D  = null

var _cam_x: float = 0.0
var _cam_y: float = 0.0
var _targeting_active: bool  = false
var _targeting_radius: float = 150.0
var _dmg_texts: Array = []

var _tooltip_lines: Array  = []
var _tooltip_pos: Vector2  = Vector2.ZERO
var _tooltip_visible: bool = false

# HUD 레이아웃 상수 (원본 _build_ui() 그대로)
const HUD_Y   := 640; const HUD_SZ := 54; const HUD_GAP := 14
const HUD_Q_X := 460; const HUD_P_X := 392; const HUD_E_X := 528; const HUD_R_X := 596
const SCR_W := 1280; const SCR_H := 720
const TOOLTIP_MAX_WIDTH := 300.0   ## 제목/설명 텍스트가 이 폭을 넘으면 자동 줄바꿈

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_font = ThemeDB.fallback_font
	_hud = %HudDraw as Control
	_hud.draw.connect(_draw_hud)

func setup(p_player: Node2D, p_dummy: Node2D) -> void:
	_player = p_player
	_dummy = p_dummy

## game_scene의 _process()에서 매 프레임 호출 — HUD가 스스로 참조를 뒤지는 대신,
## 그리기에 필요한 상태를 이 한 번의 호출로 명시적으로 전달받는다.
func sync_frame(cam_x: float, cam_y: float, targeting_active: bool, targeting_radius: float, dmg_texts: Array) -> void:
	_cam_x = cam_x
	_cam_y = cam_y
	_targeting_active = targeting_active
	_targeting_radius = targeting_radius
	_dmg_texts = dmg_texts

func redraw() -> void:
	_hud.queue_redraw()

# ── 툴팁 ──────────────────────────────────────────────────────────────────────
func update_tooltip(mouse_pos: Vector2) -> void:
	var job: Dictionary = _player.job
	var icons := [
		{"rect": Rect2(HUD_P_X, HUD_Y, HUD_SZ, HUD_SZ),
		 "lines": ["P  " + job.get("passive_name",""), job.get("passive_desc","")]},
		{"rect": Rect2(HUD_Q_X, HUD_Y, HUD_SZ, HUD_SZ),
		 "lines": ["Q  " + job.get("q_name",""), job.get("q_desc","")]},
		{"rect": Rect2(HUD_E_X, HUD_Y, HUD_SZ, HUD_SZ),
		 "lines": ["E  " + job.get("e_name",""), job.get("e_desc","")]},
		{"rect": Rect2(HUD_R_X, HUD_Y, HUD_SZ, HUD_SZ),
		 "lines": ["R  " + job.get("r_name",""), job.get("r_desc","")]},
	]
	_tooltip_visible = false
	for ic in icons:
		if (ic["rect"] as Rect2).has_point(mouse_pos):
			_tooltip_lines = ic["lines"]
			_tooltip_pos   = mouse_pos
			_tooltip_visible = true
			break
	_hud.queue_redraw()

# ── HUD ───────────────────────────────────────────────────────────────────────
func _draw_hud() -> void:
	if _font == null: return
	var jk: String = _player.job.get("key", "")
	var job: Dictionary = _player.job

	# 스킬 아이콘 4개 [P, Q, E, R]
	var xs    := [HUD_P_X, HUD_Q_X, HUD_E_X, HUD_R_X]
	var keys  := ["P", "Q", "E", "R"]
	var names := [job.get("passive_name","P"), job.get("q_name","Q"), job.get("e_name","E"), job.get("r_name","R")]
	var cds   := [float(job.get("passive_cd",0.0)), float(job.get("q_cd",0.0)), float(job.get("e_cd",0.0)), float(job.get("r_cd",0.0))]
	# Darby: passive CD는 패시브 타이머, Q CD는 매 시전마다 스탯 기반으로 동적 재계산되므로
	# job.get("q_cd")의 고정값(0.0) 대신 마지막으로 뽑힌 실제 쿨타임(q_cd_full)을 분모로 쓴다.
	var p_cd_rem: float = _player.passive_cd_rem
	if jk == "darby":
		p_cd_rem = _player._darby_passive_timer; cds[0] = 10.0
		cds[1] = _player.q_cd_full
	var rems  := [p_cd_rem, _player.q_cd_rem, _player.e_cd_rem, _player.r_cd_rem]

	for i in range(4):
		var ix := float(xs[i]); var iy := float(HUD_Y); var sz := float(HUD_SZ)
		_hud.draw_rect(Rect2(ix, iy, sz, sz), Color(0.137, 0.137, 0.165))
		_draw_rounded_border(Rect2(ix, iy, sz, sz), Color(0.333, 0.333, 0.392), 2.0, 10.0)
		_hud.draw_string(_font, Vector2(ix + 6.0, iy + 20.0), keys[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.922, 0.922, 0.941))
		# 스킬명이 박스 폭을 넘으면 잘라내는 대신 줄바꿈해 전체 이름이 보이게 한다.
		var name_lines: Array = _wrap_text(names[i] as String, _font, 10, sz - 6.0)
		var name_y := iy + 28.0
		for nl in name_lines:
			_hud.draw_string(_font, Vector2(ix + 3.0, name_y), nl,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.82, 1.0, 0.8))
			name_y += 11.0
		var cd: float = cds[i]; var rem: float = rems[i]
		if cd > 0.0 and rem > 0.0:
			_draw_radial_cd(ix, iy, sz, minf(1.0, rem / cd))
			_hud.draw_string(_font, Vector2(ix + sz/2.0 - 12.0, iy + sz/2.0 + 8.0),
				"%.1f" % rem, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0.8))

	# 활성 스킬 테두리
	if jk == "swordsman":
		if _player.q_buff_time > 0.0: _draw_rounded_border(Rect2(HUD_Q_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(1.0,0.863,0.353),3.0,12.0)
		if _player.r_active:          _draw_rounded_border(Rect2(HUD_R_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(0.353,0.863,1.0),3.0,12.0)
	elif jk == "wind_archer":
		if _player.wind_q_active:
			_draw_rounded_border(Rect2(HUD_Q_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(1.0,0.863,0.353),3.0,12.0)
			_hud.draw_string(_font, Vector2(HUD_Q_X+4.0,HUD_Y+HUD_SZ-6.0),
				"%.1fs" % _player.wind_q_time, HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.6,1.0,0.9))
		if _player.wind_e_active:
			_draw_rounded_border(Rect2(HUD_E_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(0.95,0.82,0.35),3.0,12.0)
	elif jk == "darby":
		if _player.darby_r_active:
			_draw_rounded_border(Rect2(HUD_R_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(1.0,0.314,0.392),3.0,12.0)
			_hud.draw_string(_font, Vector2(HUD_R_X+4.0,HUD_Y+HUD_SZ-6.0),
				"%.1fs" % _player.darby_r_time, HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1.0,0.7,0.8))
	elif jk == "shoveler":
		if _player.shovel_r_armed:
			_draw_rounded_border(Rect2(HUD_R_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(1.0,0.863,0.353),3.0,12.0)

	# Darby 타겟팅 원
	if _targeting_active and jk == "darby":
		var pctr := Vector2(_player.rect.get_center()) + Vector2(-_cam_x, -_cam_y)
		_hud.draw_arc(pctr, _targeting_radius, 0.0, TAU, 48, Color(0.314, 0.627, 1.0, 0.235), 3.0)
		_hud.draw_arc(pctr, _targeting_radius, 0.0, TAU, 48, Color(0.314, 0.627, 1.0, 0.588), 2.0)

	# HP 바
	var left := float(HUD_P_X); var right := float(HUD_R_X + HUD_SZ)
	var bw := right - left; var by := float(HUD_Y + HUD_SZ + 10)
	_hud.draw_rect(Rect2(left, by, bw, 22.0), Color(0.071, 0.071, 0.078))
	_draw_rounded_border(Rect2(left, by, bw, 22.0), Color(0.275, 0.275, 0.314), 2.0, 8.0)
	if _player.max_hp > 0.0:
		var ratio := maxf(0.0, minf(1.0, _player.hp / _player.max_hp))
		_hud.draw_rect(Rect2(left+2.0, by+2.0, (bw-4.0)*ratio, 18.0), Color(0.235, 0.784, 0.353))
	_hud.draw_string(_font, Vector2(left+bw/2.0-30.0, by+16.0),
		"%d / %d" % [int(max(0.0,_player.hp)), int(_player.max_hp)],
		HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.941,0.941,0.941))

	# Darby 스탯 표시 (현재 랜덤 스탯)
	if jk == "darby":
		var stat_txt := "ATK %.0f  HP %.0f  RNG %.0f  SPD %.0f  AS %.2f  [%.1fs후 재롤]" % [
			_player.attack, _player.max_hp, _player.attack_range, _player.move_speed, _player.attack_speed,
			maxf(0.0, _player._darby_passive_timer)]
		_hud.draw_string(_font, Vector2(left, by + 30.0), stat_txt,
			HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.8,0.9,1.0,0.85))

	# 누적 피해
	_hud.draw_string(_font, Vector2(SCR_W/2.0-110.0,36.0),
		"훈련 더미  누적 피해: %d" % int(_dummy.total_damage_taken),
		HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(1.0,0.871,0.471))

	# Wind 패시브 스택
	if jk == "wind_archer" and _player.wind_passive_stacks > 0:
		_hud.draw_string(_font, Vector2(16.0,60.0),
			"바람 패시브: %d스택 (%d/15타)" % [_player.wind_passive_stacks, _player.wind_passive_hits],
			HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.471,0.941,0.839))

	# Shoveler 스택
	if jk == "shoveler":
		var stk: int = _dummy.shovel_stack_count()
		if stk > 0:
			_hud.draw_string(_font, Vector2(16.0,60.0),
				"삽질 스택: %d / 5" % stk, HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.8,0.6,0.3))

	# 피해 텍스트
	for d in _dmg_texts:
		_hud.draw_string(_font, Vector2(float(d["wx"])-_cam_x, float(d["wy"])-_cam_y),
			d["text"], HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1.0,0.863,0.471))

	# 사망 오버레이
	if _player.dead:
		_hud.draw_rect(Rect2(0,0,SCR_W,SCR_H), Color(0,0,0,0.55))
		_hud.draw_string(_font, Vector2(SCR_W/2.0-90.0,SCR_H/2.0),
			"부활 대기: %.1f초" % maxf(0.0,_player.respawn_time),
			HORIZONTAL_ALIGNMENT_LEFT,-1,38,Color.WHITE)

	# 힌트
	_hud.draw_string(_font, Vector2(16.0,20.0), "ESC 메뉴  F2 즉사테스트",
		HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.6,0.6,0.65))
	var hint := "WASD/방향키 이동  마우스 조준  Q/E/R 스킬  좌클릭 기본공격"
	if jk == "darby": hint += "  [Q: 1회 눌러 타겟팅, 재클릭으로 확인]"
	_hud.draw_string(_font, Vector2(16.0,SCR_H-18.0), hint,
		HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.5,0.5,0.55))

	# 스킬 툴팁 — 스킬 아이콘 위에 마우스를 올렸을 때 (update_tooltip이 상태를 갱신)
	if _tooltip_visible:
		_draw_tooltip(_tooltip_pos, _tooltip_lines)

# ── HUD 보조 ─────────────────────────────────────────────────────────────────
func _draw_radial_cd(ix: float, iy: float, sz: float, pct: float) -> void:
	if pct <= 0.0: return
	var cx := ix+sz/2.0; var cy := iy+sz/2.0; var r := sz/2.0
	_hud.draw_circle(Vector2(cx,cy), r, Color(0,0,0,0.627))
	var clear := (1.0 - pct) * TAU
	if clear > 0.001:
		var start := -PI/2.0; var steps: int = max(16, int(clear*20.0))
		var pts := PackedVector2Array(); pts.append(Vector2(cx,cy))
		for s in range(steps+1):
			var a := start + float(s)*(clear/float(steps))
			pts.append(Vector2(cx+cos(a)*r, cy+sin(a)*r))
		_hud.draw_colored_polygon(pts, Color(0.137,0.137,0.165,0.9))

func _draw_rounded_border(rect: Rect2, col: Color, width: float, radius: float) -> void:
	var x := rect.position.x; var y := rect.position.y
	var w := rect.size.x; var h := rect.size.y
	var rr: float = min(radius, min(w,h)/2.0)
	_hud.draw_line(Vector2(x+rr,y),   Vector2(x+w-rr,y),   col, width)
	_hud.draw_line(Vector2(x+rr,y+h), Vector2(x+w-rr,y+h), col, width)
	_hud.draw_line(Vector2(x,y+rr),   Vector2(x,y+h-rr),   col, width)
	_hud.draw_line(Vector2(x+w,y+rr), Vector2(x+w,y+h-rr), col, width)
	_hud.draw_arc(Vector2(x+rr,  y+rr),   rr, PI,     PI*1.5, 8, col, width)
	_hud.draw_arc(Vector2(x+w-rr,y+rr),   rr, PI*1.5, TAU,    8, col, width)
	_hud.draw_arc(Vector2(x+rr,  y+h-rr), rr, PI*0.5, PI,     8, col, width)
	_hud.draw_arc(Vector2(x+w-rr,y+h-rr), rr, 0.0,    PI*0.5, 8, col, width)

# ── 툴팁 그리기 — 원본 Python Tooltip.draw() 1:1 이식 ──────────────────────
## 공백 기준으로 우선 줄을 나누고, 공백이 없는 긴 덩어리(스킬명 등)는 글자 단위로
## 강제 개행해 max_width(px) 안에 들어가게 한다 — 잘라내지 않고 유동적으로 접는다.
func _wrap_text(text: String, font: Font, font_size: int, max_width: float) -> Array:
	var lines: Array = []
	var words: PackedStringArray = text.split(" ")
	var current := ""
	for word in words:
		var candidate: String = word if current.is_empty() else current + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			current = candidate
			continue
		if not current.is_empty():
			lines.append(current)
			current = ""
		if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			current = word
			continue
		# 단어 자체가 max_width보다 넓다(공백 없는 긴 한글 이름 등) — 글자 단위로 강제 개행
		var chunk := ""
		for ch in word:
			var test: String = chunk + ch
			if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width and not chunk.is_empty():
				lines.append(chunk)
				chunk = ch
			else:
				chunk = test
		current = chunk
	if not current.is_empty():
		lines.append(current)
	if lines.is_empty(): lines.append("")
	return lines

func _draw_tooltip(anchor: Vector2, lines: Array) -> void:
	if _font == null or lines.is_empty():
		return

	var title: String = String(lines[0])
	var desc: String  = String(lines[1]) if lines.size() > 1 else ""
	var title_size := 18
	var desc_size  := 16

	var title_lines: Array = _wrap_text(title, _font, title_size, TOOLTIP_MAX_WIDTH)
	var desc_lines: Array  = _wrap_text(desc, _font, desc_size, TOOLTIP_MAX_WIDTH) if desc != "" else []

	# 크기 측정 — 실제 줄바꿈된 각 줄의 폭/높이 기준으로 박스를 잡는다.
	var tw := 0.0
	var th := 8.0
	for l in title_lines:
		tw = maxf(tw, _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x)
		th += float(title_size) + 4.0
	for l in desc_lines:
		tw = maxf(tw, _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size).x)
		th += float(desc_size) + 4.0
	tw += 16.0; th += 8.0

	# 위치: anchor 위쪽
	var rx := anchor.x
	var ry := anchor.y - th - 8.0
	# 화면 밖 보정
	rx = clampf(rx, 0.0, float(SCR_W) - tw)
	ry = clampf(ry, 0.0, float(SCR_H) - th)

	# 배경 — 원본 (20,20,24) fill + (110,110,130) border, border_radius=10
	_hud.draw_rect(Rect2(rx, ry, tw, th), Color(0.078, 0.078, 0.094))
	_draw_rounded_border(Rect2(rx, ry, tw, th), Color(0.431, 0.431, 0.510), 2.0, 10.0)

	# 텍스트: 제목(18px) 줄들 → 본문(16px) 줄들
	var cy := ry + 10.0
	for l in title_lines:
		_hud.draw_string(_font, Vector2(rx + 8.0, cy + float(title_size)),
			l, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.961, 0.961, 0.980))
		cy += float(title_size) + 4.0
	for l in desc_lines:
		_hud.draw_string(_font, Vector2(rx + 8.0, cy + float(desc_size)),
			l, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size, Color(0.961, 0.961, 0.980))
		cy += float(desc_size) + 4.0
