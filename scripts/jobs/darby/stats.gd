# jobs/darby/stats.gd
class_name DarbyStats
extends Resource

# ── 패시브 재롤 범위 ──────────────────────────────────────────────────────────
@export_group("패시브 스탯 재롤 범위")
@export var roll_attack_min:   int   = 5      ## 공격력 최솟값
@export var roll_attack_max:   int   = 100    ## 공격력 최댓값
@export var roll_hp_min:       int   = 300    ## 체력 최솟값
@export var roll_hp_max:       int   = 1000   ## 체력 최댓값
@export var roll_range_min:    int   = 10     ## 사거리 최솟값 (픽셀)
@export var roll_range_max:    int   = 100    ## 사거리 최댓값 (픽셀)
@export var roll_speed_min:    int   = 100    ## 이동속도 최솟값 (px/s)
@export var roll_speed_max:    int   = 500    ## 이동속도 최댓값 (px/s)
@export var roll_atk_spd_min:  float = 0.5   ## 공격속도 최솟값 (회/s)
@export var roll_atk_spd_max:  float = 2.5   ## 공격속도 최댓값 (회/s)
@export var roll_speed_floor:  float = 180.0 ## 이속 하한 (10 미만 시 이 값으로 고정)

# ── 쿨타임 ────────────────────────────────────────────────────────────────────
@export_group("스킬 쿨타임 (초)")
@export var passive_cd: float = 10.0   ## 패시브 재롤 주기
@export var q_cd_base:  float = 0.0    ## Q 쿨타임 기본 (동적 계산, 참고용)
@export var e_cd:       float = 17.0
@export var r_cd:       float = 120.0


@export_group("피해 유형")
@export var basic_dmg_types: Array[String] = ["physical"]  ## 기본 공격 피해 유형
@export var q_dmg_types: Array[String] = ["magical"]  ## Q 스킬 피해 유형
@export_group("스킬 이름 / 설명")
@export var passive_name: String = "난 최강의 도박꾼이다아아아아아아"
@export var passive_desc: String = "10초마다 모든 스탯이 무작위로 재결정됩니다. 체력이 깎인 상태에서도 비율은 유지됩니다."
@export var q_name: String = "레레레레레레레레레레이즈라고！?!!!"
@export var q_desc: String = "대상에게 카지노 칩을 연속으로 던집니다. 칩의 수, 피해, 속도, 쿨다운은 현재 스탯 기반으로 결정되는 마법 피해입니다."
@export var e_name: String = "「Good.」"
@export var e_desc: String = "현재 스탯 중 하나를 골라 그 값에 비례한 이속 버프를 4초간 획득합니다. 어느 스탯이 선택될지는 알 수 없습니다."
@export var r_name: String = "영혼은 받아가마!"
@export var r_desc: String = "14초간 아우라를 펼칩니다. 적과 접촉 시 스탯을 훔쳐 적은 30초간 약화, 다비는 60초간 2배 강화됩니다."

const KEY:    String = "darby"
const SPRITE: String = "res://assets/darby.png"

func to_dict() -> Dictionary:
	return {
		"key": KEY, "name": "D' 아르비",
		# 전투 스탯은 모두 0 — 패시브로 결정
		"attack": 0.0, "hp": 0.0, "range_px": 0.0,
		"move_speed": 0.0, "attack_speed": 0.0,
		"passive_cd": passive_cd, "q_cd": 0.0, "e_cd": e_cd, "r_cd": r_cd,
		"passive_name": passive_name, "passive_desc": passive_desc,
		"q_name": q_name, "q_desc": q_desc,
		"e_name": e_name, "e_desc": e_desc,
		"r_name": r_name, "r_desc": r_desc,
		"sprite": SPRITE,
		"basic_dmg": basic_dmg_types, "q_dmg": q_dmg_types,
		# 재롤 범위 — passive.gd가 직접 참조
		"roll_attack_min": roll_attack_min,   "roll_attack_max": roll_attack_max,
		"roll_hp_min":     roll_hp_min,       "roll_hp_max":     roll_hp_max,
		"roll_range_min":  roll_range_min,    "roll_range_max":  roll_range_max,
		"roll_speed_min":  roll_speed_min,    "roll_speed_max":  roll_speed_max,
		"roll_atk_spd_min":roll_atk_spd_min,  "roll_atk_spd_max":roll_atk_spd_max,
		"roll_speed_floor":roll_speed_floor,
	}

static func get_stats() -> Dictionary:
	return DarbyStats.new().to_dict()
