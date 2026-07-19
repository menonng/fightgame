# status_effects/stat_debuff_status.gd
# 스탯 디버프 (다비 R에 스탯을 도둑맞은 대상에게 적용되는 약화)
class_name StatDebuffStatus
extends StatModifierStatus

func _init(duration: float, atk: float, hp_amount: float,
		speed: float, atk_spd: float, owner = null) -> void:
	super._init(StatusEffect.Kind.STAT_DEBUFF, duration, atk, hp_amount, 0.0, speed, atk_spd, owner)
