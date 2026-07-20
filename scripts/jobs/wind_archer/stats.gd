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
@export var passive_desc: String = "기본 공격이 누적될수록 사거리, 공속, 공격력, 투사체 속도가 증가합니다. 3·5·7·9타마다 스택이 쌓이고 16타에 초기화됩니다."
@export var q_name: String = "바람이 불어오는 곳"
@export var q_desc: String = "4초간 피해 보호막을 두릅니다. 발동 직후 1초는 물리 피해 50% 감소, 이후 3초는 15% 감소합니다."
@export var e_name: String = "il vento d'oro"
@export var e_desc: String = "『황금의 바람』을 느껴보세요. 5초간 비행 형태로 변신합니다."
@export var r_name: String = "신궁"
@export var r_desc: String = "강력한 바람 화살을 발사합니다. 관통하며 피격 시 대상을 잠시 공중에 띄웁니다."

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
