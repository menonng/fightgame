# ChipProjectile.gd — Python ChipProjectile + ChipRiseEffect 이식
extends Node2D

var alive: bool     = true
var _world_pos: Vector2 = Vector2.ZERO
var target_node     = null
var speed: float    = 300.0
var damage: float   = 1.0
var dmg_types: Array = ["physical"]
var owner_node      = null
var color: Color    = Color.WHITE
const RADIUS := 10.0

# ChipRise 전용
var is_rise: bool   = false
var rise_t: float   = 0.0

var _tex: ImageTexture = null

func setup_chip(wx: float, wy: float, p_target, p_speed: float,
		p_damage: float, p_color: Color, p_owner, p_types: Array) -> void:
	_world_pos  = Vector2(wx, wy)
	target_node = p_target; speed = p_speed; damage = p_damage
	color = p_color; owner_node = p_owner; dmg_types = p_types
	is_rise = false; alive = true
	position = _world_pos
	var img := Image.load_from_file("res://assets/chip.png")
	if img: _tex = ImageTexture.create_from_image(img)

func setup_rise(wx: float, wy: float, p_color: Color) -> void:
	_world_pos = Vector2(wx, wy); color = p_color
	is_rise = true; alive = true; rise_t = 0.0
	position = _world_pos
	var img := Image.load_from_file("res://assets/chip.png")
	if img: _tex = ImageTexture.create_from_image(img)

func proj_update(dt: float) -> void:
	if not alive: return
	if is_rise:
		rise_t += dt; _world_pos.y -= 90.0 * dt
		if rise_t >= 1.2: alive = false
		return
	if target_node == null or not is_instance_valid(target_node):
		alive = false; return
	var tx := float(target_node.rect.get_center().x)
	var ty := float(target_node.rect.get_center().y)
	var dx := tx - _world_pos.x; var dy := ty - _world_pos.y
	var d  := maxf(1e-6, sqrt(dx*dx + dy*dy))
	_world_pos.x += dx / d * speed * dt
	_world_pos.y += dy / d * speed * dt
	if sqrt((tx - _world_pos.x)*(tx - _world_pos.x) + (ty - _world_pos.y)*(ty - _world_pos.y)) <= RADIUS:
		alive = false

func _draw() -> void:
	if not alive: return
	if is_rise:
		var a := maxf(0.0, 1.0 - rise_t / 1.2)
		if _tex:
			draw_texture_rect(_tex, Rect2(-30, -30, 60, 60), false, Color(color.r, color.g, color.b, a))
		else:
			draw_circle(Vector2.ZERO, 20.0, Color(color.r, color.g, color.b, a))
	else:
		if _tex:
			draw_texture_rect(_tex, Rect2(-8, -8, 16, 16), false, color)
		else:
			draw_circle(Vector2.ZERO, RADIUS, color)
