# GameScene.gd — Python scenes/game.py Practice 모드 완전 이식
# Plains 맵, 검사자·바람궁수·다비·쇼블러, 훈련 더미
extends Node2D

const PlayerScript  := preload("res://scripts/player.gd")
const DummyScript   := preload("res://scripts/dummy.gd")
const ProjScript    := preload("res://scripts/projectile.gd")
const SwordScript   := preload("res://scripts/sword_slam.gd")
const ChipScript    := preload("res://scripts/chip_projectile.gd")
const DirtScript    := preload("res://scripts/dirt_particle.gd")
const TombScript    := preload("res://scripts/tombstone.gd")
# ── 직업 스킬 스크립트
# 직업별 스킬은 player.skill_passive / skill_q / skill_e / skill_r 인스턴스로 접근

# ── 맵 (탑다운 평면 — Plains → 부쉬 배치) ──────────────────────────────────────
const WORLD_W := 3200; const WORLD_H := 2400
var map_solids: Array = []   ## 완전 차단 지형 (경계 벽) — 병합된 Rect2i, 충돌/렌더링 그대로 사용
var map_bushes: Array = []   ## 부쉬 — 통과 가능, 이동속도 감소 + 은신 성격 (병합된 Rect2i)

# ── 맵 타일 그리드 (docs/tile_map_proposal.md 실현안 구현) ───────────────────────
## 타일 하나당 TILE_SIZE(32)px, 3200x2400 맵 기준 100x75칸. 0/1/2 값으로 저작하고,
## 충돌용 map_solids/map_bushes는 인접한 같은 타입 타일을 큰 사각형으로 병합해 생성한다
## (기존 충돌/렌더링 코드 무변경). 각 타일의 속성은 (a)타일 종류(0/1/2)와 (b)그 종류의
## 디자인(타일셋/팔레트) 두 가지이며, 둘 다 MapTileDef 리소스(resources/map/*.tres)로
## 분리해 인스펙터에서 조정할 수 있다. 0(바닥)/1(부쉬) 타일은 그 타일셋 중 하나를 난수로
## 배정해 "확정"(고정 시드로 결정론적, 프레임마다 재계산되지 않음)한다.
const TILE_SIZE := 32
const MAP_COLS := 100   # WORLD_W / TILE_SIZE (3200/32, 나머지 없음)
const MAP_ROWS := 75    # WORLD_H / TILE_SIZE (2400/32, 나머지 없음)
const WALL_TILES := 2   ## 경계벽 두께(타일 단위) — 그리드에 맞춰 정수 타일로 정의
enum TileType { FLOOR = 0, BUSH = 1, WALL = 2 }

const MAP_RNG_SEED := 7007   ## 맵을 '확정'하는 고정 시드 — 실행할 때마다 같은 결과 재현

var _floor_def: MapTileDef = null
var _bush_def: MapTileDef  = null
var _wall_def: MapTileDef  = null

var _tile_grid: Array = []      ## flat Array[int] (TileType 값), 크기 MAP_COLS*MAP_ROWS
var _tile_variant: Array = []   ## flat Array[int], FLOOR/BUSH 타일의 타일셋 인덱스(WALL은 -1)

# ── 엔티티 ───────────────────────────────────────────────────────────────────
var player: Node2D  = null
var dummy: Node2D   = null

# ── 투사체·이펙트 ─────────────────────────────────────────────────────────────
var wind_ult_arrows: Array = []
var sword_effects:   Array = []
var swordsman_dots:  Array = []   # [{target,time,tick,owner,damage_types}]
var chips:           Array = []   # ChipProjectile (homing)
var chip_rise_fx:    Array = []   # ChipProjectile (rise)
var dirt_particles:  Array = []
var tombstones:      Array = []   # Tombstone nodes

# ── Darby 타겟팅 상태 ─────────────────────────────────────────────────────────
var targeting_active: bool  = false
var targeting_radius: float = 150.0
var targeting_timer: float  = 0.0

# ── 툴팁 상태 ─────────────────────────────────────────────────────────────────
var _tooltip_lines: Array   = []   # [title, desc]
var _tooltip_pos: Vector2   = Vector2.ZERO
var _tooltip_visible: bool  = false

# ── 피해 텍스트 ───────────────────────────────────────────────────────────────
var dmg_texts: Array = []   # [{text,wx,wy,t}]

# ── 카메라 / 화면 흔들림 ─────────────────────────────────────────────────────
var cam_x: float = 0.0; var cam_y: float = 0.0
const SCR_W := 1280; const SCR_H := 720
var shake_time: float     = 0.0   ## 남은 흔들림 시간 (초)
var shake_strength: float = 0.0   ## 현재 흔들림 진폭 (픽셀)

# ── 타격감 (히트스톱) ─────────────────────────────────────────────────────────
const HITSTOP_DURATION := 0.045   ## 적중 시 정지시간(초, 실시간 기준 — Engine.time_scale과 무관)
var _hitstop_active: bool = false

# ── 대난투 속도감 (적중 시 궁극기 쿨감) ──────────────────────────────────────
const ULT_CDR_ON_HIT := 1.0   ## 평타/Q/E/R 등 단발 적중마다 R 쿨타임 즉시 감소량(초)

# ── 특정 스킬 적중 시 화면 흔들림 ────────────────────────────────────────────
const WIND_R_SHAKE_STRENGTH := 10.0; const WIND_R_SHAKE_DURATION := 0.25
const SHOVEL_ENHANCED_SHAKE_STRENGTH := 14.0; const SHOVEL_ENHANCED_SHAKE_DURATION := 0.3

# ── 마우스 데드존 ─────────────────────────────────────────────────────────────
const MOUSE_DEADZONE_RADIUS := 40.0   ## 캐릭터 중심 기준 이 반경 이내면 조준 방향을 갱신하지 않음

# ── 선입력(Input Buffer) ─────────────────────────────────────────────────────
const INPUT_BUFFER_WINDOW := 0.1   ## 행동 잠금 종료 직전 이 구간 안에 들어온 입력만 버퍼링
var _buffered_action: String = ""  ## "" | "attack" | "q" | "e" | "r"

# ── 노드 ─────────────────────────────────────────────────────────────────────
var _map_draw: Node2D     = null
var _burial_draw: Node2D  = null   ## 파묻힘 흙무덤 전용 공용 레이어 — 맵 바로 위, 모든 캐릭터/요소보다 아래
var _hud_layer: CanvasLayer = null
var _hud: Control         = null
var _font: Font           = null

# HUD 레이아웃 상수 (원본 _build_ui() 그대로)
const HUD_Y   := 640; const HUD_SZ := 54; const HUD_GAP := 14
const HUD_Q_X := 460; const HUD_P_X := 392; const HUD_E_X := 528; const HUD_R_X := 596

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_font = ThemeDB.fallback_font
	_build_map()

	_map_draw = Node2D.new()
	_map_draw.name = "MapDraw"
	_map_draw.z_index = -2
	add_child(_map_draw)
	_map_draw.draw.connect(_draw_map)

	# 씬 트리 순서만으로는 다른 노드가 z_index를 건드릴 경우 순서 보장이 깨질 수 있어
	# z_index를 명시적으로 지정한다: 맵(-2) < 흙무덤(-1) < 캐릭터/이펙트(기본값 0).
	_burial_draw = Node2D.new()
	_burial_draw.name = "BurialDraw"
	_burial_draw.z_index = -1
	add_child(_burial_draw)
	_burial_draw.draw.connect(_draw_burial_mounds)

	player = Node2D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	add_child(player)
	var job: Dictionary = Global.JOBS.get(Global.selected_job, Global.JOBS["swordsman"])
	player.setup(job, 160, WORLD_H - 80 - 60, "blue", true)
	player.scene_ref = self
	player.basic_attack_hit.connect(_on_player_basic_attack_hit)
	Global.screen_shake_requested.connect(_on_shake_requested)
	Global.hitstop_requested.connect(_on_hitstop_requested)
	# Darby: 게임 시작 시 스탯 초기화
	if job.get("key") == "darby":
		_darby_roll_stats(player, true)

	dummy = Node2D.new()
	dummy.name = "TrainingDummy"
	dummy.set_script(DummyScript)
	add_child(dummy)
	dummy.setup(900, WORLD_H - 80 - 48)

	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HudLayer"
	_hud_layer.layer = 10
	add_child(_hud_layer)
	_hud = Control.new()
	_hud.name = "HudDraw"
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud)
	_hud.draw.connect(_draw_hud)

## 탑다운 평면 맵 — 기존 플랫폼/사다리/점프패드를 전부 제거하고
## 사방 경계 벽 + 부쉬(엄폐 지형) 배치로 대체.
## 벽/부쉬 배치를 타일 그리드(0=바닥/1=부쉬/2=벽)에 찍은 뒤, 인접한 같은 타입 타일을
## 병합(greedy merge)해 map_solids/map_bushes를 만든다 — 결과는 기존과 동일한 "개수
## 적은 Rect2i 배열"이라 충돌/렌더링 쪽 코드는 그대로 두고 여기만 교체하면 된다.
func _build_map() -> void:
	_floor_def = _load_tile_def("floor")
	_bush_def  = _load_tile_def("bush")
	_wall_def  = _load_tile_def("wall")

	var wall_px: int = WALL_TILES * TILE_SIZE
	var wall_rects: Array = [
		Rect2i(0, 0, WORLD_W, wall_px),                       # 위쪽 벽
		Rect2i(0, WORLD_H - wall_px, WORLD_W, wall_px),       # 아래쪽 벽
		Rect2i(0, 0, wall_px, WORLD_H),                       # 왼쪽 벽
		Rect2i(WORLD_W - wall_px, 0, wall_px, WORLD_H),       # 오른쪽 벽
	]

	# 기존(2100x1400 기준) 부쉬 배치를 새 맵 크기(3200x2400)에 비례 확대해 재현한다.
	# _stamp_tile_rect가 픽셀→타일 인덱스 변환(정수 나눗셈)을 하므로 별도 반올림 없이
	# 그대로 넘겨도 자동으로 격자에 맞춰진다.
	const OLD_WORLD_W := 2100.0
	const OLD_WORLD_H := 1400.0
	var scale_x: float = float(WORLD_W) / OLD_WORLD_W
	var scale_y: float = float(WORLD_H) / OLD_WORLD_H
	var old_bush_rects: Array = [
		Rect2i(300, 300, 220, 180), Rect2i(760, 220, 260, 200),
		Rect2i(1300, 340, 240, 190), Rect2i(1680, 260, 220, 180),
		Rect2i(400, 700, 260, 220), Rect2i(900, 780, 300, 220),
		Rect2i(1450, 720, 240, 200), Rect2i(650, 1080, 260, 200),
		Rect2i(1200, 1120, 280, 200), Rect2i(180, 1000, 200, 180),
	]
	var bush_rects: Array = []
	for r in old_bush_rects:
		var ri: Rect2i = r
		bush_rects.append(Rect2i(
			int(float(ri.position.x) * scale_x), int(float(ri.position.y) * scale_y),
			int(float(ri.size.x) * scale_x), int(float(ri.size.y) * scale_y)))

	_tile_grid = []
	_tile_grid.resize(MAP_COLS * MAP_ROWS)
	for i in range(_tile_grid.size()): _tile_grid[i] = TileType.FLOOR
	for r in wall_rects: _stamp_tile_rect(r, TileType.WALL)
	for r in bush_rects: _stamp_tile_rect(r, TileType.BUSH)

	map_solids = _merge_tiles_to_rects(TileType.WALL)
	map_bushes = _merge_tiles_to_rects(TileType.BUSH)

	_assign_tile_variants()

## resources/map/{kind}_tile.tres(인스펙터에서 조정된 리소스)가 있으면 우선 사용,
## 없으면 코드 기본값으로 즉석 생성 — jobs/*의 .tres 우선 로드 관례와 동일한 패턴.
func _load_tile_def(kind: String) -> MapTileDef:
	var tres_path := "res://resources/map/%s_tile.tres" % kind
	if ResourceLoader.exists(tres_path):
		return load(tres_path)
	var def := MapTileDef.new()
	match kind:
		"floor":
			def.tile_type = TileType.FLOOR
			def.tileset_colors = [Color(0.13, 0.16, 0.11)]
		"bush":
			def.tile_type = TileType.BUSH
			def.tileset_colors = [Color(0.22, 0.45, 0.20, 0.75)]
			def.draw_outline = true
			def.outline_color = Color(0.14, 0.30, 0.13, 0.9)
			def.outline_width = 2.0
		"wall":
			def.tile_type = TileType.WALL
			def.tileset_colors = [Color(0.18, 0.35, 0.22)]
			def.draw_outline = true
			def.outline_color = Color(0.10, 0.18, 0.11)
	return def

## 픽셀 좌표 Rect2i를 타일 인덱스 범위로 변환해 그리드에 값을 채운다.
func _stamp_tile_rect(r: Rect2i, value: int) -> void:
	var c0: int = clampi(int(r.position.x) / TILE_SIZE, 0, MAP_COLS - 1)
	var c1: int = clampi(int(r.position.x + r.size.x - 1) / TILE_SIZE, 0, MAP_COLS - 1)
	var r0: int = clampi(int(r.position.y) / TILE_SIZE, 0, MAP_ROWS - 1)
	var r1: int = clampi(int(r.position.y + r.size.y - 1) / TILE_SIZE, 0, MAP_ROWS - 1)
	for row in range(r0, r1 + 1):
		for col in range(c0, c1 + 1):
			_tile_grid[row * MAP_COLS + col] = value

## 같은 값의 인접 타일을 최대한 큰 사각형으로 묶는 greedy merge(2D 그리디 메싱).
## 맵 생성 시 1회만 실행되며, 결과는 지금까지의 손코딩 Rect2i 배열과 동일한 형태다.
func _merge_tiles_to_rects(target_value: int) -> Array:
	var consumed: Array = []
	consumed.resize(MAP_COLS * MAP_ROWS)
	for i in range(consumed.size()): consumed[i] = false
	var rects: Array = []
	for row in range(MAP_ROWS):
		for col in range(MAP_COLS):
			var idx: int = row * MAP_COLS + col
			if _tile_grid[idx] != target_value or consumed[idx]:
				continue
			var width: int = 1
			while col + width < MAP_COLS \
					and _tile_grid[row * MAP_COLS + col + width] == target_value \
					and not consumed[row * MAP_COLS + col + width]:
				width += 1
			var height: int = 1
			while row + height < MAP_ROWS and _tile_row_span_matches(row + height, col, width, target_value, consumed):
				height += 1
			for ry in range(row, row + height):
				for rx in range(col, col + width):
					consumed[ry * MAP_COLS + rx] = true
			rects.append(Rect2i(col * TILE_SIZE, row * TILE_SIZE, width * TILE_SIZE, height * TILE_SIZE))
	return rects

func _tile_row_span_matches(row: int, col: int, width: int, target_value: int, consumed: Array) -> bool:
	for c in range(col, col + width):
		var idx: int = row * MAP_COLS + c
		if _tile_grid[idx] != target_value or consumed[idx]:
			return false
	return true

## 0(바닥)/1(부쉬) 타일마다 해당 MapTileDef.tileset_colors 중 하나를 난수로 배정해
## 맵을 '확정'한다. 고정 시드를 쓰므로 실행할 때마다 항상 같은 배치가 재현된다.
func _assign_tile_variants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_RNG_SEED
	_tile_variant = []
	_tile_variant.resize(_tile_grid.size())
	for i in range(_tile_grid.size()):
		var t: int = _tile_grid[i]
		if t == TileType.FLOOR:
			_tile_variant[i] = rng.randi_range(0, maxi(0, _floor_def.tileset_colors.size() - 1))
		elif t == TileType.BUSH:
			_tile_variant[i] = rng.randi_range(0, maxi(0, _bush_def.tileset_colors.size() - 1))
		else:
			_tile_variant[i] = -1

# ── 피해 헬퍼 ─────────────────────────────────────────────────────────────────
## is_primary_hit: 평타/Q/E/R의 단발성 직접 적중이면 true(기본값) — 궁극기 쿨감 + 히트스톱 발동.
## DoT 틱, 검사자 R처럼 짧은 간격으로 반복되는 판정은 연출 스팸을 막기 위해 false로 호출한다.
func _deal_damage(attacker, target, dmg: float, types: Array, is_primary_hit: bool = true) -> float:
	var mult := 1.0
	var jk_a: String = attacker.job.get("key", "") if attacker != null and attacker.has_method("_draw") else ""
	if jk_a == "shoveler":
		mult = attacker.skill_passive.get_buried_damage_mult(target, attacker) if attacker.skill_passive != null else 1.0
	var taken: float = target.apply_damage(dmg * mult, types)
	_pop_dmg(float(target.rect.get_center().x), float(target.rect.position.y) - 10.0, taken)
	if is_primary_hit and taken > 0.0:
		_register_hit(attacker)
	return taken

func _pop_dmg(wx: float, wy: float, dmg: float) -> void:
	if dmg <= 0.0: return
	dmg_texts.append({"text": str(int(dmg)), "wx": wx, "wy": wy, "t": 0.8})

## 모든 직업의 평타/Q/E/R 단발 적중 공통 처리 — 대난투 속도감을 위한 궁극기 쿨감 + 히트스톱.
func _register_hit(attacker) -> void:
	attacker.r_cd_rem = maxf(0.0, attacker.r_cd_rem - ULT_CDR_ON_HIT)
	Global.request_hitstop(HITSTOP_DURATION)

# ── 히트스톱 / 화면 흔들림 (Global 시그널 수신) ──────────────────────────────
## Engine.time_scale을 잠깐 0으로 낮춰 애니메이션·이동을 전역 정지시킨다.
## 정지 해제 타이머는 ignore_time_scale=true로 실시간을 기준으로 동작해야
## time_scale=0 상태에서도 정상적으로 흘러 스스로 원상복구할 수 있다.
func _on_hitstop_requested(duration: float) -> void:
	if _hitstop_active: return
	_hitstop_active = true
	Engine.time_scale = 0.0
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		_hitstop_active = false)

func _on_shake_requested(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength, strength)
	shake_time     = maxf(shake_time, duration)

# ── Shovel 스택 / 매장 ────────────────────────────────────────────────────────
func _apply_shovel_stack(owner, target, by_dust: bool = false, trigger_bury: bool = false) -> void:
	if owner.skill_passive != null: owner.skill_passive.try_add_stack(owner, target, by_dust, trigger_bury)

# ── Darby 헬퍼 ────────────────────────────────────────────────────────────────
## DB_Passive에서 호출하는 rise fx 생성 헬퍼 (scene 참조가 필요해 game_scene에 둠)
func _darby_spawn_rise_fx(p) -> void:
	var rise := Node2D.new()
	rise.name = "ChipRise"
	rise.set_script(ChipScript)
	add_child(rise)
	rise.setup_rise(float(p.rect.get_center().x), float(p.rect.position.y), Global.random_palette_color())
	chip_rise_fx.append(rise)

## DB_Q에서 호출하는 칩 생성 헬퍼
func _darby_spawn_chip(p, tgt, spd: float, dmg: float) -> void:
	var chip := Node2D.new()
	chip.name = "ChipProjectile"
	chip.set_script(ChipScript)
	add_child(chip)
	chip.setup_chip(float(p.rect.get_center().x), float(p.rect.get_center().y) - 10.0,
		tgt, spd, dmg, Global.random_palette_color(), p, p.job.get("q_dmg", ["physical"]))
	chips.append(chip)

func _darby_roll_stats(p, initial: bool = false) -> void:
	if p.skill_passive != null:
		p.skill_passive.initial_roll(p, self)

func _darby_passive_update(p, dt: float) -> void:
	if p.skill_passive != null: p.skill_passive.update(p, dt, self)

func _darby_q_update(p, dt: float) -> void:
	if p._darby_q_queue.is_empty(): return
	var q: Dictionary = p._darby_q_queue
	q["t"] = float(q["t"]) + dt
	while int(q["left"]) > 0 and float(q["t"]) >= float(q["interval"]):
		q["t"] = float(q["t"]) - float(q["interval"])
		q["left"] = int(q["left"]) - 1
		var tgt = q["target"]
		if tgt != null and is_instance_valid(tgt):
			var chip := Node2D.new()
			chip.name = "ChipProjectile"
			chip.set_script(ChipScript)
			add_child(chip)
			chip.setup_chip(float(p.rect.get_center().x), float(p.rect.get_center().y) - 10.0,
				tgt, float(q["speed"]), float(q["damage"]),
				Global.random_palette_color(), p, p.job.get("q_dmg", ["physical"]))
			chips.append(chip)
	if int(q["left"]) <= 0: p._darby_q_queue = {}

func _darby_steal_on_touch(p) -> void:
	if not p.darby_r_active: return
	if not p.rect.intersects(dummy.rect): return
	if p.skill_r != null: p.skill_r.steal(p, dummy)

# ── 입력 ──────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 타겟팅 중 Q/E/R 외 키 → 취소
		if targeting_active and not (event.is_action("skill_q") or event.is_action("skill_e") or event.is_action("skill_r")):
			targeting_active = false
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu.tscn"); return
		if event.keycode == KEY_F2: player.hp = 0.0; return
		if player.dead or player.revive_active: return
		# Godot은 동시에 눌린 키마다 별도의 InputEventKey를 전달하므로 WASD와
		# Q/E/R가 같은 프레임에 눌려도 서로를 막지 않고 모두 처리된다.
		if event.is_action("skill_q"):
			if _try_or_buffer("q"): _press_q()
		elif event.is_action("skill_e"):
			if _try_or_buffer("e"): _press_e()
		elif event.is_action("skill_r"):
			if _try_or_buffer("r"): _press_r()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not player.dead and not player.revive_active:
			# 다비 Q 타겟팅 중이면 좌클릭이 공격이 아니라 확인(발동) 입력이 된다.
			if targeting_active and player.job.get("key", "") == "darby":
				_check_darby_q_confirm()
			elif _try_or_buffer("attack"):
				player.perform_basic_attack()

	# 툴팁: 마우스 이동 or 버튼
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_update_tooltip(get_viewport().get_mouse_position())

# ── 선입력(Input Buffer) ─────────────────────────────────────────────────────
## 현재 조작 불가 상태(스윙/캐스팅 등)로 남아있는 잠금 시간 중 최댓값.
func _player_action_lock() -> float:
	return maxf(player.move_lock_time, maxf(player.attack_lock_time, player.skill_lock_time))

## 지금 바로 실행 가능하면 true(즉시 실행하라는 뜻). 잠겨 있다면 잠금 종료가
## 임박(INPUT_BUFFER_WINDOW 이내)했을 때만 버퍼에 기록하고 false를 반환한다.
func _try_or_buffer(action: String) -> bool:
	var lock := _player_action_lock()
	if lock <= 0.0:
		return true
	if lock <= INPUT_BUFFER_WINDOW:
		_buffered_action = action
	return false

## 매 프레임 호출 — 잠금이 막 풀린 시점에 버퍼된 입력이 있으면 지연 없이 실행.
func _consume_input_buffer() -> void:
	if _buffered_action == "" or _player_action_lock() > 0.0:
		return
	var action := _buffered_action
	_buffered_action = ""
	match action:
		"attack": player.perform_basic_attack()
		"q": _press_q()
		"e": _press_e()
		"r": _press_r()

# ── 툴팁 ──────────────────────────────────────────────────────────────────────
func _update_tooltip(mouse_pos: Vector2) -> void:
	var job: Dictionary = player.job
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

# ── 기본 공격 (사거리 기반 근/원거리 시스템 — player.gd가 판정, 여기서는 피해 적용 + 직업별 후속 효과만) ──
func _on_player_basic_attack_hit(target: Node2D, dmg: float, dmg_types: Array) -> void:
	var jk: String = player.job.get("key", "")
	_deal_damage(player, target, dmg, dmg_types)
	if jk == "wind_archer":
		player.wind_on_basic_hit()
	elif jk == "shoveler":
		# R로 예약된 강화 매장 공격인지 여부를 _apply_shovel_stack이 플래그를 소비하기 전에 캡처
		var was_enhanced: bool = player.shovel_r_armed
		_apply_shovel_stack(player, target, false, true)
		if was_enhanced:
			Global.request_screen_shake(SHOVEL_ENHANCED_SHAKE_STRENGTH, SHOVEL_ENHANCED_SHAKE_DURATION)

# ── 스킬 ──────────────────────────────────────────────────────────────────────
func _press_q() -> void:
	var jk: String = player.job.get("key", "")
	match jk:
		"swordsman", "wind_archer":
			if player.q_cd_rem <= 0.0:
				if jk == "swordsman": player.start_q()
				else: player.start_wind_q()
		"darby":
			if player.skill_q == null or not player.skill_q.can_start_targeting(player):
				targeting_active = false; return
			if not targeting_active:
				targeting_active = true
				targeting_timer = player.skill_q.targeting_timeout
				targeting_radius = player.skill_q.targeting_radius
			else:
				targeting_active = false
		"shoveler":
			if player.skill_q != null and player.skill_q.can_use(player):
				var spawn_list: Array = player.skill_q.get_spawn_list(player)
				for sp in spawn_list:
					var d := Node2D.new()
					d.name = "DirtParticle"
					d.set_script(DirtScript)
					add_child(d)
					d.setup(float(sp["wx"]), float(sp["wy"]), float(sp["vx"]), float(sp["vy"]), player)
					dirt_particles.append(d)
				player.skill_q.activate(player)

func _press_e() -> void:
	var jk: String = player.job.get("key", "")
	match jk:
		"swordsman":
			if player.skill_e != null and player.skill_e.can_use(player):
				var mouse_world := get_viewport().get_mouse_position() + Vector2(cam_x, cam_y)
				var target_pos: Vector2 = player.skill_e.get_target_pos(player, mouse_world)
				var fx := Node2D.new()
				fx.name = "SwordSlam"
				fx.set_script(SwordScript)
				add_child(fx)
				fx.owner_node = player; fx.dmg_types = player.job.get("e_dmg", ["physical"])
				fx.setup(target_pos, player, player.skill_e.slam_radius,
					player.skill_e.leap_height, player.skill_e.leap_up_time, player.skill_e.leap_down_time)
				sword_effects.append(fx)
				player.skill_e.activate(player)
		"wind_archer":
			if player.skill_e != null and player.skill_e.can_use(player):
				player.skill_e.activate(player)
		"darby":
			if player.skill_e != null and player.skill_e.can_use(player):
				player.skill_e.activate(player)
		"shoveler":
			if player.skill_e != null and player.skill_e.can_use(player):
				var sp: Dictionary = player.skill_e.get_spawn_params(player, map_solids, WORLD_H)
				if (sp["hit_rect"] as Rect2i).intersects(dummy.rect):
					_deal_damage(player, dummy, float(sp["damage"]), player.job.get("e_dmg", ["physical"]))
					if player.skill_passive != null:
						player.skill_passive.try_add_stack(player, dummy, false, false)
					# 묘석이 솟는 충격으로 판정 중심에서 대상을 바깥쪽으로 튕겨낸다.
					var tomb_ctr: Vector2 = Vector2((sp["hit_rect"] as Rect2i).get_center())
					var kb_dir: Vector2 = Vector2(dummy.rect.get_center()) - tomb_ctr
					if kb_dir.length() < 0.01: kb_dir = Vector2(player.aim_dir)
					player.skill_e.apply_knockback_on_hit(dummy, kb_dir)
				var tomb := Node2D.new()
				tomb.name = "Tombstone"
				tomb.set_script(TombScript)
				add_child(tomb)
				tomb.setup(sp["rect"], float(sp["start_y"]), float(sp["target_y"]))
				tombstones.append(tomb)
				player.skill_e.activate(player)

func _press_r() -> void:
	var jk: String = player.job.get("key", "")
	match jk:
		"swordsman":
			if player.skill_r != null and player.skill_r.can_use(player):
				player.skill_r.activate(player)
		"wind_archer":
			if player.skill_r != null and player.skill_r.can_use(player):
				var sp: Dictionary = player.skill_r.get_spawn_params(player)
				var proj := Node2D.new()
				proj.name = "WindUltArrow"
				proj.set_script(ProjScript)
				add_child(proj)
				proj.setup_directional(
					float(sp["world_x"]), float(sp["world_y"]),
					float(sp["dir_x"]),   float(sp["dir_y"]),
					float(sp["speed"]),   float(sp["damage"]),
					player, sp["dmg_types"],
					int(sp["radius"]),    sp["color"],
					float(sp["life"]),    -1.0,
					sp["pierce"],         Projectile.Style.WIND_ULT)
				var img := Image.load_from_file(sp["texture"])
				if img: proj._tex = ImageTexture.create_from_image(img)
				wind_ult_arrows.append(proj)
				player.skill_r.activate(player)
		"darby":
			if player.skill_r != null and player.skill_r.can_use(player):
				player.skill_r.activate(player)
		"shoveler":
			if player.skill_r != null and player.skill_r.can_use(player):
				player.skill_r.activate(player)

# ── Darby Q 마우스 2차 확인 ───────────────────────────────────────────────────
func _check_darby_q_confirm() -> void:
	# 타겟팅 원 내에 더미가 있으면 발사
	var jk: String = player.job.get("key", "")
	if jk != "darby" or not targeting_active: return
	var my_ctr := Vector2(player.rect.get_center())
	var d := my_ctr.distance_to(dummy.center())
	if d > targeting_radius: targeting_active = false; return
	if player.skill_q != null: player.skill_q.activate(player, dummy)
	targeting_active = false

# ── 메인 루프 ─────────────────────────────────────────────────────────────────
func _process(dt: float) -> void:
	var jk: String = player.job.get("key", "")

	# 탑다운 360도 조준 방향 — 마우스 월드 좌표 기준, 매 프레임 갱신 (평타/Q/E/R 각도 계산에 사용).
	# 데드존: 마우스가 캐릭터 중심 MOUSE_DEADZONE_RADIUS 반경 이내로 들어오면 방향을 갱신하지 않고,
	# 데드존 진입 직전의 마지막 유효 방향/좌표(player.aim_dir / last_valid_mouse_world)를 그대로 유지한다.
	# → 커서가 캐릭터 위에 있을 때 조준이 급격히 뒤틀리는 현상을 방지.
	var mouse_world := get_viewport().get_mouse_position() + Vector2(cam_x, cam_y)
	var to_mouse := mouse_world - Vector2(player.rect.get_center())
	if to_mouse.length() > MOUSE_DEADZONE_RADIUS:
		player.aim_dir = to_mouse.normalized()
		player.last_valid_mouse_world = mouse_world

	# 화면 흔들림 감쇠
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - dt)
		if shake_time <= 0.0: shake_strength = 0.0

	# 타겟팅 타이머
	if targeting_active:
		targeting_timer -= dt
		if targeting_timer <= 0.0: targeting_active = false

	# 플레이어 입력·이동
	if not player.dead and not player.revive_active:
		player.handle_input(dt, map_solids, map_bushes)
	player.move_and_collide_map(dt, map_solids, map_bushes, WORLD_W, WORLD_H)
	player.player_update(dt)

	# 선입력 소비 — 이번 프레임에 행동 잠금이 막 풀렸다면 버퍼된 입력을 지연 없이 실행
	_consume_input_buffer()

	# Darby 패시브·Q큐·R스틸
	if jk == "darby":
		_darby_passive_update(player, dt)
		_darby_q_update(player, dt)
		_darby_steal_on_touch(player)

	# Swordsman R 반복 피해
	if player.r_active and jk == "swordsman":
		while player.r_tick >= 0.5:
			player.r_tick -= 0.5
			if player.rect.intersects(dummy.rect):
				_deal_damage(player, dummy, 70.0 * player.get_effective_dmg_mult(),
					player.get_effective_dmg_types(player.job.get("r_dmg", ["physical"])), false)

	# 부활 처리
	if player.dead and player.respawn_time <= 0.0:
		player.respawn(160, WORLD_H - 80 - 60)
		if player.job.get("key") == "darby": _darby_roll_stats(player, true)

	# 더미 물리
	dummy.dummy_update(dt, map_solids, map_bushes)

	# 바람궁수 R 화살
	for proj in wind_ult_arrows.duplicate():
		proj.proj_update(dt)
		if proj.alive:
			if proj._world_pos.x < -400 or proj._world_pos.x > WORLD_W + 400: proj.alive = false
			var did := dummy.get_instance_id()
			if proj.alive and not (did in proj.hit_ids) and proj.collides_rect(dummy.rect):
				_deal_damage(player, dummy, proj.damage, proj.dmg_types)
				Global.request_screen_shake(WIND_R_SHAKE_STRENGTH, WIND_R_SHAKE_DURATION)
				# 에어본(넉백+스턴) 적용 — 화살이 날아간 방향과 무관하게 항상 위(화면 위쪽)로 띄운다.
				if proj.owner_node != null and proj.owner_node.skill_r != null:
					var kb_dir := Vector2(0.0, -1.0)
					proj.owner_node.skill_r.apply_airborne_on_hit(dummy, kb_dir)
				proj.hit_ids.append(did)
				if not proj.pierce: proj.alive = false
		if not proj.alive: proj.queue_free(); wind_ult_arrows.erase(proj)

	# 검사자 E 장판 슬램 — Tween 착지 시점에 1회 광역 판정 (범위 안에 있으면 시전자 본인도 피해)
	for fx in sword_effects.duplicate():
		if fx.consume_just_landed():
			var hb: Rect2i = fx.hitbox_world()
			var e_types: Array = player.get_effective_dmg_types(fx.dmg_types)
			var e_mult: float = player.get_effective_dmg_mult()
			var did := dummy.get_instance_id()
			if not (did in fx.hit_done) and hb.intersects(dummy.rect):
				_deal_damage(player, dummy, dummy.max_hp * player.skill_e.hit_damage_pct * e_mult, e_types)
				fx.hit_done.append(did)
				swordsman_dots.append({"target": dummy, "time": player.skill_e.dot_duration,
					"tick": player.skill_e.dot_tick_rate, "owner": player, "damage_types": fx.dmg_types})
			var pid := player.get_instance_id()
			if not (pid in fx.hit_done) and hb.intersects(player.rect):
				_deal_damage(player, player, player.max_hp * player.skill_e.hit_damage_pct * e_mult, e_types)
				fx.hit_done.append(pid)
				swordsman_dots.append({"target": player, "time": player.skill_e.dot_duration,
					"tick": player.skill_e.dot_tick_rate, "owner": player, "damage_types": fx.dmg_types})
		if not fx.alive: fx.queue_free(); sword_effects.erase(fx)

	# E DoT (대상이 더미든 시전자 본인이든 동일하게 처리)
	for dot in swordsman_dots.duplicate():
		dot["time"] -= dt; dot["tick"] -= dt
		if float(dot["time"]) <= 0.0: swordsman_dots.erase(dot); continue
		if float(dot["tick"]) <= 0.0:
			dot["tick"] = player.skill_e.dot_tick_rate
			var tgt = dot["target"]
			if tgt != null:
				var dot_dmg: float = max(1.0, float(tgt.hp) * player.skill_e.dot_tick_damage) * player.get_effective_dmg_mult()
				_deal_damage(player, tgt, dot_dmg, player.get_effective_dmg_types(dot["damage_types"]), false)

	# Chip 투사체 (Darby Q)
	for chip in chips.duplicate():
		chip.proj_update(dt)
		if not chip.alive:
			# 도착 시 피해
			if is_instance_valid(chip.target_node):
				_deal_damage(player, chip.target_node, chip.damage, chip.dmg_types)
			chip.queue_free(); chips.erase(chip)

	# Chip 라이즈 이펙트
	for rise in chip_rise_fx.duplicate():
		rise.proj_update(dt)
		if not rise.alive: rise.queue_free(); chip_rise_fx.erase(rise)

	# Dirt 파티클 (Shoveler Q)
	for d in dirt_particles.duplicate():
		d.proj_update(dt, map_solids, map_bushes)
		if d.alive and d.collides_rect(dummy.rect):
			if player.skill_passive != null:
				player.skill_passive.apply_slow(dummy)
				player.skill_passive.try_add_stack(player, dummy, true, false)
		if not d.alive: d.queue_free(); dirt_particles.erase(d)

	# Tombstone (Shoveler E)
	for tomb in tombstones.duplicate():
		var just_solid: bool = tomb.tomb_update(dt)
		if just_solid and not (tomb.world_rect in map_solids):
			map_solids.append(tomb.world_rect)
		tomb.position = Vector2(tomb.world_rect.position) + Vector2(-cam_x, -cam_y)
		if not tomb.alive:
			map_solids.erase(tomb.world_rect)
			tomb.queue_free(); tombstones.erase(tomb)

	# 피해 텍스트
	var kept: Array = []
	for d in dmg_texts:
		d["t"] -= dt; d["wy"] -= 25.0 * dt
		if float(d["t"]) > 0.0: kept.append(d)
	dmg_texts = kept

	_update_camera()
	_map_draw.queue_redraw()
	_burial_draw.queue_redraw()
	player.queue_redraw(); dummy.queue_redraw()
	_hud.queue_redraw()

# ── 카메라 ────────────────────────────────────────────────────────────────────
func _current_shake_offset() -> Vector2:
	if shake_time <= 0.0: return Vector2.ZERO
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength

func _update_camera() -> void:
	cam_x = clampf(float(player.rect.get_center().x) - SCR_W / 2.0, 0.0, float(WORLD_W - SCR_W))
	cam_y = clampf(float(player.rect.get_center().y) - SCR_H / 2.0, 0.0, float(WORLD_H - SCR_H))
	# 화면 흔들림은 렌더링 오프셋에만 더한다 — cam_x/cam_y 자체(마우스 월드 좌표 변환 등
	# 게임플레이 로직이 참조하는 "논리적" 카메라 값)는 흔들림의 영향을 받지 않는다.
	var off := Vector2(-cam_x, -cam_y) + _current_shake_offset()
	player.position = Vector2(player.rect.position) + off
	dummy.position  = Vector2(dummy.rect.position) + off
	for proj in wind_ult_arrows:
		if is_instance_valid(proj): proj.position = proj._world_pos + off
	for chip in chips:
		if is_instance_valid(chip): chip.position = chip._world_pos + off
	for rise in chip_rise_fx:
		if is_instance_valid(rise): rise.position = rise._world_pos + off
	for d in dirt_particles:
		if is_instance_valid(d): d.position = d._world_pos + off
	for fx in sword_effects:
		if is_instance_valid(fx): fx.position = fx.target_pos + off

# ── 맵 렌더 ──────────────────────────────────────────────────────────────────
func _draw_map() -> void:
	# 바닥/부쉬 — 타일(0/1)마다 확정된 타일셋(MapTileDef.tileset_colors) 인덱스로 칠한다.
	# 벽(2)은 여기서 건너뛰고 아래에서 병합된 사각형으로 그린다.
	# 맵이 100x75(7500칸)로 커졌으므로, 매 프레임 전체를 순회하지 않고 화면에 보이는
	# 범위의 타일만 순회한다(카메라 컬링) — 시야 밖 타일은 어차피 그려도 보이지 않는다.
	var col0: int = clampi(int(cam_x) / TILE_SIZE - 1, 0, MAP_COLS - 1)
	var col1: int = clampi(int(cam_x + SCR_W) / TILE_SIZE + 1, 0, MAP_COLS - 1)
	var row0: int = clampi(int(cam_y) / TILE_SIZE - 1, 0, MAP_ROWS - 1)
	var row1: int = clampi(int(cam_y + SCR_H) / TILE_SIZE + 1, 0, MAP_ROWS - 1)
	for row in range(row0, row1 + 1):
		for col in range(col0, col1 + 1):
			var idx: int = row * MAP_COLS + col
			var t: int = _tile_grid[idx]
			if t == TileType.WALL: continue
			var variant: int = _tile_variant[idx]
			var def: MapTileDef = _floor_def if t == TileType.FLOOR else _bush_def
			var cell_color: Color = def.tileset_colors[variant]
			var cell := Rect2i(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			_map_draw.draw_rect(_ws(cell), cell_color)
	# 경계 벽 — 병합된 사각형
	for r in map_solids:
		_map_draw.draw_rect(_ws(r), _wall_def.tileset_colors[0])
		if _wall_def.draw_outline:
			_map_draw.draw_rect(_ws(r), _wall_def.outline_color, false, _wall_def.outline_width)
	# 부쉬 테두리 — 채움은 위에서 타일 단위로 이미 그렸으므로 병합 영역 외곽선만 덧그린다.
	if _bush_def.draw_outline:
		for r in map_bushes:
			_map_draw.draw_rect(_ws(r), _bush_def.outline_color, false, _bush_def.outline_width)

func _ws(r) -> Rect2:
	return Rect2(r.position.x - cam_x, r.position.y - cam_y, r.size.x, r.size.y)

# ── 파묻힘 흙무덤 (공용 지면 레이어 — 맵 바로 위, 모든 캐릭터/요소보다 아래) ──────
func _draw_burial_mounds() -> void:
	if player.is_buried():
		var ground := Vector2(player.rect.position.x + player.rect.size.x / 2.0,
			player.rect.position.y + player.rect.size.y)
		_draw_one_burial_mound(ground, float(player.SPR_W))
	if dummy.is_buried():
		var ground := Vector2(dummy.rect.position.x + dummy.rect.size.x / 2.0,
			dummy.rect.position.y + dummy.rect.size.y)
		_draw_one_burial_mound(ground, float(dummy.rect.size.x) * 1.7)

func _draw_one_burial_mound(world_ground: Vector2, width_ref: float) -> void:
	var screen_pt := world_ground - Vector2(cam_x, cam_y)
	var dirt_dark := Color(0.145, 0.094, 0.047, 1.0)
	var dirt_light := Color(0.267, 0.176, 0.098, 1.0)
	var mound_r := width_ref * 0.62
	_burial_draw.draw_rect(Rect2(screen_pt.x - mound_r - 20.0, screen_pt.y - 6.0, mound_r * 2.0 + 40.0, 160.0), dirt_dark)
	_burial_draw.draw_set_transform(Vector2(screen_pt.x, screen_pt.y - 6.0), 0.0, Vector2(1.1, 0.4))
	_burial_draw.draw_circle(Vector2.ZERO, mound_r, dirt_light)
	_burial_draw.draw_arc(Vector2.ZERO, mound_r, 0.0, TAU, 24, dirt_dark, 3.0)
	_burial_draw.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── HUD ───────────────────────────────────────────────────────────────────────
func _draw_hud() -> void:
	if _font == null: return
	var jk: String = player.job.get("key", "")
	var job: Dictionary = player.job

	# 스킬 아이콘 4개 [P, Q, E, R]
	var xs    := [HUD_P_X, HUD_Q_X, HUD_E_X, HUD_R_X]
	var keys  := ["P", "Q", "E", "R"]
	var names := [job.get("passive_name","P"), job.get("q_name","Q"), job.get("e_name","E"), job.get("r_name","R")]
	var cds   := [float(job.get("passive_cd",0.0)), float(job.get("q_cd",0.0)), float(job.get("e_cd",0.0)), float(job.get("r_cd",0.0))]
	# Darby: passive CD는 패시브 타이머, Q CD는 매 시전마다 스탯 기반으로 동적 재계산되므로
	# job.get("q_cd")의 고정값(0.0) 대신 마지막으로 뽑힌 실제 쿨타임(q_cd_full)을 분모로 쓴다.
	var p_cd_rem: float = player.passive_cd_rem
	if jk == "darby":
		p_cd_rem = player._darby_passive_timer; cds[0] = 10.0
		cds[1] = player.q_cd_full
	var rems  := [p_cd_rem, player.q_cd_rem, player.e_cd_rem, player.r_cd_rem]

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
		if player.q_buff_time > 0.0: _draw_rounded_border(Rect2(HUD_Q_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(1.0,0.863,0.353),3.0,12.0)
		if player.r_active:          _draw_rounded_border(Rect2(HUD_R_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(0.353,0.863,1.0),3.0,12.0)
	elif jk == "wind_archer":
		if player.wind_q_active:
			_draw_rounded_border(Rect2(HUD_Q_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(1.0,0.863,0.353),3.0,12.0)
			_hud.draw_string(_font, Vector2(HUD_Q_X+4.0,HUD_Y+HUD_SZ-6.0),
				"%.1fs" % player.wind_q_time, HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.6,1.0,0.9))
		if player.wind_e_active:
			_draw_rounded_border(Rect2(HUD_E_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(0.95,0.82,0.35),3.0,12.0)
	elif jk == "darby":
		if player.darby_r_active:
			_draw_rounded_border(Rect2(HUD_R_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(1.0,0.314,0.392),3.0,12.0)
			_hud.draw_string(_font, Vector2(HUD_R_X+4.0,HUD_Y+HUD_SZ-6.0),
				"%.1fs" % player.darby_r_time, HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1.0,0.7,0.8))
	elif jk == "shoveler":
		if player.shovel_r_armed:
			_draw_rounded_border(Rect2(HUD_R_X-3,HUD_Y-3,HUD_SZ+6,HUD_SZ+6),Color(1.0,0.863,0.353),3.0,12.0)

	# Darby 타겟팅 원
	if targeting_active and jk == "darby":
		var pctr := Vector2(player.rect.get_center()) + Vector2(-cam_x, -cam_y)
		_hud.draw_arc(pctr, targeting_radius, 0.0, TAU, 48, Color(0.314, 0.627, 1.0, 0.235), 3.0)
		_hud.draw_arc(pctr, targeting_radius, 0.0, TAU, 48, Color(0.314, 0.627, 1.0, 0.588), 2.0)

	# HP 바
	var left := float(HUD_P_X); var right := float(HUD_R_X + HUD_SZ)
	var bw := right - left; var by := float(HUD_Y + HUD_SZ + 10)
	_hud.draw_rect(Rect2(left, by, bw, 22.0), Color(0.071, 0.071, 0.078))
	_draw_rounded_border(Rect2(left, by, bw, 22.0), Color(0.275, 0.275, 0.314), 2.0, 8.0)
	if player.max_hp > 0.0:
		var ratio := maxf(0.0, minf(1.0, player.hp / player.max_hp))
		_hud.draw_rect(Rect2(left+2.0, by+2.0, (bw-4.0)*ratio, 18.0), Color(0.235, 0.784, 0.353))
	_hud.draw_string(_font, Vector2(left+bw/2.0-30.0, by+16.0),
		"%d / %d" % [int(max(0.0,player.hp)), int(player.max_hp)],
		HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.941,0.941,0.941))

	# Darby 스탯 표시 (현재 랜덤 스탯)
	if jk == "darby":
		var stat_txt := "ATK %.0f  HP %.0f  RNG %.0f  SPD %.0f  AS %.2f  [%.1fs후 재롤]" % [
			player.attack, player.max_hp, player.attack_range, player.move_speed, player.attack_speed,
			maxf(0.0, player._darby_passive_timer)]
		_hud.draw_string(_font, Vector2(left, by + 30.0), stat_txt,
			HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.8,0.9,1.0,0.85))

	# 누적 피해
	_hud.draw_string(_font, Vector2(SCR_W/2.0-110.0,36.0),
		"훈련 더미  누적 피해: %d" % int(dummy.total_damage_taken),
		HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(1.0,0.871,0.471))

	# Wind 패시브 스택
	if jk == "wind_archer" and player.wind_passive_stacks > 0:
		_hud.draw_string(_font, Vector2(16.0,60.0),
			"바람 패시브: %d스택 (%d/15타)" % [player.wind_passive_stacks, player.wind_passive_hits],
			HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.471,0.941,0.839))

	# Shoveler 스택
	if jk == "shoveler":
		var stk: int = dummy.shovel_stack_count()
		if stk > 0:
			_hud.draw_string(_font, Vector2(16.0,60.0),
				"삽질 스택: %d / 5" % stk, HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.8,0.6,0.3))

	# 피해 텍스트
	for d in dmg_texts:
		_hud.draw_string(_font, Vector2(float(d["wx"])-cam_x, float(d["wy"])-cam_y),
			d["text"], HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1.0,0.863,0.471))

	# 사망 오버레이
	if player.dead:
		_hud.draw_rect(Rect2(0,0,SCR_W,SCR_H), Color(0,0,0,0.55))
		_hud.draw_string(_font, Vector2(SCR_W/2.0-90.0,SCR_H/2.0),
			"부활 대기: %.1f초" % maxf(0.0,player.respawn_time),
			HORIZONTAL_ALIGNMENT_LEFT,-1,38,Color.WHITE)

	# 힌트
	_hud.draw_string(_font, Vector2(16.0,20.0), "ESC 메뉴  F2 즉사테스트",
		HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.6,0.6,0.65))
	var hint := "WASD/방향키 이동  마우스 조준  Q/E/R 스킬  좌클릭 기본공격"
	if jk == "darby": hint += "  [Q: 1회 눌러 타겟팅, 재클릭으로 확인]"
	_hud.draw_string(_font, Vector2(16.0,SCR_H-18.0), hint,
		HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.5,0.5,0.55))

	# 스킬 툴팁 — 스킬 아이콘 위에 마우스를 올렸을 때 (_update_tooltip이 상태를 갱신)
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
const TOOLTIP_MAX_WIDTH := 300.0   ## 제목/설명 텍스트가 이 폭을 넘으면 자동 줄바꿈

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
