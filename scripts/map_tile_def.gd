# map_tile_def.gd — 맵 타일 종류(0=바닥/1=부쉬/2=벽) 하나의 정의.
# 인스펙터에서 tile_type / tileset_colors(색상 팔레트, 추후 텍스처로 확장 가능) /
# 외곽선 여부를 직접 조정할 수 있도록 Resource로 분리했다.
class_name MapTileDef
extends Resource

@export var tile_type: int = 0                ## 0=바닥, 1=부쉬, 2=벽 (game_scene.gd의 TileType과 일치시켜야 함)
@export var tileset_colors: Array[Color] = []  ## 이 타입의 타일에 무작위로 배정될 팔레트(타일셋) 후보들
@export var draw_outline: bool = false         ## 병합된 영역 테두리를 그릴지 여부
@export var outline_color: Color = Color(0, 0, 0, 0)
@export var outline_width: float = -1.0        ## -1.0이면 Godot 기본(hairline) 두께
