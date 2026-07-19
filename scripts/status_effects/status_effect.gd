# status_effects/status_effect.gd
# 모든 상태이상의 기반 클래스. OOP 다형성으로 동작 캡슐화:
#   on_apply()  — 부여되는 순간 1회 실행 (target 필드 변경 등 사이드이펙트)
#   on_tick()   — 매 프레임 실행. true 반환 시 만료 처리로 이어짐
#   on_expire() — 만료(또는 명시적 제거) 시 1회 실행 (원상복구 등)
#   stacks_with(other) — 동일 kind의 새 효과가 부여 요청될 때의 병합 정책
#
# 각 상태이상은 이 클래스를 상속해 자신의 로직을 스스로 알고 있어야 하며,
# StatusEffectManager나 외부 코드가 kind별로 분기하지 않아도 되게 한다.
class_name StatusEffect
extends RefCounted

enum Kind {
	AIRBORNE,       ## 공중에 뜸 (바람궁수 R 등) — 중력 무시, 낙하 불가
	SHOVEL_STACK,   ## 삽질 스택 누적 (묻히기 전 단계)
	BURIED,         ## 매장 상태 — 이동/공격/스킬 불가, 받는 피해 배율 적용
	SLOWED,         ## 이동속도 감소
	STAT_DEBUFF,    ## 스탯 감소 (다비 R 등)
	STAT_BONUS,     ## 스탯 증가 (다비 R 시전자 등)
	TINTED,         ## 색조 오버레이만 (시각 효과)
}

var kind: Kind
var owner_ref = null       ## 이 효과를 건 주체 (Player) — 없으면 null
var time_left: float = 0.0
var total_duration: float = 0.0   ## 부여 시점의 전체 지속시간 (경과 비율 계산용)

func _init(p_kind: Kind, p_duration: float, p_owner = null) -> void:
	kind = p_kind
	time_left = p_duration
	total_duration = p_duration
	owner_ref = p_owner

## 부여되는 순간 1회 호출. target에 대한 초기 사이드이펙트를 여기서 수행.
## 서브클래스가 override.
func on_apply(_target) -> void:
	pass

## 매 프레임 호출. 자체 타이머 감소 + 필요한 지속 효과 적용.
## true를 반환하면 만료된 것으로 간주되어 매니저가 제거 + on_expire 호출.
## 서브클래스가 override하되, 기본 구현은 단순 카운트다운.
func on_tick(_target, dt: float) -> bool:
	time_left -= dt
	return time_left <= 0.0

## 만료(정상 종료) 또는 명시적 제거 시 1회 호출. 원상복구를 여기서 수행.
## 서브클래스가 override.
func on_expire(_target) -> void:
	pass

## 동일 kind의 효과가 이미 존재할 때, 새로 들어온 incoming을 어떻게 병합할지 결정.
## 기본 정책: 지속시간을 최댓값으로 갱신(refresh)하고 incoming은 버림.
## 반환값 true면 "새 효과를 별도로 추가"(스택형, 예: 삽질 스택), false면 "기존 것만 갱신하고 추가 안 함".
func stacks_with(_incoming: StatusEffect) -> bool:
	return false

## 기본 갱신 동작(stacks_with가 false를 반환했을 때 매니저가 호출) —
## 기존 효과(self)에 incoming의 정보를 반영. 기본은 지속시간 연장.
func refresh_from(incoming: StatusEffect) -> void:
	if incoming.time_left > time_left:
		total_duration = incoming.total_duration
	time_left = maxf(time_left, incoming.time_left)
	owner_ref = incoming.owner_ref

func is_expired() -> bool:
	return time_left <= 0.0
