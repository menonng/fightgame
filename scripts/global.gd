# global.gd — AutoLoad
# 각 직업의 stats.tres(있으면) 또는 stats.gd 기본값에서 스탯을 로드해 JOBS 구성
extends Node

var selected_job: String = "swordsman"

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
