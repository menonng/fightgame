# player.gd — 직업별 스킬 파일 위임 구조
extends Node2D

# ── 직업별 스킬 Resource (setup()에서 job.key에 따라 인스턴스화) ─────────────
var skill_passive = null
var skill_q       = null
var skill_e       = null
var skill_r       = null

# ── 상태이상 매니저 ────────────────────────────────────────────────────────
var status: StatusEffectManager = null

var job: Dictionary = {}
var team: String    = "blue"
var is_human: bool  = true
var facing: int     = 1
var aim_dir: Vector2 = Vector2.RIGHT   ## 탑다운 360도 조준 방향 (마우스 방향), 매 프레임 game_scene이 갱신

var rect      := Rect2i(0, 0, 40, 60)
var prev_rect := Rect2i(0, 0, 40, 60)
const SPR_W := 60
const SPR_H := 90

# ── 기저 스탯
var base_attack: float       = 0.0
var base_speed: float        = 0.0
var base_range: float        = 0.0
var base_attack_speed: float = 0.0
var base_max_hp: float       = 0.0

# ── 런타임 스탯
var max_hp: float        = 0.0
var hp: float            = 0.0
var attack: float        = 0.0
var move_speed: float    = 0.0
var attack_range: float  = 0.0
var attack_speed: float  = 0.0
var attack_cd: float     = 0.0
var attack_cd_rem: float = 0.0
var last_damage_taken: float = 0.0

# ── 버프 누산치
var inc_attack: float       = 0.0
var dec_damage_taken: float = 0.0
var inc_move: float         = 0.0
var dec_move: float         = 0.0
var dec_attack_speed: float = 0.0
var speed_buff_time: float  = 0.0
var speed_buff_inc: float   = 0.0
var move_lock_time: float   = 0.0
var attack_lock_time: float = 0.0
var skill_lock_time: float  = 0.0
var slow_mult: float        = 1.0
var slow_time: float        = 0.0

# ── 쿨다운
var q_cd_rem: float       = 0.0
var e_cd_rem: float       = 0.0
var r_cd_rem: float       = 0.0
var passive_cd_rem: float = 0.0

# ── Swordsman
var q_buff_time: float       = 0.0
var q_cast_fx_time: float    = 0.0
var r_active: bool           = false
var r_time: float            = 0.0
var r_tick: float            = 0.0
var spin_angle: float        = 0.0
var basic_swing_time: float  = 0.0
var basic_swing_duration: float = 0.14
var basic_swing_angle: float = 0.0

# ── Wind Archer
var wind_q_active: bool  = false
var wind_q_time: float   = 0.0
var wind_e_active: bool  = false
var wind_e_time: float   = 0.0
var wind_passive_hits: int   = 0
var wind_passive_stacks: int = 0
var wind_bonus_attack: float           = 0.0
var wind_bonus_range: float            = 0.0
var wind_bonus_attack_speed: float     = 0.0
var wind_bonus_projectile_speed: float = 0.0

# ── Darby
var darby_r_active: bool  = false
var darby_r_time: float   = 0.0
var _darby_passive_timer: float = 10.0
var _darby_q_queue: Dictionary  = {}  # {} = empty

# ── Shoveler (삽질 스택/매장 상태는 status 매니저가 단일 진실 공급원)
var shovel_immunity_time: float = 0.0
var shovel_r_armed: bool       = false
var _shovel_dust_lock: float   = 0.0

## 현재 삽질 스택 개수 (표시/판정용 헬퍼)
func shovel_stack_count() -> int:
	return status.count(StatusEffect.Kind.SHOVEL_STACK) if status != null else 0

## 현재 매장 상태 여부
func is_buried() -> bool:
	return status.has(StatusEffect.Kind.BURIED) if status != null else false

## 매장 상태 정보 (없으면 null)
func buried_status() -> BuriedStatus:
	if status == null: return null
	var e := status.get_effect(StatusEffect.Kind.BURIED)
	return e as BuriedStatus

## 현재 에어본(공중 판정) 상태 여부 — 스턴 + 넉백 이동 중
func is_airborne() -> bool:
	return status.has(StatusEffect.Kind.AIRBORNE) if status != null else false

## 에어본 상태 정보 (없으면 null) — 착지 위치 가이드, Tween 연출 등에서 참조
func airborne_status() -> AirborneStatus:
	if status == null: return null
	var e := status.get_effect(StatusEffect.Kind.AIRBORNE)
	return e as AirborneStatus

## 에어본 중이면 매 프레임 착지 지점을 향해 실제 위치(rect)를 이동시킴.
## (진행되는 동안 판정 잠금이 없으므로 다른 공격에 계속 피격 가능)
func _apply_airborne_position() -> void:
	var ab := airborne_status()
	if ab == null: return
	rect.position = Vector2i(ab.get_current_pos())
	position = Vector2(rect.position)

# ── 색조
var tint_color: Color = Color.TRANSPARENT
var tint_time: float  = 0.0

# ── 부활/사망
var revive_active: bool = false
var revive_time: float  = 0.0
var dead: bool          = false
var respawn_time: float = 0.0

# ── 물리
var vx: float = 0.0; var vy: float = 0.0
var on_ground: bool  = false
# 탑다운 전환으로 중력/점프/사다리 물리 제거됨. on_ground는 하위호환용으로 항상 true.

# ── 텍스처
var _tex_body: ImageTexture   = null
var _tex_body_e: ImageTexture = null
var _tex_wind_q_fancy: ImageTexture  = null
var _tex_wind_q_simple: ImageTexture = null
var _tex_wind_r_arrow: ImageTexture  = null

# ─────────────────────────────────────────────────────────────────────────────
func setup(p_job: Dictionary, sx: int, sy: int, p_team: String, p_human: bool) -> void:
	job = p_job; team = p_team; is_human = p_human; facing = 1
	rect = Rect2i(sx, sy, 40, 60); prev_rect = rect
	base_attack       = float(job.get("attack",       10.0))
	base_speed        = float(job.get("move_speed",  200.0))
	base_range        = float(job.get("range_px",     60.0))
	base_attack_speed = float(job.get("attack_speed",  1.0))
	base_max_hp       = float(job.get("hp",         1000.0))
	max_hp = base_max_hp; hp = max_hp
	_darby_passive_timer = 10.0
	_darby_q_queue = {}
	status = StatusEffectManager.new()
	status.bind(self)
	_load_skill_resources()
	_load_textures()
	refresh_stats()
	position = Vector2(rect.position)

## 직업 키에 따라 스킬 Resource 인스턴스를 로드 (인스펙터 조정값 반영을 위해 .tres 우선 시도)
func _load_skill_resources() -> void:
	var jk: String = job.get("key", "")
	skill_passive = _load_skill_res(jk, "passive")
	skill_q       = _load_skill_res(jk, "q")
	skill_e       = _load_skill_res(jk, "e")
	skill_r       = _load_skill_res(jk, "r")

## .tres (인스펙터에서 커스텀 저장한 리소스, resources/jobs/)가 있으면 우선 사용,
## 없으면 .gd 스크립트의 @export 기본값으로 새 인스턴스 생성 (scripts/jobs/)
func _load_skill_res(jk: String, part: String):
	var tres_path := "res://resources/jobs/%s/%s.tres" % [jk, part]
	if ResourceLoader.exists(tres_path):
		return load(tres_path)
	var gd_path := "res://scripts/jobs/%s/%s.gd" % [jk, part]
	if ResourceLoader.exists(gd_path):
		var script: GDScript = load(gd_path)
		return script.new()
	return null

func _load_img(path: String) -> ImageTexture:
	if path == "" or not FileAccess.file_exists(path): return null
	var img := Image.load_from_file(path)
	if img == null: return null
	return ImageTexture.create_from_image(img)

func _load_textures() -> void:
	_tex_body = _load_img(job.get("sprite", ""))
	var jk: String = job.get("key", "")
	if jk == "wind_archer":
		_tex_body_e        = _load_img(job.get("sprite_e", ""))
		_tex_wind_q_fancy  = _load_img("res://assets/wind_q_aura_fancy.png")
		_tex_wind_q_simple = _load_img("res://assets/wind_q_aura_simple.png")
		_tex_wind_r_arrow  = _load_img("res://assets/wind_r_arrow.png")

# ── 스탯 ──────────────────────────────────────────────────────────────────────
func _apply_inc(base: float, inc: float) -> float: return base * (1.0 + inc)
func _apply_dec(base: float, dec: float, mn: float) -> float: return max(mn, base * (1.0 - dec))

## StatBonusStatus / StatDebuffStatus 목록을 순회해 합산.
## 각 스택은 독립된 지속시간을 갖고, 만료되면 StatusEffectManager.update()가 알아서 제거한다.
func _sum_mods() -> Array:
	var ba := 0.0; var bh := 0.0; var br := 0.0; var bs := 0.0; var bas := 0.0
	var da := 0.0; var dh := 0.0; var ds := 0.0; var das := 0.0
	if status != null:
		for e in status.effects:
			if e is StatBonusStatus:
				ba += e.attack; bh += e.hp; br += e.range_amount
				bs += e.speed;  bas += e.atk_spd
			elif e is StatDebuffStatus:
				da += e.attack; dh += e.hp
				ds += e.speed;  das += e.atk_spd
	return [ba, bh, br, bs, bas, da, dh, ds, das]

func refresh_stats() -> void:
	var m := _sum_mods()
	var eff_atk   := max(0.0,  base_attack + float(m[0]) - float(m[5]) + wind_bonus_attack)
	var eff_range := max(1.0,  base_range  + float(m[2]) + wind_bonus_range)
	var eff_spd   := max(10.0, base_speed  + float(m[3]) - float(m[7]))
	var eff_as    := max(0.08, base_attack_speed + float(m[4]) - float(m[8]) + wind_bonus_attack_speed)
	var old_max   := max(1.0, max_hp)
	var ratio     := clampf(hp / old_max, 0.0, 1.0)
	var eff_hp    := max(1.0, base_max_hp + float(m[1]) - float(m[6]))
	max_hp = eff_hp; hp = clampf(max_hp * ratio, 0.0, max_hp)
	attack       = _apply_inc(eff_atk, inc_attack)
	var spd      := _apply_inc(eff_spd, inc_move + (speed_buff_inc if speed_buff_time > 0.0 else 0.0))
	spd          = _apply_dec(spd, dec_move, 10.0)
	if slow_time > 0.0: spd *= slow_mult
	move_speed   = max(10.0, spd)
	attack_speed = _apply_dec(eff_as, dec_attack_speed, 0.08)
	attack_cd    = 1.0 / max(0.01, attack_speed)
	attack_range = eff_range

func set_base_stats(atk: float, hp_val: float, rng: float, spd: float, asp: float) -> void:
	base_attack = atk; base_range = rng; base_speed = spd; base_attack_speed = asp
	var new_max := max(1.0, hp_val)
	var ratio   := clampf(hp / max(1.0, max_hp), 0.0, 1.0)
	base_max_hp = new_max; max_hp = new_max; hp = max(1.0, min(max_hp, max_hp * ratio))
	refresh_stats()

func add_speed_buff(inc_pct: float, dur: float) -> void:
	speed_buff_inc  = max(speed_buff_inc, inc_pct)
	speed_buff_time = max(speed_buff_time, dur)
	refresh_stats()

func apply_damage(dmg: float, dmg_types: Array = []) -> float:
	var taken := max(0.0, dmg * (1.0 - minf(0.95, dec_damage_taken)))
	var jk: String = job.get("key", "")
	if jk == "wind_archer" and wind_q_active and skill_q != null:
		# 피해 유형 체크와 감소 배율 계산을 모두 skill_q에 위임
		taken *= skill_q.get_damage_mult(self, dmg_types)
	if r_active and jk == "swordsman" and skill_r != null:
		taken *= skill_r.dmg_mult
	if revive_active and skill_passive != null:
		taken *= skill_passive.get_damage_mult()
	hp -= taken; last_damage_taken = taken
	return taken

# ── Swordsman Q/R ──────────────────────────────────────────────────────────
func start_q() -> bool:
	if skill_q == null or not skill_q.can_use(self): return false
	skill_q.activate(self); return true

func end_q() -> void:
	if skill_q != null: skill_q.deactivate(self)

func can_e() -> bool: return not revive_active and e_cd_rem <= 0.0 and skill_lock_time <= 0.0
func can_r() -> bool: return not revive_active and r_cd_rem <= 0.0 and not r_active and skill_lock_time <= 0.0

func start_r() -> bool:
	if skill_r == null or not skill_r.can_use(self): return false
	skill_r.activate(self); return true

# ── Wind Archer ────────────────────────────────────────────────────────────
func start_wind_q() -> bool:
	if skill_q == null or not skill_q.can_use(self): return false
	skill_q.activate(self); return true

func start_wind_e() -> bool:
	if skill_e == null or not skill_e.can_use(self): return false
	skill_e.activate(self); return true

func wind_on_basic_hit() -> void:
	if skill_passive != null: skill_passive.on_basic_hit(self)

# ── 기본 공격 ──────────────────────────────────────────────────────────────
func start_basic_swing() -> void:
	var jk: String = job.get("key", "")
	if jk == "swordsman" or jk == "shoveler": basic_swing_time = basic_swing_duration

func try_basic_attack(tgt_center: Vector2) -> float:
	if revive_active or attack_lock_time > 0.0 or move_lock_time > 0.0: return -1.0
	if attack_cd_rem > 0.0: return -1.0
	if Vector2(rect.get_center()).distance_to(tgt_center) <= attack_range:
		attack_cd_rem = attack_cd; start_basic_swing(); return attack
	return -1.0

# ── 부활 ──────────────────────────────────────────────────────────────────
func respawn(sx: int, sy: int) -> void:
	dead = false; respawn_time = 0.0; revive_active = false; revive_time = 0.0
	hp = max_hp; vx = 0.0; vy = 0.0; on_ground = true
	r_active = false; r_time = 0.0; r_tick = 0.0; spin_angle = 0.0
	wind_q_active = false; wind_q_time = 0.0; wind_e_active = false; wind_e_time = 0.0
	wind_passive_hits = 0; wind_passive_stacks = 0
	wind_bonus_attack = 0.0; wind_bonus_range = 0.0
	wind_bonus_attack_speed = 0.0; wind_bonus_projectile_speed = 0.0
	darby_r_active = false; darby_r_time = 0.0; _darby_q_queue = {}
	speed_buff_time = 0.0; speed_buff_inc = 0.0
	move_lock_time = 0.0; attack_lock_time = 0.0; skill_lock_time = 0.0
	shovel_immunity_time = 0.0
	shovel_r_armed = false; _shovel_dust_lock = 0.0
	if status != null:
		status.clear_kind(StatusEffect.Kind.SHOVEL_STACK)
		status.clear_kind(StatusEffect.Kind.BURIED)
	slow_mult = 1.0; slow_time = 0.0; tint_color = Color.TRANSPARENT; tint_time = 0.0
	if job.get("key") == "darby": _darby_passive_timer = 10.0; _roll_darby_stats_on_respawn()
	refresh_stats()
	rect = Rect2i(sx, sy, rect.size.x, rect.size.y)
	position = Vector2(rect.position)

func _roll_darby_stats_on_respawn() -> void:
	var atk := float(randi_range(5, 100)); var hp_v := float(randi_range(300, 1000))
	var rng := float(randi_range(10, 100)); var spd := float(randi_range(100, 500))
	var asp := randf_range(0.5, 2.5)
	set_base_stats(atk, hp_v, rng, spd, asp)
	if move_speed < 10.0: base_speed = 180.0; refresh_stats()

# ── 업데이트 ──────────────────────────────────────────────────────────────
func player_update(dt: float) -> void:
	if status != null: status.update(dt)
	_apply_airborne_position()

	attack_cd_rem = max(0.0, attack_cd_rem - dt)
	if basic_swing_time > 0.0:
		basic_swing_time = max(0.0, basic_swing_time - dt)
		var p := 1.0 - basic_swing_time / max(0.001, basic_swing_duration)
		basic_swing_angle = 180.0 * p if p < 0.5 else 90.0 * (1.0 - (p - 0.5) / 0.5)
	else:
		basic_swing_angle = 0.0

	q_cd_rem = max(0.0, q_cd_rem - dt); e_cd_rem = max(0.0, e_cd_rem - dt)
	r_cd_rem = max(0.0, r_cd_rem - dt); passive_cd_rem = max(0.0, passive_cd_rem - dt)
	q_cast_fx_time = max(0.0, q_cast_fx_time - dt)

	if speed_buff_time > 0.0:
		speed_buff_time = max(0.0, speed_buff_time - dt)
		if speed_buff_time == 0.0: speed_buff_inc = 0.0; refresh_stats()

	move_lock_time   = max(0.0, move_lock_time - dt)
	attack_lock_time = max(0.0, attack_lock_time - dt)
	skill_lock_time  = max(0.0, skill_lock_time - dt)
	shovel_immunity_time = max(0.0, shovel_immunity_time - dt)
	_shovel_dust_lock    = max(0.0, _shovel_dust_lock - dt)

	if slow_time > 0.0:
		slow_time = max(0.0, slow_time - dt)
		if slow_time == 0.0: slow_mult = 1.0; refresh_stats()

	if tint_time > 0.0:
		tint_time = max(0.0, tint_time - dt)
		if tint_time == 0.0: tint_color = Color.TRANSPARENT

	# Swordsman Q / R
	if job.get("key") == "swordsman":
		if skill_q != null: skill_q.update(self, dt)
		if skill_r != null: skill_r.update(self, dt)

	# Wind Archer Q / E
	if job.get("key") == "wind_archer":
		if skill_q != null: skill_q.update(self, dt)
		if skill_e != null: skill_e.update(self, dt)

	# Darby R
	if darby_r_active:
		darby_r_time = max(0.0, darby_r_time - dt)
		if darby_r_time <= 0.0: darby_r_active = false

	# Swordsman 패시브 부활
	if revive_active and skill_passive != null: skill_passive.update(self, dt)

	# 사망
	if hp <= 0.0 and not revive_active and not dead:
		if status != null:
			status.clear_kind(StatusEffect.Kind.STAT_BONUS)
			status.clear_kind(StatusEffect.Kind.STAT_DEBUFF)
		refresh_stats()
		if skill_passive != null and skill_passive.can_trigger(self):
			skill_passive.trigger(self)
		else:
			dead = true; respawn_time = 5.0; hp = 0.0

	if dead: respawn_time = max(0.0, respawn_time - dt)

	queue_redraw()

# ── 입력 (탑다운 8방향) ────────────────────────────────────────────────────
func handle_input(dt: float, map_solids: Array, map_bushes: Array = []) -> void:
	if revive_active or dead: vx = 0.0; vy = 0.0; return
	if status != null and status.has(StatusEffect.Kind.AIRBORNE):
		vx = 0.0; vy = 0.0   # 에어본 중엔 입력 무시 (Tween이 시각적 이동을 대신 처리)
		return
	if move_lock_time > 0.0:
		vx = 0.0; vy = 0.0
		return

	# 8방향 입력: 좌우 = move_left/right, 상하 = move_up/down (탑다운 전후 이동으로 재해석)
	var mx := (1 if Input.is_action_pressed("move_right") else 0) - (1 if Input.is_action_pressed("move_left") else 0)
	var my := (1 if Input.is_action_pressed("move_down")  else 0) - (1 if Input.is_action_pressed("move_up")   else 0)
	var dir := Vector2(mx, my)
	if dir.length() > 0.0:
		dir = dir.normalized()   # 대각선 이동 속도 보정
	vx = dir.x * move_speed
	vy = dir.y * move_speed

	if abs(vx) > 0.01: facing = 1 if vx > 0.0 else -1

## 탑다운 평면 충돌 — 부쉬(bush)는 통과 가능한 감속 지형, solids만 완전 차단
func move_and_collide_map(dt: float, map_solids: Array, map_bushes: Array, world_w: int, world_h: int) -> void:
	if dead: vx = 0.0; vy = 0.0; return
	prev_rect = rect

	var is_airborne: bool = status != null and status.has(StatusEffect.Kind.AIRBORNE)

	if not is_airborne:
		# 부쉬 내부에서는 이동속도 감소 (은신·엄폐 지형 성격)
		var in_bush := false
		for b in map_bushes:
			if rect.intersects(b): in_bush = true; break
		var speed_mult := 0.6 if in_bush else 1.0

		rect = Rect2i(rect.position + Vector2i(int(vx * dt * speed_mult), 0), rect.size)
		for p in map_solids:
			if rect.intersects(p):
				if vx > 0: rect.position.x = p.position.x - rect.size.x
				elif vx < 0: rect.position.x = p.position.x + p.size.x

		rect = Rect2i(rect.position + Vector2i(0, int(vy * dt * speed_mult)), rect.size)
		for p in map_solids:
			if rect.intersects(p):
				if vy > 0: rect.position.y = p.position.y - rect.size.y
				elif vy < 0: rect.position.y = p.position.y + p.size.y

	on_ground = true   # 탑다운에는 낙하 개념이 없으므로 항상 지면 취급

	rect.position.x = clampi(rect.position.x, 0, world_w - rect.size.x)
	rect.position.y = clampi(rect.position.y, 0, world_h - rect.size.y)
	position = Vector2(rect.position)

# ── _draw ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	if dead: return
	var jk: String = job.get("key", "")
	var buried_oy := 0.0
	if is_buried(): buried_oy = rect.size.y * 0.6

	var spr_x := float(rect.size.x / 2 - SPR_W / 2)
	var spr_y := float(rect.size.y - SPR_H) - buried_oy
	var spr_rect := Rect2(spr_x, spr_y, float(SPR_W), float(SPR_H))

	# 사거리 링
	if is_human:
		draw_arc(Vector2(rect.size.x / 2.0, rect.size.y / 2.0),
			max(40.0, attack_range), 0.0, TAU, 64, Color(1.0, 0.922, 0.275, 0.5), 5.0)

	# Wind Q 오라
	if jk == "wind_archer" and wind_q_active:
		var atex := _tex_wind_q_fancy if wind_q_time > 3.0 else _tex_wind_q_simple
		if atex:
			var ctr := Vector2(spr_rect.get_center())
			draw_texture(atex, ctr - Vector2(atex.get_width() / 2.0, atex.get_height() / 2.0))

	# Swordsman Q 방어막
	if jk == "swordsman" and q_buff_time > 0.0:
		var ctr := Vector2(spr_rect.get_center()); var sr := 59.0
		draw_circle(ctr, sr, Color(0.471, 0.824, 1.0, 0.216))
		draw_arc(ctr, sr, 0.0, TAU, 48, Color(0.706, 0.922, 1.0, 0.706), 4.0)

	# Darby R 오라
	if jk == "darby" and darby_r_active:
		var ctr := Vector2(spr_rect.get_center())
		var ar  := Rect2(spr_rect.position - Vector2(20, 20), spr_rect.size + Vector2(40, 40))
		draw_rect(ar, Color(0.784, 0.157, 0.235, 0.314))
		draw_rect(ar, Color(1.0, 0.314, 0.392, 0.588), false)

	# Shovel 묻힘 표시 (삽 스택 dots)
	var stack_n := shovel_stack_count()
	if is_buried(): stack_n = 6
	if stack_n > 0 and stack_n < 6:
		for i in range(stack_n):
			var dot_col := Color(0.478, 0.082, 0.082) if stack_n >= 5 else Color(0.941, 0.941, 0.941)
			draw_circle(Vector2(4.0 + i * 10.0, spr_y - 10.0), 4.0, dot_col)

	# 바디 스프라이트
	var use_tex: ImageTexture = null
	if jk == "wind_archer":
		use_tex = _tex_body_e if (wind_e_active and _tex_body_e != null) else _tex_body
	else:
		use_tex = _tex_body

	if use_tex:
		var tw := float(use_tex.get_width()); var th := float(use_tex.get_height())
		if jk == "swordsman" and r_active:
			var ctr := Vector2(spr_rect.get_center())
			draw_set_transform(ctr, deg_to_rad(-spin_angle), Vector2(float(SPR_W) / tw * facing, float(SPR_H) / th))
			draw_texture(use_tex, Vector2(-tw / 2.0, -th / 2.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var src := Rect2(0, 0, tw, th) if facing >= 0 else Rect2(tw, 0, -tw, th)
			draw_texture_rect_region(use_tex, spr_rect, src)
	else:
		draw_rect(spr_rect, Color(0.9, 0.9, 1.0) if team == "blue" else Color(1.0, 0.7, 0.7))

	# 색조
	if tint_color != Color.TRANSPARENT:
		var tc := tint_color; tc.a = 0.35; draw_rect(spr_rect, tc)

	# Swordsman 검
	if jk == "swordsman":
		var ctr := Vector2(spr_rect.get_center()); var top := spr_rect.position.y
		var sw := 26.0; var sh := 74.0; var cx := sw / 2.0; var cy := sh / 2.0
		if r_active:
			draw_set_transform(ctr, deg_to_rad(-spin_angle), Vector2(float(facing), 1.0))
			_draw_sword_shape(cx, cy)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var pivot := Vector2(ctr.x + float(facing) * 24.0, top + 19.0)
			var angle := (-18.0 - basic_swing_angle) if facing >= 0 else (18.0 + basic_swing_angle)
			draw_set_transform(pivot, deg_to_rad(angle), Vector2(float(facing), 1.0))
			_draw_sword_shape(cx, cy)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Wind Archer 활
	if jk == "wind_archer" and not wind_e_active:
		var ctr := Vector2(spr_rect.get_center())
		var bw := 24.0; var bh := 18.0
		var bx := ctr.x + 4.0 if facing >= 0 else ctr.x - bw - 4.0
		draw_set_transform(Vector2(bx + bw / 2.0, ctr.y - 8.0 + bh / 2.0), 0.0, Vector2(float(facing), 1.0))
		_draw_bow_shape(bw, bh)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# HP 바
	if max_hp > 0.0:
		var ratio := maxf(0.0, minf(1.0, hp / max_hp))
		var by    := spr_y - 24.0
		draw_rect(Rect2(0, by, float(rect.size.x), 6.0), Color(0, 0, 0))
		draw_rect(Rect2(0, by, float(rect.size.x) * ratio, 6.0),
			Color(0.275, 0.51, 1.0) if team == "blue" else Color(1.0, 0.31, 0.31))

	# Wind 패시브 스택
	if jk == "wind_archer" and wind_passive_stacks > 0:
		for i in range(wind_passive_stacks):
			draw_circle(Vector2(4.0 + i * 10.0, spr_y - 10.0), 4.0, Color(0.235, 0.784, 0.847))

# 검 (상하반전 후 좌표 기준)
func _draw_sword_shape(cx: float, cy: float) -> void:
	var ox := -cx; var oy := -cy
	draw_rect(Rect2(ox+cx-5.0, oy+12.0, 10.0, 44.0), Color(0.824, 0.882, 1.0, 0.97))
	var tip := PackedVector2Array([Vector2(ox+cx-5.0,oy+12.0),Vector2(ox+cx+5.0,oy+12.0),Vector2(ox+cx,oy+2.0)])
	draw_colored_polygon(tip, Color(0.824, 0.882, 1.0, 0.97))
	draw_rect(Rect2(ox+cx-14.0, oy+54.0, 28.0, 6.0), Color(0.706, 0.627, 0.353))
	draw_rect(Rect2(ox+cx-3.0,  oy+60.0, 6.0, 14.0), Color(0.471, 0.353, 0.157))
	draw_circle(Vector2(ox+cx, oy+74.0), 4.0, Color(0.588, 0.471, 0.235))

func _draw_bow_shape(bw: float, bh: float) -> void:
	var ox := -bw/2.0; var oy := -bh/2.0
	var wood := Color(0.471,0.314,0.196); var gold := Color(0.824,0.706,0.353)
	var sc   := Color(0.941,0.941,0.941)
	draw_rect(Rect2(ox+2.0, oy+3.0, 3.0,12.0), wood); draw_rect(Rect2(ox+19.0,oy+3.0,3.0,12.0), wood)
	draw_rect(Rect2(ox+1.0, oy+2.0, 5.0, 2.0), gold); draw_rect(Rect2(ox+1.0, oy+14.0,5.0,2.0), gold)
	draw_rect(Rect2(ox+18.0,oy+2.0, 5.0, 2.0), gold); draw_rect(Rect2(ox+18.0,oy+14.0,5.0,2.0), gold)
	draw_rect(Rect2(ox+10.0,oy+7.0, 4.0, 4.0), wood)
	draw_rect(Rect2(ox+9.0, oy+6.0, 6.0, 1.0), gold); draw_rect(Rect2(ox+9.0,oy+11.0,6.0,1.0), gold)
	var mcx := ox+12.0; var mcy := oy+9.0
	draw_line(Vector2(ox+4.0, oy+4.0), Vector2(mcx,mcy), sc, 1.0)
	draw_line(Vector2(ox+4.0, oy+14.0),Vector2(mcx,mcy), sc, 1.0)
	draw_line(Vector2(ox+20.0,oy+4.0), Vector2(mcx,mcy), sc, 1.0)
	draw_line(Vector2(ox+20.0,oy+14.0),Vector2(mcx,mcy), sc, 1.0)
