# jobs/swordsman/r.gd — 돌려 돌려 돌림판
# 값은 인스펙터에서 조정 가능.
class_name SwordsmanR
extends Resource

@export_group("돌림판 수치")
@export var duration:       float = 5.0    ## 지속 시간 (초)
@export var tick_damage:    float = 70.0   ## 틱당 피해량
@export var tick_interval:  float = 0.5    ## 틱 간격 (초)
@export var spin_speed_deg: float = 720.0  ## 회전 속도 (도/초)
@export var inc_move:       float = 0.5    ## 이속 증가 비율 (+50%)
@export var dmg_mult:       float = 0.6    ## 받는 피해 배율 (×60%)

func can_use(player) -> bool:
	return not player.revive_active \
		and player.r_cd_rem <= 0.0 \
		and not player.r_active \
		and player.skill_lock_time <= 0.0

func activate(player) -> void:
	player.r_active   = true
	player.r_time     = duration
	player.r_tick     = 0.0
	player.spin_angle = 0.0
	player.inc_move  += inc_move
	player.refresh_stats()

func update(player, dt: float) -> void:
	if not player.r_active:
		return
	player.r_time    = max(0.0, player.r_time - dt)
	player.r_tick   += dt
	player.spin_angle = fmod(player.spin_angle + spin_speed_deg * dt, 360.0)
	if player.r_time <= 0.0:
		deactivate(player)

func deactivate(player) -> void:
	player.r_active   = false
	player.spin_angle = 0.0
	player.inc_move  -= inc_move
	player.r_cd_rem   = float(player.job.get("r_cd", 50.0))
	player.refresh_stats()
