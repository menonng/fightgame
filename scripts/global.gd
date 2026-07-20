# global.gd — AutoLoad
# 각 직업의 stats.tres(있으면) 또는 stats.gd 기본값에서 스탯을 로드해 JOBS 구성
extends Node

var selected_job: String = "swordsman"

## game_scene.gd의 WORLD_W/WORLD_H/경계벽 두께와 반드시 동일하게 유지 — 넉백/에어본처럼
## game_scene을 직접 참조할 수 없는 상태이상(status_effects/*)이 착지 지점을 맵 밖으로
## 벗어나지 않게 클램프할 때 사용한다.
const WORLD_W := 2100
const WORLD_H := 1400
const WORLD_WALL := 40

## 히트박스/판정 텔레그래프 등 디버그성 시각 요소를 보여줄지 여부.
## 연습 모드(현재 game_scene)는 true, 추후 추가될 멀티플레이 씬은 false로 설정해
## 상대에게 정확한 판정 범위가 노출되지 않도록 한다.
var is_practice_mode: bool = true

# ── 글로벌 연출 트리거 ────────────────────────────────────────────────────────
# game_scene을 직접 참조할 수 없는 스크립트(직업 스킬 Resource 등)도 화면 흔들림/
# 히트스톱을 요청할 수 있도록 시그널로 중계한다. game_scene이 _ready()에서 구독해
# 실제 카메라 오프셋/Engine.time_scale 처리를 담당한다.
signal screen_shake_requested(strength: float, duration: float)
signal hitstop_requested(duration: float)

func request_screen_shake(strength: float, duration: float) -> void:
	screen_shake_requested.emit(strength, duration)

func request_hitstop(duration: float) -> void:
	hitstop_requested.emit(duration)

const PALETTE: Array = [
	Color(0.22, 0.77, 0.73), Color(0.85, 0.00, 0.00), Color(0.00, 0.00, 1.00),
	Color(1.00, 0.65, 0.00), Color(1.00, 0.89, 0.07), Color(1.00, 0.75, 0.80),
	Color(0.90, 0.00, 0.20), Color(0.55, 0.78, 0.25), Color(0.96, 0.65, 0.72),
	Color(0.12, 0.24, 0.86), Color(0.36, 0.25, 0.65),
]

func random_palette_color() -> Color:
	return PALETTE[randi() % PALETTE.size()]

var JOBS: Dictionary = {}
const JOB_KEYS := ["swordsman", "wind_archer", "darby", "shoveler"]

func _ready() -> void:
	for jk in JOB_KEYS:
		JOBS[jk] = _load_stats(jk)

## resources/jobs/{jk}/stats.tres 가 있으면 그 값을, 없으면 scripts/jobs/{jk}/stats.gd 기본값을 사용
func _load_stats(jk: String) -> Dictionary:
	var tres_path := "res://resources/jobs/%s/stats.tres" % jk
	if ResourceLoader.exists(tres_path):
		var res: Resource = load(tres_path)
		if res.has_method("to_dict"):
			return res.to_dict()
	var gd_path := "res://scripts/jobs/%s/stats.gd" % jk
	var script: GDScript = load(gd_path)
	return script.get_stats()
