# map_tile_def.gd — 맵 타일 종류(0=바닥/1=부쉬/2=벽) 하나의 정의.
# 인스펙터에서 tile_type / tileset_colors(색상 팔레트) 또는 tileset_textures(실제 이미지) /
# 외곽선 여부를 직접 조정할 수 있도록 Resource로 분리했다.
class_name MapTileDef
extends Resource

@export var tile_type: int = 0                    ## 0=바닥, 1=부쉬, 2=벽 (game_scene.gd의 TileType과 일치시켜야 함)
@export var tileset_colors: Array[Color] = []      ## tileset_textures가 비어있을 때 쓰는 색상 팔레트(폴백)
@export var tileset_textures: Array[Texture2D] = [] ## 있으면 색상 대신 이 텍스처를 원본 크기 그대로 그린다
@export var draw_outline: bool = false             ## 병합된 영역 테두리를 그릴지 여부
@export var outline_color: Color = Color(0, 0, 0, 0)
@export var outline_width: float = -1.0            ## -1.0이면 Godot 기본(hairline) 두께

## 이 타일 종류에 배정 가능한 타일셋 변형 개수 — 텍스처가 있으면 텍스처 개수, 없으면 색상 개수.
func variant_count() -> int:
	return tileset_textures.size() if tileset_textures.size() > 0 else tileset_colors.size()
