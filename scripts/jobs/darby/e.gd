# jobs/darby/e.gd — 「Good.」
# 현재 스탯 중 하나를 골라 이속 버프를 부여. 값은 인스펙터에서 조정 가능.
class_name DarbyE
extends Resource

@export_group("지속 시간")
@export var buff_duration: float = 4.0  ## 이속 버프 지속 시간 (초)

@export_group("이속 증가량 계산")
@export var speed_increase_pct: float = 1.0
## 선택된 스탯값의 몇 %를 이속 증가량으로 적용할지.
## 예: 1.0 = 스탯값의 1%, 2.0 = 스탯값의 2%.
## 실제 증가량 = 선택 스탯값 × speed_increase_pct / 100
## 예시: 공격력 50, speed_increase_pct=1.0 → 이속 +50% 가산 없이 +0.5 (배율로 적용됨)
##       move_speed 300, speed_increase_pct=1.0 → 300 × 0.01 = +3.0 (300% 가산)
##       실제로는 add_speed_buff(3.0, 4.0) → move_speed × (1 + 3.0) = 4배가 되므로
##       의도에 맞게 divisor 개념으로 보면: speed_increase_pct=1.0 → 스탯/100 배율

@export_group("스탯 선택 풀")
@export var use_attack:      bool = true   ## 공격력을 선택 후보에 포함
@export var use_hp:          bool = true   ## 최대 체력을 선택 후보에 포함
@export var use_range:       bool = true   ## 사거리를 선택 후보에 포함
@export var use_move_speed:  bool = true   ## 이동속도를 선택 후보에 포함
@export var use_attack_speed: bool = true  ## 공격속도를 선택 후보에 포함

func can_use(player) -> bool:
	return not player.revive_active \
		and player.e_cd_rem <= 0.0 \
		and player.skill_lock_time <= 0.0

func activate(player) -> void:
	# 인스펙터에서 활성화된 스탯만 풀에 넣음
	var pool: Array = []
	if use_attack:       pool.append(player.attack)
	if use_hp:           pool.append(player.max_hp)
	if use_range:        pool.append(player.attack_range)
	if use_move_speed:   pool.append(player.move_speed)
	if use_attack_speed: pool.append(player.attack_speed)

	if pool.is_empty():
		# 풀이 비어있으면 이속 자체를 기준으로 사용
		pool.append(player.move_speed)

	var selected := float(pool[randi() % pool.size()])
	var buff_amount := selected * speed_increase_pct / 100.0
	player.add_speed_buff(buff_amount, buff_duration)
	player.e_cd_rem = float(player.job.get("e_cd", 17.0))
