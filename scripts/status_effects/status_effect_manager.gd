# status_effects/status_effect_manager.gd
# Player / TrainingDummy에 컴포지션으로 부착되는 상태이상 관리자.
# Kind별 분기 없이 전부 다형 호출(on_apply/on_tick/on_expire)로 처리한다.
class_name StatusEffectManager
extends RefCounted

var _target = null           ## 이 매니저가 붙어있는 대상 (Player/TrainingDummy)
var effects: Array = []      ## Array[StatusEffect]

func _init(target = null) -> void:
	_target = target

## 대상을 나중에 지정해야 할 때(선언과 초기화 분리) 사용
func bind(target) -> void:
	_target = target

## 상태이상 부여. 동일 kind가 있으면 effect.stacks_with()가 병합 정책을 결정한다.
func apply(effect: StatusEffect) -> StatusEffect:
	for e in effects:
		if e.kind == effect.kind:
			if e.stacks_with(effect):
				break  # 중첩 허용 → 아래에서 새 효과를 그대로 추가
			else:
				e.refresh_from(effect)
				return e
	effects.append(effect)
	effect.on_apply(_target)
	return effect

## 특정 종류의 효과 존재 여부
func has(kind: StatusEffect.Kind) -> bool:
	for e in effects:
		if e.kind == kind: return true
	return false

## 특정 종류의 첫 효과 반환 (없으면 null)
func get_effect(kind: StatusEffect.Kind) -> StatusEffect:
	for e in effects:
		if e.kind == kind: return e
	return null

## 특정 종류의 효과 개수 (스택형 상태이상에 사용 — 예: 삽질 스택 여러 개)
func count(kind: StatusEffect.Kind) -> int:
	var n := 0
	for e in effects:
		if e.kind == kind: n += 1
	return n

## 특정 종류의 효과를 전부 제거 (즉시 on_expire 호출하여 원상복구까지 수행)
func clear_kind(kind: StatusEffect.Kind) -> void:
	var remaining: Array = []
	for e in effects:
		if e.kind == kind:
			e.on_expire(_target)
		else:
			remaining.append(e)
	effects = remaining

## 전체 제거 (원상복구 포함)
func clear_all() -> void:
	for e in effects:
		e.on_expire(_target)
	effects.clear()

## 매 프레임 갱신 — on_tick()이 true를 반환하면 on_expire() 호출 후 제거
func update(dt: float) -> void:
	var kept: Array = []
	for e in effects:
		var expired: bool = e.on_tick(_target, dt)
		if expired:
			e.on_expire(_target)
		else:
			kept.append(e)
	effects = kept
