# jobs/wind_archer/passive.gd — 바람의 나라:연
# 값은 인스펙터에서 조정 가능.
class_name WindArcherPassive
extends Resource

@export_group("스택 획득 조건")
@export var thresholds: Array[int] = [3, 5, 7, 9]  ## 스택 획득 타격 수 (누적 4단계)
@export var reset_at:   int = 16                     ## 초기화 타격 수

@export_group("스택당 보너스")
@export var bonus_range_per:    float = 50.0  ## 스택당 사거리 증가 (픽셀)
@export var bonus_atk_spd_per:  float = 0.15  ## 스택당 공속 증가 (회/s)
@export var bonus_attack_per:   float = 5.0   ## 스택당 공격력 증가
@export var bonus_proj_spd_per: float = 0.10  ## 스택당 투사체 속도 증가 비율

func on_basic_hit(player) -> void:
	player.wind_passive_hits += 1

	if player.wind_passive_hits >= reset_at:
		_reset(player)
		return

	var new_stacks := 0
	for t in thresholds:
		if player.wind_passive_hits >= t:
			new_stacks += 1

	if new_stacks != player.wind_passive_stacks:
		player.wind_passive_stacks         = new_stacks
		player.wind_bonus_range            = bonus_range_per    * new_stacks
		player.wind_bonus_attack_speed     = bonus_atk_spd_per  * new_stacks
		player.wind_bonus_attack           = bonus_attack_per   * new_stacks
		player.wind_bonus_projectile_speed = bonus_proj_spd_per * new_stacks
		player.refresh_stats()

func _reset(player) -> void:
	player.wind_passive_hits           = 0
	player.wind_passive_stacks         = 0
	player.wind_bonus_attack           = 0.0
	player.wind_bonus_range            = 0.0
	player.wind_bonus_attack_speed     = 0.0
	player.wind_bonus_projectile_speed = 0.0
	player.refresh_stats()
