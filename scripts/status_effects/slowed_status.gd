# status_effects/slowed_status.gd
# 이동속도 감소 — 쇼블러 흙 파티클(Q) 피격 시 적용.
# 원본 로직: 이미 슬로우 중이고 남은 시간이 새 지속시간보다 길면 갱신하지 않는다(중첩 방지 정책).
class_name SlowedStatus
extends StatusEffect

var mult: float

func _init(duration: float, p_mult: float, owner = null) -> void:
	super._init(StatusEffect.Kind.SLOWED, duration, owner)
	mult = p_mult

func on_apply(target) -> void:
	target.slow_mult = mult
	target.slow_time = time_left

func on_tick(target, dt: float) -> bool:
	var expired: bool = super.on_tick(target, dt)
	target.slow_time = time_left
	return expired

func on_expire(target) -> void:
	target.slow_mult = 1.0
	target.slow_time = 0.0

## 원본 정책: 남은 시간이 더 길면 새 요청을 무시(갱신 안 함)
func refresh_from(incoming: StatusEffect) -> void:
	if incoming is SlowedStatus and time_left >= incoming.time_left:
		return   # 기존 지속시간이 이미 더 김 → 무시
	super.refresh_from(incoming)
	if incoming is SlowedStatus:
		mult = incoming.mult
