# Tombstone.gd — Python tombstone dict 이식 (Shoveler E)
# 솟아오르는 묘석. solid_platforms 에 자신을 추가/제거.
extends Node2D

var world_rect: Rect2i = Rect2i(0, 0, 56, 86)
var world_y: float    = 0.0
var target_y: float   = 0.0
var rise_speed: float = 400.0
var solid: bool       = false
var duration: float   = 5.0
var alive: bool       = true

var _tex: ImageTexture = null

func setup(p_rect: Rect2i, p_start_y: float, p_target_y: float) -> void:
	world_rect = p_rect; world_y = p_start_y; target_y = p_target_y
	solid = false; duration = 5.0; alive = true
	var img := Image.load_from_file("res://assets/shoveler_gravestone.png")
	if img:
		_apply_white_colorkey(img)
		_tex = ImageTexture.create_from_image(img)
	position = Vector2(world_rect.position.x, world_y)

# 반환: solid가 된 순간 true (GameScene에서 map_solids에 추가)
func tomb_update(dt: float) -> bool:
	duration -= dt
	var just_solidified := false
	if not solid:
		world_y = maxf(target_y, world_y - rise_speed * dt)
		world_rect = Rect2i(world_rect.position.x, int(world_y), world_rect.size.x, world_rect.size.y)
		if world_y <= target_y:
			solid = true; just_solidified = true
	if duration <= 0.0: alive = false
	position = Vector2(world_rect.position)
	queue_redraw()
	return just_solidified

## pygame Surface.set_colorkey()의 흰색 배경 제거를 Godot Image API로 재구현한 것.
## Image에는 그런 메서드가 없어(원본 Python 이식 잔재) 호출 시 즉시 런타임 에러로
## 죽는 버그가 있었다 — 흰색 픽셀을 직접 순회하며 알파를 0으로 만든다.
func _apply_white_colorkey(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var px := img.get_pixel(x, y)
			if px.r > 0.98 and px.g > 0.98 and px.b > 0.98:
				img.set_pixel(x, y, Color(px.r, px.g, px.b, 0.0))

func _draw() -> void:
	if not alive: return
	if _tex:
		draw_texture_rect(_tex, Rect2(0, 0, world_rect.size.x, world_rect.size.y), false)
	else:
		draw_rect(Rect2(0, 0, world_rect.size.x, world_rect.size.y), Color(0.5, 0.5, 0.55))
		draw_rect(Rect2(0, 0, world_rect.size.x, world_rect.size.y), Color(0.3, 0.3, 0.35), false)
