# ranged_projectile.gd — 사거리 기반 평타 시스템: 원거리(사거리 >= 70) 발사체
# player.gd가 인스턴스화하여 scene_ref(게임 씬)의 자식으로 추가한다. 카메라가 매
# 프레임 이동하는 이 프로젝트 구조에 맞춰, 자신의 월드 좌표(_world_pos)를 직접
# 추적하고 scene_ref의 카메라 오프셋(cam_x/cam_y)을 읽어 화면 좌표로 변환한다.
class_name RangedAttackProjectile
extends Area2D

signal hit_target(target: Node2D, damage: float, dmg_types: Array)

const RADIUS := 10.0
const HURTBOX_MASK := 2       ## project.godot [layer_names] 2d_physics/layer_2 = "Hurtbox"
const RANGE_GRACE_TIME := 0.5 ## 사거리 초과 후 소멸까지 유예 시간(초)

var owner_node: Node2D = null
var scene_ref: Node2D  = null   ## cam_x/cam_y를 읽기 위한 게임 씬 참조
var damage: float      = 0.0
var dmg_types: Array   = ["physical"]
var _hit_targets: Array = []    ## 이 발사체 수명 동안 이미 타격한 대상 (중복 대미지 방지)

var _world_pos: Vector2  = Vector2.ZERO
var _dir: Vector2         = Vector2.RIGHT
var _speed: float         = 640.0
var _max_range: float     = 0.0
var _dist_travelled: float = 0.0
var _over_range: bool     = false   ## 사거리를 벗어나 유예 타이머가 이미 시작됐는지

func setup(p_owner: Node2D, p_scene: Node2D, p_world_pos: Vector2, p_dir: Vector2,
		p_speed: float, p_damage: float, p_max_range: float, p_types: Array) -> void:
	owner_node = p_owner; scene_ref = p_scene
	_world_pos = p_world_pos
	_dir       = p_dir.normalized() if p_dir.length() > 0.0 else Vector2.RIGHT
	_speed     = p_speed; damage = p_damage; _max_range = p_max_range; dmg_types = p_types
	_hit_targets.clear()

	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	monitoring  = true
	monitorable = false
	collision_layer = 0
	collision_mask  = HURTBOX_MASK
	area_entered.connect(_on_area_entered)
	_sync_screen_position()

func _process(dt: float) -> void:
	var step := _dir * _speed * dt
	_world_pos += step
	_dist_travelled += step.length()
	_sync_screen_position()
	queue_redraw()

	if not _over_range and _max_range > 0.0 and _dist_travelled > _max_range:
		_over_range = true
		# 사거리 초과 즉시 제거하지 않고 0.5초간 유지 후 안전하게 소멸 (Timer 유예)
		get_tree().create_timer(RANGE_GRACE_TIME).timeout.connect(queue_free)

func _sync_screen_position() -> void:
	var off := Vector2.ZERO
	if scene_ref != null:
		off = Vector2(-scene_ref.get("cam_x"), -scene_ref.get("cam_y"))
	position = _world_pos + off

func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null or target == owner_node: return
	if target in _hit_targets: return
	_hit_targets.append(target)
	hit_target.emit(target, damage, dmg_types)

func _draw() -> void:
	var alpha := 1.0
	if _over_range: alpha = 0.5   # 사거리 초과 유예 구간 — 서서히 옅어지는 느낌
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.85, 0.4, alpha))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, alpha), 2.0)
