# sword_slam.gd — 검사자 E (탑다운 장판 슬램), falling_sword.gd 대체
# 기존(사이드뷰): 화면 상단에서 지수 가속하며 실제로 낙하하는 검.
# 신규(탑다운):   실제 Z축 물리 없이 create_tween()으로 검 스프라이트를 화면 위로
#                띄웠다가 지정된 착지 지점(target_pos)으로 내리찍는 "눈속임" 연출.
#                그림자/착지 링은 target_pos에 고정, 검 스프라이트만 위아래로 움직인다.
#                착지 순간 한 번, target_pos 중심 원형 범위에 피해 판정을 적용한다(장판기).
extends Node2D

var alive: bool       = true
var owner_node        = null
var dmg_types: Array   = ["physical"]
var hit_done: Array    = []   # 이미 맞은 대상 instance_id (다중 대상 확장 대비)

var target_pos: Vector2 = Vector2.ZERO   ## 착지 지점 (월드 좌표, 그림자/판정 기준 — 고정)
var hit_radius: float   = 90.0

var visual_offset_y: float = 0.0   ## 검 스프라이트 전용 시각 오프셋 (Tween 대상, 판정과 무관)
var _shockwave_progress: float = 0.0  ## 착지 후 충격파 페이드 진행도 (0~1, Tween 대상)
var _landed: bool      = false
var _just_landed: bool = false
const FADE_TIME := 0.35

func setup(p_target: Vector2, p_owner, p_radius: float, p_leap_height: float,
		p_up_time: float, p_down_time: float) -> void:
	target_pos = p_target
	owner_node = p_owner
	hit_radius = p_radius
	alive = true; _landed = false; _just_landed = false
	hit_done.clear()
	visual_offset_y = 0.0
	_shockwave_progress = 0.0
	position = target_pos

	var tw := create_tween()
	tw.tween_property(self, "visual_offset_y", -p_leap_height, p_up_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "visual_offset_y", 0.0, p_down_time)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_on_landed)

## 착지 여부를 1회 소비 — game_scene이 이 프레임에 착지 판정(광역 피해)을 적용해야 하는지 확인.
func consume_just_landed() -> bool:
	if _just_landed:
		_just_landed = false
		return true
	return false

func _on_landed() -> void:
	_landed = true
	_just_landed = true
	var tw2 := create_tween()
	tw2.tween_property(self, "_shockwave_progress", 1.0, FADE_TIME)
	tw2.tween_callback(func(): alive = false)

## 착지 지점 기준 원형 판정 영역 (game_scene이 dummy.rect와 교차 검사)
func hitbox_world() -> Rect2i:
	var r := int(hit_radius)
	return Rect2i(int(target_pos.x) - r, int(target_pos.y) - r, r * 2, r * 2)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not alive: return
	if not _landed:
		# 착지 예정 범위 경고 링 — 정확한 판정 반경을 드러내므로 연습 모드에서만 표시.
		# 검 스프라이트 자체는 실제 스킬 연출이므로 모드와 무관하게 항상 그린다.
		if Global.is_practice_mode:
			var warn_t := clampf(1.0 - absf(visual_offset_y) / 40.0, 0.0, 1.0)
			draw_circle(Vector2.ZERO, hit_radius * (0.35 + 0.35 * warn_t), Color(1.0, 0.3, 0.3, 0.25))
			draw_arc(Vector2.ZERO, hit_radius, 0.0, TAU, 32, Color(1.0, 0.35, 0.35, 0.7), 3.0)
		_draw_blade(Vector2(0.0, visual_offset_y))
	else:
		# 착지 충격파 — target_pos 고정 중심에서 확산하며 페이드
		var p := _shockwave_progress
		var r := lerpf(hit_radius * 0.3, hit_radius * 1.6, p)
		var a := 1.0 - p
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.824, 0.882, 1.0, a), 4.0)
		draw_circle(Vector2.ZERO, hit_radius * 0.5 * (1.0 - p), Color(0.824, 0.882, 1.0, a * 0.5))

func _draw_blade(offset: Vector2) -> void:
	var ox := offset.x; var oy := offset.y - 90.0
	draw_rect(Rect2(ox - 5.0, oy, 10.0, 44.0), Color(0.824, 0.882, 1.0, 0.97))
	var tip := PackedVector2Array([
		Vector2(ox - 5.0, oy), Vector2(ox + 5.0, oy), Vector2(ox, oy - 12.0)])
	draw_colored_polygon(tip, Color(0.824, 0.882, 1.0, 0.97))
	draw_rect(Rect2(ox - 14.0, oy + 44.0, 28.0, 6.0), Color(0.706, 0.627, 0.353))
	draw_rect(Rect2(ox - 3.0, oy + 50.0, 6.0, 14.0), Color(0.471, 0.353, 0.157))
	draw_circle(Vector2(ox, oy + 64.0), 4.0, Color(0.588, 0.471, 0.235))
