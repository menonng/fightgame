# jobs/swordsman/passive.gd — 리바이브 트릭컬
# 체력이 0이 됐을 때 자동 발동. 값은 인스펙터에서 조정 가능.
class_name SwordsmanPassive
extends Resource

@export_group("리바이브 트릭컬 수치")
@export var revive_duration: float = 5.0   ## 부활 상태 지속 시간 (초)
@export var damage_mult:     float = 0.1   ## 부활 중 받는 피해 배율 (10%)
@export var heal_rate:       float = 0.2   ## 초당 최대 체력 회복 비율 (20% → 5초에 풀피)

func can_trigger(player) -> bool:
	return player.hp <= 0.0 \
		and not player.revive_active \
		and not player.dead \
		and player.passive_cd_rem <= 0.0 \
		and float(player.job.get("passive_cd", 0.0)) > 0.0

func trigger(player) -> void:
	player.revive_active  = true
	player.revive_time    = revive_duration
	player.hp             = 1.0
	player.passive_cd_rem = float(player.job.get("passive_cd", 100.0))

func update(player, dt: float) -> void:
	if not player.revive_active:
		return
	player.revive_time = max(0.0, player.revive_time - dt)
	player.hp = min(player.max_hp, player.hp + player.max_hp * heal_rate * dt)
	if player.revive_time <= 0.0:
		player.revive_active = false

## 부활 중 받는 피해 배율 반환
func get_damage_mult() -> float:
	return damage_mult
