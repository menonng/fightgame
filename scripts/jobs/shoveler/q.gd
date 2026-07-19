# jobs/shoveler/q.gd — 삽질 (탑다운 버전)
# 기존: 좌우 방향으로 포물선 발사. 탑다운: aim_dir(마우스 방향) 기준 부채꼴로 흙을 뿌림.
class_name ShovelerQ
extends Resource

@export_group("흙 파티클 개수")
@export var particle_count_min: int = 70
@export var particle_count_max: int = 100

@export_group("발사 속도 범위 (px/s)")
@export var speed_min: float = 220.0  ## 최소 발사 속도
@export var speed_max: float = 520.0  ## 최대 발사 속도

@export_group("부채꼴 퍼짐")
@export var spread_angle_deg: float = 50.0  ## aim_dir 기준 좌우로 퍼지는 최대 각도(도)

@export_group("발사 위치 오프셋")
@export var spawn_offset: float = 20.0  ## 캐릭터 중심에서 조준 방향으로 떨어진 발사 거리

func can_use(player) -> bool:
	return player.q_cd_rem <= 0.0 and not player.revive_active

func get_spawn_list(player) -> Array:
	var aim: Vector2 = player.aim_dir.normalized() if player.aim_dir.length() > 0.0 else Vector2.RIGHT
	var base_angle := aim.angle()
	var base_pos: Vector2 = Vector2(player.rect.get_center()) + aim * spawn_offset

	var count := randi_range(particle_count_min, particle_count_max)
	var result: Array = []
	var half_spread := deg_to_rad(spread_angle_deg)
	for i in range(count):
		var a := base_angle + randf_range(-half_spread, half_spread)
		var spd := randf_range(speed_min, speed_max)
		var dir := Vector2(cos(a), sin(a))
		result.append({
			"wx": base_pos.x, "wy": base_pos.y,
			"vx": dir.x * spd, "vy": dir.y * spd,
		})
	return result

func activate(player) -> void:
	player.q_cd_rem = float(player.job.get("q_cd", 15.0))
