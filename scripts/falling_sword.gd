# FallingSword.gd — 원본 Python effects.py FallingSwordEffect 1:1 이식
extends Node2D

var alive: bool     = true
var world_x: float  = 0.0
var y: float        = 0.0
var time: float     = 0.0
var owner_node      = null
var dmg_types: Array = ["physical"]
var hit_done: Array = []   # 이미 맞은 대상 instance_id

const WIDTH  := 26
const HEIGHT := 180

func setup(wx: float, camera_y: float, p_owner) -> void:
	world_x    = wx
	y          = camera_y - 220.0
	owner_node = p_owner
	alive      = true
	time       = 0.0
	position   = Vector2(world_x, y)

func sword_update(dt: float, camera_y: float) -> void:
	if not alive: return
	time += dt
	var fall_speed: float
	if time < 1.0:
		fall_speed = 20.0 * (time * time)
	else:
		fall_speed = 20.0 * exp((time - 1.0) * 2.2)
	y += fall_speed * dt
	position = Vector2(world_x, y)
	if y > camera_y + 720.0 + 260.0: alive = false
	queue_redraw()

func hitbox_world() -> Rect2i:
	return Rect2i(int(world_x) - 18, int(y) + 10, 36, HEIGHT + 32)

func _draw() -> void:
	if not alive: return
	var sx := 0.0; var sy := 0.0   # 로컬 origin = (world_x, y)
	var hw := float(WIDTH)
	# blade
	draw_rect(Rect2(sx - hw/2.0, sy, hw, float(HEIGHT)), Color(0.824, 0.882, 1.0, 0.95))
	# tip
	var tip := PackedVector2Array([
		Vector2(sx - hw/2.0, sy + HEIGHT),
		Vector2(sx + hw/2.0, sy + HEIGHT),
		Vector2(sx, sy + HEIGHT + 26.0)])
	draw_colored_polygon(tip, Color(0.824, 0.882, 1.0, 0.95))
	# guard
	draw_rect(Rect2(sx - 30.0, sy - 16.0, 60.0, 10.0), Color(0.706, 0.627, 0.353))
	# handle
	draw_rect(Rect2(sx - 6.0, sy - 55.0, 12.0, 40.0), Color(0.471, 0.353, 0.157))
	# pommel
	draw_circle(Vector2(sx, sy - 58.0), 8.0, Color(0.588, 0.471, 0.235))
