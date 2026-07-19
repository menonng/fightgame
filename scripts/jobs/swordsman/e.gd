# jobs/swordsman/e.gd — 매지컬플레임초울트라비저블스워드나이트
# 낙하검 소환. 값은 인스펙터에서 조정 가능.
class_name SwordsmanE
extends Resource

@export_group("낙하검 피해")
@export var hit_damage_pct:  float = 0.10   ## 최초 타격: 최대 체력의 몇 % 피해
@export var dot_tick_damage: float = 0.005  ## DoT 틱당: 현재 체력의 몇 % 피해
@export var dot_duration:    float = 10.0   ## DoT 지속 시간 (초)
@export var dot_tick_rate:   float = 0.25   ## DoT 틱 간격 (초)

@export_group("이속 버프")
@export var speed_buff_pct: float = 1.0    ## 이속 버프 비율 (+100%)
@export var speed_buff_dur: float = 1.0    ## 이속 버프 지속 시간 (초)

@export_group("낙하검 크기")
@export var sword_width:  int = 26    ## 낙하검 너비 (픽셀)
@export var sword_height: int = 180   ## 낙하검 높이 (픽셀)

@export_group("낙하 물리")
@export var fall_speed_base:      float = 20.0  ## 낙하 속도 기준값
@export var fall_speed_exp_rate:  float = 2.2   ## 지수 가속 계수 (1초 이후)
@export var spawn_screen_offset:  float = 220.0 ## 화면 상단에서 스폰되는 오프셋

func can_use(player) -> bool:
	return not player.revive_active \
		and player.e_cd_rem <= 0.0 \
		and player.skill_lock_time <= 0.0

func activate(player) -> void:
	player.add_speed_buff(speed_buff_pct, speed_buff_dur)
	player.e_cd_rem = float(player.job.get("e_cd", 15.0))
