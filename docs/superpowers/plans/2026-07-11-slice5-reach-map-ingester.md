# Reach-Map Ingester (Slice 5 foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ingest painted PNG reach maps (1px = one 8px cell) into playable reaches; ship Maram's `marsh_draft` as **the Canals — the game's first level** (turtle rescue moves there), chain canals ↔ estuary ↔ hub.

**Architecture:** A `ReachField` service (rect-backed on legacy reaches = parity by construction; mask-backed on map reaches) becomes the single water/footing oracle for the axolotl, companions, oil, and spawners. A `ReachMap` cove component classifies the PNGs, expands the runtime config, retires the hand-built cove, and builds land (one masked shader quad), collision (greedy rect merge), seals/gates, climbs, and marker-driven components.

**Tech Stack:** Godot 4.7 GDScript (TABS, `##` doc comments), headless test scripts, GL Compatibility / web no-threads export.

**Spec:** `docs/superpowers/specs/2026-07-11-slice5-reach-map-ingester.md` (v2, design-reviewed — its §4 details are normative where this plan summarizes).

## Global Constraints

- D-0003 swim tuning and the swim state machine: numbers and structure untouched. Boundary *queries* may change, motion may not.
- Apollo palette named swatches only (`Palette.*`); never color literals in drawing code.
- Cozy contract: no fail states, nothing killed; locked gates say "not yet", never "no".
- WebGL perf: no per-frame full-map redraws; shared ShaderMaterial uniforms follow the ALWAYS-write rule (set every setup, never only-when-custom).
- Parse gate after every task: headless `--import` grepped for `SCRIPT ERROR|Parse Error|Compile error` must be clean. Godot: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`, project `c:\Users\maram\Dev\GODOT PROJECTS\LilAxol`.
- Existing suites stay green every task: `tests/test_world_state.gd` (11) and `tests/test_reach_state.gd` (12), run via `--headless --script`, must print `RESULT: ALL PASS`.
- Hand-built reaches (hub `main.tscn`, estuary `estuary.tscn`) must behave identically until Task 8 touches wiring — every task's gate includes "hub boots and swims normally".
- Legend colors (exact, alpha ≥ 128 first): earth `7A4A23`, rubble `8C8C8C`, water `2E6FF2`, climb `2E9E3F`, silt `D2B48C`, boulder `56707E`; markers spawn `FF00FF`, friend `FFD700`, portal `00FFFF`, leak `FF2222`, barrel `FF8800`, curio `FFFF00`, lilypad `B7F04A`, vent `A020F0`.
- Cell size 8.0. Map frame: `cove_local = cfg.map_origin + Vector2(cx, cy) * 8.0` (cell top-left).
- The z-map (map reaches): bedrock surround 3 · leak 4 · Water 5 · oil film/pads/school 6 · land quad 7 · portals + FX 8 · companions 9 · axolotl 10.
- `marsh_draft` ground truth (post-patch, commit 541dc74): terrain tallies E=2556, R=102, W=2348, C=125, air=2069; markers: 1 spawn (6,16), 2 portals (2,41)+(119,54), 1 friend (70,26), 1 leak (62,52), 6 barrels, 3 curios, 15 lilypads (row 21), 1 vent (94,56). Water table row 22.

---

### Task 1: ReachField service + legacy adoption (zero visible change)

**Files:**
- Create: `game/cove/reach_field.gd`
- Create: `tests/test_reach_field.gd`
- Modify: `game/cove/cove.gd` (spawn the field first)
- Modify: `game/axolotl/axolotl.gd:186-193` (water test via field)
- Modify: `game/cove/oil_spill.gd:52-58, 63-67, 69-101` (setup-time rect capture + `oil_allowed` gate)

**Interfaces:**
- Produces (consumed by every later task):
  - `ReachField` (class_name, extends Node, group `"reach_field"`), all coords cove-local:
    - `setup_rect(cfg: CoveConfig) -> void`
    - `set_mask(origin: Vector2, cells: PackedByteArray, w: int, h: int, table_row: int) -> void` (cell codes: 0 air, 1 earth, 2 rubble, 3 water, 4 climb, 5 silt, 6 boulder)
    - `is_water(p: Vector2) -> bool`
    - `oil_allowed(p: Vector2) -> bool` — rect backing: always true (legacy parity); mask: `is_water`
    - `surface_y() -> float` · `water_bounds() -> Rect2`
    - `floor_y_at(x: float) -> float` — y of the first solid top below the surface at x (rect: `seabed_y`)
    - `random_water_cell(rng: RandomNumberGenerator) -> Vector2` · `random_surface_x(rng) -> float`
    - `carve(p: Vector2, radius: float) -> void` — mask: solid→water at/below the table; rect: no-op

- [ ] **Step 1: Write the failing test** — `tests/test_reach_field.gd`, same harness shape as `tests/test_reach_state.gd` (SceneTree script, `_check(name, cond)`, prints `RESULT: ALL PASS`):

```gdscript
extends SceneTree
## ReachField: rect backing == mask backing on an equivalent rectangular world (parity proof),
## plus mask-only behaviors (holes, carve, floor scan).
const ReachFieldScript := preload("res://game/cove/reach_field.gd")
const CoveConfigScript := preload("res://game/cove/cove_config.gd")
var fails := 0
func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok: fails += 1
func _init() -> void:
	var cfg := CoveConfigScript.new()
	cfg.water_left = -80.0; cfg.water_right = 80.0
	cfg.surface_y = -16.0; cfg.seabed_y = 64.0
	var rectf = ReachFieldScript.new(); rectf.setup_rect(cfg)
	# mask equivalent: 30x14 cells at origin (-120,-40): water spans cells x 5..24, y 3..12
	var w := 30; var h := 14
	var cells := PackedByteArray(); cells.resize(w * h); cells.fill(1)
	for cy in range(3, 13):
		for cx in range(5, 25): cells[cy * w + cx] = 3
	var maskf = ReachFieldScript.new(); maskf.set_mask(Vector2(-120, -40), cells, w, h, 3)
	for p in [Vector2(0, 0), Vector2(0, -20), Vector2(-100, 20), Vector2(79, 63), Vector2(-79, -15)]:
		_check("parity is_water %s" % p, rectf.is_water(p) == maskf.is_water(p))
	_check("parity surface", absf(rectf.surface_y() - maskf.surface_y()) < 0.01)
	_check("rect oil_allowed above surface", rectf.oil_allowed(Vector2(0, -18)))
	_check("mask oil gate", not maskf.oil_allowed(Vector2(-100, 20)) and maskf.oil_allowed(Vector2(0, 0)))
	_check("rect floor", absf(rectf.floor_y_at(0.0) - 64.0) < 0.01)
	_check("mask floor", absf(maskf.floor_y_at(0.0) - 64.0) < 0.01)   # water ends cell y12 -> floor top y13 = -40+13*8 = 64
	cells[7 * w + 15] = 1                       # a solid pocket cell mid-water
	maskf.set_mask(Vector2(-120, -40), cells, w, h, 3)
	var pocket := Vector2(-120 + 15 * 8 + 4, -40 + 7 * 8 + 4)
	_check("mask hole solid", not maskf.is_water(pocket))
	maskf.carve(pocket, 4.0)
	_check("carve flips to water", maskf.is_water(pocket))
	rectf.carve(Vector2(0, 0), 10.0)            # rect: no-op, no crash
	_check("rect carve noop", rectf.is_water(Vector2(0, 0)))
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
```

- [ ] **Step 2: Run to verify it fails** — `& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "c:\Users\maram\Dev\GODOT PROJECTS\LilAxol" --script tests/test_reach_field.gd` → expect script error (reach_field.gd missing).

- [ ] **Step 3: Implement `game/cove/reach_field.gd`**

```gdscript
class_name ReachField
extends Node
## The reach's water/footing ORACLE (slice 5 spec §4.1/4.5). One API, two backings:
## RECT (legacy hand-built reaches — answers derived from config numbers, so behavior is
## preserved by construction) and MASK (painted map reaches — per-cell truth). Everything that
## used to test the water rectangle (axolotl, companions, oil, spawners) asks this instead.
## All coordinates are cove-local (the config frame). Group: "reach_field".

const CELL := 8.0
# cell codes (mask backing)
const AIR := 0; const EARTH := 1; const RUBBLE := 2; const WATER := 3
const CLIMB := 4; const SILT := 5; const BOULDER := 6

var _rect_cfg: CoveConfig = null      # rect backing when set
var _origin := Vector2.ZERO           # mask backing
var _cells := PackedByteArray()
var _w := 0
var _h := 0
var _table_row := 0

func _ready() -> void:
	add_to_group("reach_field")

func setup_rect(cfg: CoveConfig) -> void:
	_rect_cfg = cfg

func set_mask(origin: Vector2, cells: PackedByteArray, w: int, h: int, table_row: int) -> void:
	_rect_cfg = null
	_origin = origin; _cells = cells; _w = w; _h = h; _table_row = table_row

func _cell_at(p: Vector2) -> int:
	var cx := int(floorf((p.x - _origin.x) / CELL))
	var cy := int(floorf((p.y - _origin.y) / CELL))
	if cx < 0 or cx >= _w or cy < 0 or cy >= _h:
		return EARTH                   # off-map reads solid: nothing swims off the edge
	return _cells[cy * _w + cx]

func is_water(p: Vector2) -> bool:
	if _rect_cfg:
		return _rect_cfg.has_water and p.x > _rect_cfg.water_left and p.x < _rect_cfg.water_right \
			and p.y > _rect_cfg.surface_y and p.y < _rect_cfg.seabed_y
	return _cell_at(p) == WATER

## Oil coverage may exist here. Rect: ALWAYS true — the legacy mask build had no terrain
## knowledge, and gating it would shift _total/cleanliness on saved worlds. Mask: water only
## (oil born inside painted earth is invisible and would block the win — spec C2).
func oil_allowed(p: Vector2) -> bool:
	if _rect_cfg:
		return true
	return _cell_at(p) == WATER

func surface_y() -> float:
	if _rect_cfg:
		return _rect_cfg.surface_y
	return _origin.y + float(_table_row) * CELL

func water_bounds() -> Rect2:
	if _rect_cfg:
		return Rect2(_rect_cfg.water_left, _rect_cfg.surface_y,
			_rect_cfg.water_right - _rect_cfg.water_left, _rect_cfg.seabed_y - _rect_cfg.surface_y)
	var minx := _w; var maxx := -1; var miny := _h; var maxy := -1
	for cy in _h:
		for cx in _w:
			if _cells[cy * _w + cx] == WATER:
				minx = mini(minx, cx); maxx = maxi(maxx, cx)
				miny = mini(miny, cy); maxy = maxi(maxy, cy)
	if maxx < 0:
		return Rect2()
	return Rect2(_origin + Vector2(minx, miny) * CELL, Vector2(maxx - minx + 1, maxy - miny + 1) * CELL)

## y of the first solid top below the waterline at x — where floor-rooted life plants.
func floor_y_at(x: float) -> float:
	if _rect_cfg:
		return _rect_cfg.seabed_y
	var cx := int(floorf((x - _origin.x) / CELL))
	if cx < 0 or cx >= _w:
		return surface_y()
	for cy in range(_table_row, _h):
		var c := _cells[cy * _w + cx]
		if c != WATER and c != AIR:
			return _origin.y + float(cy) * CELL
	return _origin.y + float(_h) * CELL

func random_water_cell(rng: RandomNumberGenerator) -> Vector2:
	if _rect_cfg:
		return Vector2(rng.randf_range(_rect_cfg.water_left + 8.0, _rect_cfg.water_right - 8.0),
			rng.randf_range(_rect_cfg.surface_y + 8.0, _rect_cfg.seabed_y - 8.0))
	for _i in 200:                     # rejection sample; painted maps are ~1/3 water
		var cx := rng.randi_range(0, _w - 1)
		var cy := rng.randi_range(0, _h - 1)
		if _cells[cy * _w + cx] == WATER:
			return _origin + Vector2(float(cx) + 0.5, float(cy) + 0.5) * CELL
	return water_bounds().get_center()

## An x whose SURFACE cell (just below the table) is open water — lilypad/debris band.
func random_surface_x(rng: RandomNumberGenerator) -> float:
	if _rect_cfg:
		return rng.randf_range(_rect_cfg.water_left + 20.0, _rect_cfg.water_right - 20.0)
	for _i in 200:
		var cx := rng.randi_range(0, _w - 1)
		if _table_row < _h and _cells[_table_row * _w + cx] == WATER:
			return _origin.x + (float(cx) + 0.5) * CELL
	return water_bounds().get_center().x
## Broken rock becomes swimmable at/below the table (spec C5 — the legacy rect made carved
## tunnels swimmable by construction; the mask must do it explicitly). Rect: no-op.
func carve(p: Vector2, radius: float) -> void:
	if _rect_cfg:
		return
	var r := int(ceilf(radius / CELL))
	var cx := int(floorf((p.x - _origin.x) / CELL))
	var cy := int(floorf((p.y - _origin.y) / CELL))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var nx := cx + dx; var ny := cy + dy
			if nx < 0 or nx >= _w or ny < 0 or ny >= _h or ny < _table_row:
				continue
			var c := _cells[ny * _w + nx]
			if c == RUBBLE or c == SILT or c == BOULDER:
				_cells[ny * _w + nx] = WATER
```

- [ ] **Step 4: Run the test** → `RESULT: ALL PASS`.

- [ ] **Step 5: Spawn the field in the composition root** — `game/cove/cove.gd`, in `_ready()` immediately after `WorldState.current_id = config.id` and BEFORE the `_inject` list:

```gdscript
	# the water/footing oracle — FIRST, so every injected component can find it (slice 5).
	# Rect-backed here; a map reach's ReachMap upgrades it to the painted mask in its setup.
	var field := ReachField.new()
	field.setup_rect(config)
	add_child(field)
```

- [ ] **Step 6: Axolotl adopts the field** — `game/axolotl/axolotl.gd`. Add member near `_oil_mgr` grab in `setup()` (line ~66-69):

```gdscript
var _field: ReachField = null
```
and in `setup()` after the `_oil_mgr` line:
```gdscript
	_field = get_tree().get_first_node_in_group("reach_field")
```
Replace the rect test (lines 186-193) — hysteresis preserved verbatim, lateral/shape test delegated:

```gdscript
	var submerged := false
	if has_water:
		var probe := Vector2(local.x, feet)
		if _field != null:
			if _in_water:
				submerged = _field.is_water(Vector2(local.x, feet - 2.0)) \
					or feet > _field.surface_y() - 2.0 and _field.is_water(Vector2(local.x, feet + 6.0))
			else:
				submerged = feet > _field.surface_y() + 4.0 and _field.is_water(probe)
		else:
			var over_water := local.x > _cfg.water_left and local.x < _cfg.water_right
			if over_water:
				if _in_water:
					submerged = feet > _cfg.surface_y - 2.0
				else:
					submerged = feet > _cfg.surface_y + 4.0
```
Note the rect fallback stays (standalone-scene testability idiom, `_cove_local()` comment block). With the rect backing this evaluates identically to the old test: `is_water` == over_water ∧ y-in-column, and the ±2/+4 hysteresis shifts are expressed as probe offsets.

- [ ] **Step 7: OilSpill setup-time capture + gate** — `game/cove/oil_spill.gd`. Move the Water-rect read from `_ready` (lines 54-58) into `setup()` (spec C1 — `_ready` runs before ReachMap can resize the sprite):

```gdscript
func _ready() -> void:
	add_to_group("oil_manager")
	_fx = CleanupFX.new()
	add_child(_fx)

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	var wt := get_node_or_null("../Water") as Sprite2D
	if wt:
		_water_mat = wt.material as ShaderMaterial
		_origin = wt.position
		_size = wt.scale          # 1px texture scaled to px size -> scale == size
	_build_mask()
	_build_surface()
	_set_clean()
```
In `_build_mask()`, gate coverage birth (after the `cov` clamp at line 92, extending the existing `VIS_FLOOR` zeroing):
```gdscript
			var field: ReachField = get_tree().get_first_node_in_group("reach_field")
			if cov >= VIS_FLOOR and field != null and not field.oil_allowed(Vector2(lx, ly)):
				cov = 0.0                   # no oil born inside painted terrain (spec C2)
```
(Hoist the `field` lookup above the loops — one lookup, not 16,896.)

- [ ] **Step 8: Parse gate + all three suites + hub smoke** — parse gate clean; `test_world_state`, `test_reach_state`, `test_reach_field` all `RESULT: ALL PASS`. Boot the hub (`godot --path . main.tscn` or editor run): swim in/out at the beach edge, dip/exit hysteresis feels unchanged, oil scrubs to 100%.

- [ ] **Step 9: Commit** — `git add -A && git commit -m "feat(slice5): ReachField oracle - rect-backed legacy parity, axolotl+oil adopt"`

---

### Task 2: ReachMap loader — classify, derive, harvest, lint, retire

**Files:**
- Create: `game/cove/reach_map.gd`
- Create: `tests/test_reach_map.gd`
- Modify: `game/cove/cove_config.gd` (map fields)
- Modify: `game/cove/cove.gd` (inject `$ReachMap` FIRST; add the node to `cove.tscn`)
- Modify: `game/cove/cove.tscn` (add `ReachMap` Node2D child, top of component children)

**Interfaces:**
- Consumes: `ReachField.set_mask` (Task 1).
- Produces:
  - `CoveConfig` new exports: `map_terrain: Texture2D`, `map_markers: Texture2D`, `map_origin: Vector2 = Vector2(-480, -200)`, `map_exits: Dictionary = {}`, `exit2_enabled/exit2_target/exit2_pos` (used Task 8).
  - Runtime config expansion (plain vars are NOT exports; add as `var` on CoveConfig so .tres never serializes them): `spawn_pos: Vector2`, `pad_xs: PackedFloat32Array`, `barrel_positions: Array[Vector2]`, `vent_positions: Array[Vector2]`, `portal_markers: Array[Dictionary]` (`{pos: Vector2, edge: String}`), `camera_bounds: Rect2`, `ground_hold_y: float = -62.0`, `has_map: bool` (true when ingested).
  - `ReachMap` members later tasks read: `grid: PackedByteArray`, `gw: int`, `gh: int`, `table_row: int`, `cell_world(cx, cy) -> Vector2`, `component_rects(code: int) -> Array[Rect2i]` (4-connected components of a cell code, as cell-space Rect2i, warning if non-rect).

- [ ] **Step 1: Failing test** — `tests/test_reach_map.gd` (headless; loads the REAL marsh PNGs):

```gdscript
extends SceneTree
## ReachMap loader vs marsh_draft ground truth (commit 541dc74 tallies).
const ReachMapScript := preload("res://game/cove/reach_map.gd")
const CoveConfigScript := preload("res://game/cove/cove_config.gd")
var fails := 0
func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name); if not ok: fails += 1
func _init() -> void:
	var cfg := CoveConfigScript.new()
	cfg.id = "canals"
	cfg.map_terrain = load("res://assets/maps/marsh_draft_terrain.png")
	cfg.map_markers = load("res://assets/maps/marsh_draft_markers.png")
	var rm = ReachMapScript.new()
	var root := Node2D.new(); get_root().add_child(root); root.add_child(rm)
	rm.classify(cfg)                      # pure data stage — no scene building needed for this suite
	_check("dims", rm.gw == 120 and rm.gh == 60)
	var t := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}
	for c in rm.grid: t[c] += 1
	_check("tally earth", t[1] == 2556);  _check("tally rubble", t[2] == 102)
	_check("tally water", t[3] == 2348);  _check("tally climb", t[4] == 125)
	_check("table row", rm.table_row == 22)
	_check("surface_y", absf(cfg.surface_y - (cfg.map_origin.y + 22.0 * 8.0)) < 0.01)
	_check("spawn", cfg.spawn_pos == cfg.map_origin + Vector2(6.5, 16.5) * 8.0)
	_check("friend", cfg.friend_pos == cfg.map_origin + Vector2(70.5, 26.5) * 8.0)
	_check("curios", cfg.curios.size() == 3)
	_check("pads", cfg.pad_xs.size() == 15)
	_check("barrels", cfg.barrel_positions.size() == 6)
	_check("vents", cfg.vent_positions.size() == 1)
	_check("portals", cfg.portal_markers.size() == 2)
	var edges := [cfg.portal_markers[0]["edge"], cfg.portal_markers[1]["edge"]]
	_check("portal edges", edges.has("west") and edges.has("east"))
	var seals = rm.component_rects(2)
	_check("seal components", seals.size() == 4)      # west plug, two mesa plugs, bottom plug
	_check("camera bounds", cfg.camera_bounds.size.x >= 960.0)
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
```
(If a tally assert fails, re-derive ground truth by running `tools/audit_reach_map.ps1` — the map is authoritative, the test constants follow it.)

- [ ] **Step 2: Run → fails** (no reach_map.gd).

- [ ] **Step 3: CoveConfig additions** — append to `game/cove/cove_config.gd`:

```gdscript
@export_group("Painted Map (slice 5)")
## A painted reach: 1px = one 8px cell (see docs field guide + spec 2026-07-11). Null = the
## classic hand-built reach; every map field below is then ignored and ReachMap retires.
@export var map_terrain: Texture2D
@export var map_markers: Texture2D
## World position of map cell (0,0)'s top-left corner (cove-local frame).
@export var map_origin := Vector2(-480.0, -200.0)
## Edge key ("west"/"east"/"top"/"bottom") -> scene path. A painted portal marker on that edge
## crosses to the scene; an edge portal with no entry here spawns DORMANT (dark, no trigger).
@export var map_exits: Dictionary = {}

@export_group("Second Exit (hand-built reaches)")
## Optional second pathway for classic reaches (the estuary's onward door to the canals).
@export var exit2_enabled: bool = false
@export var exit2_target: String = ""
@export var exit2_pos: Vector2 = Vector2.ZERO

# --- runtime expansion (ReachMap fills these at load; plain vars so .tres never saves them) ---
var has_map := false
var spawn_pos := Vector2.ZERO
var pad_xs := PackedFloat32Array()
var barrel_positions: Array[Vector2] = []
var vent_positions: Array[Vector2] = []
var portal_markers: Array[Dictionary] = []   # {pos: Vector2, edge: String} ("" = interior)
var camera_bounds := Rect2()
var ground_hold_y := -62.0
```

- [ ] **Step 4: Implement `game/cove/reach_map.gd`** (loader half; geometry lands Tasks 3-6):

```gdscript
extends Node2D
## THE INGESTER (slice 5 spec §4.1): turns a painted reach map into config + world. This task:
## classify both PNGs, expand the runtime config, upgrade the ReachField to the mask, retire the
## hand-built cove nodes, and lint loudly. Geometry builders arrive in later tasks and hang off
## build() below. No map on the config -> retire (the classic reaches never feel this node).

const CELL := 8.0
const TERRAIN_COLORS := {                       # exact legend RGB (alpha-gated first)
	Color8(122, 74, 35): ReachField.EARTH,   Color8(140, 140, 140): ReachField.RUBBLE,
	Color8(46, 111, 242): ReachField.WATER,  Color8(46, 158, 63): ReachField.CLIMB,
	Color8(210, 180, 140): ReachField.SILT,  Color8(86, 112, 126): ReachField.BOULDER,
}
const MARKER_COLORS := {
	Color8(255, 0, 255): &"spawn",  Color8(255, 215, 0): &"friend", Color8(0, 255, 255): &"portal",
	Color8(255, 34, 34): &"leak",   Color8(255, 136, 0): &"barrel", Color8(255, 255, 0): &"curio",
	Color8(183, 240, 74): &"lilypad", Color8(160, 32, 240): &"vent",
}
## queue_free'd on map reaches (spec C3 — normative). Hidden-but-alive hub vents make a map
## reach UNWINNABLE (the banner's all-vents gate polls the group), so retirement is by free.
const RETIRE := ["Beach", "Seabed", "Banks", "BeachRight", "BankTowerBody", "BlockLand",
	"BlockLandRight", "BankTower", "Grass", "GrassFront", "TowerWall", "TowerDrape",
	"LandNook1", "LandNook2", "LandNook3", "Vent1", "Vent2", "Vent3",
	"GroundFill", "SeabedBackdrop"]

var grid := PackedByteArray()
var gw := 0
var gh := 0
var table_row := 0
var _cfg: CoveConfig

func setup(cfg: CoveConfig) -> void:
	if cfg.map_terrain == null:
		queue_free()                            # classic reach — the rect ReachField stands
		return
	classify(cfg)
	var field: ReachField = get_tree().get_first_node_in_group("reach_field")
	field.set_mask(cfg.map_origin, grid, gw, gh, table_row)
	_retire_handbuilt()
	build()
	print("[reach_map] %s: %dx%d cells, table row %d, %d portals" %
		[cfg.id, gw, gh, table_row, cfg.portal_markers.size()])

## Pure data stage (headless-testable without a scene): grids + config expansion.
func classify(cfg: CoveConfig) -> void:
	_cfg = cfg
	var timg := cfg.map_terrain.get_image()
	var mimg := cfg.map_markers.get_image()
	assert(not timg.is_compressed(), "map textures must import lossless (compress mode 0)")
	gw = timg.get_width(); gh = timg.get_height()
	grid.resize(gw * gh)
	table_row = gh
	for cy in gh:
		for cx in gw:
			var code := ReachField.AIR
			var px := timg.get_pixel(cx, cy)
			if px.a8 >= 128:                    # alpha gate FIRST (import bleeds RGB — spec M3)
				var key := Color8(px.r8, px.g8, px.b8)
				if TERRAIN_COLORS.has(key):
					code = TERRAIN_COLORS[key]
				else:
					push_warning("reach_map: off-legend terrain %s at (%d,%d)" % [key, cx, cy])
			grid[cy * gw + cx] = code
			if code == ReachField.WATER and cy < table_row:
				table_row = cy
	cfg.has_map = true
	cfg.surface_y = cfg.map_origin.y + float(table_row) * CELL
	var wb := _water_cell_bounds()
	cfg.water_left = cfg.map_origin.x + float(wb.position.x) * CELL
	cfg.water_right = cfg.map_origin.x + float(wb.end.x) * CELL
	cfg.seabed_y = cfg.map_origin.y + float(wb.end.y) * CELL
	cfg.camera_bounds = Rect2(cfg.map_origin, Vector2(gw, gh) * CELL).grow(24.0)
	cfg.ground_hold_y = _derive_ground_hold()
	_harvest(mimg)

func cell_world(cx: int, cy: int) -> Vector2:   # cell CENTER, cove-local
	return _cfg.map_origin + Vector2(float(cx) + 0.5, float(cy) + 0.5) * CELL

func _water_cell_bounds() -> Rect2i:
	var minx := gw; var maxx := -1; var miny := gh; var maxy := -1
	for cy in gh:
		for cx in gw:
			if grid[cy * gw + cx] == ReachField.WATER:
				minx = mini(minx, cx); maxx = maxi(maxx, cx)
				miny = mini(miny, cy); maxy = maxi(maxy, cy)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)

## Highest DRY standable earth top (air above earth, above the table), minus a 4-cell margin:
## the follower ceiling (spec 4.6). Fallback: the legacy hub const.
func _derive_ground_hold() -> float:
	for cy in range(0, table_row):
		for cx in gw:
			if cy + 1 < gh and grid[cy * gw + cx] == ReachField.AIR \
					and grid[(cy + 1) * gw + cx] == ReachField.EARTH:
				return _cfg.map_origin.y + float(cy - 4) * CELL
	return -62.0

func _harvest(mimg: Image) -> void:
	_cfg.curios = []
	_cfg.pad_xs = PackedFloat32Array()
	_cfg.barrel_positions = []; _cfg.vent_positions = []; _cfg.portal_markers = []
	for cy in gh:
		for cx in gw:
			var px := mimg.get_pixel(cx, cy)
			if px.a8 < 128:
				continue
			var key := Color8(px.r8, px.g8, px.b8)
			if not MARKER_COLORS.has(key):
				push_warning("reach_map: off-legend marker %s at (%d,%d)" % [key, cx, cy])
				continue
			var pos := cell_world(cx, cy)
			var solid := grid[cy * gw + cx] != ReachField.AIR and grid[cy * gw + cx] != ReachField.WATER
			if solid:
				push_warning("reach_map: %s marker buried at (%d,%d)" % [MARKER_COLORS[key], cx, cy])
			match MARKER_COLORS[key]:
				&"spawn":  _cfg.spawn_pos = pos
				&"friend": _cfg.friend_pos = pos
				&"leak":   _cfg.leak_pos = pos
				&"curio":  _cfg.curios.append(pos)
				&"lilypad": _cfg.pad_xs.append(pos.x)
				&"barrel": _cfg.barrel_positions.append(pos)
				&"vent":   _cfg.vent_positions.append(pos)
				&"portal": _cfg.portal_markers.append({"pos": pos, "edge": _edge_of(cx, cy)})

func _edge_of(cx: int, cy: int) -> String:
	if cx <= 2: return "west"
	if cx >= gw - 3: return "east"
	if cy <= 2: return "top"
	if cy >= gh - 3: return "bottom"
	return ""

func _retire_handbuilt() -> void:
	var root := get_parent()
	for n in RETIRE:
		var node := root.get_node_or_null(n)
		if node:
			node.queue_free()

## Geometry builders (Tasks 3-6) chain here.
func build() -> void:
	pass

## 4-connected components of one cell code, as cell-space rects. Non-rect components warn and
## return their bounding box (authoring lint enforces rectangles for seals/gates).
func component_rects(code: int) -> Array[Rect2i]:
	var seen := PackedByteArray(); seen.resize(gw * gh)
	var out: Array[Rect2i] = []
	for cy in gh:
		for cx in gw:
			if grid[cy * gw + cx] != code or seen[cy * gw + cx] == 1:
				continue
			var stack := [Vector2i(cx, cy)]
			seen[cy * gw + cx] = 1
			var minx := cx; var maxx := cx; var miny := cy; var maxy := cy
			var count := 0
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				count += 1
				minx = mini(minx, c.x); maxx = maxi(maxx, c.x)
				miny = mini(miny, c.y); maxy = maxi(maxy, c.y)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := c + d
					if n.x < 0 or n.x >= gw or n.y < 0 or n.y >= gh:
						continue
					if grid[n.y * gw + n.x] == code and seen[n.y * gw + n.x] == 0:
						seen[n.y * gw + n.x] = 1
						stack.push_back(n)
			var rect := Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
			if count != rect.size.x * rect.size.y:
				push_warning("reach_map: non-rectangular component (code %d) near (%d,%d)" % [code, cx, cy])
			out.append(rect)
	return out
```

- [ ] **Step 5: Wire the node** — `game/cove/cove.tscn`: add child `[node name="ReachMap" type="Node2D" parent="."]` with `script = reach_map.gd` (new ExtResource), placed among component nodes. `game/cove/cove.gd`: add `_inject($ReachMap)` as the FIRST line of the `_inject` list (before `$Axolotl`) — config expansion must precede every consumer.

- [ ] **Step 6: Run test** → `RESULT: ALL PASS`. Parse gate + other suites green. Hub boots (ReachMap retires instantly — no visible change).

- [ ] **Step 7: Commit** — `git commit -m "feat(slice5): ReachMap loader - classify/derive/harvest/lint/retire + suite"`

---

### Task 3: Land visual — masked shader quad, grass tops, bedrock surround, water resize

**Files:**
- Create: `shaders/reach_land.gdshader`
- Modify: `game/cove/reach_map.gd` (`build()` gains `_build_land()`, `_build_surround()`, `_resize_water()`, env-tint self-apply)
- Modify: `game/cove/cove.gd` `_apply_environment()` (rect_size ALWAYS-write; tint reaches ReachMap)

**Interfaces:**
- Consumes: `grid/gw/gh/table_row`, `cell_world` (Task 2).
- Produces: land quad z=7 named `"MapLand"`; surround z=3; method `set_env_tint(c: Color)` on ReachMap.

- [ ] **Step 1: Shader** — `shaders/reach_land.gdshader`, evolved from `shaders/block_land.gdshader` (read it first; keep its loam pattern math verbatim where marked). New uniform set:

```glsl
shader_type canvas_item;
// Painted-map land: one full-map quad; the terrain PNG is the mask. Solid cells render the
// Apollo loam cell pattern (dry above the water-table row, submerged band below); everything
// else discards. Evolved from block_land.gdshader — cell pattern math copied verbatim.
uniform sampler2D mask_tex : filter_nearest;   // the terrain PNG itself
uniform vec2 grid = vec2(120.0, 60.0);         // cells
uniform float surface_row = 22.0;              // water-table row (dry/submerged split)
uniform float oil = 1.0;                       // restoration tint driver (matches block_land)
uniform vec4 env_tint : source_color = vec4(1.0);

bool is_solid(vec4 texel) {
    if (texel.a < 0.5) { return false; }
    // earth 7A4A23, climb 2E9E3F, silt D2B48C, boulder 56707E read as land mass; the climb
    // curtain art + gate rocks draw their own identity on top. Water/air discard.
    bool water = abs(texel.r - 0.180) < 0.04 && texel.b > 0.9;
    return !water;
}

void fragment() {
    vec4 texel = texture(mask_tex, UV);
    if (!is_solid(texel)) { discard; }
    vec2 cell = floor(UV * grid);
    // [PASTE block_land.gdshader's per-cell loam pattern here VERBATIM, driven by `cell`,
    //  `surface_row`, `oil`; it already produces dry loam above surface_row and the darker
    //  submerged band at/below it.]
    COLOR *= env_tint;
}
```

- [ ] **Step 2: Builders in reach_map.gd** — append; call from `build()` in order `_build_land()`, `_build_surround()`, `_resize_water()`:

```gdscript
const LAND_SHADER := preload("res://shaders/reach_land.gdshader")
const WHITE := preload("res://assets/white.png")
var _land_mat: ShaderMaterial

func _build_land() -> void:
	_land_mat = ShaderMaterial.new()
	_land_mat.shader = LAND_SHADER
	_land_mat.set_shader_parameter("mask_tex", _cfg.map_terrain)
	_land_mat.set_shader_parameter("grid", Vector2(gw, gh))
	_land_mat.set_shader_parameter("surface_row", float(table_row))
	var quad := Sprite2D.new()
	quad.name = "MapLand"
	quad.texture = WHITE
	quad.centered = false
	quad.position = _cfg.map_origin
	quad.scale = Vector2(gw, gh) * CELL
	quad.material = _land_mat
	quad.z_index = 7                            # the z-map: over water(5)+film(6), under portals(8)
	add_child(quad)

func set_env_tint(c: Color) -> void:
	if _land_mat:
		_land_mat.set_shader_parameter("env_tint", c)

## Dark earth surround + the backdrop behind translucent water (spec I4): fills the whole map
## rect below the table AND a margin outside it, GroundFill's palette language, one draw.
func _build_surround() -> void:
	var s := Node2D.new()
	s.name = "MapSurround"
	s.z_index = 3
	add_child(s)
	s.draw.connect(func() -> void:
		var deep := Palette.INK.lerp(Color(0.11, 0.16, 0.23), 0.25)
		var r := Rect2(_cfg.map_origin, Vector2(gw, gh) * CELL).grow(1400.0)
		s.draw_rect(r, deep)                                        # far field
		var below := Rect2(Vector2(_cfg.map_origin.x, _cfg.surface_y),
			Vector2(float(gw) * CELL, float(gh) * CELL - float(table_row) * CELL))
		s.draw_rect(below, Color(0.11, 0.16, 0.23)))                # water backdrop
	s.queue_redraw()

func _resize_water() -> void:
	var wt := get_parent().get_node_or_null("Water") as Sprite2D
	if wt == null:
		return
	var b: Rect2 = (get_tree().get_first_node_in_group("reach_field") as ReachField).water_bounds()
	wt.position = b.position
	wt.scale = b.size
	# rect_size follows _apply_environment's ALWAYS-write (Task 3 step 3) — set here too for
	# ordering safety (ReachMap setup runs before _apply_environment).
	(wt.material as ShaderMaterial).set_shader_parameter("rect_size", b.size)
```
(Grass clusters on dry tops: fold into this task if quick — a Node2D drawing ≤64 tuft fans at cells where `grid[cy*gw+cx]==AIR and grid[(cy+1)*gw+cx]==EARTH and cy<=table_row`, GrassLayer's blade math generalized to per-cluster baselines, 18Hz throttle. If it fights the schedule, file as follow-up polish — the land quad's loam tops read fine bare.)

- [ ] **Step 3: rect_size joins the ALWAYS-write rule** — `game/cove/cove.gd` `_apply_environment()` water branch becomes:

```gdscript
	var water := get_node_or_null("Water") as Sprite2D
	if water and water.material is ShaderMaterial:
		var wm := water.material as ShaderMaterial
		wm.set_shader_parameter("env_tint", wt)
		# shared sub-resource cached across cove instances: ALWAYS re-assert size, or a canals
		# visit leaks 944px waves onto the hub (same leak class as env_tint — spec I3)
		wm.set_shader_parameter("rect_size", water.scale)
```
and the land-tint loop gains ReachMap:
```gdscript
	for n in ["BlockLand", "BlockLandRight", "ReachMap"]:
```

- [ ] **Step 4: Visual smoke** — temp scene or dev flag booting a config with the marsh PNGs: land silhouette matches the painted map; water visible in basins/tunnels only; hub still pristine (rect_size unchanged there because `water.scale` IS the legacy size). Parse gate + suites.

- [ ] **Step 5: Commit** — `git commit -m "feat(slice5): painted land quad + bedrock surround + water resize (z-map, always-write)"`

---

### Task 4: Collision — greedy rect merge + property test

**Files:**
- Modify: `game/cove/reach_map.gd` (`_build_collision()` in `build()`)
- Modify: `tests/test_reach_map.gd` (merge property checks)

**Interfaces:**
- Produces: `static func merge_rects(grid: PackedByteArray, gw: int, gh: int, solid: Callable) -> Array[Rect2i]` (pure, testable headless).

- [ ] **Step 1: Failing test** — append to `tests/test_reach_map.gd`:

```gdscript
	# --- collision merge property: union == solid set, no overlaps ---
	var rects = ReachMapScript.merge_rects(rm.grid, rm.gw, rm.gh,
		func(c): return c == 1 or c == 4)       # earth + climb
	var covered := {}
	var overlap := false
	for r in rects:
		for cy2 in range(r.position.y, r.end.y):
			for cx2 in range(r.position.x, r.end.x):
				var k := cy2 * rm.gw + cx2
				if covered.has(k): overlap = true
				covered[k] = true
	var solid_n := 0
	for i in rm.grid.size():
		if rm.grid[i] == 1 or rm.grid[i] == 4: solid_n += 1
	_check("merge covers exactly", covered.size() == solid_n and not overlap)
	_check("merge is compact", rects.size() <= 96)
```

- [ ] **Step 2: Run → fails.**

- [ ] **Step 3: Implement** — in reach_map.gd:

```gdscript
## Greedy horizontal-run + vertical-extend merge: rows of identical runs fuse downward.
static func merge_rects(g: PackedByteArray, w: int, h: int, solid: Callable) -> Array[Rect2i]:
	var used := PackedByteArray(); used.resize(w * h)
	var out: Array[Rect2i] = []
	for cy in h:
		var cx := 0
		while cx < w:
			if used[cy * w + cx] == 1 or not solid.call(g[cy * w + cx]):
				cx += 1
				continue
			var x1 := cx
			while x1 < w and used[cy * w + x1] == 0 and solid.call(g[cy * w + x1]):
				x1 += 1
			var y1 := cy + 1
			while y1 < h:
				var ok := true
				for xx in range(cx, x1):
					if used[y1 * w + xx] == 1 or not solid.call(g[y1 * w + xx]):
						ok = false
						break
				if not ok: break
				y1 += 1
			for yy in range(cy, y1):
				for xx in range(cx, x1):
					used[yy * w + xx] = 1
			out.append(Rect2i(cx, cy, x1 - cx, y1 - cy))
			cx = x1
	return out

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "MapCollision"
	add_child(body)
	for r in merge_rects(grid, gw, gh, func(c): return c == ReachField.EARTH or c == ReachField.CLIMB):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(r.size) * CELL
		shape.shape = rect
		shape.position = _cfg.map_origin + (Vector2(r.position) + Vector2(r.size) * 0.5) * CELL
		body.add_child(shape)
```
Call from `build()` after `_build_land()`.

- [ ] **Step 4: Test → ALL PASS; parse gate; hub smoke.**
- [ ] **Step 5: Commit** — `git commit -m "feat(slice5): map collision via greedy rect merge (+property test)"`

---

### Task 5: Seals, locked gates, carve, seal persistence

**Files:**
- Modify: `game/cove/destructible_rock.gd` (`locked` export; `carved` signal)
- Modify: `game/cove/reach_map.gd` (`_build_breakables()`; seal persistence; climb walls)
- Modify: `tests/test_reach_map.gd` (locked no-op + persistence round-trip via WorldState)

**Interfaces:**
- Consumes: `component_rects` (T2), `ReachField.carve` (T1), `WorldState.mark/get_cove`.
- Produces: `DestructibleRock.locked: bool`; signal `carved(world_pos: Vector2, radius: float)` emitted per blast bite; ClimbWall instances from green runs.

- [ ] **Step 1: DestructibleRock additions** — read `game/cove/destructible_rock.gd:136-160` (`blast`) first. Add:

```gdscript
signal carved(world_pos: Vector2, radius: float)   # a bite landed (ReachField flips cells)
## A TEASED gate (silt/boulder — slice 5): blast() bounces off with a dull thunk + shimmer.
## The world says "not yet", never "no" (cozy). Slice 6 unlocks by gate kind.
@export var locked := false
```
At the top of `blast(...)`: 
```gdscript
	if locked:
		Sfx.play("thud", -12.0, 0.8)
		_flash_locked()                # brief tone-colored shimmer; reuse the breakable_glow pulse
		return 0
```
and where cells are actually removed (inside the blast loop, after `_remaining` decrements), emit `carved(world_pos, radius)` once per call when any cell broke. Implement `_flash_locked()` as a 0.2s modulate pulse toward `tone_a`.

- [ ] **Step 2: Builder + persistence** — reach_map.gd:

```gdscript
const RockScript := preload("res://game/cove/destructible_rock.gd")
const ClimbWallScript := preload("res://game/cove/climb_wall.gd")

func _build_breakables() -> void:
	var field: ReachField = get_tree().get_first_node_in_group("reach_field")
	var idx := 0
	for entry in [[ReachField.RUBBLE, false, Palette.SLATE, Palette.STEEL],
			[ReachField.SILT, true, Color8(210, 180, 140), Color8(184, 152, 112)],
			[ReachField.BOULDER, true, Color8(86, 112, 126), Color8(64, 86, 98)]]:
		for r in component_rects(entry[0]):
			var key := "seal_%d" % idx
			idx += 1
			var rock = RockScript.new()
			rock.cols = r.size.x
			rock.rows = r.size.y
			rock.edge = 1.5                       # FULL rect: default 0.92 erodes 2-wide seals (spec I7)
			rock.locked = entry[1]
			rock.tone_a = entry[2]
			rock.tone_b = entry[3]
			rock.position = _cfg.map_origin + Vector2(r.position) * CELL
			add_child(rock)
			if not entry[1]:
				# broken seals STAY broken (ruling 5); echo runs replay them sealed
				var root := get_tree().get_first_node_in_group("cove_root")
				var echo: bool = root != null and root.has_method("is_echo") and root.is_echo()
				if not echo and bool(WorldState.get_cove(_cfg.id, key, false)):
					_carve_rect(field, r)
					rock.queue_free()
					continue
				rock.carved.connect(func(p: Vector2, rad: float) -> void: field.carve(p, rad))
				rock.cleared.connect(func() -> void:
					_carve_rect(field, r)         # belt & braces: the whole seal is open water now
					if not echo:
						WorldState.mark(_cfg.id, key, true))

func _carve_rect(field: ReachField, r: Rect2i) -> void:
	for cy in range(r.position.y, r.end.y):
		for cx in range(r.position.x, r.end.x):
			field.carve(cell_world(cx, cy), 0.1)

func _build_climbs() -> void:
	for r in component_rects(ReachField.CLIMB):
		var wall = ClimbWallScript.new()
		wall.extent = Vector2(r.size) * CELL
		wall.strands = maxi(2, r.size.x)          # thin strips still read as a curtain
		wall.position = _cfg.map_origin + Vector2(r.position) * CELL
		add_child(wall)
```
Both called from `build()`. Note: seal ids are ordinal over a fixed iteration order (code asc, then scan order) — stable for a given PNG; changing the painting invalidates seal saves for that reach only (acceptable — note in code comment).

- [ ] **Step 3: Tests** — append to `tests/test_reach_map.gd`: instantiate a locked rock, call `blast(rock.global_position, 20.0)`, assert return 0 and `_remaining` unchanged; mark `seal_0` true in a scratch WorldState id, rebuild, assert the west-plug cells answer `is_water` and no rock exists for it. (WorldState test idiom: copy `tests/test_world_state.gd`'s temp-file setup so the real save is never touched.)

- [ ] **Step 4: Run all suites + parse gate + hub smoke.**
- [ ] **Step 5: Commit** — `git commit -m "feat(slice5): map seals + locked gates + carve->water + seal persistence"`

---

### Task 6: Marker wiring — spawn, multi-portals + arrival, explicit positions, camera

**Files:**
- Modify: `game/cove/reach_map.gd` (`_build_portals()`, spawn reposition)
- Modify: `game/cove/cove_portal.gd` (instance params: `exit_to`, `entry_key`, `dormant`, z)
- Modify: `game/cove/cove.gd` (`_arrive` entry-key path; wire map portal saves)
- Modify: `game/hud/settings_store.gd:29` (`arrive_entry`)
- Modify: `game/axolotl/axolotl.gd` `setup()` (camera limits)
- Modify: `game/cove/lily_pads.gd` (pad_xs mode), `game/cove/shore_pollution.gd` (explicit barrels)
- Modify: `game/cove/reach_map.gd` (`_build_vents()` spawning `ThermalVent`)

**Interfaces:**
- Consumes: `cfg.portal_markers/spawn_pos/pad_xs/barrel_positions/vent_positions/camera_bounds` (T2).
- Produces: `Settings.arrive_entry: String`; `cove_portal.configure(exit_to: String, entry_key: String, dormant: bool)`.

- [ ] **Step 1: settings_store** — below `arrive_via_portal` add:

```gdscript
var arrive_entry := ""               # which edge/door we arrive through on a map reach ("" = legacy)
```

- [ ] **Step 2: cove_portal instance mode** — add fields + `configure()`; portals built by ReachMap skip config-singular reads:

```gdscript
var _exit_to := ""        # instance destination (map reaches); falls back to _cfg.exit_target
var _entry_key := ""      # save key suffix + arrival identity ("west"/"east"/...)
var _dormant := false     # a promise, not a door: drawn dark, no swirl, no trigger

func configure(exit_to: String, entry_key: String, dormant: bool) -> void:
	_exit_to = exit_to
	_entry_key = entry_key
	_dormant = dormant
	z_index = 8                        # over the map land quad (z-map); legacy stays z2
	if dormant:
		_glow = 0.0
	else:
		_on_open()                     # painted seals gate map portals; the portal itself is open
```
In `setup()` first line: `if cfg.exit_enabled or not cfg.exit_target.is_empty(): ...` stays for legacy; map instances are constructed by ReachMap and call `configure()` INSTEAD of `setup()` (give them `_cfg` via a `cfg_direct(cfg)` setter or make `configure(cfg, ...)` take it — implementer's choice, keep one path). In `_process`, `if _dormant: return` before the trigger poll. In `_cross()`, target becomes `(_exit_to if _exit_to != "" else _cfg.exit_target)` and before the wipe: `Settings.arrive_entry = _entry_key`. In `_draw()`, when dormant skip the glow block entirely (mouth only, `Palette.INK` throat).

- [ ] **Step 3: ReachMap portals + spawn** —

```gdscript
const PortalScript := preload("res://game/cove/cove_portal.gd")

func _build_portals() -> void:
	for m in _cfg.portal_markers:
		var target: String = _cfg.map_exits.get(m["edge"], "")
		var p = PortalScript.new()
		p.position = m["pos"]
		add_child(p)
		p.configure(target, m["edge"], target == "")
		if target != "":
			p.opened.connect(func() -> void: WorldState.mark(_cfg.id, "portal_" + m["edge"], true))

func _place_spawn() -> void:
	var axo := get_parent().get_node_or_null("Axolotl") as Node2D
	if axo == null:
		return
	if Settings.arrive_via_portal and Settings.arrive_entry != "":
		for m in _cfg.portal_markers:
			if m["edge"] == Settings.arrive_entry:
				axo.position = get_parent().to_local(to_global(m["pos"])) + Vector2(20.0, 0.0)
				return
	axo.position = get_parent().to_local(to_global(_cfg.spawn_pos))
```
`_place_spawn()` runs in `build()`; note cove.gd's legacy `_arrive()` must SKIP its hardcoded reposition when `config.has_map` (guard: `if Settings.arrive_via_portal and not config.has_map:` around the existing `_arrive()` call; on map reaches keep only the iris + velocity part — extract the wipe into `_arrive_wipe()` used by both paths). `Settings.arrive_entry = ""` after consumption, same one-shot idiom as `arrive_via_portal`.

- [ ] **Step 4: Camera limits** — axolotl.gd `setup()` append:

```gdscript
	if _cfg.camera_bounds.size.x > 0.0:
		var b := _cfg.camera_bounds
		_cam.limit_left = int(b.position.x);  _cam.limit_top = int(b.position.y)
		_cam.limit_right = int(b.end.x);      _cam.limit_bottom = int(b.end.y)
```
(cove-local == world here only if the cove sits at origin — it does NOT (main.tscn offsets by (402,28)); convert: `var tl := (get_parent() as Node2D).to_global(b.position); var br := (get_parent() as Node2D).to_global(b.end)` and use those.)

- [ ] **Step 5: lily_pads explicit mode** — in `setup()` after the retire check, replace the layout loop when pads are authored:

```gdscript
	if not cfg.pad_xs.is_empty():
		for x in cfg.pad_xs:
			_pads.append([x, rng.randf_range(7.0, 12.0), rng.randf_range(0.0, TAU)])
	else:
		for i in cfg.lilypad_count:
			# ...existing random layout loop unchanged...
```
Retire check becomes `if cfg.lilypad_count <= 0 and cfg.pad_xs.is_empty():`.

- [ ] **Step 6: shore_pollution explicit barrels + vents** — read `game/cove/shore_pollution.gd:40-70` and add the same authored-positions branch for its floating barrels (`if not cfg.barrel_positions.is_empty(): use them verbatim; else existing random spans`). Shore splats: skip entirely when `cfg.has_map` (no legacy shore strip exists on a painted reach). Vents in reach_map.gd:

```gdscript
const VentScene := preload("res://game/cove/thermal_vent.gd")
func _build_vents() -> void:
	for p in _cfg.vent_positions:
		var v = VentScene.new()
		v.cap_cols = 7
		v.cap_rows = 5
		v.position = p
		add_child(v)
```
(ThermalVent builds its own cap + joins the win-gate group in `_ready` — exactly why the hub's three were freed in Task 2.)

- [ ] **Step 7: Suite additions** — portal configure dormant => no trigger crossing (`_dormant` true keeps `_crossing` false after a fake player proximity poll — structure the check on the flag, not on scene simulation); `pad_xs` layout count == 15 for the marsh config.

- [ ] **Step 8: All gates + hub/estuary smoke** (portals in legacy scenes unchanged: single $Portal path intact).
- [ ] **Step 9: Commit** — `git commit -m "feat(slice5): marker wiring - multi-portals+arrival keys, spawn, camera, explicit pads/barrels/vents"`

---

### Task 7: Field-true companions + spawner placement + demolition clamps

**Files:**
- Modify: `game/companion/companion.gd` (footing via field; re-fan snap; pilot clamps)
- Modify: `game/axolotl/bubble.gd` (auto-pop ceiling on maps)
- Modify: `game/cove/cove_life.gd`, `game/cove/debris_field.gd`, `game/cove/pest_field.gd`, `game/cove/reeds.gd`, `game/cove/invasive_school.gd` (placement via field)

**Interfaces:**
- Consumes: `ReachField` (`floor_y_at`, `random_water_cell`, `random_surface_x`, `is_water`), `cfg.ground_hold_y`, `cfg.camera_bounds`, `cfg.has_map`.

- [ ] **Step 1: Companion footing** — `game/companion/companion.gd`. Add `var _field: ReachField` set in both `setup()` and `setup_traveller()` (`get_tree().get_first_node_in_group("reach_field")`). In the follow block, replace the over-water/ground-hold clamp (currently `var over_water := target.x > _cfg.water_left - 8.0` + maxf line — the x-test is true map-wide and dead-codes ground hold, spec C6):

```gdscript
	# GROUND HOLD, field-true: over actual water never rise above the line; elsewhere hold at
	# the reach's bank ceiling (derived on maps, hub const on legacy). A follow target must
	# never sit inside earth: project it back to the waterline of its column when it does.
	var hold: float = _cfg.ground_hold_y if "ground_hold_y" in _cfg else GROUND_HOLD
	var over_water := _field != null and _field.is_water(Vector2(target.x, _cfg.surface_y + 6.0))
	target.y = maxf(target.y, (_cfg.surface_y - 6.0) if over_water else hold)
	target.y = minf(target.y, _cfg.seabed_y)
	if _field != null and target.y > _cfg.surface_y + 4.0 and not _field.is_water(target):
		target.y = _cfg.surface_y - 2.0           # column blocked below: wait at the surface
```
Re-fan snap, right after `var gap := target - position`:
```gdscript
	if gap.length() > 300.0:                      # lost the tidekeeper across a maze wall: re-fan
		position = target
		gap = Vector2.ZERO
```
Frog hop landing guard, in `_frog_hop` launch block after the waypoint's y is set for water landings: `if _field != null and not _field.is_water(Vector2(to.x, _cfg.surface_y + 4.0)) and to.x > _cfg.water_left - 8.0: to.x = position.x` (don't hop onto a column with no water or ground — stay put this beat).

- [ ] **Step 2: Pilot + bubble clamps** — companion.gd `_run_pilot` clamp block becomes:

```gdscript
	if "camera_bounds" in _cfg and _cfg.camera_bounds.size.x > 0.0:
		position = _cfg.camera_bounds.grow(-8.0).clamp(position)   # helper below
	else:
		position.x = clampf(position.x, _cfg.water_left - 260.0, _cfg.water_right + 64.0)
		position.y = clampf(position.y, _cfg.surface_y - 125.0, _cfg.seabed_y)
```
(`Rect2` has no `clamp(Vector2)`: write `position = Vector2(clampf(position.x, b.position.x, b.end.x), clampf(position.y, b.position.y, b.end.y))` with `var b := _cfg.camera_bounds.grow(-8.0)`.) Same pattern for `bubble.gd`'s auto-pop ceiling (read `bubble.gd:70-80` first): on map configs pop only above `camera_bounds.position.y + 16`.

- [ ] **Step 3: Spawner placement** — in each of cove_life / debris_field / pest_field / reeds / invasive_school `setup()`, fetch `var field: ReachField = get_tree().get_first_node_in_group("reach_field")` and swap PLACEMENT only (per-frame motion clamps stay bbox — spec accepts wall-brush visuals v1):
  - kelp/sprout/crab plant y: `cfg.seabed_y` → `field.floor_y_at(x)` (and pick x via `field.random_surface_x(rng)` where currently `randf_range(water_left.., water_right..)`).
  - fish/school spawn points: `field.random_water_cell(rng)`.
  - debris/pests surface positions: x via `field.random_surface_x(rng)`, y unchanged (surface band).
  - reeds root positions: keep for legacy; on `cfg.has_map` root at the two shore columns adjacent to water at the table (`for cx: water at table with earth neighbor` — collect once in ReachMap into `cfg` if simpler: add runtime var `shore_xs: PackedFloat32Array` harvested in `classify()` and use it here).
  These files were not read during planning — locate each via `grep -n "seabed_y\|water_left\|water_right\|surface_y" game/cove/<file>.gd`, keep diffs minimal, placement-only.

- [ ] **Step 4: Gates + smokes** — all suites, parse gate; hub feel-run (companions follow/hop/pilot identically — the rect field keeps every branch equivalent: `is_water(x, surface+6)` == the old x-span test on a rectangle).
- [ ] **Step 5: Commit** — `git commit -m "feat(slice5): field-true companions + spawner placement + map-safe demolition clamps"`

---

### Task 8: The Canals — first level, travel loop, deploy

**Files:**
- Create: `game/cove/canals_a.tres`
- Create: `canals.tscn`
- Modify: `project.godot` (main scene → canals.tscn)
- Modify: `game/cove/estuary_a.tres` (exit2 → canals; keep exit → main.tscn)
- Modify: `game/cove/cove.tscn` + `game/cove/cove.gd` (add `$Portal2` node + inject; cove_portal reads `exit2_*` when its export `use_second_exit := true`)
- Modify: `game/cove/canals_a.tres` map_exits west → `res://estuary.tscn`

**Interfaces:** consumes everything above.

- [ ] **Step 1: canals_a.tres** — mirror `estuary_a.tres` structure:

```
[gd_resource type="Resource" script_class="CoveConfig" load_steps=4 format=3 uid="uid://b0canals0cfg01"]
[ext_resource type="Script" path="res://game/cove/cove_config.gd" id="1_cfg"]
[ext_resource type="Texture2D" path="res://assets/maps/marsh_draft_terrain.png" id="2_terr"]
[ext_resource type="Texture2D" path="res://assets/maps/marsh_draft_markers.png" id="3_mark"]
[resource]
script = ExtResource("1_cfg")
id = "canals"
map_terrain = ExtResource("2_terr")
map_markers = ExtResource("3_mark")
map_exits = { "west": "res://estuary.tscn" }
friend_kind = 0
spill_left = 200.0
spill_right = 640.0
clean_rate = 1.4
kelp_count = 5
fish_count = 6
debris_count = 0
pest_count = 0
lilypad_count = 0
invasive_count = 0
in_play = Array[StringName]([&"purity"])
win_threshold = 0.98
leak_enabled = true
exit_enabled = false
```
(`spill_*` in cove-local frame: table row 22 with default origin puts the surface at y=-24; spill spans the east basin around the mesa. `leak_pos` comes from the map marker — the .tres default is overwritten by harvest. First-level tuning: purity-only recipe, no pests/debris/invasives — the turtle's teaching reach.)

- [ ] **Step 2: canals.tscn** — clone `estuary.tscn`'s shape minus MudBed/Tint:

```
[gd_scene format=3 uid="uid://bcanals0scn01"]
[ext_resource type="PackedScene" uid="uid://npmxewd65pxb" path="res://game/cove/cove.tscn" id="1_cove"]
[ext_resource type="Script" path="res://game/hud/title_card.gd" id="2_title"]
[ext_resource type="Script" path="res://game/hud/rest_card.gd" id="3_rest"]
[ext_resource type="Script" path="res://game/hud/settings_menu.gd" id="4_settings"]
[ext_resource type="Script" path="res://game/hud/credits_card.gd" id="5_credits"]
[ext_resource type="Resource" path="res://game/cove/canals_a.tres" id="6_cfg"]
[node name="Canals" type="Node2D"]
[node name="Cove" parent="." instance=ExtResource("1_cove")]
position = Vector2(402, 28)
config = ExtResource("6_cfg")
[node name="TitleCard" type="CanvasLayer" parent="."]
script = ExtResource("2_title")
[node name="RestCard" type="CanvasLayer" parent="."]
script = ExtResource("3_rest")
[node name="SettingsMenu" type="CanvasLayer" parent="."]
script = ExtResource("4_settings")
[node name="CreditsCard" type="CanvasLayer" parent="."]
script = ExtResource("5_credits")
```

- [ ] **Step 3: Estuary Portal2** — `cove.tscn` gains `[node name="Portal2" type="Node2D" parent="."]` with the cove_portal script and a new export `use_second_exit = true`; `cove.gd` injects `$Portal2` after `$Portal`; `cove_portal.setup()` with `use_second_exit` reads `exit2_enabled/exit2_target/exit2_pos` instead (retire when disabled — every existing scene keeps Portal2 retired except the estuary). `estuary_a.tres` adds `exit2_enabled = true`, `exit2_target = "res://canals.tscn"`, `exit2_pos = Vector2(-380.0, 40.0)` (west end of the estuary water — verify against estuary water_left in-editor and nudge). Estuary Portal2 persistence: reuse the `portal_cleared` idiom with key `portal2_cleared` (wire in `_wire_saves`/`_apply_saved` beside the first portal, guarded by `exit2_enabled`).
- Crossing symmetry: estuary Portal2 sets `Settings.arrive_entry = "west"`?? No — arriving INTO canals through its west door: the canals reads `arrive_entry == "west"`. So Portal2's `_cross()` must set `arrive_entry = "west"` — give legacy cove_portal an export `entry_key_out := ""` (estuary Portal2 sets `"west"`; canals' west portal sets nothing when crossing back — the estuary is legacy and uses its old `_arrive`). Keep it that simple and comment it.

- [ ] **Step 4: Main scene** — `project.godot`: `run/main_scene` → canals.tscn's uid (grab the uid Godot assigns on first import — open the project once, or set `run/main_scene="res://canals.tscn"` path form). New Day flow: `new_day.gd` reloads the CURRENT scene (verify with `grep -n "reload\|change_scene" game/cove/new_day.gd`) — canals echo runs then work unchanged.

- [ ] **Step 5: Full loop playtest (the slice gate)** — new game boots in the canals at the west shallows; turtle sleeps at (70,26)-world, wakes on spray, shell-spin works; mesa seals break, curio found inside; west seal breaks → west portal crosses to the estuary; estuary Portal2 returns to canals (arrive at the west door); estuary → hub → estuary unchanged; hub identical to live; suites + parse gate green.

- [ ] **Step 6: Export + deploy + push** — web export, `vercel deploy --prod --scope marios-projects-481b4b4e`, verify Ready, commit `feat(slice5): the Canals - first level live`, push.

---

## Self-Review (done at write time)

- **Spec coverage:** §4.1→T2, §4.2→T3, §4.3→T4, §4.4→T5, §4.5→T1+T3+T7, §4.6→T7, §4.7→T6, §4.8→T8, §5→T2/T6/T8, §6→suites in T1/T2/T4/T5/T6, §7 budgets respected (quad/rects/rock counts), §8 risks each land in their mitigating task. Grass clusters explicitly allowed to slip to polish (T3) — the only soft edge.
- **Placeholder scan:** one deliberate delegation — T3's shader marks "paste block_land's loam pattern verbatim" (the pattern is existing code the implementer copies, not invented); T7 step 3 names grep anchors for five files not read at plan time, diffs constrained to placement lines. Both are flagged for the task reviewer.
- **Type consistency:** `ReachField` API names checked against every consumer reference (`is_water`, `oil_allowed`, `surface_y()`, `floor_y_at`, `random_water_cell`, `random_surface_x`, `carve`, `set_mask`); `component_rects`/`merge_rects`/`cell_world` signatures match usage in T4/T5; config runtime vars match T2's declarations everywhere they're read.
