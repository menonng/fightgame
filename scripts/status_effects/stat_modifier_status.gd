# status_effects/stat_modifier_status.gd
# 스탯 증감 — 다비 R (훔치기)에서 사용.
# StatBonusStatus(시전자 강화) / StatDebuffStatus(대상 약화) 두 서브클래스로 구성.
# 둘 다 "중첩형"이라 여러 개가 동시에 존재할 수 있으며(스택마다 만료시점이 다를 수 있음),
# 최종 수치는 Player._sum_mods()가 목록을 순회하며 합산한다.
class_name StatModifierStatus
extends StatusEffect

var attack: float = 0.0
var hp:     float = 0.0
var range_amount: float = 0.0
var speed:  float = 0.0
var atk_spd: float = 0.0

func _init(p_kind: StatusEffect.Kind, duration: float,
		p_attack: float, p_hp: float, p_range: float, p_speed: float, p_atk_spd: float,
		owner = null) -> void:
	super._init(p_kind, duration, owner)
	attack = p_attack; hp = p_hp; range_amount = p_range
	speed = p_speed; atk_spd = p_atk_spd

## 중첩형: 훔친 스탯마다 별개의 지속시간을 가지므로 항상 새로 추가
func stacks_with(_incoming: StatusEffect) -> bool:
	return true
