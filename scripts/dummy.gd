# dummy.gd — Python dummy.py 완전 이식 (모든 직업 호환)
# 상태이상(슬로우, 삽질 스택, 매장, 에어본)은 StatusEffectManager가 단일 진실 공급원.
extends Node2D

var status: StatusEffectManager = null

var max_hp: float = 2000.0
var hp: float     = 2000.0
var team: String  = "neutral"
var rect := Rect2i(0, 0, 34, 48)
var vx: float = 0.0; var vy: float = 0.0
var on_ground: bool = true   # 탑다운 전환으로 낙하 개념 없음, 하위호환용

# 공격/스킬 호환 변수
var attack: float       = 0.0
var move_speed: float   = 0.0
var attack_speed: float = 0.5
var attack_range: float = 0.0

# 잠금
var move_lock_time: float   = 0.0
var attack_lock_time: float = 0.0
var skill_lock_time: float  = 0.0

# Shoveler 호환 (스택 개수/매장 여부는 status 매니저에서 조회)
var shovel_immunity_time: float = 0.0
var _shovel_dust_lock: float    = 0.0

# 슬로우 표시용 (실제 이동속도 배율은 SlowedStatus가 slow_mult에 직접 기록)
var slow_mult: float = 1.0
var slow_time: float = 0.0

# 색조 (다비 R 등에서 참조 가능하도록 더미도 보유)
var tint_color: Color = Color.TRANSPARENT
var tint_time: float  = 0.0

var total_damage_taken: float = 0.0
var last_damage: float        = 0.0
var last_damage_t: float      = 0.0

func setup(sx: int, sy: int) -> void:
	rect = Rect2i(sx, sy, 34, 48); position = Vector2(rect.position)
	status = StatusEffectManager.new()
	status.bind(self)

func center() -> Vector2:
	return Vector2(rect.get_center())

## 현재 삽질 스택 개수
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

## 현재 에어본(공중 판정) 상태 여부
func is_airborne() -> bool:
	return status.has(StatusEffect.Kind.AIRBORNE) if status != null else false

func airborne_status() -> AirborneStatus:
	if status == null: return null
	var e := status.get_effect(StatusEffect.Kind.AIRBORNE)
	return e as AirborneStatus

func _apply_airborne_position() -> void:
	var ab := airborne_status()
	if ab == null: return
	rect.position = Vector2i(ab.get_current_pos())
	position = Vector2(rect.position)

func take_damage(dmg: float, _types: Array = []) -> float:
	hp -= dmg; total_damage_taken += dmg; last_damage = dmg; last_damage_t = 1.2; return dmg

func apply_damage(dmg: float, types: Array = []) -> float:
	return take_damage(dmg, types)

## 탑다운 더미 갱신 — 낙하/중력 없음. 에어본(공중 판정) 중에도 위치는 고정,
## Player 쪽 AirborneStatus가 화면 연출(Tween)과 스턴만 담당한다.
func dummy_update(dt: float, map_solids: Array, map_bushes: Array = []) -> void:
	if status != null: status.update(dt)
	_apply_airborne_position()

	if last_damage_t > 0.0: last_damage_t = max(0.0, last_damage_t - dt)
	move_lock_time   = max(0.0, move_lock_time   - dt)
	attack_lock_time = max(0.0, attack_lock_time - dt)
	skill_lock_time  = max(0.0, skill_lock_time  - dt)
	shovel_immunity_time = max(0.0, shovel_immunity_time - dt)
	_shovel_dust_lock    = max(0.0, _shovel_dust_lock    - dt)

	# 더미는 고정 대상이므로 vx/vy를 쓰지 않음 (호환 필드만 유지)
	position = Vector2(rect.position)
	queue_redraw()

func _draw() -> void:
	var buried_oy := 0.0
	if is_buried(): buried_oy = rect.size.y * 0.6
	var r := Rect2(0, buried_oy, rect.size.x, rect.size.y)
	draw_rect(r, Color(0.549,0.353,0.196), true, -1.0, true)
	draw_rect(r, Color(0.196,0.118,0.078), false, 2.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(rect.size.x/2.0-22.0, -6.0 + buried_oy),
		"DMG %d" % int(total_damage_taken), HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1.0,0.922,0.706))
	if last_damage_t > 0.0:
		draw_string(font, Vector2(rect.size.x/2.0-14.0, -20.0 + buried_oy),
			"-%d" % int(last_damage), HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1.0,0.784,0.471))
	# Shovel 스택 점
	var stk := shovel_stack_count()
	if is_buried(): stk = 6
	if stk > 0 and stk < 6:
		for i in range(stk):
			var col := Color(0.478,0.082,0.082) if stk >= 5 else Color(0.941,0.941,0.941)
			draw_circle(Vector2(4.0 + i*10.0, buried_oy - 10.0), 4.0, col)
