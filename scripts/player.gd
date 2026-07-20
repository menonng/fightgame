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
## 마우스 데드존 보정: game_scene은 마우스가 데드존(캐릭터 중심 반경) 밖에 있을 때만
## aim_dir/last_valid_mouse_world를 갱신한다. 데드존 안에서는 마지막 유효 값을 그대로 유지해
## 커서가 캐릭터 위에 있을 때 조준 방향이 급격히 뒤틀리는 것을 방지한다.
var last_valid_mouse_world: Vector2 = Vector2.ZERO

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

# ── 걷기 진자 애니메이션 (대충 구현) ────────────────────────────────────────
# 스프라이트는 동서(좌우) 걷기 모션 하나뿐 — 남북 전용 모션은 없다.
# 8방향 어디로 움직이든 이 하나의 좌우 진자를 facing 방향으로 사용한다.
@export_group("걷기 진자 애니메이션 (대충 구현)")
@export var walk_pivot_ratio: float = 0.35   ## 머리/몸통 분할 지점 (0=정수리, 1=발끝)
@export var walk_swing_deg: float = 17.5     ## 진자 최대 회전 각도 (도) — 기존 10.0의 1.75배
@export var walk_swing_speed: float = 9.0    ## 진자 흔들림 속도
@export var walk_swing_enabled: bool = true  ## on/off
var _walk_anim_time: float = 0.0

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

# ── 시각 전용 오프셋 (히트박스는 그대로 두고 스프라이트만 Tween으로 띄우는 "눈속임") ──
var visual_offset: Vector2 = Vector2.ZERO

## 에어본/넉백 부여 시 StatusEffect가 호출. 실제 위치(rect)는 건드리지 않고
## 스프라이트만 위로 살짝 띄웠다 원위치로 복귀시켜 붕 뜬 느낌을 연출.
## 그림자(사거리 링 아래 고정 표시)는 rect 기준 그대로 유지되어 입체감을 만든다.
func play_airborne_visual(duration: float) -> void:
	visual_offset = Vector2.ZERO
	var peak := -48.0
	var up_time: float = max(0.05, duration * 0.35)
	var down_time: float = max(0.05, duration * 0.65)
	var tw := create_tween()
	tw.tween_property(self, "visual_offset:y", peak, up_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "visual_offset:y", 0.0, down_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

## 검사자 패시브(리바이브 트릭컬) 발동 시 텍스트 대신 재생하는 빛무리 파티클.
## 자식 노드라 player.position(카메라 추종)을 그대로 따라간다.
func play_revive_light_burst(duration: float) -> void:
	var p := CPUParticles2D.new()
	p.name = "ReviveLightBurst"
	p.position = Vector2(rect.size) / 2.0
	p.z_index = 5
	p.amount = 48
	p.lifetime = 0.9
	p.explosiveness = 0.15
	p.one_shot = false
	p.emitting = true
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0.0, -60.0)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = Color(1.0, 0.96, 0.66, 0.95)
	add_child(p)

	var stop_timer := get_tree().create_timer(maxf(0.1, duration))
	stop_timer.timeout.connect(func():
		if is_instance_valid(p): p.emitting = false)
	var free_timer := get_tree().create_timer(duration + p.lifetime + 0.1)
	free_timer.timeout.connect(func():
		if is_instance_valid(p): p.queue_free())

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
var in_bush: bool = false        ## 현재 부쉬 내부인지 — 이동속도 감소 + 반투명 연출에 사용
var _move_frac: Vector2 = Vector2.ZERO   ## move_and_collide_map의 프레임 간 소수점 이동량 누적

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
	aim_dir = Vector2.RIGHT
	last_valid_mouse_world = Vector2(rect.get_center()) + aim_dir
	base_attack       = float(job.get("attack",       10.0))
	base_speed        = float(job.get("move_speed",  200.0))
	base_range        = float(job.get("range_px",    120.0))
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
	var eff_atk: float   = max(0.0,  base_attack + float(m[0]) - float(m[5]) + wind_bonus_attack)
	var eff_range: float = max(1.0,  base_range  + float(m[2]) + wind_bonus_range)
	var eff_spd: float   = max(10.0, base_speed  + float(m[3]) - float(m[7]))
	var eff_as: float    = max(0.08, base_attack_speed + float(m[4]) - float(m[8]) + wind_bonus_attack_speed)
	var old_max: float   = max(1.0, max_hp)
	var ratio     := clampf(hp / old_max, 0.0, 1.0)
	var eff_hp: float    = max(1.0, base_max_hp + float(m[1]) - float(m[6]))
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
	var new_max: float = max(1.0, hp_val)
	var ratio   := clampf(hp / max(1.0, max_hp), 0.0, 1.0)
	base_max_hp = new_max; max_hp = new_max; hp = max(1.0, min(max_hp, max_hp * ratio))
	refresh_stats()

func add_speed_buff(inc_pct: float, dur: float) -> void:
	speed_buff_inc  = max(speed_buff_inc, inc_pct)
	speed_buff_time = max(speed_buff_time, dur)
	refresh_stats()

func apply_damage(dmg: float, dmg_types: Array = []) -> float:
	var taken: float = max(0.0, dmg * (1.0 - minf(0.95, dec_damage_taken)))
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
	# 다비/쇼블러도 사거리 기준 근접 모드일 때 무기(고양이/삽) 스윙 모션을 재생한다.
	if jk == "swordsman" or jk == "shoveler" or jk == "darby": basic_swing_time = basic_swing_duration

# ═══════════════════════════════════════════════════════════════════════════
# ── 사거리 기반 근/원거리 평타 시스템 (독립) ─────────────────────────────────
# 직업 종류가 아니라 공격 시점의 "실제 attack_range 값"으로 매번 근/원거리를
# 새로 판정한다. 다비처럼 패시브로 사거리가 수시로 바뀌는 직업도 하드코딩된
# 직업 분기 없이 자동으로 대응된다 (attack_range < MELEE_RANGE_THRESHOLD → 근거리).
# ═══════════════════════════════════════════════════════════════════════════
const MeleeHitboxScript      := preload("res://scripts/melee_hitbox.gd")
const RangedProjectileScript := preload("res://scripts/ranged_projectile.gd")

const MELEE_RANGE_THRESHOLD := 140.0  ## 이 값 미만이면 근거리, 이상이면 원거리
const RANGED_PROJ_SPEED     := 640.0  ## 원거리 발사체 속도 (px/s)

signal basic_attack_hit(target: Node2D, damage: float, dmg_types: Array)

var scene_ref: Node2D     = null   ## game_scene 참조 — 발사체가 카메라 오프셋(cam_x/cam_y)을 읽는 데 사용
var is_attacking: bool    = false  ## 공격(근거리 스윙) 진행 중 여부 — 이동은 막지 않음, 상태 조회용
var _melee_hitbox: Area2D = null   ## 현재 활성화된 근거리 히트박스 (없으면 null)

## 좌클릭 시 game_scene이 호출하는 진입점. 방향은 aim_dir(이미 마우스 데드존 보정이
## 적용된 값)을 그대로 사용해 커서가 캐릭터 근처에 있어도 방향이 뒤틀리지 않는다.
func perform_basic_attack() -> bool:
	if revive_active or dead: return false
	if attack_lock_time > 0.0 or move_lock_time > 0.0: return false
	if attack_cd_rem > 0.0: return false

	var origin := Vector2(rect.get_center())
	var dir := aim_dir.normalized() if aim_dir.length() > 0.01 else Vector2(float(facing), 0.0)
	# facing(스프라이트 좌우 반전)은 handle_input()의 이동 방향이 유일한 기준 — 조준 방향으로는 갱신하지 않는다.

	attack_cd_rem = attack_cd
	is_attacking  = true

	if attack_range < MELEE_RANGE_THRESHOLD:
		_start_melee_attack(dir)
	else:
		_start_ranged_attack(origin, dir)
	return true

## 현재 검사자 Q 버프 등 상태에 따른 피해 유형 보정 — 평타뿐 아니라 E/R 등 모든 피해원이
## 적중 시점(캐스트 시점이 아님)에 이 함수를 거쳐야 Q 지속 중 실시간으로 true타입이 반영된다.
func get_effective_dmg_types(base_types: Array) -> Array:
	if job.get("key", "") == "swordsman" and q_buff_time > 0.0:
		return job.get("q_buffed_basic_dmg", ["true"])
	return base_types

## Q의 공격력 증가(inc_attack)는 평타 피해엔 attack 스탯을 통해 이미 반영되지만,
## E/R처럼 attack 스탯을 참조하지 않는 고정/비율 피해 공식은 별도로 이 배율을 곱해야 한다.
func get_effective_dmg_mult() -> float:
	if job.get("key", "") == "swordsman" and q_buff_time > 0.0:
		return 1.0 + inc_attack
	return 1.0

## 현재 검사자 Q 버프 등 상태에 따른 기본 공격 피해 유형 (직업별 예외를 이 한 곳에서 처리)
func _current_basic_dmg_types() -> Array:
	return get_effective_dmg_types(job.get("basic_dmg", ["physical"]))

func _start_melee_attack(dir: Vector2) -> void:
	start_basic_swing()
	# 애니메이션/히트박스 지속 시간을 공격 속도(attack_cd = 1/attack_speed)에 비례해 동기화.
	# 대난투 특성상 공격 중에도 자유롭게 움직일 수 있어야 하므로 이동 잠금은 걸지 않는다.
	var swing_duration := clampf(attack_cd * 0.4, 0.05, 0.5)

	var hb := Area2D.new()
	hb.name = "MeleeHitbox"
	hb.set_script(MeleeHitboxScript)
	add_child(hb)
	# 히트박스의 '시작점'이 캐릭터 중심(로컬 rect 중심)에 오도록 배치, 회전은 마우스 방향
	hb.position = Vector2(rect.size) / 2.0
	hb.rotation = dir.angle()
	hb.setup(self, attack_range)
	hb.hit_target.connect(_on_melee_hit)
	_melee_hitbox = hb

	get_tree().create_timer(swing_duration).timeout.connect(_end_melee_attack)

func _end_melee_attack() -> void:
	if is_instance_valid(_melee_hitbox): _melee_hitbox.queue_free()
	_melee_hitbox = null
	is_attacking  = false

func _on_melee_hit(target: Node2D) -> void:
	basic_attack_hit.emit(target, attack, _current_basic_dmg_types())

func _start_ranged_attack(origin: Vector2, dir: Vector2) -> void:
	var proj := Area2D.new()
	proj.name = "RangedAttackProjectile"
	proj.set_script(RangedProjectileScript)
	if scene_ref != null: scene_ref.add_child(proj)
	else: add_child(proj)
	proj.setup(self, scene_ref, origin, dir, RANGED_PROJ_SPEED,
		attack, attack_range, _current_basic_dmg_types())
	proj.hit_target.connect(_on_ranged_hit)

	is_attacking = false

func _on_ranged_hit(target: Node2D, dmg: float, types: Array) -> void:
	basic_attack_hit.emit(target, dmg, types)

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
	var rng := float(randi_range(20, 200)); var spd := float(randi_range(100, 500))
	var asp := randf_range(0.5, 2.5)
	set_base_stats(atk, hp_v, rng, spd, asp)
	if move_speed < 10.0: base_speed = 180.0; refresh_stats()

# ── 업데이트 ──────────────────────────────────────────────────────────────
func player_update(dt: float) -> void:
	if status != null: status.update(dt)
	_apply_airborne_position()

	# 걷기 진자 애니메이션 시간 누적 — 8방향(대각선·순수 상하 포함) 모두 이동 중이면 재생.
	# 스프라이트는 동서 모션 하나뿐이므로 방향과 무관하게 동일한 좌우 진자를 사용하고,
	# 좌우를 뒤집을지(facing)는 handle_input에서 "가장 최근의 좌우 이동 방향"으로 이미 결정됨.
	var is_moving := Vector2(vx, vy).length() > 5.0
	if is_moving and not dead and not revive_active:
		_walk_anim_time += dt * walk_swing_speed
	else:
		_walk_anim_time = 0.0

	attack_cd_rem = max(0.0, attack_cd_rem - dt)
	if basic_swing_time > 0.0:
		basic_swing_time = max(0.0, basic_swing_time - dt)
		var p: float = 1.0 - basic_swing_time / max(0.001, basic_swing_duration)
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
		if skill_passive != null and skill_passive.has_method("can_trigger") and skill_passive.can_trigger(self):
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
	# 스프라이트는 동서(좌우) 걷기 모션만 존재 — 남북 전용 모션 없음.
	# 북/북동/북서, 남/남동/남서 전부 동서 진자를 그대로 사용.
	# 순수 상하 이동(vx == 0)일 때는 facing을 갱신하지 않아
	# "가장 최근에 이동했던 좌우 방향"이 그대로 유지된다.
	if abs(vx) > 0.01: facing = 1 if vx > 0.0 else -1

## 탑다운 평면 충돌 — 부쉬(bush)는 통과 가능한 감속 지형, solids만 완전 차단
func move_and_collide_map(dt: float, map_solids: Array, map_bushes: Array, world_w: int, world_h: int) -> void:
	if dead: vx = 0.0; vy = 0.0; return
	prev_rect = rect

	var is_airborne: bool = status != null and status.has(StatusEffect.Kind.AIRBORNE)

	if not is_airborne:
		# 부쉬 내부에서는 이동속도 10% 감소 (은신·엄폐 지형 성격) + 외부에는 반투명으로 표시(_draw 참조)
		in_bush = false
		for b in map_bushes:
			if rect.intersects(b): in_bush = true; break
		var speed_mult := 0.9 if in_bush else 1.0

		# 소수점 이하 이동량을 프레임 간 누적해 저속/감속 상태에서도 int() 절삭으로
		# 이동량이 0이 되어 멈춰버리는 현상을 방지한다.
		_move_frac.x += vx * dt * speed_mult
		var step_x := int(_move_frac.x)
		_move_frac.x -= float(step_x)
		rect = Rect2i(rect.position + Vector2i(step_x, 0), rect.size)
		for p in map_solids:
			if rect.intersects(p):
				if vx > 0: rect.position.x = p.position.x - rect.size.x
				elif vx < 0: rect.position.x = p.position.x + p.size.x

		_move_frac.y += vy * dt * speed_mult
		var step_y := int(_move_frac.y)
		_move_frac.y -= float(step_y)
		rect = Rect2i(rect.position + Vector2i(0, step_y), rect.size)
		for p in map_solids:
			if rect.intersects(p):
				if vy > 0: rect.position.y = p.position.y - rect.size.y
				elif vy < 0: rect.position.y = p.position.y + p.size.y
	else:
		in_bush = false

	on_ground = true   # 탑다운에는 낙하 개념이 없으므로 항상 지면 취급

	rect.position.x = clampi(rect.position.x, 0, world_w - rect.size.x)
	rect.position.y = clampi(rect.position.y, 0, world_h - rect.size.y)
	position = Vector2(rect.position)

# ── _draw ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	if dead: return
	var jk: String = job.get("key", "")
	var buried_now := is_buried()
	var buried_oy := 0.0
	# 지면 아래로 가라앉는 방향(+)으로 크게 내려 머리만 살짝 보이게 한다.
	# (기존 부호는 위로 띄우는 방향이라 "파묻힘"으로 읽히지 않던 버그)
	if buried_now: buried_oy = rect.size.y * 1.3

	var spr_x := float(rect.size.x / 2 - SPR_W / 2)
	var spr_y := float(rect.size.y - SPR_H) + buried_oy
	var spr_rect := Rect2(spr_x, spr_y, float(SPR_W), float(SPR_H))
	# 시각 전용 오프셋이 적용된 스프라이트 사각형 (히트박스인 rect/spr_rect는 그대로 유지)
	var visual_spr_rect := Rect2(spr_rect.position + visual_offset, spr_rect.size)

	# 착지 지점 가이드 (에어본/넉백 중)
	var ab := airborne_status()
	if ab != null: _draw_landing_guide(ab)

	# 그림자 — 스프라이트가 Tween으로 떠 있는 동안에도 지면(spr_rect) 기준으로 고정
	if absf(visual_offset.y) > 0.5:
		var shadow_ctr := Vector2(spr_rect.get_center().x, spr_rect.position.y + spr_rect.size.y - 6.0)
		var shrink := clampf(1.0 - absf(visual_offset.y) / 60.0, 0.35, 1.0)
		draw_set_transform(shadow_ctr, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, (SPR_W / 2.5) * shrink, Color(0.0, 0.0, 0.0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 사거리 링
	if is_human:
		draw_arc(Vector2(rect.size.x / 2.0, rect.size.y / 2.0),
			max(40.0, attack_range), 0.0, TAU, 64, Color(1.0, 0.922, 0.275, 0.5), 5.0)

	# Wind Q 오라
	if jk == "wind_archer" and wind_q_active:
		var atex := _tex_wind_q_fancy if wind_q_time > 3.0 else _tex_wind_q_simple
		if atex:
			var ctr := Vector2(visual_spr_rect.get_center())
			draw_texture(atex, ctr - Vector2(atex.get_width() / 2.0, atex.get_height() / 2.0))

	# Swordsman Q 방어막
	if jk == "swordsman" and q_buff_time > 0.0:
		var ctr := Vector2(visual_spr_rect.get_center()); var sr := 59.0
		draw_circle(ctr, sr, Color(0.471, 0.824, 1.0, 0.216))
		draw_arc(ctr, sr, 0.0, TAU, 48, Color(0.706, 0.922, 1.0, 0.706), 4.0)

	# Darby R 오라
	if jk == "darby" and darby_r_active:
		var ctr := Vector2(visual_spr_rect.get_center())
		var ar  := Rect2(visual_spr_rect.position - Vector2(20, 20), visual_spr_rect.size + Vector2(40, 40))
		draw_rect(ar, Color(0.784, 0.157, 0.235, 0.314))
		draw_rect(ar, Color(1.0, 0.314, 0.392, 0.588), false)

	# Shovel 묻힘 표시 (삽 스택 dots)
	var stack_n := shovel_stack_count()
	if buried_now: stack_n = 6
	if stack_n > 0 and stack_n < 6:
		for i in range(stack_n):
			var dot_col := Color(0.478, 0.082, 0.082) if stack_n >= 5 else Color(0.941, 0.941, 0.941)
			draw_circle(Vector2(4.0 + i * 10.0, spr_y + visual_offset.y - 10.0), 4.0, dot_col)

	# 바디 스프라이트
	var use_tex: ImageTexture = null
	if jk == "wind_archer":
		use_tex = _tex_body_e if (wind_e_active and _tex_body_e != null) else _tex_body
	else:
		use_tex = _tex_body

	# 부쉬 내부에서는 반투명 처리 — 은신·엄폐 지형 성격을 외부에서도 알아볼 수 있게 한다.
	var body_modulate := Color(1.0, 1.0, 1.0, 0.45) if in_bush else Color(1.0, 1.0, 1.0, 1.0)

	if use_tex:
		var tw := float(use_tex.get_width()); var th := float(use_tex.get_height())
		if jk == "swordsman" and r_active:
			var ctr := Vector2(visual_spr_rect.get_center())
			draw_set_transform(ctr, deg_to_rad(-spin_angle), Vector2(float(SPR_W) / tw * facing, float(SPR_H) / th))
			draw_texture(use_tex, Vector2(-tw / 2.0, -th / 2.0), body_modulate)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif walk_swing_enabled and _walk_anim_time > 0.0:
			_draw_body_with_walk_pendulum(use_tex, tw, th, visual_spr_rect, body_modulate)
		else:
			# 반전은 항상 draw_set_transform의 음수 x 스케일로 처리한다 (r_active 스핀·
			# 걷기 진자와 동일한 검증된 방식). 음수 폭 소스 Rect2로 반전을 시도하면
			# 부분 UV 영역(파묻힘 클리핑 등)에서 아무것도 그려지지 않아 서쪽을 볼 때
			# 캐릭터가 통째로 사라지던 버그가 있었다.
			if buried_now:
				# 파묻힘: 지면 위로 드러난 부분(머리)만 그려 몸통이 무덤 밖으로 새어나오지 않게 한다.
				# 무덤 자체는 game_scene의 공용 지면 레이어가 맵 바로 위에 별도로 그린다.
				var visible_h := clampf(float(rect.size.y) - visual_spr_rect.position.y, 4.0, visual_spr_rect.size.y)
				var src_h := th * (visible_h / spr_rect.size.y)
				var head_ctr := Vector2(visual_spr_rect.get_center().x, visual_spr_rect.position.y + visible_h / 2.0)
				draw_set_transform(head_ctr, 0.0, Vector2(float(facing), 1.0))
				draw_texture_rect_region(use_tex,
					Rect2(-visual_spr_rect.size.x / 2.0, -visible_h / 2.0, visual_spr_rect.size.x, visible_h),
					Rect2(0.0, 0.0, tw, src_h), body_modulate)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var ctr := Vector2(visual_spr_rect.get_center())
				draw_set_transform(ctr, 0.0, Vector2(float(facing), 1.0))
				draw_texture_rect_region(use_tex,
					Rect2(-visual_spr_rect.size.x / 2.0, -visual_spr_rect.size.y / 2.0,
						visual_spr_rect.size.x, visual_spr_rect.size.y),
					Rect2(0.0, 0.0, tw, th), body_modulate)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var fallback_col := Color(0.9, 0.9, 1.0) if team == "blue" else Color(1.0, 0.7, 0.7)
		fallback_col.a = body_modulate.a
		draw_rect(visual_spr_rect, fallback_col)

	# 색조
	if tint_color != Color.TRANSPARENT:
		var tc := tint_color; tc.a = 0.35; draw_rect(visual_spr_rect, tc)

	# Swordsman 검
	if jk == "swordsman":
		var ctr := Vector2(visual_spr_rect.get_center()); var top := visual_spr_rect.position.y
		var sw := 26.0; var sh := 74.0; var cx := sw / 2.0; var cy := sh / 2.0
		if r_active:
			draw_set_transform(ctr, deg_to_rad(-spin_angle), Vector2(float(facing), 1.0))
			_draw_sword_shape(cx, cy)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var pivot := Vector2(ctr.x + float(facing) * 24.0, top + 19.0)
			var angle := (18.0 + basic_swing_angle) if facing >= 0 else (-18.0 - basic_swing_angle)
			draw_set_transform(pivot, deg_to_rad(angle), Vector2(float(facing), 1.0))
			_draw_sword_shape(cx, cy)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Wind Archer 활
	if jk == "wind_archer" and not wind_e_active:
		var ctr := Vector2(visual_spr_rect.get_center())
		var bw := 24.0; var bh := 18.0
		var bx := ctr.x + 4.0 if facing >= 0 else ctr.x - bw - 4.0
		draw_set_transform(Vector2(bx + bw / 2.0, ctr.y - 8.0 + bh / 2.0), 0.0, Vector2(float(facing), 1.0))
		_draw_bow_shape(bw, bh)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Darby 고양이 (근접 냥냥펀치 모드 — 현재 사거리가 근접 기준일 때만 착용 표시)
	if jk == "darby" and attack_range < MELEE_RANGE_THRESHOLD:
		var ctr := Vector2(visual_spr_rect.get_center()); var top := visual_spr_rect.position.y
		var cx := 12.0; var cy := 40.0
		var pivot := Vector2(ctr.x + float(facing) * 20.0, top + 24.0)
		var angle := (18.0 + basic_swing_angle) if facing >= 0 else (-18.0 - basic_swing_angle)
		draw_set_transform(pivot, deg_to_rad(angle), Vector2(float(facing), 1.0))
		_draw_cat_shape(cx, cy)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Shoveler 삽
	if jk == "shoveler":
		var ctr := Vector2(visual_spr_rect.get_center()); var top := visual_spr_rect.position.y
		var cx := 10.0; var cy := 43.0
		var pivot := Vector2(ctr.x + float(facing) * 22.0, top + 20.0)
		var angle := (18.0 + basic_swing_angle) if facing >= 0 else (-18.0 - basic_swing_angle)
		draw_set_transform(pivot, deg_to_rad(angle), Vector2(float(facing), 1.0))
		_draw_shovel_shape(cx, cy)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# HP 바 (스프라이트를 따라 함께 떠오름)
	if max_hp > 0.0:
		var ratio := maxf(0.0, minf(1.0, hp / max_hp))
		var by    := spr_y + visual_offset.y - 24.0
		draw_rect(Rect2(0, by, float(rect.size.x), 6.0), Color(0, 0, 0))
		draw_rect(Rect2(0, by, float(rect.size.x) * ratio, 6.0),
			Color(0.275, 0.51, 1.0) if team == "blue" else Color(1.0, 0.31, 0.31))

	# Wind 패시브 스택 — 캐릭터 머리 위가 아니라 주위를 도는 최대 4개의 오브로 표시
	if jk == "wind_archer" and wind_passive_stacks > 0:
		var orbit_ctr := Vector2(visual_spr_rect.get_center())
		var orbit_r := SPR_W * 0.62
		var spin_t := Time.get_ticks_msec() / 1000.0 * 2.2
		for i in range(wind_passive_stacks):
			var a := spin_t + float(i) * (TAU / 4.0)
			var orb_pos := orbit_ctr + Vector2(cos(a), sin(a) * 0.6) * orbit_r
			draw_circle(orb_pos, 5.0, Color(0.235, 0.784, 0.847))
			draw_arc(orb_pos, 5.0, 0.0, TAU, 10, Color(0.7, 0.98, 1.0, 0.8), 1.5)

	# 파묻힘 흙무덤 자체는 이 노드(캐릭터)보다 낮은 z-order가 필요해 여기서 그리지 않는다.
	# game_scene의 공용 지면 레이어(맵 바로 위, 모든 캐릭터/요소보다 아래)가 대신 그린다.
	# 이 노드는 스프라이트를 지면 위로 드러난 부분(머리)만 그려 무덤 밖으로 새어나오지 않게 한다.

## 에어본/넉백 중 착지 예정 지점을 링으로 표시 — 경과 비율에 따라 반경이 서서히 줄어들며 착지 타이밍을 안내.
## 정확한 착지 좌표를 드러내는 판정 정보이므로 연습 모드에서만 그린다.
func _draw_landing_guide(ab: AirborneStatus) -> void:
	if not Global.is_practice_mode: return
	var local_target := Vector2(ab.landing_pos) - Vector2(rect.position) + Vector2(rect.size) / 2.0
	var t := 1.0 - clampf(ab.time_left / max(0.001, ab.total_duration), 0.0, 1.0)
	var r := lerpf(30.0, 12.0, t)
	draw_set_transform(local_target, 0.0, Vector2(1.0, 0.4))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(1.0, 0.35, 0.35, 0.85), 3.0)
	draw_circle(Vector2.ZERO, r * 0.3, Color(1.0, 0.35, 0.35, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 걷기 진자 애니메이션 — 텍스처를 자르지 않고 소스 UV를 머리/몸통으로 나눠 두 번 그린다.
## 머리는 고정, 몸통만 머리 밑동을 축으로 좌우로 흔들려 걷는 느낌을 낸다.
## 좌우 반전은 (음수 폭 소스 Rect2가 아니라) r_active 스핀·검/활 그리기와 동일한
## transform scale 방식으로 처리한다 — 부분 UV 분할에 음수 폭을 쓰면 아무것도
## 그려지지 않는 문제가 있어 서쪽(facing<0) 이동 시 캐릭터가 통째로 사라지던 버그의 원인이었다.
func _draw_body_with_walk_pendulum(tex: ImageTexture, tw: float, th: float, spr_rect: Rect2,
		modulate: Color = Color.WHITE) -> void:
	var pivot_y_src := th * walk_pivot_ratio
	var scale_x := float(facing)

	# 머리: 고정, 회전 없음. 반전만 transform scale로 적용.
	var head_src := Rect2(0.0, 0.0, tw, pivot_y_src)
	var head_h := spr_rect.size.y * walk_pivot_ratio
	var head_ctr := Vector2(spr_rect.get_center().x, spr_rect.position.y + head_h / 2.0)
	draw_set_transform(head_ctr, 0.0, Vector2(scale_x, 1.0))
	draw_texture_rect_region(tex, Rect2(-spr_rect.size.x / 2.0, -head_h / 2.0, spr_rect.size.x, head_h),
		head_src, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 몸통: 머리 밑동을 축으로 좌우 진자 회전 + 반전(같은 transform에 포함)
	var body_src := Rect2(0.0, pivot_y_src, tw, th - pivot_y_src)
	var body_h := spr_rect.size.y * (1.0 - walk_pivot_ratio)
	var body_dst_local := Rect2(-spr_rect.size.x / 2.0, 0.0, spr_rect.size.x, body_h)
	var swing_angle_deg := sin(_walk_anim_time) * walk_swing_deg
	var pivot_point := Vector2(spr_rect.get_center().x, spr_rect.position.y + spr_rect.size.y * walk_pivot_ratio)
	draw_set_transform(pivot_point, deg_to_rad(swing_angle_deg), Vector2(scale_x, 1.0))
	draw_texture_rect_region(tex, body_dst_local, body_src, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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

## 다비 근접 무기 — 냥냥펀치용 고양이. 목덜미를 잡고 몽둥이처럼 휘두르는 모양새(꼬리쪽이 손잡이).
func _draw_cat_shape(cx: float, cy: float) -> void:
	var ox := -cx; var oy := -cy
	var fur := Color(0.906, 0.706, 0.373); var fur_dark := Color(0.706, 0.510, 0.235)
	var ink := Color(0.106, 0.106, 0.122)
	# 꼬리 (손잡이 역할)
	draw_line(Vector2(ox+cx+7.0, oy+56.0), Vector2(ox+cx+15.0, oy+74.0), fur_dark, 4.0)
	# 몸통
	draw_set_transform(Vector2(ox+cx, oy+48.0), 0.0, Vector2(1.0, 1.35))
	draw_circle(Vector2.ZERO, 11.0, fur)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 머리
	draw_circle(Vector2(ox+cx, oy+18.0), 11.0, fur)
	var ear_l := PackedVector2Array([Vector2(ox+cx-9.0,oy+11.0),Vector2(ox+cx-3.0,oy+11.0),Vector2(ox+cx-7.0,oy+1.0)])
	var ear_r := PackedVector2Array([Vector2(ox+cx+3.0,oy+11.0),Vector2(ox+cx+9.0,oy+11.0),Vector2(ox+cx+7.0,oy+1.0)])
	draw_colored_polygon(ear_l, fur_dark)
	draw_colored_polygon(ear_r, fur_dark)
	draw_circle(Vector2(ox+cx-4.0, oy+18.0), 1.6, ink)
	draw_circle(Vector2(ox+cx+4.0, oy+18.0), 1.6, ink)
	# 앞발 (앞으로 뻗은 펀치 포즈)
	draw_circle(Vector2(ox+cx-9.0, oy+34.0), 4.0, fur)
	draw_circle(Vector2(ox+cx+9.0, oy+34.0), 4.0, fur)

## 쇼블러 근접 무기 — 삽
func _draw_shovel_shape(cx: float, cy: float) -> void:
	var ox := -cx; var oy := -cy
	var wood := Color(0.471, 0.353, 0.157); var steel := Color(0.706, 0.706, 0.745); var steel_dark := Color(0.471, 0.471, 0.510)
	# 자루
	draw_rect(Rect2(ox+cx-3.0, oy+8.0, 6.0, 50.0), wood)
	# D자형 손잡이
	draw_arc(Vector2(ox+cx, oy+8.0), 7.0, PI, TAU, 12, wood, 3.0)
	# 삽날
	var blade := PackedVector2Array([
		Vector2(ox+cx-10.0, oy+56.0), Vector2(ox+cx+10.0, oy+56.0),
		Vector2(ox+cx+8.0, oy+76.0), Vector2(ox+cx-8.0, oy+76.0)])
	draw_colored_polygon(blade, steel)
	draw_rect(Rect2(ox+cx-11.0, oy+54.0, 22.0, 5.0), steel_dark)
