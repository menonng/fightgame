# jobs/swordsman/stats.gd
# @export 변수로 인스펙터에서 직접 수정 가능
class_name SwordsmanStats
extends Resource

# ── 전투 스탯 ────────────────────────────────────────────────────────────────
@export_group("전투 스탯")
@export var attack:       float = 50.0    ## 기본 공격력
@export var hp:           float = 1500.0  ## 최대 체력
@export var range_px:     float = 40.0    ## 공격 사거리 (픽셀)
@export var move_speed:   float = 240.0   ## 이동 속도 (px/s)
@export var attack_speed: float = 0.8     ## 공격 속도 (회/s)

# ── 쿨타임 ───────────────────────────────────────────────────────────────────
@export_group("스킬 쿨타임 (초)")
@export var passive_cd: float = 100.0  ## 패시브 (리바이브) 재발동 대기
@export var q_cd:       float = 10.0   ## Q 나타드코코
@export var e_cd:       float = 15.0   ## E 낙하검
@export var r_cd:       float = 50.0   ## R 돌림판

# ── 스킬 설명 ─────────────────────────────────────────────────────────────────

@export_group("피해 유형")
@export var basic_dmg_types: Array[String] = ["physical"]  ## 기본 공격 피해 유형
@export var q_buffed_basic_dmg_types: Array[String] = ["true"]  ## Q 활성 중 기본 공격 피해 유형 (기본: 고정 피해)
@export var e_dmg_types: Array[String] = ["physical"]  ## E 스킬 피해 유형
@export var r_dmg_types: Array[String] = ["physical"]  ## R 스킬 피해 유형
@export_group("스킬 이름 / 설명")
@export var passive_name: String = "리바이브 트릭컬"
@export var passive_desc: String = "체력이 0이 되면 부활해 5초간 회복합니다. 100초마다 재발동. 부활 중 받는 피해가 90% 감소합니다."
@export var q_name: String = "나타드코코"
@export var q_desc: String = "5초간 공격력이 크게 상승하지만 이속과 공속이 느려집니다. 이 상태의 기본 공격은 방어를 무시하는 고정 피해를 줍니다."
@export var e_name: String = "매지컬플레임초울트라비저블스워드나이트"
@export var e_desc: String = "굉장히 신성해보이는 검을 소환해 마우스 방향 지점에 내리찍습니다. 착지 시 범위 내 대상의 최대 체력 10%를 깎고 10초간 지속 피해를 남깁니다. 발동 직후 1초간 이속이 2배가 됩니다."
@export var r_name: String = "돌려 돌려 돌림판"
@export var r_desc: String = "5초간 고속 회전합니다. 이속 증가, 받는 피해 40% 감소. 인접한 적에게 0.5초마다 피해를 입힙니다."

# ── 내부 상수 (코드 참조용) ──────────────────────────────────────────────────
const KEY:    String = "swordsman"
const SPRITE: String = "res://assets/swordsman.png"

func to_dict() -> Dictionary:
	return {
		"key": KEY, "name": "검사자",
		"attack": attack, "hp": hp, "range_px": range_px,
		"move_speed": move_speed, "attack_speed": attack_speed,
		"passive_cd": passive_cd, "q_cd": q_cd, "e_cd": e_cd, "r_cd": r_cd,
		"passive_name": passive_name, "passive_desc": passive_desc,
		"q_name": q_name, "q_desc": q_desc,
		"e_name": e_name, "e_desc": e_desc,
		"r_name": r_name, "r_desc": r_desc,
		"sprite": SPRITE,
		"basic_dmg": basic_dmg_types, "q_buffed_basic_dmg": q_buffed_basic_dmg_types, "e_dmg": e_dmg_types, "r_dmg": r_dmg_types,
	}

## 싱글턴처럼 사용 — 에디터 커스텀 없이 기본값으로 dict 반환
static func get_stats() -> Dictionary:
	return SwordsmanStats.new().to_dict()
