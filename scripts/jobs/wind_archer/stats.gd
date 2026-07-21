# jobs/wind_archer/stats.gd
class_name WindArcherStats
extends Resource

@export_group("전투 스탯")
@export var attack:       float = 10.0    ## 기본 공격력 (패시브 스택으로 증가)
@export var hp:           float = 600.0   ## 최대 체력
@export var range_px:     float = 240.0   ## 투사체 사거리 (픽셀)
@export var move_speed:   float = 320.0   ## 이동 속도 (px/s)
@export var attack_speed: float = 1.5     ## 공격 속도 (회/s)

@export_group("스킬 쿨타임 (초)")
@export var passive_cd: float = 0.0
@export var q_cd:       float = 15.0
@export var e_cd:       float = 17.0
@export var r_cd:       float = 100.0


@export_group("피해 유형")
@export var basic_dmg_types: Array[String] = ["physical"]  ## 기본 공격 피해 유형
@export var r_dmg_types: Array[String] = ["physical"]  ## R 스킬 피해 유형
@export_group("스킬 이름 / 설명")
@export var passive_name: String = "바람의 나라:연"
@export var passive_desc: String = "바람궁수의 신빠람은 다다익선입니다."
@export var q_name: String = "바람이 불어오는 곳"
@export var q_desc: String = "4초 동안 피해를 감소시킵니다."
@export var e_name: String = "il vento d'oro"
@export var e_desc: String = "『황금의 바람』을 느껴보세요."
@export var r_name: String = "신궁"
@export var r_desc: String = "바람 화살의 힘은 가히 신의 힘에 필적합니다."

const KEY:      String = "wind_archer"
const SPRITE:   String = "res://assets/wind_archer_base.png"
const SPRITE_E: String = "res://assets/wind_archer_e.png"

func to_dict() -> Dictionary:
	return {
		"key": KEY, "name": "바람궁수",
		"attack": attack, "hp": hp, "range_px": range_px,
		"move_speed": move_speed, "attack_speed": attack_speed,
		"passive_cd": passive_cd, "q_cd": q_cd, "e_cd": e_cd, "r_cd": r_cd,
		"passive_name": passive_name, "passive_desc": passive_desc,
		"q_name": q_name, "q_desc": q_desc,
		"e_name": e_name, "e_desc": e_desc,
		"r_name": r_name, "r_desc": r_desc,
		"sprite": SPRITE, "sprite_e": SPRITE_E,
		"basic_dmg": basic_dmg_types, "r_dmg": r_dmg_types,
	}

static func get_stats() -> Dictionary:
	return WindArcherStats.new().to_dict()
