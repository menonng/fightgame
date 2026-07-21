# 맵 타일 그리드화 실현안

상태: 설계안 (구현 보류 — 사용자 승인 후 진행)
대상 파일: `scripts/game_scene.gd` (`_build_map`), 신규 유틸리티 함수 추가 예정

## 1. 배경

현재 맵(`game_scene.gd` `_build_map()`, line 133-154)은 다음과 같이 구성되어 있다.

```gdscript
func _build_map() -> void:
    const WALL := 40
    map_solids = [
        Rect2i(0, 0, WORLD_W, WALL),              # 위쪽 벽
        Rect2i(0, WORLD_H - WALL, WORLD_W, WALL),  # 아래쪽 벽
        Rect2i(0, 0, WALL, WORLD_H),               # 왼쪽 벽
        Rect2i(WORLD_W - WALL, 0, WALL, WORLD_H),  # 오른쪽 벽
    ]
    map_bushes = [
        Rect2i(300, 300, 220, 180),
        Rect2i(760, 220, 260, 200),
        # ... 총 10개, 좌표 전부 하드코딩
    ]
```

- 바닥: `WORLD_W x WORLD_H`(2100x1400) 통짜 사각형 하나.
- 부쉬: 220~300px짜리 큰 직사각형 10개, 좌표 개별 하드코딩.
- 타일 개념 없음 — "임의 크기의 큰 Rect2i 몇 개"로 지형 전체를 표현.

시각적으로 "큰 사각형이 초콜릿칩처럼 박혀있는" 느낌이 나는 원인이 바로 이 구조다.

### 1.1 이 구조를 소비하는 코드 (영향 범위 조사 결과)

| 파일 : 함수 | 사용 방식 |
|---|---|
| `player.gd` : `move_and_collide_map()` | 매 프레임, 축(x/y)별로 `map_solids` 전체를 순회하며 rect 겹침 검사 후 위치 보정 |
| `player.gd` : `handle_input()` | `map_bushes` 순회해 은신/이속감소 판정(`in_bush`) |
| `dummy.gd` : `dummy_update()` | 시그니처만 `map_solids`/`map_bushes`를 받고 실제로는 사용하지 않음(더미는 고정 대상) |
| `dirt_particle.gd` : `proj_update()` | 파티클마다 매 프레임 `map_solids` 순회, 점-사각형 충돌로 소멸 판정 |
| `jobs/shoveler/e.gd` : `get_spawn_params()` | `_map_solids` 파라미터를 받지만 밑줄 접두사가 붙어있고 실제로 사용하지 않음(죽은 파라미터) |
| `game_scene.gd` : `_draw_map()` | `map_solids`/`map_bushes` 순회해서 `draw_rect()`로 그림 |
| `game_scene.gd` : 쇼블러 E 처리부 | 묘석(Tombstone)이 솔리드가 되는 순간 자신의 rect를 `map_solids`에 **런타임으로 append**, 소멸 시 **erase** (정적 맵과 무관한 동적 지형) |

## 2. 제안: 타일 그리드 저작 + 병합(merge) 파이프라인

### 2.1 핵심 설계 원칙

> 타일 그리드는 **저작(authoring) 레이어**로만 쓰고, 실제 게임 로직에는 지금과 동일하게 "개수가 적은 병합된 Rect2i 배열"을 넘긴다.

이렇게 하면:

1. `player.gd`, `dummy.gd`, `dirt_particle.gd`, `_draw_map()`, 쇼블러 묘석 append/erase 로직 — **전부 코드 변경 없음**. 이들은 여전히 `map_solids: Array[Rect2i]`, `map_bushes: Array[Rect2i]`를 받을 뿐, 그 배열이 손코딩인지 그리드에서 생성됐는지 알 필요가 없다.
2. 타일을 병합하지 않고 그대로(예: 726개 개별 Rect2i) `map_solids`에 밀어넣으면 두 가지 문제가 생긴다.
   - 매 프레임 이동/충돌 루프가 수백 개 rect를 순회 (이 게임 규모에선 감당 가능하겠지만 불필요한 비용).
   - **더 심각한 문제**: 지금 충돌 처리(`move_and_collide_map`)는 "겹치는 rect를 찾으면 그 rect 하나 기준으로 밀어냄" 방식이라, 캐릭터가 인접한 벽 타일 2개의 경계에 걸치면 순회 순서에 따라 다른 타일 기준으로 밀려나는 **이음매(seam) 버짐/끼임 버그**가 발생할 수 있다.
   - 인접한 같은 타입 타일을 큰 사각형으로 병합하면 이 두 문제가 동시에 해결된다(병합된 결과는 지금의 "손으로 그린 큰 사각형들"과 개수·성격이 사실상 같아짐).

### 2.2 데이터 모델

```gdscript
const TILE_SIZE := 64                                   # 반복 블록 크기 (앞서 논의한 64x64와 통일)
const MAP_COLS := 33   # ceil(WORLD_W / TILE_SIZE) = ceil(2100/64)
const MAP_ROWS := 22   # ceil(WORLD_H / TILE_SIZE) = ceil(1400/64)

enum TileType { FLOOR = 0, BUSH = 1, WALL = 2 }
```

- 격자 크기: 약 33 x 22 = 726칸.
- 값 의미는 사용자 예시 그대로: `0`=바닥(통과 가능, 아무 효과 없음), `1`=부쉬(통과 가능 + 이속감소 + 은신), `2`=벽(완전 차단).
- 나중에 `3`=물, `4`=스폰 지점 태그 등으로 확장 가능하도록 enum으로 정의(하드코딩 정수 대신).

### 2.3 저작(레이아웃 정의) 방식

1차로는 **문자열 배열로 손수 배치**하는 방식을 권장한다 (가장 검증하기 쉽고, 리스크가 낮음).

```gdscript
# 각 문자가 타일 하나. '2'=벽 '1'=부쉬 '0'=바닥. 행 길이는 MAP_COLS와 일치해야 함.
const MAP_LAYOUT: Array[String] = [
    "2222222222222222222222222222222",
    "2000000000000000000000000000002",
    "2001110000011100000000111000002",
    "2001110000011100000000111000002",
    ...
    "2222222222222222222222222222222",
]
```

- 경계벽(맵 가장자리)은 그리드 첫/끝 행·열을 전부 `2`로 채워 표현 — 지금의 "경계벽 4개 Rect2i"를 대체.
- 추후 원하면 이 리터럴 대신 **노이즈 기반 절차 생성**(이번 세션에서 다뤘던 값-노이즈 클러스터링 기법 재활용)으로 부쉬 배치를 자동화할 수 있다. 다만 이는 2차 확장 과제로 분리해 리스크를 낮춘다.

### 2.4 생성 파이프라인

```
MAP_LAYOUT(문자열 배열)
    → _parse_tile_grid()          # 문자열 → PackedByteArray/Array[int] 2차원 격자
    → _merge_tiles_to_rects(grid, TileType.WALL) → map_solids 에 대입
    → _merge_tiles_to_rects(grid, TileType.BUSH) → map_bushes 에 대입
```

`_build_map()`은 다음 형태로 교체된다(다른 함수는 무변경):

```gdscript
func _build_map() -> void:
    var grid := _parse_tile_grid(MAP_LAYOUT)
    map_solids = _merge_tiles_to_rects(grid, TileType.WALL)
    map_bushes = _merge_tiles_to_rects(grid, TileType.BUSH)
```

### 2.5 병합 알고리즘 (greedy rectangle merge)

2D 그리드에서 같은 값의 셀들을 최소 개수의 사각형으로 묶는 표준 기법("greedy meshing", 복셀/타일 엔진에서 흔히 쓰임)을 그대로 적용한다.

```
_merge_tiles_to_rects(grid, target_value):
    consumed := 전부 false인 2차원 불리언 배열 (grid와 같은 크기)
    rects := []
    for row in rows:
        for col in cols:
            if grid[row][col] != target_value or consumed[row][col]:
                continue
            # 1) 현재 칸에서 오른쪽으로 같은 값이 이어지는 만큼 폭(width)을 늘림
            width := 1
            while col + width < cols
                  and grid[row][col+width] == target_value
                  and not consumed[row][col+width]:
                width += 1
            # 2) 그 폭 전체가 같은 값으로 이어지는 만큼 아래로 높이(height)를 늘림
            height := 1
            while row + height < rows and _row_span_matches(grid, consumed, row+height, col, width, target_value):
                height += 1
            # 3) 이 사각형이 차지한 칸들을 consumed로 표시하고 결과에 추가
            mark consumed[row..row+height][col..col+width] = true
            rects.append(Rect2i(col*TILE_SIZE, row*TILE_SIZE, width*TILE_SIZE, height*TILE_SIZE))
    return rects
```

- `_row_span_matches`: 다음 행의 `[col, col+width)` 구간이 전부 `target_value`이고 아직 `consumed`되지 않았는지 확인하는 헬퍼.
- 이 알고리즘은 최적(사각형 개수 최소)까지는 아니지만 충분히 실용적이며, 726칸 규모에서는 순식간에 끝난다(맵 생성 시 1회만 실행, 매 프레임 실행 아님).
- 결과로 나오는 `rects` 배열은 지금의 하드코딩된 `map_solids`/`map_bushes`와 **완전히 같은 형태**(개수 적은 Rect2i 배열)이므로 이후 파이프라인은 손댈 필요가 없다.

## 3. 영향 범위 재확인 — 변경 없음 체크리스트

| 파일 | 변경 필요? |
|---|---|
| `game_scene.gd` : `_build_map()` | ✅ 교체 (그리드 파싱 + 병합 호출) |
| `game_scene.gd` : `TileType` enum, `MAP_LAYOUT` 상수, `_parse_tile_grid()`, `_merge_tiles_to_rects()` | ✅ 신규 추가 |
| `game_scene.gd` : `_draw_map()` | 변경 없음 |
| `game_scene.gd` : 쇼블러 E 묘석 append/erase | 변경 없음 (동적 지형, 그리드와 무관하게 유지) |
| `player.gd` : `move_and_collide_map()`, `handle_input()` | 변경 없음 |
| `dummy.gd` : `dummy_update()` | 변경 없음 |
| `dirt_particle.gd` : `proj_update()` | 변경 없음 |
| `jobs/shoveler/e.gd` : `get_spawn_params()` | 변경 없음 |

즉 이 리팩터는 **`_build_map()` 하나와 그 옆에 붙는 유틸리티 함수 2~3개로 완전히 격리**된다.

## 4. 단계별 구현 순서 (제안)

1. **1단계 (검증)**: `_parse_tile_grid`/`_merge_tiles_to_rects` 작성 후, 지금의 하드코딩 레이아웃을 그대로 `MAP_LAYOUT` 문자열로 옮겨 재현 — 병합 결과가 기존 `map_solids`/`map_bushes`와 시각적으로 동일한지 확인(리스크를 이 단계에서 먼저 제거).
2. **2단계 (재설계)**: 검증되면 `MAP_LAYOUT`을 실제로 다양하게(통로, 작은 부쉬 여러 개, 병목 지형 등) 다시 디자인.
3. **3단계 (선택/확장)**: 노이즈 기반 절차 생성으로 `MAP_LAYOUT` 자체를 자동 생성하는 옵션 추가.
4. **4단계 (선택/확장)**: 벽/부쉬 외 타일 타입 확장(물, 스폰 지점 태그 등).

## 5. 리스크 및 검증 방법

- **리스크 수준: 낮음.** 병합 단계만 정확하면 나머지 시스템은 무변경이라 회귀 가능성이 낮다.
- 유일하게 검증이 필요한 지점은 병합 알고리즘 자체의 경계 케이스:
  - 경계벽(그리드 테두리)과 내부 벽이 인접할 때 하나의 큰 rect로 합쳐지는지.
  - 부쉬와 벽이 맞닿아 있을 때 서로 다른 타입이므로 병합되지 않고 올바르게 분리되는지.
- 검증 방법: 1단계에서 기존 레이아웃을 그리드로 재현한 뒤, `_draw_map()`으로 그려지는 결과 + 실제 충돌(벽에 부딪히는지, 부쉬에서 은신되는지)을 연습 모드에서 육안 확인.

## 6. 결론 / 권고

제안하신 "0=바닥/1=부쉬/2=벽" 타일 값 방식은 채택할 가치가 있다. 다만 **타일을 그대로 충돌 리스트에 넣지 말고, 저작 후 병합해서 지금과 같은 형태의 Rect2i 배열로 변환**하는 단계를 반드시 포함해야 이음매 버그와 성능 저하를 피할 수 있다. 이 방식이면 리팩터 범위가 `_build_map()` 주변으로 좁게 격리되어 안전하게 진행할 수 있다.

승인해주시면 1단계(검증)부터 시작하겠습니다.
