# jobs/wind_archer/r.gd — 신궁
# 값은 인스펙터에서 조정 가능. 피격 시 AirborneStatus(에어본)를 부여.
class_name WindArcherR
extends Resource

@export_group("투사체 수치")
@export var proj_speed:  float = 850.0  ## 투사체 속도 (px/s)
@export var proj_damage: float = 400.0  ## 피해량
@export var proj_radius: int   = 44     ## 판정 반경 (픽셀)
@export var proj_life:   float = 2.2    ## 최대 지속 시간 (초)
@export var proj_color:  Color = Color(0.471, 1.0, 0.824)

@export_group("에어본 (탑다운: 위로 띄우는 넉업 + 스턴)")
@export var airborne_duration: float = 0.6  ## 스턴 및 공중에 뜬 상태 지속 시간 (초)
## 위로 띄우기만 하고 지면상의 위치는 옮기지 않는다 — 지속시간이 끝나면 원래 있던
## 자리로 그대로 돌아온다(0이면 landing_pos == start_pos가 되어 이동이 발생하지 않음).
@export var knockback_dist:    float = 0.0

@export_group("발사 위치 오프셋")
@export var spawn_offset_x: float = 40.0   ## 발사 위치 x 오프셋
@export var spawn_offset_y: float = -12.0  ## 발사 위치 y 오프셋

@export_group("피해 유형")
@export var dmg_types: Array[String] = ["physical"]  ## R 화살 피해 유형

func can_use(player) -> bool:
	return not player.revive_active \
		and player.r_cd_rem <= 0.0 \
		and not player.r_active \
		and player.skill_lock_time <= 0.0

## 발동 파라미터 반환 — game_scene이 Projectile 노드 생성 시 사용.
## 탑다운: 좌우 고정 방향(dir_x/dir_y) 대신 aim_dir(마우스 방향) 360도 조준.
func get_spawn_params(player) -> Dictionary:
	var aim: Vector2 = player.aim_dir.normalized() if player.aim_dir.length() > 0.0 else Vector2.RIGHT
	var spawn_pos: Vector2 = Vector2(player.rect.get_center()) + aim.rotated(0.0) * spawn_offset_x + Vector2(0, spawn_offset_y)
	return {
		"world_x":  spawn_pos.x,
		"world_y":  spawn_pos.y,
		"dir_x":    aim.x,
		"dir_y":    aim.y,
		"speed":    proj_speed,
		"damage":   proj_damage,
		"radius":   proj_radius,
		"color":    proj_color,
		"life":     proj_life,
		"pierce":   true,
		"dmg_types": dmg_types,
		"texture":  "res://assets/wind_r_arrow.png",
	}

func activate(player) -> void:
	player.r_cd_rem = float(player.job.get("r_cd", 100.0))

## 피격 대상에게 에어본(넉업+스턴) 부여 — game_scene의 충돌 처리에서 호출.
## knockback_direction: 위로 뜨는 시각 연출 방향(정규화 필요 없음, 내부에서 정규화) —
## knockback_dist가 0이라 실제 이동에는 영향이 없고, 지속시간이 끝나면 원위치로 돌아온다.
func apply_airborne_on_hit(target, knockback_direction: Vector2) -> void:
	if target.status == null:
		return
	target.status.apply(AirborneStatus.new(airborne_duration, knockback_direction, knockback_dist))
