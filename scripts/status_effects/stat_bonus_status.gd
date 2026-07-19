# status_effects/stat_bonus_status.gd
# 스탯 보너스 (다비 R로 훔친 스탯을 시전자가 얻는 버프)
class_name StatBonusStatus
extends StatModifierStatus

func _init(duration: float, atk: float, hp_amount: float, range_amount: float,
		speed: float, atk_spd: float, owner = null) -> void:
	super._init(StatusEffect.Kind.STAT_BONUS, duration, atk, hp_amount, range_amount, speed, atk_spd, owner)
