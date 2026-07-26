class_name MapScene
extends Node2D

## 맵 지형(타일 그리드 → TileMapLayer 채우기, 벽/부쉬 병합 사각형 렌더링)과 파묻힘 흙무덤
## 렌더링을 전담하는 독립 서브씬(scenes/map/map.tscn). game_scene.gd는 이 씬을 game.tscn에
## 직접 인스턴싱해 넣고, setup()으로 player/dummy 참조만 넘겨준 뒤 매 프레임 sync_camera()와
## redraw()만 호출한다 — 맵 생성/그리기 로직 자체는 이 스크립트 안에서 자기완결적으로 처리된다.

const WORLD_W := 3200
const WORLD_H := 2400
const TILE_SIZE := 32
const MAP_COLS := 100   # WORLD_W / TILE_SIZE (3200/32, 나머지 없음)
const MAP_ROWS := 75    # WORLD_H / TILE_SIZE (2400/32, 나머지 없음)
const WALL_TILES := 2   ## 경계벽 두께(타일 단위) — 그리드에 맞춰 정수 타일로 정의
enum TileType { FLOOR = 0, BUSH = 1, WALL = 2 }

const MAP_RNG_SEED := 7007   ## 맵을 '확정'하는 고정 시드 — 실행할 때마다 같은 결과 재현

var map_solids: Array = []   ## 완전 차단 지형 (경계 벽) — 병합된 Rect2i, 충돌/렌더링 그대로 사용
var map_bushes: Array = []   ## 부쉬 — 통과 가능, 이동속도 감소 + 은신 성격 (병합된 Rect2i)

var _floor_def: MapTileDef = null
var _bush_def: MapTileDef  = null
var _wall_def: MapTileDef  = null

var _tile_grid: Array = []      ## flat Array[int] (TileType 값), 크기 MAP_COLS*MAP_ROWS
var _tile_variant: Array = []   ## flat Array[int], FLOOR/BUSH 타일의 타일셋 인덱스(WALL은 -1)

var _terrain_tilemap: TileMapLayer = null
var _floor_source_ids: Array = []
var _bush_source_ids: Array = []

var _map_draw: Node2D    = null
var _burial_draw: Node2D = null   ## 파묻힘 흙무덤 전용 공용 레이어 — 맵 바로 위, 캐릭터보다 아래

var player_ref: Node2D = null   ## 파묻힘 흙무덤을 그리기 위한 game_scene의 플레이어/더미 참조
var dummy_ref: Node2D  = null

var _cam_x: float = 0.0   ## game_scene이 sync_camera()로 매 프레임 넘겨주는 카메라 오프셋
var _cam_y: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_terrain_tilemap = %TerrainTileMap as TileMapLayer
	_map_draw = %MapDraw as Node2D
	_map_draw.draw.connect(_draw_map)

	_burial_draw = %BurialDraw as Node2D
	_burial_draw.draw.connect(_draw_burial_mounds)

	_build_map()

func setup(p_player: Node2D, p_dummy: Node2D) -> void:
	player_ref = p_player
	dummy_ref = p_dummy

## game_scene의 _update_camera()에서 매 프레임 호출 — TerrainTileMap은 _ws()처럼 칸마다
## 오프셋을 계산하는 대신, 노드 전체를 카메라만큼 옮겨서 스크롤을 흉내낸다(_draw_map()의
## 벽/외곽선과 동일하게 흔들림은 적용하지 않는다).
func sync_camera(cam_x: float, cam_y: float) -> void:
	_cam_x = cam_x
	_cam_y = cam_y
	_terrain_tilemap.position = Vector2(-cam_x, -cam_y)

func redraw() -> void:
	_map_draw.queue_redraw()
	_burial_draw.queue_redraw()

## 탑다운 평면 맵 — 사방 경계 벽 + 부쉬(엄폐 지형) 배치.
## 벽/부쉬 배치를 타일 그리드(0=바닥/1=부쉬/2=벽)에 찍은 뒤, 인접한 같은 타입 타일을
## 병합(greedy merge)해 map_solids/map_bushes를 만든다 — 결과는 "개수 적은 Rect2i 배열"이라
## 충돌/렌더링 쪽 코드는 그대로 두고 여기만 교체하면 된다.
func _build_map() -> void:
	_floor_def = _load_tile_def("floor")
	_bush_def  = _load_tile_def("bush")
	_wall_def  = _load_tile_def("wall")

	var wall_px: int = WALL_TILES * TILE_SIZE
	var wall_rects: Array = [
		Rect2i(0, 0, WORLD_W, wall_px),                       # 위쪽 벽
		Rect2i(0, WORLD_H - wall_px, WORLD_W, wall_px),       # 아래쪽 벽
		Rect2i(0, 0, wall_px, WORLD_H),                       # 왼쪽 벽
		Rect2i(WORLD_W - wall_px, 0, wall_px, WORLD_H),       # 오른쪽 벽
	]

	# 기존(2100x1400 기준) 부쉬 배치를 새 맵 크기(3200x2400)에 비례 확대해 재현한다.
	# _stamp_tile_rect가 픽셀→타일 인덱스 변환(정수 나눗셈)을 하므로 별도 반올림 없이
	# 그대로 넘겨도 자동으로 격자에 맞춰진다.
	const OLD_WORLD_W := 2100.0
	const OLD_WORLD_H := 1400.0
	var scale_x: float = float(WORLD_W) / OLD_WORLD_W
	var scale_y: float = float(WORLD_H) / OLD_WORLD_H
	var old_bush_rects: Array = [
		Rect2i(300, 300, 220, 180), Rect2i(760, 220, 260, 200),
		Rect2i(1300, 340, 240, 190), Rect2i(1680, 260, 220, 180),
		Rect2i(400, 700, 260, 220), Rect2i(900, 780, 300, 220),
		Rect2i(1450, 720, 240, 200), Rect2i(650, 1080, 260, 200),
		Rect2i(1200, 1120, 280, 200), Rect2i(180, 1000, 200, 180),
	]
	var bush_rects: Array = []
	for r in old_bush_rects:
		var ri: Rect2i = r
		bush_rects.append(Rect2i(
			int(float(ri.position.x) * scale_x), int(float(ri.position.y) * scale_y),
			int(float(ri.size.x) * scale_x), int(float(ri.size.y) * scale_y)))

	_tile_grid = []
	_tile_grid.resize(MAP_COLS * MAP_ROWS)
	for i in range(_tile_grid.size()): _tile_grid[i] = TileType.FLOOR
	for r in wall_rects: _stamp_tile_rect(r, TileType.WALL)
	for r in bush_rects: _stamp_tile_rect(r, TileType.BUSH)

	map_solids = _merge_tiles_to_rects(TileType.WALL)
	map_bushes = _merge_tiles_to_rects(TileType.BUSH)

	_assign_tile_variants()

	_floor_source_ids = _build_terrain_source_lookup(_floor_def)
	_bush_source_ids  = _build_terrain_source_lookup(_bush_def)
	_populate_terrain_tilemap()

## def.tileset_textures[i]와 같은 Texture2D를 쓰는 TileSetAtlasSource를 찾아 그 source id를
## 반환한다(찾지 못하면 -1). 텍스처 객체로 매칭하므로 인스펙터에서 tileset_textures 순서/개수를
## 바꿔도 TileSet의 source id 하드코딩 없이 그대로 따라간다.
func _build_terrain_source_lookup(def: MapTileDef) -> Array:
	var ids: Array = []
	var ts: TileSet = _terrain_tilemap.tile_set
	for tex in def.tileset_textures:
		var found_id := -1
		if ts != null:
			for i in range(ts.get_source_count()):
				var sid: int = ts.get_source_id(i)
				var src: TileSetAtlasSource = ts.get_source(sid) as TileSetAtlasSource
				if src != null and src.texture == tex:
					found_id = sid
					break
		ids.append(found_id)
	return ids

## _tile_grid/_tile_variant를 기준으로 TerrainTileMap의 셀을 한 번에 채운다(맵 생성 시 1회).
## 벽 타일은 텍스처가 없어 여기서 건너뛰고 기존처럼 _draw_map()이 병합된 사각형으로 그린다.
func _populate_terrain_tilemap() -> void:
	if _terrain_tilemap == null: return
	_terrain_tilemap.clear()
	for row in range(MAP_ROWS):
		for col in range(MAP_COLS):
			var idx: int = row * MAP_COLS + col
			var t: int = _tile_grid[idx]
			if t == TileType.WALL: continue
			var variant: int = _tile_variant[idx]
			var ids: Array = _floor_source_ids if t == TileType.FLOOR else _bush_source_ids
			if variant >= ids.size(): continue
			var source_id: int = ids[variant]
			if source_id < 0: continue
			_terrain_tilemap.set_cell(Vector2i(col, row), source_id, Vector2i.ZERO)

## resources/map/{kind}_tile.tres(인스펙터에서 조정된 리소스)가 있으면 우선 사용,
## 없으면 코드 기본값으로 즉석 생성 — jobs/*의 .tres 우선 로드 관례와 동일한 패턴.
func _load_tile_def(kind: String) -> MapTileDef:
	var tres_path := "res://resources/map/%s_tile.tres" % kind
	if ResourceLoader.exists(tres_path):
		return load(tres_path)
	var def := MapTileDef.new()
	match kind:
		"floor":
			def.tile_type = TileType.FLOOR
			def.tileset_colors = [Color(0.13, 0.16, 0.11)]
		"bush":
			def.tile_type = TileType.BUSH
			def.tileset_colors = [Color(0.22, 0.45, 0.20, 0.75)]
			def.draw_outline = true
			def.outline_color = Color(0.14, 0.30, 0.13, 0.9)
			def.outline_width = 2.0
		"wall":
			def.tile_type = TileType.WALL
			def.tileset_colors = [Color(0.18, 0.35, 0.22)]
			def.draw_outline = true
			def.outline_color = Color(0.10, 0.18, 0.11)
	return def

## 픽셀 좌표 Rect2i를 타일 인덱스 범위로 변환해 그리드에 값을 채운다.
func _stamp_tile_rect(r: Rect2i, value: int) -> void:
	var c0: int = clampi(int(r.position.x) / TILE_SIZE, 0, MAP_COLS - 1)
	var c1: int = clampi(int(r.position.x + r.size.x - 1) / TILE_SIZE, 0, MAP_COLS - 1)
	var r0: int = clampi(int(r.position.y) / TILE_SIZE, 0, MAP_ROWS - 1)
	var r1: int = clampi(int(r.position.y + r.size.y - 1) / TILE_SIZE, 0, MAP_ROWS - 1)
	for row in range(r0, r1 + 1):
		for col in range(c0, c1 + 1):
			_tile_grid[row * MAP_COLS + col] = value

## 같은 값의 인접 타일을 최대한 큰 사각형으로 묶는 greedy merge(2D 그리디 메싱).
## 맵 생성 시 1회만 실행되며, 결과는 지금까지의 손코딩 Rect2i 배열과 동일한 형태다.
func _merge_tiles_to_rects(target_value: int) -> Array:
	var consumed: Array = []
	consumed.resize(MAP_COLS * MAP_ROWS)
	for i in range(consumed.size()): consumed[i] = false
	var rects: Array = []
	for row in range(MAP_ROWS):
		for col in range(MAP_COLS):
			var idx: int = row * MAP_COLS + col
			if _tile_grid[idx] != target_value or consumed[idx]:
				continue
			var width: int = 1
			while col + width < MAP_COLS \
					and _tile_grid[row * MAP_COLS + col + width] == target_value \
					and not consumed[row * MAP_COLS + col + width]:
				width += 1
			var height: int = 1
			while row + height < MAP_ROWS and _tile_row_span_matches(row + height, col, width, target_value, consumed):
				height += 1
			for ry in range(row, row + height):
				for rx in range(col, col + width):
					consumed[ry * MAP_COLS + rx] = true
			rects.append(Rect2i(col * TILE_SIZE, row * TILE_SIZE, width * TILE_SIZE, height * TILE_SIZE))
	return rects

func _tile_row_span_matches(row: int, col: int, width: int, target_value: int, consumed: Array) -> bool:
	for c in range(col, col + width):
		var idx: int = row * MAP_COLS + c
		if _tile_grid[idx] != target_value or consumed[idx]:
			return false
	return true

## 0(바닥)/1(부쉬) 타일마다 해당 MapTileDef.tileset_colors 중 하나를 난수로 배정해
## 맵을 '확정'한다. 고정 시드를 쓰므로 실행할 때마다 항상 같은 배치가 재현된다.
func _assign_tile_variants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_RNG_SEED
	_tile_variant = []
	_tile_variant.resize(_tile_grid.size())
	for i in range(_tile_grid.size()):
		var t: int = _tile_grid[i]
		if t == TileType.FLOOR:
			_tile_variant[i] = rng.randi_range(0, maxi(0, _floor_def.variant_count() - 1))
		elif t == TileType.BUSH:
			_tile_variant[i] = rng.randi_range(0, maxi(0, _bush_def.variant_count() - 1))
		else:
			_tile_variant[i] = -1

# ── 맵 렌더 ──────────────────────────────────────────────────────────────────
func _draw_map() -> void:
	# 바닥/부쉬 칠은 더 이상 여기서 매 프레임 그리지 않는다 — TerrainTileMap(TileMapLayer)이
	# 실제 씬 노드로 그 역할을 담당한다(_populate_terrain_tilemap 참고, 맵 생성 시 1회만 채움).
	# 여기서는 텍스처가 없는 벽(병합된 사각형)만 그린다.
	for r in map_solids:
		_map_draw.draw_rect(_ws(r), _wall_def.tileset_colors[0])
		if _wall_def.draw_outline:
			_map_draw.draw_rect(_ws(r), _wall_def.outline_color, false, _wall_def.outline_width)
	# 부쉬 테두리 — 채움은 TerrainTileMap이 이미 그렸으므로 병합 영역 외곽선만 덧그린다.
	if _bush_def.draw_outline:
		for r in map_bushes:
			_map_draw.draw_rect(_ws(r), _bush_def.outline_color, false, _bush_def.outline_width)

func _ws(r) -> Rect2:
	return Rect2(r.position.x - _cam_x, r.position.y - _cam_y, r.size.x, r.size.y)

# ── 파묻힘 흙무덤 (공용 지면 레이어 — 맵 바로 위, 모든 캐릭터/요소보다 아래) ──────
func _draw_burial_mounds() -> void:
	if player_ref != null and player_ref.is_buried():
		var ground := Vector2(player_ref.rect.position.x + player_ref.rect.size.x / 2.0,
			player_ref.rect.position.y + player_ref.rect.size.y)
		_draw_one_burial_mound(ground, float(player_ref.SPR_W))
	if dummy_ref != null and dummy_ref.is_buried():
		var ground := Vector2(dummy_ref.rect.position.x + dummy_ref.rect.size.x / 2.0,
			dummy_ref.rect.position.y + dummy_ref.rect.size.y)
		_draw_one_burial_mound(ground, float(dummy_ref.rect.size.x) * 1.7)

func _draw_one_burial_mound(world_ground: Vector2, width_ref: float) -> void:
	var screen_pt := world_ground - Vector2(_cam_x, _cam_y)
	var dirt_dark := Color(0.145, 0.094, 0.047, 1.0)
	var dirt_light := Color(0.267, 0.176, 0.098, 1.0)
	var mound_r := width_ref * 0.62
	_burial_draw.draw_rect(Rect2(screen_pt.x - mound_r - 20.0, screen_pt.y - 6.0, mound_r * 2.0 + 40.0, 160.0), dirt_dark)
	_burial_draw.draw_set_transform(Vector2(screen_pt.x, screen_pt.y - 6.0), 0.0, Vector2(1.1, 0.4))
	_burial_draw.draw_circle(Vector2.ZERO, mound_r, dirt_light)
	_burial_draw.draw_arc(Vector2.ZERO, mound_r, 0.0, TAU, 24, dirt_dark, 3.0)
	_burial_draw.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
