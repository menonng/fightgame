# jobs/shoveler/passive.gd — 깡!
# 값은 인스펙터에서 조정 가능. ShovelStackStatus / BuriedStatus를 직접 부여한다.
class_name ShovelerPassive
extends Resource

@export_group("삽질 스택")
@export var max_stacks:     int   = 5     ## 최대 스택 수
@export var stack_duration: float = 20.0  ## 개별 스택 유지 시간 (초)

@export_group("일반 매장 (5스택 상태 기본공격)")
@export var bury_duration_normal: float = 3.0  ## 지속 시간 (초)
@export var bury_mult_normal:     float = 1.5  ## 받는 피해 배율

@export_group("R 강화 매장")
@export var bury_duration_r: float = 10.0  ## 지속 시간 (초)
@export var bury_mult_r:     float = 2.5   ## 받는 피해 배율

@export_group("매장 해제 후")
@export var immunity_duration: float = 20.0  ## 재매장 방지 면역 시간 (초)

@export_group("흙 파티클 재적용 방지")
@export var dust_lock_duration: float = 5.0  ## 동일 파티클 재스택 방지 시간 (초)

@export_group("Q 슬로우")
@export var slow_mult:     float = 0.90  ## 슬로우 배율 (10% 감소)
@export var slow_duration: float = 5.0   ## 슬로우 지속 시간 (초)

## 스택 추가 시도
func try_add_stack(owner, target, by_dust: bool, trigger_bury: bool) -> void:
	if owner.job.get("key", "") != "shoveler":
		return
	if target == null or target.status == null:
		return

	# R 선처리: 강화 매장
	if owner.shovel_r_armed and trigger_bury:
		owner.shovel_r_armed = false
		target.status.apply(BuriedStatus.new(bury_duration_r, bury_mult_r, immunity_duration, owner))
		return

	if target.is_buried():
		return
	if float(target.shovel_immunity_time) > 0.0 and not trigger_bury:
		return

	if by_dust:
		if float(target._shovel_dust_lock) > 0.0:
			return
		target._shovel_dust_lock = dust_lock_duration

	if target.shovel_stack_count() >= max_stacks:
		if trigger_bury:
			target.status.apply(BuriedStatus.new(bury_duration_normal, bury_mult_normal, immunity_duration, owner))
		return

	target.status.apply(ShovelStackStatus.new(stack_duration, owner))

## Q 흙 파티클 슬로우 적용
func apply_slow(target) -> void:
	if target.status == null:
		return
	target.status.apply(SlowedStatus.new(slow_duration, slow_mult))

## 매장 피해 배율 조회 (owner가 가하는 피해에만 배율 적용)
func get_buried_damage_mult(target, owner) -> float:
	var bs: BuriedStatus = target.buried_status() if target.has_method("buried_status") else null
	return bs.get_damage_mult_for(owner) if bs != null else 1.0
