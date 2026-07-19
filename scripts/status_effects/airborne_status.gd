# status_effects/airborne_status.gd
# 에어본(탑다운 재설계) — 바람궁수 R 피격 시 적용.
#
# 기존(사이드뷰): 실제 Y축 물리로 캐릭터를 띄웠다 낙하시킴.
# 신규(탑다운):   실제 이동은 knockback_dir 방향으로 rect.position만 서서히 이동시키고,
#                시각적 "붕 뜬 느낌"은 game_scene이 Sprite2D를 Tween으로 살짝 위로
#                올렸다 내리는 연출을 담당한다(이 클래스는 로직만 소유).
#                지속시간 동안 스턴(이동/공격/스킬 불가) 상태가 되며,
#                피격 판정은 그대로 유지되어 다른 공격에 계속 맞을 수 있다.
class_name AirborneStatus
extends StatusEffect

var knockback_dir: Vector2   ## 떠밀려 이동할 방향 (정규화됨)
var knockback_dist: float    ## 총 이동 거리 (착지 지점 계산에 사용)
var start_pos: Vector2       ## 부여 시점의 위치 (보간 기준점)
var landing_pos: Vector2     ## 최종 착지 위치 (미리 계산되어 가이드 표시에 사용)

func _init(duration: float, p_knockback_dir: Vector2, p_knockback_dist: float, owner = null) -> void:
	super._init(StatusEffect.Kind.AIRBORNE, duration, owner)
	knockback_dir = p_knockback_dir.normalized() if p_knockback_dir.length() > 0.0 else Vector2.ZERO
	knockback_dist = p_knockback_dist

func on_apply(target) -> void:
	start_pos = Vector2(target.rect.position)
	landing_pos = start_pos + knockback_dir * knockback_dist
	# 스턴: 기존 잠금 필드를 그대로 활용 (이동/공격/스킬 전부 불가)
	target.move_lock_time   = maxf(target.get("move_lock_time"),   time_left)
	target.attack_lock_time = maxf(target.get("attack_lock_time"), time_left)
	target.skill_lock_time  = maxf(target.get("skill_lock_time"),  time_left)
	# 시각 연출은 game_scene / player가 on_apply 이후 target.get_airborne_status()로 조회해 Tween을 건다.

## 현재 경과 비율(0~1) 기반으로 위치 보간 — player_update에서 매 프레임 호출해 rect.position에 반영
func get_current_pos() -> Vector2:
	var elapsed := total_duration - time_left
	var t := clampf(elapsed / max(0.001, total_duration), 0.0, 1.0)
	# ease-out: 착지 직전 감속 (자연스러운 낙하 느낌)
	var eased := 1.0 - pow(1.0 - t, 2.0)
	return start_pos.lerp(landing_pos, eased)

func on_expire(target) -> void:
	# 착지 시점에 정확히 landing_pos로 스냅 (부동소수 오차 방지)
	target.rect.position = Vector2i(landing_pos)
	target.position = Vector2(target.rect.position)

func stacks_with(_incoming: StatusEffect) -> bool:
	return false

func refresh_from(incoming: StatusEffect) -> void:
	super.refresh_from(incoming)
	if incoming is AirborneStatus:
		knockback_dir = incoming.knockback_dir
		knockback_dist = incoming.knockback_dist
