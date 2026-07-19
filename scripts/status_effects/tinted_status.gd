# status_effects/tinted_status.gd
# 색조 오버레이 — 다비 R 피해 시 시각 효과 (전투 로직에 영향 없음)
class_name TintedStatus
extends StatusEffect

var color: Color

func _init(duration: float, p_color: Color, owner = null) -> void:
	super._init(StatusEffect.Kind.TINTED, duration, owner)
	color = p_color

func on_apply(target) -> void:
	target.tint_color = color
	target.tint_time = time_left

func on_tick(target, dt: float) -> bool:
	var expired: bool = super.on_tick(target, dt)
	target.tint_time = time_left
	return expired

func on_expire(target) -> void:
	target.tint_color = Color.TRANSPARENT
	target.tint_time = 0.0

func refresh_from(incoming: StatusEffect) -> void:
	super.refresh_from(incoming)
	if incoming is TintedStatus:
		color = incoming.color
