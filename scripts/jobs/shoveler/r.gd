# jobs/shoveler/r.gd — 참을성 없는 할아버지
# 값은 인스펙터에서 조정 가능. 실제 강화 매장 배율/지속은 passive.gd에서 관리.
class_name ShovelerR
extends Resource

func can_use(player) -> bool:
	return player.r_cd_rem <= 0.0 \
		and not player.revive_active \
		and player.skill_lock_time <= 0.0

func activate(player) -> void:
	player.shovel_r_armed = true
	player.r_cd_rem = float(player.job.get("r_cd", 100.0))
