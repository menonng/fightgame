# jobs/wind_archer/q.gd — 바람이 불어오는 곳
# 값은 인스펙터에서 조정 가능.
class_name WindArcherQ
extends Resource

@export_group("지속 시간")
@export var duration: float = 4.0  ## 버프 지속 시간 (초)

@export_group("피해 감소 구간 기준")
@export var strong_phase_threshold: float = 3.0
## 발동 후 남은 시간이 이 값을 초과하면 '강화 구간'으로 판정.
## 예: duration=4, threshold=3 → 첫 1초가 강화 구간

@export_group("강화 구간 피해 감소 (발동 직후)")
@export var dmg_red_strong: float = 0.50
## 강화 구간에서 감소시킬 피해 비율. 0.50 = 50% 감소 (받는 피해 절반)
@export var dmg_types_strong: Array[String] = ["physical"]
## 강화 구간에서 감소가 적용되는 피해 유형. 기본: physical만

@export_group("일반 구간 피해 감소 (이후)")
@export var dmg_red_normal: float = 0.15
## 일반 구간에서 감소시킬 피해 비율. 0.15 = 15% 감소
@export var dmg_types_normal: Array[String] = ["physical"]
## 일반 구간에서 감소가 적용되는 피해 유형. 기본: physical만

func can_use(player) -> bool:
	return not player.revive_active \
		and player.q_cd_rem <= 0.0 \
		and not player.wind_q_active

func activate(player) -> void:
	player.wind_q_active = true
	player.wind_q_time   = duration

func update(player, dt: float) -> void:
	if not player.wind_q_active:
		return
	player.wind_q_time = max(0.0, player.wind_q_time - dt)
	if player.wind_q_time <= 0.0:
		player.wind_q_active = false
		player.q_cd_rem = float(player.job.get("q_cd", 15.0))

## 피해 유형을 받아 해당 구간의 피해 배율 반환.
## 반환값 = 1.0이면 감소 없음, 0.5면 피해 50%로 감소.
func get_damage_mult(player, damage_types: Array) -> float:
	if not player.wind_q_active:
		return 1.0
	if player.wind_q_time > strong_phase_threshold:
		# 강화 구간: 지정된 피해 유형만 감소
		for t in damage_types:
			if t in dmg_types_strong:
				return 1.0 - dmg_red_strong
	else:
		# 일반 구간: 지정된 피해 유형만 감소
		for t in damage_types:
			if t in dmg_types_normal:
				return 1.0 - dmg_red_normal
	return 1.0
