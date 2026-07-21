# jobs/shoveler/stats.gd
class_name ShovelerStats
extends Resource

@export_group("전투 스탯")
@export var attack:       float = 70.0    ## 기본 공격력
@export var hp:           float = 1200.0  ## 최대 체력
@export var range_px:     float = 120.0   ## 근접 공격 사거리 (픽셀)
@export var move_speed:   float = 220.0   ## 이동 속도 (px/s)
@export var attack_speed: float = 0.5     ## 공격 속도 (회/s)

@export_group("스킬 쿨타임 (초)")
@export var passive_cd: float = 0.0
@export var q_cd:       float = 15.0
@export var e_cd:       float = 24.0
@export var r_cd:       float = 100.0


@export_group("피해 유형")
@export var basic_dmg_types: Array[String] = ["physical"]  ## 기본 공격 피해 유형
@export var q_dmg_types: Array[String] = ["physical"]  ## Q 스킬 피해 유형
@export var e_dmg_types: Array[String] = ["magical"]  ## E 스킬 피해 유형
@export var r_dmg_types: Array[String] = ["physical"]  ## R 스킬 피해 유형
@export_group("스킬 이름 / 설명")
@export var passive_name: String = "깡!"
@export var passive_desc: String = "쇼블러가 삽질 스택이 채워진 상대를 땅에 파묻습니다. 바이바이!"
@export var q_name: String = "삽질"
@export var q_desc: String = "보는 방향으로 많은 흙을 날립니다."
@export var e_name: String = "평화 속 나머지"
@export var e_desc: String = "앞쪽 땅에서 묘석을 솟아오르게 합니다."
@export var r_name: String = "참을성 없는 할아버지"
@export var r_desc: String = "다음 기본 공격이 강화된 매장 효과를 적용합니다."

const KEY:    String = "shoveler"
const SPRITE: String = "res://assets/shoveler.png"

func to_dict() -> Dictionary:
	return {
		"key": KEY, "name": "장의사 쇼블러",
		"attack": attack, "hp": hp, "range_px": range_px,
		"move_speed": move_speed, "attack_speed": attack_speed,
		"passive_cd": passive_cd, "q_cd": q_cd, "e_cd": e_cd, "r_cd": r_cd,
		"passive_name": passive_name, "passive_desc": passive_desc,
		"q_name": q_name, "q_desc": q_desc,
		"e_name": e_name, "e_desc": e_desc,
		"r_name": r_name, "r_desc": r_desc,
		"sprite": SPRITE,
		"basic_dmg": basic_dmg_types, "q_dmg": q_dmg_types,
		"e_dmg": e_dmg_types, "r_dmg": r_dmg_types,
	}

static func get_stats() -> Dictionary:
	return ShovelerStats.new().to_dict()
