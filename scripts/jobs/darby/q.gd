# jobs/darby/q.gd — 레레레레레레레레레레이즈라고！?!!!
# 값은 인스펙터에서 조정 가능. 칩 파라미터는 현재 스탯 기반 동적 계산 유지.
class_name DarbyQ
extends Resource

@export_group("타겟팅")
@export var targeting_radius:  float = 150.0  ## 타겟팅 유효 거리 (픽셀)
@export var targeting_timeout: float = 7.0    ## 타겟팅 대기 최대 시간 (초)

@export_group("칩 개수 계산 (num = ceil(stat / divisor))")
@export var num_divisor: float = 40.0

@export_group("칩 피해 계산 (damage = floor(stat / divisor))")
@export var damage_divisor: float = 5.0

@export_group("투사체 속도 하한")
@export var speed_floor: float = 120.0

@export_group("시전 시간 범위 (clamp)")
@export var cast_time_min: float = 0.5
@export var cast_time_max: float = 4.0

@export_group("쿨다운 범위 (clamp, 초)")
@export var cd_min: float = 1.0
@export var cd_max: float = 30.0

func can_start_targeting(player) -> bool:
	return player.q_cd_rem <= 0.0 \
		and not player.revive_active \
		and player._darby_q_queue.is_empty()

func calc_params(player) -> Dictionary:
	var s := {
		"attack": player.attack, "hp": player.max_hp,
		"range":  player.attack_range, "speed": player.move_speed,
		"as":     player.attack_speed,
	}
	var vals := s.values()

	var num_src := float(vals[randi() % vals.size()])
	var num: int = max(1, int(ceil(num_src / num_divisor)))

	var dmg_src := float(vals[randi() % vals.size()])
	var dmg: int = max(1, int(floor(dmg_src / damage_divisor)))

	var spd_src := float(vals[randi() % vals.size()])
	var spd     := maxf(speed_floor, spd_src)

	var cast_vals := [s["range"], s["as"]]
	var cast_t    := clampf(float(cast_vals[randi() % 2]), cast_time_min, cast_time_max)
	var interval: float = cast_t / max(1, num)

	var cd_vals := [s["attack"], s["range"], s["speed"], s["as"]]
	var cd      := int(clampf(float(cd_vals[randi() % 4]), cd_min, cd_max))

	return {
		"num":      num,
		"damage":   float(dmg),
		"speed":    spd,
		"interval": interval,
		"cd":       float(cd),
	}

func activate(player, target) -> void:
	var d := calc_params(player)
	player._darby_q_queue = {
		"t":        0.0,
		"interval": d["interval"],
		"left":     d["num"],
		"target":   target,
		"speed":    d["speed"],
		"damage":   d["damage"],
	}
	player.q_cd_rem = d["cd"]

func update_queue(player, dt: float, scene) -> void:
	if player._darby_q_queue.is_empty():
		return
	var q: Dictionary = player._darby_q_queue
	q["t"] = float(q["t"]) + dt
	while int(q["left"]) > 0 and float(q["t"]) >= float(q["interval"]):
		q["t"] = float(q["t"]) - float(q["interval"])
		q["left"] = int(q["left"]) - 1
		var tgt = q["target"]
		if tgt != null and is_instance_valid(tgt):
			scene._darby_spawn_chip(player, tgt, float(q["speed"]), float(q["damage"]))
	if int(q["left"]) <= 0:
		player._darby_q_queue = {}
