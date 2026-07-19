# jobs/shoveler/e.gd — 평화 속 나머지
# 값은 인스펙터에서 조정 가능.
class_name ShovelerE
extends Resource

@export_group("묘석 크기")
@export var tomb_w: int = 56   ## 너비 (픽셀)
@export var tomb_h: int = 86   ## 높이 (픽셀)

@export_group("스폰 위치")
@export var spawn_offset_x: float = 70.0  ## 캐릭터 앞 거리 (픽셀)
@export var ground_search_range: int = 40 ## 지면 탐색 범위 (±픽셀)

@export_group("피해 / 물리")
@export var hit_damage:     float = 100.0  ## 최초 판정 피해
@export var rise_speed:     float = 400.0  ## 솟아오르는 속도 (px/s)
@export var solid_duration: float = 5.0    ## 발판 유지 시간 (초)

func can_use(player) -> bool:
	return player.e_cd_rem <= 0.0 \
		and not player.revive_active \
		and player.skill_lock_time <= 0.0

## 탑다운 버전: 지면 Y 탐색 대신 aim_dir(마우스 방향)의 spawn_offset_x 거리에 그대로 배치.
func get_spawn_params(player, _map_solids: Array = [], _world_h: int = 0) -> Dictionary:
	var aim: Vector2 = player.aim_dir.normalized() if player.aim_dir.length() > 0.0 else Vector2.RIGHT
	var center: Vector2 = Vector2(player.rect.get_center()) + aim * spawn_offset_x
	var tomb_x := int(center.x - tomb_w / 2.0)
	var tomb_y := int(center.y - tomb_h / 2.0)

	return {
		"rect":       Rect2i(tomb_x, tomb_y, tomb_w, tomb_h),
		"start_y":    float(tomb_y),   ## 하위호환 필드 (탑다운에서는 솟아오름 연출의 알파/스케일 시작점으로만 사용)
		"target_y":   float(tomb_y),
		"hit_rect":   Rect2i(tomb_x, tomb_y, tomb_w, tomb_h),
		"damage":     hit_damage,
		"rise_speed": rise_speed,
		"duration":   solid_duration,
	}

func activate(player) -> void:
	player.e_cd_rem = float(player.job.get("e_cd", 24.0))
