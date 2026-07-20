# jobs/swordsman/e.gd — 매지컬플레임초울트라비저블스워드나이트 (탑다운 장판 슬램)
# 값은 인스펙터에서 조정 가능.
# 기존(사이드뷰): 화면 위에서 낙하하는 검을 캐릭터 앞에 소환.
# 신규(탑다운):   마우스가 가리키는 지점(사거리 내로 제한)을 향해 검이 도약했다가
#                내리찍는 광역 슬램. 실제 Z축 낙하 대신 sword_slam.gd가 Tween으로
#                시각적 도약/착지만 연출하고, 판정은 착지 순간 착지 지점 원형 범위에 적용.
class_name SwordsmanE
extends Resource

@export_group("슬램 피해")
@export var hit_damage_pct:  float = 0.10   ## 착지 판정: 최대 체력의 몇 % 피해
@export var dot_tick_damage: float = 0.005  ## DoT 틱당: 현재 체력의 몇 % 피해
@export var dot_duration:    float = 10.0   ## DoT 지속 시간 (초)
@export var dot_tick_rate:   float = 0.25   ## DoT 틱 간격 (초)

@export_group("이속 버프")
@export var speed_buff_pct: float = 1.0    ## 이속 버프 비율 (+100%)
@export var speed_buff_dur: float = 1.0    ## 이속 버프 지속 시간 (초)

@export_group("슬램 범위 / 사거리")
@export var slam_radius:    float = 90.0   ## 착지 시 판정 반경 (픽셀)
@export var max_cast_range: float = 420.0  ## 캐릭터로부터 착지 지점까지 최대 거리 (마우스 방향, 이 거리로 클램프)

@export_group("연출 (Tween)")
@export var leap_height:  float = 260.0  ## 도약 시 화면상 최대 상승 높이 (픽셀)
@export var leap_up_time: float = 0.18   ## 도약 소요 시간 (초)
@export var leap_down_time: float = 0.22 ## 낙하(착지) 소요 시간 (초)

func can_use(player) -> bool:
	return not player.revive_active \
		and player.e_cd_rem <= 0.0 \
		and player.skill_lock_time <= 0.0

## 탑다운: 마우스 월드 좌표 방향으로 착지 지점을 계산 (사거리 내로 클램프).
func get_target_pos(player, mouse_world: Vector2) -> Vector2:
	var origin: Vector2 = Vector2(player.rect.get_center())
	var to_mouse := mouse_world - origin
	if to_mouse.length() > max_cast_range:
		to_mouse = to_mouse.normalized() * max_cast_range
	return origin + to_mouse

func activate(player) -> void:
	player.add_speed_buff(speed_buff_pct, speed_buff_dur)
	player.e_cd_rem = float(player.job.get("e_cd", 15.0))
