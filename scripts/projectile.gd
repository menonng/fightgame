# Projectile.gd — 원본 Python DirectionalProjectile + wind_ult 이식
class_name Projectile
extends Node2D

enum Style { ORB, WIND_ULT }

var style: Style  = Style.ORB
var alive: bool   = true
var owner_node    = null
var damage: float = 0.0
var dmg_types: Array  = ["physical"]
var radius: int       = 10
var color: Color      = Color.WHITE
var pierce: bool      = false
var hit_ids: Array    = []

var vx: float     = 0.0; var vy: float = 0.0
var life: float   = 2.0
var max_range: float        = -1.0
var dist_travelled: float   = 0.0
var over_range_time: float  = 0.0
var _world_pos: Vector2  = Vector2.ZERO

var _tex: ImageTexture = null

func setup_directional(wx: float, wy: float, dx: float, dy: float,
		speed: float, dmg: float, p_owner, p_types: Array,
		p_radius: int, p_color: Color, p_life: float,
		p_max_range: float, p_pierce: bool, p_style: Style) -> void:
	_world_pos  = Vector2(wx, wy)
	position    = _world_pos
	var mag     := maxf(1e-6, sqrt(dx*dx + dy*dy))
	vx = dx / mag * speed; vy = dy / mag * speed
	damage      = dmg; owner_node = p_owner; dmg_types = p_types
	radius      = p_radius; color = p_color; life = p_life
	max_range   = p_max_range; pierce = p_pierce; style = p_style
	alive       = true

func proj_update(dt: float) -> void:
	if not alive: return
	life -= dt
	if life <= 0.0: alive = false; return
	var step := Vector2(vx, vy) * dt
	_world_pos += step
	dist_travelled += step.length()
	if max_range > 0.0 and dist_travelled > max_range:
		over_range_time += dt
		if over_range_time >= 0.2: alive = false

func collides_rect(r: Rect2i) -> bool:
	var cx := clampf(_world_pos.x, float(r.position.x), float(r.position.x + r.size.x))
	var cy := clampf(_world_pos.y, float(r.position.y), float(r.position.y + r.size.y))
	return ((_world_pos.x-cx)*(_world_pos.x-cx) + (_world_pos.y-cy)*(_world_pos.y-cy)) <= float(radius * radius)

func _draw() -> void:
	if not alive: return
	match style:
		Style.ORB:
			draw_circle(Vector2.ZERO, float(radius), color)
			draw_arc(Vector2.ZERO, float(radius), 0.0, TAU, 24, Color.WHITE, 2.0)
		Style.WIND_ULT:
			if _tex:
				var th := 150.0
				var tw := _tex.get_width() * th / float(_tex.get_height())
				var ang := -atan2(vy, vx)
				draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
				draw_texture_rect(_tex, Rect2(-tw/2.0, -th/2.0, tw, th), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_circle(Vector2.ZERO, float(radius), Color(0.471, 1.0, 0.824))
