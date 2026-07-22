# melee_hitbox.gd — 사거리 기반 평타 시스템: 근거리(사거리 < 70) 히트박스
# player.gd의 자식 노드로 scenes/objects/melee_hitbox.tscn을 instantiate()해 생성된다.
# 부모(player)의 로컬 좌표계를 그대로 물려받으므로, 이 노드의 position/rotation만
# 조절하면 카메라 스크롤과 무관하게 항상 캐릭터 기준으로 정확히 따라다닌다.
#
# 히트박스는 '중심점'이 아니라 '시작점'이 원점(부모 기준 캐릭터 중심)에 오도록
# CollisionShape2D를 오른쪽으로 length/2만큼 밀어서 배치하고, 이 노드 전체의
# rotation을 마우스 방향 각도로 맞춰 캐릭터 앞으로 정확히 뻗어나가게 한다.
# CollisionShape2D/RectangleShape2D는 씬에 미리 저작되어 있고(동적 생성 없음),
# setup()은 그 shape의 크기/위치만 갱신한다.
class_name MeleeHitbox
extends Area2D

signal hit_target(target: Node2D)

const WIDTH := 34.0        ## 히트박스 폭(고정)
const HURTBOX_MASK := 2    ## project.godot [layer_names] 2d_physics/layer_2 = "Hurtbox"

@onready var _col: CollisionShape2D = $CollisionShape2D

var owner_node: Node2D = null
var _hit_targets: Array = []   ## 이번 공격 사이클 동안 이미 타격한 대상 (중복 대미지 방지)
var _length: float = 0.0       ## 현재 히트박스 길이 — _draw()가 get_children()으로 되짚지 않도록 캐시

## p_length: 캐릭터의 attack_range 값 — 히트박스 길이에 그대로 비례.
func setup(p_owner: Node2D, p_length: float) -> void:
	owner_node = p_owner
	_hit_targets.clear()

	_length = maxf(1.0, p_length)
	(_col.shape as RectangleShape2D).size = Vector2(_length, WIDTH)
	_col.position = Vector2(_length / 2.0, 0.0)   # 시작점(왼쪽 변)을 원점에 정렬

	monitoring   = true
	monitorable  = false
	collision_layer = 0
	collision_mask  = HURTBOX_MASK
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null or target == owner_node: return
	if target in _hit_targets: return
	_hit_targets.append(target)
	hit_target.emit(target)

func _draw() -> void:
	# 판정 범위 시각화 — 연습 모드 전용. 멀티플레이에서는 상대에게 정확한 히트박스를
	# 노출하지 않도록 아무것도 그리지 않는다 (실제 검격 연출은 player.gd가 별도로 그림).
	if not Global.is_practice_mode: return
	if _length <= 0.0: return
	draw_rect(Rect2(0.0, -WIDTH / 2.0, _length, WIDTH), Color(1.0, 0.9, 0.6, 0.35))
	draw_arc(Vector2.ZERO, _length, -0.5, 0.5, 16, Color(1.0, 0.95, 0.7, 0.6), 3.0)
