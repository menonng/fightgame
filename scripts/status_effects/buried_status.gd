# status_effects/buried_status.gd
# 매장 상태 — 쇼블러 패시브 최종 단계. 이동/공격/스킬 불가, 받는 피해 배율 적용.
# 만료 시 삽질 스택을 없앤 채로 유지하고 재매장 방지 면역을 부여한다.
class_name BuriedStatus
extends StatusEffect

var damage_mult: float
var immunity_after: float

func _init(duration: float, p_damage_mult: float, p_immunity_after: float, owner = null) -> void:
	super._init(StatusEffect.Kind.BURIED, duration, owner)
	damage_mult = p_damage_mult
	immunity_after = p_immunity_after

func on_apply(target) -> void:
	# 매장되는 순간 기존 삽질 스택은 모두 소모된다.
	target.status.clear_kind(StatusEffect.Kind.SHOVEL_STACK)
	target.move_lock_time   = maxf(target.get("move_lock_time"),   time_left)
	target.attack_lock_time = maxf(target.get("attack_lock_time"), time_left)
	target.skill_lock_time  = maxf(target.get("skill_lock_time"),  time_left)

func on_expire(target) -> void:
	target.shovel_immunity_time = immunity_after

## 이 효과를 건 owner가 가하는 피해에 배율 적용 (다른 공격자는 영향 없음)
func get_damage_mult_for(attacker) -> float:
	return damage_mult if attacker == owner_ref else 1.0

func refresh_from(incoming: StatusEffect) -> void:
	super.refresh_from(incoming)
	if incoming is BuriedStatus:
		damage_mult = incoming.damage_mult
		immunity_after = incoming.immunity_after
