# jobs/darby/passive.gd — 난 최강의 도박꾼이다아아아아아아
# 재롤 주기는 stats.gd(passive_cd)에서, 범위도 stats.gd에서 관리.
# 이 파일은 재롤 로직 자체만 담당.
class_name DarbyPassive
extends Resource

func update(player, dt: float, scene) -> void:
	player._darby_passive_timer -= dt
	if player._darby_passive_timer <= 0.0:
		player._darby_passive_timer = float(player.job.get("passive_cd", 10.0))
		_roll(player, scene, false)

func _roll(player, scene, initial: bool) -> void:
	var j := player.job

	var atk  := float(randi_range(
		int(j.get("roll_attack_min",  5)),   int(j.get("roll_attack_max",  100))))
	var rng  := float(randi_range(
		int(j.get("roll_range_min",  20)),   int(j.get("roll_range_max",  200))))
	var spd  := float(randi_range(
		int(j.get("roll_speed_min", 100)),   int(j.get("roll_speed_max",  500))))
	var asp  := randf_range(
		float(j.get("roll_atk_spd_min", 0.5)),
		float(j.get("roll_atk_spd_max", 2.5)))
	var hp_v := float(randi_range(
		int(j.get("roll_hp_min", 300)),      int(j.get("roll_hp_max", 1000))))

	# HP 비율 보존: 재롤 전 hp/max_hp 비율을 새 max_hp에 그대로 적용
	var hp_ratio := clampf(player.hp / maxf(1.0, player.max_hp), 0.0, 1.0)

	player.base_attack       = atk
	player.base_range        = rng
	player.base_speed        = spd
	player.base_attack_speed = asp
	player.base_max_hp       = hp_v
	player.max_hp            = hp_v
	player.hp                = maxf(1.0, hp_v * hp_ratio)
	player.refresh_stats()

	var floor_spd := float(j.get("roll_speed_floor", 180.0))
	if player.move_speed < 10.0:
		player.base_speed = floor_spd
		player.refresh_stats()

	if not initial and scene != null:
		scene._darby_spawn_rise_fx(player)

func initial_roll(player, scene) -> void:
	player._darby_passive_timer = float(player.job.get("passive_cd", 10.0))
	_roll(player, scene, true)
