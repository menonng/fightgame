# GameScene.gd — Python scenes/game.py Practice 모드 완전 이식
# Plains 맵, 검사자·바람궁수·다비·쇼블러, 훈련 더미
extends Node2D

## 런타임에 스폰되는 오브젝트는 Node.new()+set_script() 대신 씬(.tscn)을
## instantiate()해 생성한다 — Godot의 표준 씬 인스턴싱 방식.
const PlayerScene := preload("res://scenes/objects/player.tscn")
const DummyScene  := preload("res://scenes/objects/dummy.tscn")
const ProjScene   := preload("res://scenes/objects/projectile.tscn")
const SwordScene  := preload("res://scenes/objects/sword_slam.tscn")
const ChipScene   := preload("res://scenes/objects/chip_projectile.tscn")
const DirtScene   := preload("res://scenes/objects/dirt_particle.tscn")
const TombScene   := preload("res://scenes/objects/tombstone.tscn")
# ── 직업 스킬 스크립트
# 직업별 스킬은 player.skill_passive / skill_q / skill_e / skill_r 인스턴스로 접근

# ── 맵 (탑다운 평면 — Plains → 부쉬 배치) ──────────────────────────────────────
## 맵 생성(타일 그리드→TileMapLayer)/파묻힘 흙무덤 렌더링은 독립 서브씬
## scenes/map/map.tscn(스크립트 scripts/map_gen/map_scene.gd)으로 분리되어 있다.
## game.tscn이 이를 직접 인스턴싱해 넣고, game_scene은 결과(map_solids/map_bushes)를
## _map_scene을 통해 읽고 카메라 동기화·리드로만 챙긴다.
const WORLD_W := 3200; const WORLD_H := 2400
var _map_scene: MapScene = null

# ── 엔티티 ───────────────────────────────────────────────────────────────────
var player: Node2D  = null
var dummy: Node2D   = null

# ── 투사체·이펙트 ─────────────────────────────────────────────────────────────
var wind_ult_arrows: Array = []
var sword_effects:   Array = []
var swordsman_dots:  Array = []   # [{target,time,tick,owner,damage_types}]
var chips:           Array = []   # ChipProjectile (homing)
var chip_rise_fx:    Array = []   # ChipProjectile (rise)
var dirt_particles:  Array = []
var tombstones:      Array = []   # Tombstone nodes

# ── Darby 타겟팅 상태 ─────────────────────────────────────────────────────────
var targeting_active: bool  = false
var targeting_radius: float = 150.0
var targeting_timer: float  = 0.0

# ── 피해 텍스트 ───────────────────────────────────────────────────────────────
var dmg_texts: Array = []   # [{text,wx,wy,t}]

# ── 카메라 / 화면 흔들림 ─────────────────────────────────────────────────────
var cam_x: float = 0.0; var cam_y: float = 0.0
const SCR_W := 1280; const SCR_H := 720
var shake_time: float     = 0.0   ## 남은 흔들림 시간 (초)
var shake_strength: float = 0.0   ## 현재 흔들림 진폭 (픽셀)

# ── 타격감 (히트스톱) ─────────────────────────────────────────────────────────
const HITSTOP_DURATION := 0.045   ## 적중 시 정지시간(초, 실시간 기준 — Engine.time_scale과 무관)
var _hitstop_active: bool = false

# ── 대난투 속도감 (적중 시 궁극기 쿨감) ──────────────────────────────────────
const ULT_CDR_ON_HIT := 1.0   ## 평타/Q/E/R 등 단발 적중마다 R 쿨타임 즉시 감소량(초)

# ── 특정 스킬 적중 시 화면 흔들림 ────────────────────────────────────────────
const WIND_R_SHAKE_STRENGTH := 10.0; const WIND_R_SHAKE_DURATION := 0.25
const SHOVEL_ENHANCED_SHAKE_STRENGTH := 14.0; const SHOVEL_ENHANCED_SHAKE_DURATION := 0.3

# ── 마우스 데드존 ─────────────────────────────────────────────────────────────
const MOUSE_DEADZONE_RADIUS := 40.0   ## 캐릭터 중심 기준 이 반경 이내면 조준 방향을 갱신하지 않음

# ── 선입력(Input Buffer) ─────────────────────────────────────────────────────
const INPUT_BUFFER_WINDOW := 0.1   ## 행동 잠금 종료 직전 이 구간 안에 들어온 입력만 버퍼링
var _buffered_action: String = ""  ## "" | "attack" | "q" | "e" | "r"

# ── 노드 ─────────────────────────────────────────────────────────────────────
var _hud_scene: HudScene = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# 맵/HUD는 각각 독립 서브씬(scenes/map/map.tscn, scenes/ui/hud.tscn)으로 game.tscn에
	# 직접 인스턴싱되어 있다 — 런타임에 new()로 조립하는 대신 고유 이름으로 찾아 참조만 쥔다.
	_map_scene = %MapScene as MapScene
	_hud_scene = %HudScene as HudScene

	player = PlayerScene.instantiate() as Node2D
	add_child(player)
	var job: Dictionary = Global.JOBS.get(Global.selected_job, Global.JOBS["swordsman"])
	player.setup(job, 160, WORLD_H - 80 - 60, "blue", true)
	player.scene_ref = self
	player.basic_attack_hit.connect(_on_player_basic_attack_hit)
	Global.screen_shake_requested.connect(_on_shake_requested)
	Global.hitstop_requested.connect(_on_hitstop_requested)
	# Darby: 게임 시작 시 스탯 초기화
	if job.get("key") == "darby":
		_darby_roll_stats(player, true)

	dummy = DummyScene.instantiate() as Node2D
	add_child(dummy)
	dummy.setup(900, WORLD_H - 80 - 48)

	_map_scene.setup(player, dummy)
	_hud_scene.setup(player, dummy)

# ── 피해 헬퍼 ─────────────────────────────────────────────────────────────────
## is_primary_hit: 평타/Q/E/R의 단발성 직접 적중이면 true(기본값) — 궁극기 쿨감 + 히트스톱 발동.
## DoT 틱, 검사자 R처럼 짧은 간격으로 반복되는 판정은 연출 스팸을 막기 위해 false로 호출한다.
func _deal_damage(attacker, target, dmg: float, types: Array, is_primary_hit: bool = true) -> float:
	var mult := 1.0
	var jk_a: String = attacker.job.get("key", "") if attacker != null and attacker.has_method("_draw") else ""
	if jk_a == "shoveler":
		mult = attacker.skill_passive.get_buried_damage_mult(target, attacker) if attacker.skill_passive != null else 1.0
	var taken: float = target.apply_damage(dmg * mult, types)
	_pop_dmg(float(target.rect.get_center().x), float(target.rect.position.y) - 10.0, taken)
	if is_primary_hit and taken > 0.0:
		_register_hit(attacker)
	return taken

func _pop_dmg(wx: float, wy: float, dmg: float) -> void:
	if dmg <= 0.0: return
	dmg_texts.append({"text": str(int(dmg)), "wx": wx, "wy": wy, "t": 0.8})

## 모든 직업의 평타/Q/E/R 단발 적중 공통 처리 — 대난투 속도감을 위한 궁극기 쿨감 + 히트스톱.
func _register_hit(attacker) -> void:
	attacker.r_cd_rem = maxf(0.0, attacker.r_cd_rem - ULT_CDR_ON_HIT)
	Global.request_hitstop(HITSTOP_DURATION)

# ── 히트스톱 / 화면 흔들림 (Global 시그널 수신) ──────────────────────────────
## Engine.time_scale을 잠깐 0으로 낮춰 애니메이션·이동을 전역 정지시킨다.
## 정지 해제 타이머는 ignore_time_scale=true로 실시간을 기준으로 동작해야
## time_scale=0 상태에서도 정상적으로 흘러 스스로 원상복구할 수 있다.
func _on_hitstop_requested(duration: float) -> void:
	if _hitstop_active: return
	_hitstop_active = true
	Engine.time_scale = 0.0
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		_hitstop_active = false)

func _on_shake_requested(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength, strength)
	shake_time     = maxf(shake_time, duration)

# ── Shovel 스택 / 매장 ────────────────────────────────────────────────────────
func _apply_shovel_stack(owner, target, by_dust: bool = false, trigger_bury: bool = false) -> void:
	if owner.skill_passive != null: owner.skill_passive.try_add_stack(owner, target, by_dust, trigger_bury)

# ── Darby 헬퍼 ────────────────────────────────────────────────────────────────
## DB_Passive에서 호출하는 rise fx 생성 헬퍼 (scene 참조가 필요해 game_scene에 둠)
func _darby_spawn_rise_fx(p) -> void:
	var rise: Node2D = ChipScene.instantiate() as Node2D
	rise.name = "ChipRise"
	add_child(rise)
	rise.setup_rise(float(p.rect.get_center().x), float(p.rect.position.y), Global.random_palette_color())
	chip_rise_fx.append(rise)

## DB_Q에서 호출하는 칩 생성 헬퍼
func _darby_spawn_chip(p, tgt, spd: float, dmg: float) -> void:
	var chip: Node2D = ChipScene.instantiate() as Node2D
	add_child(chip)
	chip.setup_chip(float(p.rect.get_center().x), float(p.rect.get_center().y) - 10.0,
		tgt, spd, dmg, Global.random_palette_color(), p, p.job.get("q_dmg", ["physical"]))
	chips.append(chip)

func _darby_roll_stats(p, initial: bool = false) -> void:
	if p.skill_passive != null:
		p.skill_passive.initial_roll(p, self)

func _darby_passive_update(p, dt: float) -> void:
	if p.skill_passive != null: p.skill_passive.update(p, dt, self)

func _darby_q_update(p, dt: float) -> void:
	if p._darby_q_queue.is_empty(): return
	var q: Dictionary = p._darby_q_queue
	q["t"] = float(q["t"]) + dt
	while int(q["left"]) > 0 and float(q["t"]) >= float(q["interval"]):
		q["t"] = float(q["t"]) - float(q["interval"])
		q["left"] = int(q["left"]) - 1
		var tgt = q["target"]
		if tgt != null and is_instance_valid(tgt):
			var chip: Node2D = ChipScene.instantiate() as Node2D
			add_child(chip)
			chip.setup_chip(float(p.rect.get_center().x), float(p.rect.get_center().y) - 10.0,
				tgt, float(q["speed"]), float(q["damage"]),
				Global.random_palette_color(), p, p.job.get("q_dmg", ["physical"]))
			chips.append(chip)
	if int(q["left"]) <= 0: p._darby_q_queue = {}

func _darby_steal_on_touch(p) -> void:
	if not p.darby_r_active: return
	if not p.rect.intersects(dummy.rect): return
	if p.skill_r != null: p.skill_r.steal(p, dummy)

# ── 입력 ──────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 타겟팅 중 Q/E/R 외 키 → 취소
		if targeting_active and not (event.is_action("skill_q") or event.is_action("skill_e") or event.is_action("skill_r")):
			targeting_active = false
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu.tscn"); return
		if event.keycode == KEY_F2: player.hp = 0.0; return
		if player.dead or player.revive_active: return
		# Godot은 동시에 눌린 키마다 별도의 InputEventKey를 전달하므로 WASD와
		# Q/E/R가 같은 프레임에 눌려도 서로를 막지 않고 모두 처리된다.
		if event.is_action("skill_q"):
			if _try_or_buffer("q"): _press_q()
		elif event.is_action("skill_e"):
			if _try_or_buffer("e"): _press_e()
		elif event.is_action("skill_r"):
			if _try_or_buffer("r"): _press_r()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not player.dead and not player.revive_active:
			# 다비 Q 타겟팅 중이면 좌클릭이 공격이 아니라 확인(발동) 입력이 된다.
			if targeting_active and player.job.get("key", "") == "darby":
				_check_darby_q_confirm()
			elif _try_or_buffer("attack"):
				player.perform_basic_attack()

	# 툴팁: 마우스 이동 or 버튼
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_hud_scene.update_tooltip(get_viewport().get_mouse_position())

# ── 선입력(Input Buffer) ─────────────────────────────────────────────────────
## 현재 조작 불가 상태(스윙/캐스팅 등)로 남아있는 잠금 시간 중 최댓값.
func _player_action_lock() -> float:
	return maxf(player.move_lock_time, maxf(player.attack_lock_time, player.skill_lock_time))

## 지금 바로 실행 가능하면 true(즉시 실행하라는 뜻). 잠겨 있다면 잠금 종료가
## 임박(INPUT_BUFFER_WINDOW 이내)했을 때만 버퍼에 기록하고 false를 반환한다.
func _try_or_buffer(action: String) -> bool:
	var lock := _player_action_lock()
	if lock <= 0.0:
		return true
	if lock <= INPUT_BUFFER_WINDOW:
		_buffered_action = action
	return false

## 매 프레임 호출 — 잠금이 막 풀린 시점에 버퍼된 입력이 있으면 지연 없이 실행.
func _consume_input_buffer() -> void:
	if _buffered_action == "" or _player_action_lock() > 0.0:
		return
	var action := _buffered_action
	_buffered_action = ""
	match action:
		"attack": player.perform_basic_attack()
		"q": _press_q()
		"e": _press_e()
		"r": _press_r()

# ── 기본 공격 (사거리 기반 근/원거리 시스템 — player.gd가 판정, 여기서는 피해 적용 + 직업별 후속 효과만) ──
func _on_player_basic_attack_hit(target: Node2D, dmg: float, dmg_types: Array) -> void:
	var jk: String = player.job.get("key", "")
	_deal_damage(player, target, dmg, dmg_types)
	if jk == "wind_archer":
		player.wind_on_basic_hit()
	elif jk == "shoveler":
		# R로 예약된 강화 매장 공격인지 여부를 _apply_shovel_stack이 플래그를 소비하기 전에 캡처
		var was_enhanced: bool = player.shovel_r_armed
		_apply_shovel_stack(player, target, false, true)
		if was_enhanced:
			Global.request_screen_shake(SHOVEL_ENHANCED_SHAKE_STRENGTH, SHOVEL_ENHANCED_SHAKE_DURATION)

# ── 스킬 ──────────────────────────────────────────────────────────────────────
func _press_q() -> void:
	var jk: String = player.job.get("key", "")
	match jk:
		"swordsman", "wind_archer":
			if player.q_cd_rem <= 0.0:
				if jk == "swordsman": player.start_q()
				else: player.start_wind_q()
		"darby":
			if player.skill_q == null or not player.skill_q.can_start_targeting(player):
				targeting_active = false; return
			if not targeting_active:
				targeting_active = true
				targeting_timer = player.skill_q.targeting_timeout
				targeting_radius = player.skill_q.targeting_radius
			else:
				targeting_active = false
		"shoveler":
			if player.skill_q != null and player.skill_q.can_use(player):
				var spawn_list: Array = player.skill_q.get_spawn_list(player)
				for sp in spawn_list:
					var d: Node2D = DirtScene.instantiate() as Node2D
					add_child(d)
					d.setup(float(sp["wx"]), float(sp["wy"]), float(sp["vx"]), float(sp["vy"]), player)
					dirt_particles.append(d)
				player.skill_q.activate(player)

func _press_e() -> void:
	var jk: String = player.job.get("key", "")
	match jk:
		"swordsman":
			if player.skill_e != null and player.skill_e.can_use(player):
				var mouse_world := get_viewport().get_mouse_position() + Vector2(cam_x, cam_y)
				var target_pos: Vector2 = player.skill_e.get_target_pos(player, mouse_world)
				var fx: Node2D = SwordScene.instantiate() as Node2D
				add_child(fx)
				fx.owner_node = player; fx.dmg_types = player.job.get("e_dmg", ["physical"])
				fx.setup(target_pos, player, player.skill_e.slam_radius,
					player.skill_e.leap_height, player.skill_e.leap_up_time, player.skill_e.leap_down_time)
				sword_effects.append(fx)
				player.skill_e.activate(player)
		"wind_archer":
			if player.skill_e != null and player.skill_e.can_use(player):
				player.skill_e.activate(player)
		"darby":
			if player.skill_e != null and player.skill_e.can_use(player):
				player.skill_e.activate(player)
		"shoveler":
			if player.skill_e != null and player.skill_e.can_use(player):
				var sp: Dictionary = player.skill_e.get_spawn_params(player, _map_scene.map_solids, WORLD_H)
				if (sp["hit_rect"] as Rect2i).intersects(dummy.rect):
					_deal_damage(player, dummy, float(sp["damage"]), player.job.get("e_dmg", ["physical"]))
					if player.skill_passive != null:
						player.skill_passive.try_add_stack(player, dummy, false, false)
					# 묘석이 솟는 충격으로 판정 중심에서 대상을 바깥쪽으로 튕겨낸다.
					var tomb_ctr: Vector2 = Vector2((sp["hit_rect"] as Rect2i).get_center())
					var kb_dir: Vector2 = Vector2(dummy.rect.get_center()) - tomb_ctr
					if kb_dir.length() < 0.01: kb_dir = Vector2(player.aim_dir)
					player.skill_e.apply_knockback_on_hit(dummy, kb_dir)
				var tomb: Node2D = TombScene.instantiate() as Node2D
				add_child(tomb)
				tomb.setup(sp["rect"], float(sp["start_y"]), float(sp["target_y"]))
				tombstones.append(tomb)
				player.skill_e.activate(player)

func _press_r() -> void:
	var jk: String = player.job.get("key", "")
	match jk:
		"swordsman":
			if player.skill_r != null and player.skill_r.can_use(player):
				player.skill_r.activate(player)
		"wind_archer":
			if player.skill_r != null and player.skill_r.can_use(player):
				var sp: Dictionary = player.skill_r.get_spawn_params(player)
				var proj: Node2D = ProjScene.instantiate() as Node2D
				add_child(proj)
				proj.setup_directional(
					float(sp["world_x"]), float(sp["world_y"]),
					float(sp["dir_x"]),   float(sp["dir_y"]),
					float(sp["speed"]),   float(sp["damage"]),
					player, sp["dmg_types"],
					int(sp["radius"]),    sp["color"],
					float(sp["life"]),    -1.0,
					sp["pierce"],         Projectile.Style.WIND_ULT)
				var img := Image.load_from_file(sp["texture"])
				if img: proj._tex = ImageTexture.create_from_image(img)
				wind_ult_arrows.append(proj)
				player.skill_r.activate(player)
		"darby":
			if player.skill_r != null and player.skill_r.can_use(player):
				player.skill_r.activate(player)
		"shoveler":
			if player.skill_r != null and player.skill_r.can_use(player):
				player.skill_r.activate(player)

# ── Darby Q 마우스 2차 확인 ───────────────────────────────────────────────────
func _check_darby_q_confirm() -> void:
	# 타겟팅 원 내에 더미가 있으면 발사
	var jk: String = player.job.get("key", "")
	if jk != "darby" or not targeting_active: return
	var my_ctr := Vector2(player.rect.get_center())
	var d := my_ctr.distance_to(dummy.center())
	if d > targeting_radius: targeting_active = false; return
	if player.skill_q != null: player.skill_q.activate(player, dummy)
	targeting_active = false

# ── 메인 루프 ─────────────────────────────────────────────────────────────────
func _process(dt: float) -> void:
	var jk: String = player.job.get("key", "")

	# 탑다운 360도 조준 방향 — 마우스 월드 좌표 기준, 매 프레임 갱신 (평타/Q/E/R 각도 계산에 사용).
	# 데드존: 마우스가 캐릭터 중심 MOUSE_DEADZONE_RADIUS 반경 이내로 들어오면 방향을 갱신하지 않고,
	# 데드존 진입 직전의 마지막 유효 방향/좌표(player.aim_dir / last_valid_mouse_world)를 그대로 유지한다.
	# → 커서가 캐릭터 위에 있을 때 조준이 급격히 뒤틀리는 현상을 방지.
	var mouse_world := get_viewport().get_mouse_position() + Vector2(cam_x, cam_y)
	var to_mouse := mouse_world - Vector2(player.rect.get_center())
	if to_mouse.length() > MOUSE_DEADZONE_RADIUS:
		player.aim_dir = to_mouse.normalized()
		player.last_valid_mouse_world = mouse_world

	# 화면 흔들림 감쇠
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - dt)
		if shake_time <= 0.0: shake_strength = 0.0

	# 타겟팅 타이머
	if targeting_active:
		targeting_timer -= dt
		if targeting_timer <= 0.0: targeting_active = false

	# 플레이어 입력·이동
	if not player.dead and not player.revive_active:
		player.handle_input(dt, _map_scene.map_solids, _map_scene.map_bushes)
	player.move_and_collide_map(dt, _map_scene.map_solids, _map_scene.map_bushes, WORLD_W, WORLD_H)
	player.player_update(dt)

	# 선입력 소비 — 이번 프레임에 행동 잠금이 막 풀렸다면 버퍼된 입력을 지연 없이 실행
	_consume_input_buffer()

	# Darby 패시브·Q큐·R스틸
	if jk == "darby":
		_darby_passive_update(player, dt)
		_darby_q_update(player, dt)
		_darby_steal_on_touch(player)

	# Swordsman R 반복 피해
	if player.r_active and jk == "swordsman":
		while player.r_tick >= 0.5:
			player.r_tick -= 0.5
			if player.rect.intersects(dummy.rect):
				_deal_damage(player, dummy, 70.0 * player.get_effective_dmg_mult(),
					player.get_effective_dmg_types(player.job.get("r_dmg", ["physical"])), false)

	# 부활 처리
	if player.dead and player.respawn_time <= 0.0:
		player.respawn(160, WORLD_H - 80 - 60)
		if player.job.get("key") == "darby": _darby_roll_stats(player, true)

	# 더미 물리
	dummy.dummy_update(dt, _map_scene.map_solids, _map_scene.map_bushes)

	# 바람궁수 R 화살
	for proj in wind_ult_arrows.duplicate():
		proj.proj_update(dt)
		if proj.alive:
			if proj._world_pos.x < -400 or proj._world_pos.x > WORLD_W + 400: proj.alive = false
			var did := dummy.get_instance_id()
			if proj.alive and not (did in proj.hit_ids) and proj.collides_rect(dummy.rect):
				_deal_damage(player, dummy, proj.damage, proj.dmg_types)
				Global.request_screen_shake(WIND_R_SHAKE_STRENGTH, WIND_R_SHAKE_DURATION)
				# 에어본(넉백+스턴) 적용 — 화살이 날아간 방향과 무관하게 항상 위(화면 위쪽)로 띄운다.
				if proj.owner_node != null and proj.owner_node.skill_r != null:
					var kb_dir := Vector2(0.0, -1.0)
					proj.owner_node.skill_r.apply_airborne_on_hit(dummy, kb_dir)
				proj.hit_ids.append(did)
				if not proj.pierce: proj.alive = false
		if not proj.alive: proj.queue_free(); wind_ult_arrows.erase(proj)

	# 검사자 E 장판 슬램 — Tween 착지 시점에 1회 광역 판정 (범위 안에 있으면 시전자 본인도 피해)
	for fx in sword_effects.duplicate():
		if fx.consume_just_landed():
			var hb: Rect2i = fx.hitbox_world()
			var e_types: Array = player.get_effective_dmg_types(fx.dmg_types)
			var e_mult: float = player.get_effective_dmg_mult()
			var did := dummy.get_instance_id()
			if not (did in fx.hit_done) and hb.intersects(dummy.rect):
				_deal_damage(player, dummy, dummy.max_hp * player.skill_e.hit_damage_pct * e_mult, e_types)
				fx.hit_done.append(did)
				swordsman_dots.append({"target": dummy, "time": player.skill_e.dot_duration,
					"tick": player.skill_e.dot_tick_rate, "owner": player, "damage_types": fx.dmg_types})
			var pid := player.get_instance_id()
			if not (pid in fx.hit_done) and hb.intersects(player.rect):
				_deal_damage(player, player, player.max_hp * player.skill_e.hit_damage_pct * e_mult, e_types)
				fx.hit_done.append(pid)
				swordsman_dots.append({"target": player, "time": player.skill_e.dot_duration,
					"tick": player.skill_e.dot_tick_rate, "owner": player, "damage_types": fx.dmg_types})
		if not fx.alive: fx.queue_free(); sword_effects.erase(fx)

	# E DoT (대상이 더미든 시전자 본인이든 동일하게 처리)
	for dot in swordsman_dots.duplicate():
		dot["time"] -= dt; dot["tick"] -= dt
		if float(dot["time"]) <= 0.0: swordsman_dots.erase(dot); continue
		if float(dot["tick"]) <= 0.0:
			dot["tick"] = player.skill_e.dot_tick_rate
			var tgt = dot["target"]
			if tgt != null:
				var dot_dmg: float = max(1.0, float(tgt.hp) * player.skill_e.dot_tick_damage) * player.get_effective_dmg_mult()
				_deal_damage(player, tgt, dot_dmg, player.get_effective_dmg_types(dot["damage_types"]), false)

	# Chip 투사체 (Darby Q)
	for chip in chips.duplicate():
		chip.proj_update(dt)
		if not chip.alive:
			# 도착 시 피해
			if is_instance_valid(chip.target_node):
				_deal_damage(player, chip.target_node, chip.damage, chip.dmg_types)
			chip.queue_free(); chips.erase(chip)

	# Chip 라이즈 이펙트
	for rise in chip_rise_fx.duplicate():
		rise.proj_update(dt)
		if not rise.alive: rise.queue_free(); chip_rise_fx.erase(rise)

	# Dirt 파티클 (Shoveler Q)
	for d in dirt_particles.duplicate():
		d.proj_update(dt, _map_scene.map_solids, _map_scene.map_bushes)
		if d.alive and d.collides_rect(dummy.rect):
			if player.skill_passive != null:
				player.skill_passive.apply_slow(dummy)
				player.skill_passive.try_add_stack(player, dummy, true, false)
		if not d.alive: d.queue_free(); dirt_particles.erase(d)

	# Tombstone (Shoveler E)
	for tomb in tombstones.duplicate():
		var just_solid: bool = tomb.tomb_update(dt)
		if just_solid and not (tomb.world_rect in _map_scene.map_solids):
			_map_scene.map_solids.append(tomb.world_rect)
		tomb.position = Vector2(tomb.world_rect.position) + Vector2(-cam_x, -cam_y)
		if not tomb.alive:
			_map_scene.map_solids.erase(tomb.world_rect)
			tomb.queue_free(); tombstones.erase(tomb)

	# 피해 텍스트
	var kept: Array = []
	for d in dmg_texts:
		d["t"] -= dt; d["wy"] -= 25.0 * dt
		if float(d["t"]) > 0.0: kept.append(d)
	dmg_texts = kept

	_update_camera()
	_map_scene.redraw()
	player.queue_redraw(); dummy.queue_redraw()
	_hud_scene.sync_frame(cam_x, cam_y, targeting_active, targeting_radius, dmg_texts)
	_hud_scene.redraw()

# ── 카메라 ────────────────────────────────────────────────────────────────────
func _current_shake_offset() -> Vector2:
	if shake_time <= 0.0: return Vector2.ZERO
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength

func _update_camera() -> void:
	cam_x = clampf(float(player.rect.get_center().x) - SCR_W / 2.0, 0.0, float(WORLD_W - SCR_W))
	cam_y = clampf(float(player.rect.get_center().y) - SCR_H / 2.0, 0.0, float(WORLD_H - SCR_H))
	# 화면 흔들림은 렌더링 오프셋에만 더한다 — cam_x/cam_y 자체(마우스 월드 좌표 변환 등
	# 게임플레이 로직이 참조하는 "논리적" 카메라 값)는 흔들림의 영향을 받지 않는다.
	var off := Vector2(-cam_x, -cam_y) + _current_shake_offset()
	_map_scene.sync_camera(cam_x, cam_y)
	player.position = Vector2(player.rect.position) + off
	dummy.position  = Vector2(dummy.rect.position) + off
	for proj in wind_ult_arrows:
		if is_instance_valid(proj): proj.position = proj._world_pos + off
	for chip in chips:
		if is_instance_valid(chip): chip.position = chip._world_pos + off
	for rise in chip_rise_fx:
		if is_instance_valid(rise): rise.position = rise._world_pos + off
	for d in dirt_particles:
		if is_instance_valid(d): d.position = d._world_pos + off
	for fx in sword_effects:
		if is_instance_valid(fx): fx.position = fx.target_pos + off
