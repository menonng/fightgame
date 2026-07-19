# jobs/wind_archer/e.gd — il vento d'oro
# 값은 인스펙터에서 조정 가능.
class_name WindArcherE
extends Resource

@export_group("비행 모드 수치")
@export var duration: float = 5.0   ## 지속 시간 (초)

func can_use(player) -> bool:
	return not player.revive_active \
		and player.e_cd_rem <= 0.0 \
		and not player.wind_e_active \
		and player.skill_lock_time <= 0.0

func activate(player) -> void:
	player.wind_e_active = true
	player.wind_e_time   = duration

func update(player, dt: float) -> void:
	if not player.wind_e_active:
		return
	player.wind_e_time = max(0.0, player.wind_e_time - dt)
	if player.wind_e_time <= 0.0:
		player.wind_e_active = false
		player.e_cd_rem      = float(player.job.get("e_cd", 17.0))
