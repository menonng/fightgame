# jobs/darby/r.gd — 영혼은 받아가마!
# 값은 인스펙터에서 조정 가능. StatDebuffStatus / StatBonusStatus / TintedStatus를 부여.
class_name DarbyR
extends Resource

@export_group("아우라 지속")
@export var duration: float = 14.0   ## R 아우라 지속 시간 (초)

@export_group("훔치는 비율")
@export var steal_attack:  float = 0.10  ## 훔치는 공격력 비율
@export var steal_hp:      float = 0.20  ## 훔치는 체력 비율
@export var steal_speed:   float = 0.15  ## 훔치는 이속 비율
@export var steal_atk_spd: float = 0.10  ## 훔치는 공속 비율

@export_group("지속시간 / 배율")
@export var debuff_duration: float = 30.0  ## 대상 디버프 지속 (초)
@export var bonus_duration:  float = 60.0  ## 다비 버프 지속 (초)
@export var bonus_mult:      float = 2.0   ## 획득 배율 (훔친 양의 배수)

@export_group("시각 효과")
@export var tint_color: Color = Color(0.314, 0.824, 0.902)  ## 대상 디버프 색조

func can_use(player) -> bool:
	return not player.revive_active \
		and player.r_cd_rem <= 0.0 \
		and not player.darby_r_active \
		and player.skill_lock_time <= 0.0

func activate(player) -> void:
	player.darby_r_active = true
	player.darby_r_time   = duration
	player.r_cd_rem       = float(player.job.get("r_cd", 120.0))

func update(player, dt: float) -> void:
	if not player.darby_r_active:
		return
	player.darby_r_time = max(0.0, player.darby_r_time - dt)
	if player.darby_r_time <= 0.0:
		player.darby_r_active = false

## 접촉 훔치기
func steal(player, target) -> void:
	var has_stats: bool = target.has_method("apply_damage")
	var t_atk: float = float(target.attack)       if has_stats else 0.0
	var t_hp: float  = float(target.max_hp)       if has_stats else 100.0
	var t_spd: float = float(target.move_speed)   if has_stats else 0.0
	var t_as: float  = float(target.attack_speed) if has_stats else 0.0

	var sa := t_atk * steal_attack
	var sh := t_hp  * steal_hp
	var ss := t_spd * steal_speed
	var sx := t_as  * steal_atk_spd

	if has_stats and target.status != null:
		target.status.apply(StatDebuffStatus.new(debuff_duration, sa, sh, ss, sx))
		target.refresh_stats()
		target.status.apply(TintedStatus.new(debuff_duration, tint_color))

	if player.status != null:
		player.status.apply(StatBonusStatus.new(bonus_duration,
			sa * bonus_mult, sh * bonus_mult, 0.0, ss * bonus_mult, sx * bonus_mult))
		player.refresh_stats()

	player.darby_r_active = false
	player.darby_r_time   = 0.0
