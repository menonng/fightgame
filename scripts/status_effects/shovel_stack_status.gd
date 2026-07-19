# status_effects/shovel_stack_status.gd
# 쇼블러 삽질 스택 — 개별 스택마다 독립된 지속시간(기본 20초)을 가지며,
# 여러 개가 동시에 존재할 수 있는 "중첩형" 상태이상이다.
class_name ShovelStackStatus
extends StatusEffect

func _init(duration: float, owner = null) -> void:
	super._init(StatusEffect.Kind.SHOVEL_STACK, duration, owner)

## 중첩형: 이미 같은 kind가 있어도 항상 새로 추가되어야 한다.
func stacks_with(_incoming: StatusEffect) -> bool:
	return true
