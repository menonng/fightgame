# jobs/swordsman/q.gd — 나타드코코
# 값은 인스펙터에서 조정 가능.
class_name SwordsmanQ
extends Resource

@export_group("나타드코코 수치")
@export var duration:       float = 5.0    ## 버프 지속 시간 (초)
@export var inc_attack:     float = 1.10   ## 공격력 증가 비율 (+110%)
@export var dec_dmg_taken:  float = 0.70   ## 받는 피해 감소 비율 (-70%)
@export var dec_move:       float = 0.90   ## 이동속도 감소 비율 (-90%)
@export var dec_atk_speed:  float = 0.80   ## 공격속도 감소 비율 (-80%)
@export var cast_fx_time:   float = 0.6    ## 발동 이펙트 지속 시간 (초)

func can_use(player) -> bool:
	return not player.revive_active \
		and player.q_buff_time <= 0.0 \
		and player.q_cd_rem <= 0.0

func activate(player) -> void:
	player.q_cast_fx_time = cast_fx_time
	player.q_buff_time    = duration
	player.inc_attack        += inc_attack
	player.dec_damage_taken  += dec_dmg_taken
	player.dec_move          += dec_move
	player.dec_attack_speed  += dec_atk_speed
	player.refresh_stats()

func deactivate(player) -> void:
	player.q_buff_time       = 0.0
	player.inc_attack        -= inc_attack
	player.dec_damage_taken  -= dec_dmg_taken
	player.dec_move          -= dec_move
	player.dec_attack_speed  -= dec_atk_speed
	player.q_cd_rem = float(player.job.get("q_cd", 10.0))
	player.refresh_stats()

func update(player, dt: float) -> void:
	player.q_cast_fx_time = max(0.0, player.q_cast_fx_time - dt)
	if player.q_buff_time > 0.0:
		player.q_buff_time = max(0.0, player.q_buff_time - dt)
		if player.q_buff_time == 0.0:
			deactivate(player)
