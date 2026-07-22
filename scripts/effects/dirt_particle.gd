# dirt_particle.gd — Shoveler Q 흙 파티클 (탑다운 평면 버전)
# 기존: 포물선으로 날아가 바닥에 충돌 시 소멸.
# 탑다운: 중력/바닥 개념이 없으므로 지정된 사거리만큼 평면으로 날아가다 감속 후 소멸.
extends Node2D

var alive: bool     = true
var _world_pos: Vector2 = Vector2.ZERO
var vx: float       = 0.0
var vy: float       = 0.0
var life: float     = 1.2          ## 탑다운에서는 포물선 낙하 대신 고정 수명으로 사거리를 표현
var owner_node      = null
var dmg_types: Array = ["physical"]
const RADIUS := 2.0
const COLOR   := Color(0.471, 0.353, 0.275)
const DRAG := 2.2   ## 평면 마찰 감속 계수

func setup(wx: float, wy: float, p_vx: float, p_vy: float, p_owner) -> void:
	_world_pos = Vector2(wx, wy)
	vx = p_vx; vy = p_vy; owner_node = p_owner
	alive = true; life = 1.2
	position = _world_pos

func proj_update(dt: float, map_solids: Array = [], map_bushes: Array = []) -> void:
	if not alive: return
	life -= dt
	if life <= 0.0: alive = false; return

	# 평면 마찰 — 시간이 지날수록 느려지다 멈춤 (기존의 포물선 낙하를 평면 감속으로 대체)
	vx = move_toward(vx, 0.0, DRAG * 200.0 * dt)
	vy = move_toward(vy, 0.0, DRAG * 200.0 * dt)
	_world_pos.x += vx * dt
	_world_pos.y += vy * dt

	# 지형(부쉬 제외, 단단한 지형만) 충돌 시 소멸
	for p in map_solids:
		if _world_pos.x >= float(p.position.x) and _world_pos.x <= float(p.position.x + p.size.x):
			if _world_pos.y >= float(p.position.y) and _world_pos.y <= float(p.position.y + p.size.y):
				alive = false; return

func collides_rect(r: Rect2i) -> bool:
	var cx := clampf(_world_pos.x, float(r.position.x), float(r.position.x + r.size.x))
	var cy := clampf(_world_pos.y, float(r.position.y), float(r.position.y + r.size.y))
	return (_world_pos.x-cx)*(_world_pos.x-cx) + (_world_pos.y-cy)*(_world_pos.y-cy) <= RADIUS*RADIUS

func _draw() -> void:
	if not alive: return
	draw_circle(Vector2.ZERO, RADIUS, COLOR)
