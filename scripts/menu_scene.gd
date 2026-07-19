# MenuScene.gd
extends Node2D

var _font: Font = null
var _job_idx: int = 0
const JOB_KEYS := ["swordsman", "wind_archer", "darby", "shoveler"]

var _btn_job   := Rect2(440, 310, 400, 56)
var _btn_start := Rect2(440, 400, 400, 70)

func _ready() -> void:
	_font = ThemeDB.fallback_font
	for i in range(JOB_KEYS.size()):
		if JOB_KEYS[i] == Global.selected_job: _job_idx = i; break

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720), Color(0.04,0.05,0.06))
	if _font == null: return
	draw_string(_font, Vector2(490,190), "FightGame",
		HORIZONTAL_ALIGNMENT_LEFT,-1,58,Color(0.96,0.96,0.98))
	draw_string(_font, Vector2(450,255), "Plains 맵  ·  연습 모드 (Practice)",
		HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(0.55,0.55,0.6))
	var jname: String = Global.JOBS.get(JOB_KEYS[_job_idx],{}).get("name","?")
	_draw_btn(_btn_job,   "직업: " + jname + "  (클릭으로 변경)")
	_draw_btn(_btn_start, "START")
	# 조작법
	draw_string(_font, Vector2(380,510),
		"A/D 이동  W 점프/사다리  Q/E/R 스킬  좌클릭 기본공격  ESC 메뉴  F2 즉사",
		HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.5,0.5,0.55))
	# 직업 설명
	var jk: String = JOB_KEYS[_job_idx]
	var job := Global.JOBS.get(jk, {})
	var lines := ["  P: " + job.get("passive_name","") + " — " + job.get("passive_desc",""),
				  "  Q: " + job.get("q_name","")       + " — " + job.get("q_desc",""),
				  "  E: " + job.get("e_name","")       + " — " + job.get("e_desc",""),
				  "  R: " + job.get("r_name","")       + " — " + job.get("r_desc","")]
	for i in range(lines.size()):
		draw_string(_font, Vector2(380, 545 + i * 22),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.7,0.8,1.0,0.85))

func _draw_btn(r: Rect2, text: String) -> void:
	draw_rect(r, Color(0.18,0.18,0.22))
	draw_rect(r, Color(0.47,0.47,0.55), false)
	draw_string(_font, Vector2(r.position.x+12.0, r.position.y+r.size.y/2.0+8.0),
		text, HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color(0.94,0.94,0.96))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _btn_job.has_point(event.position):
			_job_idx = (_job_idx + 1) % JOB_KEYS.size()
			Global.selected_job = JOB_KEYS[_job_idx]
			queue_redraw()
		if _btn_start.has_point(event.position):
			get_tree().change_scene_to_file("res://scenes/game.tscn")
