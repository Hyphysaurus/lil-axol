# Slice 3 — Full-Pixel Unification @ 320×180 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the entire game world on one 320×180 pixel grid (integer-scaled, Apollo-quantized with Bayer dither) while the HUD stays native-res — per the approved spec `docs/superpowers/specs/2026-07-23-slice3-full-pixel-unification-design.md`.

**Architecture:** A runtime-built "pixel shell": `cove.gd` wraps its own world children into a `SubViewportContainer → SubViewport → WorldOffset(Node2D)` chain at `_ready()`, leaving 10 HUD CanvasLayers at root. The scene files stay flat and authorable; world coordinates inside the viewport are contract-identical to today. A final fullscreen `apollo_post.gdshader` pass inside the viewport snaps every pixel to an Apollo swatch.

**Tech Stack:** Godot 4.7 (GL Compatibility, D3D12), GDScript, Godot shading language. No new dependencies.

## Global Constraints

- Base grid **320×180**; scale = biggest integer that fits the physical window; viewport **expands** to fill the remainder (never letterbox, never fractional world pixels).
- **World coordinates inside the SubViewport must equal today's world coordinates exactly** (camera limits, portals, reach maps, saves untouched). Any drift is a shell bug.
- HUD/text layers stay native-res and unmodified (the 10 layers listed in Task 3).
- No runtime fractional scaling of pixel art; swim tuning frozen (D-0003); no gameplay changes.
- Palette single-source: the post shader includes `res://shaders/apollo.gdshaderinc` — **no color literals**.
- New scripts use the **preload pattern, NOT `class_name`** (class_name doesn't resolve headless/export without an editor pass — see `game/fx/spring.gd`).
- All 9 existing headless suites in `tests/` must stay green after every task.
- Godot binary: the Steam build. Every command below assumes:
  ```powershell
  $godot = (Get-ChildItem "D:\SteamLibrary\steamapps\common\Godot Engine" -Filter "*.exe" | Where-Object Name -NotMatch "console" | Select-Object -First 1).FullName
  ```
  Run all commands from the project root `C:\Users\maram\Dev\GODOT PROJECTS\LilAxol`.

**Facts you'd otherwise have to rediscover** (verified 2026-07-23):
- `cove.tscn` root `Cove` (Node2D, `cove.gd`, authored position (509,172)) is instanced by three wrappers (`main.tscn`, `estuary.tscn`, `canals.tscn`) which override its position to (402,28) and add TitleCard/RestCard/SettingsMenu/CreditsCard CanvasLayers at wrapper level (those are outside cove — untouched by this plan).
- The camera is `Axolotl/Camera` (`axolotl.tscn:19-20`, zoom (3,3) today). Camera limits are computed in `axolotl.gd setup()` via `(get_parent() as Node2D).to_global(...)` — parent becomes WorldOffset (same global transform), so values are preserved by construction.
- Cross-component discovery is almost entirely **group-based** (`player`, `shine`, `oil_manager`, `reach_field`, `restoration`, `cove_root`…). The only literal `../` paths are in `day_night.gd` (siblings that move WITH it) and `cove_audio.gd`/`shore_health.gd` (also move with the world) — **zero cross-boundary path breaks** if the whole world subtree moves together.
- Nothing in `game/` reads viewport/window size for world logic (verified by grep); the fullscreen ColorRects (Sky, SunMoon, Clouds, Post) are full-rect anchored so they auto-shrink to the SubViewport.
- No `AudioStreamPlayer2D` exists — all audio is non-positional; audio nodes work identically inside the viewport.
- Only `cove.gd` and `touch_controls.gd` define `_exit_tree` — neither is reparented, so runtime reparenting has no exit-side effects.
- `shine.gd _spawn_pop()` adds world-anchored "+N" Labels via `get_parent()` — Shine must move world-side (it does, under the keep-at-root rule) so pops keep rendering in-world.
- `iris_wipe.gd` is a self-building CanvasLayer (layer 200) with a full-rect ColorRect — it adapts to whatever viewport it's added to.
- `apollo.gdshaderinc` defines exactly **29 swatches**: INK SLATE STEEL MIST FOAM / AQUA CYAN SKY BLUE DEEP ABYSS TEAL / MOSS GREEN FERN LEAF SPROUT / SOIL LOAM CLAY SAND / EMBER AMBER GOLD / ROSE CORAL PLUM PINK BLOSSOM (all `SW_` prefixed).
- Headless test pattern: `extends SceneTree`, `_init()` runs checks, prints `PASS/FAIL` lines + `RESULT:`, `quit(1 if fails else 0)` — see `tests/test_reach_state.gd`. Tests that need a sandboxed save use `tests/reach_map_worldstate_helper.gd` the way `tests/test_reach_map.gd` does.
- **The stretch trap:** project stretch is `canvas_items` + `expand`, so the root canvas is *fractionally* scaled (e.g. ×0.5417 on a 844×390 phone). Integer world scaling must therefore be computed in **physical pixels** and the container counter-scaled by `k * (design_h / phys_h)` — `stretch_shrink` alone would only be integer in *design* space and shimmer on phones.

---

### Task 1: pixel_shell layout math (pure, TDD)

**Files:**
- Create: `game/fx/pixel_shell.gd` (math only in this task)
- Create: `tests/test_pixel_shell.gd`

**Interfaces:**
- Produces: `PixelShell.compute_layout(phys: Vector2i) -> Dictionary` with keys `"scale"` (int ≥ 1) and `"view"` (Vector2i, the SubViewport size). `const BASE := Vector2i(320, 180)`. Task 3 consumes both.

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree
## Headless tests for the slice-3 pixel-shell layout math (pure — no scene needed).
## Run: & $godot --headless --path . --script res://tests/test_pixel_shell.gd

const Shell := preload("res://game/fx/pixel_shell.gd")

var _fails := 0

func _init() -> void:
	_test_exact_fit()
	_test_expand()
	_test_degenerate()
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _test_exact_fit() -> void:
	var l := Shell.compute_layout(Vector2i(1280, 720))
	_check("720p: scale 4", l["scale"] == 4)
	_check("720p: view 320x180", l["view"] == Vector2i(320, 180))
	l = Shell.compute_layout(Vector2i(1920, 1080))
	_check("1080p: scale 6", l["scale"] == 6)
	_check("1080p: view 320x180", l["view"] == Vector2i(320, 180))

func _test_expand() -> void:
	# phone landscape: 844x390 -> k = min(2.6, 2.16) floored = 2, view expands to fill
	var l := Shell.compute_layout(Vector2i(844, 390))
	_check("phone: scale 2", l["scale"] == 2)
	_check("phone: view 422x195", l["view"] == Vector2i(422, 195))
	# just under a scale step: k=1, view = window (bigger than base on x, y)
	l = Shell.compute_layout(Vector2i(639, 359))
	_check("under-step: scale 1", l["scale"] == 1)
	_check("under-step: view 639x359", l["view"] == Vector2i(639, 359))
	# non-divisible: 1000x600 -> k=3, view = ceil(1000/3)=334 x 200
	l = Shell.compute_layout(Vector2i(1000, 600))
	_check("nondiv: scale 3", l["scale"] == 3)
	_check("nondiv: view 334x200", l["view"] == Vector2i(334, 200))

func _test_degenerate() -> void:
	# headless server / zero window: neutral shell, never crash, never scale 0
	var l := Shell.compute_layout(Vector2i(0, 0))
	_check("zero: scale 1", l["scale"] == 1)
	_check("zero: view = BASE", l["view"] == Shell.BASE)
	# window smaller than base: k=1, view = window (shows less world, never upscale-blurs)
	l = Shell.compute_layout(Vector2i(300, 200))
	_check("tiny: scale 1", l["scale"] == 1)
	_check("tiny: view 300x200", l["view"] == Vector2i(300, 200))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& $godot --headless --path . --script res://tests/test_pixel_shell.gd`
Expected: FAIL (script `res://game/fx/pixel_shell.gd` doesn't exist yet → preload error)

- [ ] **Step 3: Write the minimal implementation**

```gdscript
extends Node
## Slice-3 pixel shell (spec 2026-07-23): wraps the cove's world subtree in a 320x180
## SubViewport at runtime so the whole world renders on one integer-scaled pixel grid while
## HUD layers stay native-res at the cove root. Layout math is pure + static for headless
## testing. Preloaded (not class_name) by cove.gd — same portable pattern as game/fx/spring.gd.

const BASE := Vector2i(320, 180)

## Biggest integer scale that fits the physical window, view expanded to fill the remainder
## (ratified fill policy: integer + expand, never letterbox, never fractional world pixels).
static func compute_layout(phys: Vector2i) -> Dictionary:
	if phys.x <= 0 or phys.y <= 0:
		return {"scale": 1, "view": BASE}   # headless / degenerate window: neutral shell
	var k := maxi(1, mini(phys.x / BASE.x, phys.y / BASE.y))   # int division = floor
	return {"scale": k, "view": Vector2i(ceili(phys.x / float(k)), ceili(phys.y / float(k)))}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& $godot --headless --path . --script res://tests/test_pixel_shell.gd`
Expected: `ALL PASS`, exit 0

- [ ] **Step 5: Commit**

```bash
git add game/fx/pixel_shell.gd tests/test_pixel_shell.gd
git commit -m "feat(slice3): pixel-shell layout math (320x180 integer+expand) + headless tests"
```

---

### Task 2: coordinate-contract baseline test (locks today's world coords)

**Files:**
- Create: `tests/test_pixel_contract.gd`

**Interfaces:**
- Consumes: nothing new — boots `res://canals.tscn` (the main scene) exactly as the game does.
- Produces: a green baseline that Task 3 must keep green. Constants `EXPECTED_*` captured from the CURRENT build.

- [ ] **Step 1: Capture today's ground truth with a throwaway probe**

Create `tests/_probe_contract.gd` (temporary — deleted in Step 3):

```gdscript
extends SceneTree
## One-shot probe: prints the world coordinates the slice-3 contract test will lock.
func _init() -> void:
	var scene: Node = (load("res://canals.tscn") as PackedScene).instantiate()
	root.add_child(scene)   # runs every _ready synchronously, incl. cove.gd injection
	var axo := get_first_node_in_group("player") as CharacterBody2D
	var cam := axo.get_node("Camera") as Camera2D
	print("axo=", axo.global_position)
	print("cam_limits=", cam.limit_left, ",", cam.limit_top, ",", cam.limit_right, ",", cam.limit_bottom)
	for v in get_nodes_in_group("thermal_vent"):
		print("vent=", (v as Node2D).global_position)
	quit(0)
```

Sandbox the save first so the probe reads a FRESH world (model on how `tests/test_reach_map.gd`
uses `tests/reach_map_worldstate_helper.gd` — read those two files and copy the same setup lines
into the probe before the scene load).

Run: `& $godot --headless --path . --script res://tests/_probe_contract.gd`
Expected: printed positions + limits (record them for Step 2).

- [ ] **Step 2: Write the contract test using the recorded values**

Create `tests/test_pixel_contract.gd` (same SceneTree pattern; replace the `EXPECTED_*` constants
with the values Step 1 printed — the placeholders below are ILLUSTRATIVE and MUST be replaced):

```gdscript
extends SceneTree
## Slice-3 coordinate contract: world global coordinates (inside or outside the pixel shell)
## must equal the pre-slice values EXACTLY. If this test breaks, fix the shell, not the numbers.
## Run: & $godot --headless --path . --script res://tests/test_pixel_contract.gd

const EXPECTED_AXO := Vector2(0.0, 0.0)          # <- paste probe value
const EXPECTED_LIMITS := [0, 0, 0, 0]            # <- paste probe values [l, t, r, b]
const EXPECTED_VENT_COUNT := 0                   # <- paste probe count
const EXPECTED_VENT_0 := Vector2(0.0, 0.0)       # <- paste first vent

var _fails := 0

func _init() -> void:
	# (same WorldState sandbox lines as the probe / test_reach_map)
	var scene: Node = (load("res://canals.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var axo := get_first_node_in_group("player") as CharacterBody2D
	_check("player exists", axo != null)
	if axo:
		_check("axo spawn position", axo.global_position.is_equal_approx(EXPECTED_AXO))
		var cam := axo.get_node("Camera") as Camera2D
		_check("camera limits", [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom] == EXPECTED_LIMITS)
	var vents := get_nodes_in_group("thermal_vent")
	_check("vent count", vents.size() == EXPECTED_VENT_COUNT)
	if vents.size() > 0:
		_check("vent 0 position", (vents[0] as Node2D).global_position.is_equal_approx(EXPECTED_VENT_0))
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
```

Note: read positions synchronously after `add_child` (no `await`) — no physics tick runs, so the
values are deterministic.

- [ ] **Step 3: Verify it passes TODAY (baseline), then delete the probe**

Run: `& $godot --headless --path . --script res://tests/test_pixel_contract.gd`
Expected: `ALL PASS` on the current, un-restructured tree.
Then delete `tests/_probe_contract.gd` (and its `.uid` if generated).

- [ ] **Step 4: Commit**

```bash
git add tests/test_pixel_contract.gd
git commit -m "test(slice3): lock the world-coordinate contract before the pixel shell lands"
```

---

### Task 3: build the shell — restructure at runtime, camera ×1

**Files:**
- Modify: `game/fx/pixel_shell.gd` (add build/resize)
- Modify: `game/cove/cove.gd` (shell-first `_ready`, `_w()` helper, world-side adds)
- Modify: `game/axolotl/axolotl.tscn:20` (remove `zoom = Vector2(3, 3)`)

**Interfaces:**
- Consumes: `compute_layout` from Task 1.
- Produces: `shell.build(cove: Node2D, keep_at_root: Array) -> Node2D` (returns the WorldOffset node); `cove.gd` gains `var _world: Node2D`, `const KEEP_AT_ROOT`, and `func _w(n: String) -> Node`. Task 4 parents ApolloSnap via the shell's `_viewport`.

- [ ] **Step 1: Extend pixel_shell.gd with build + resize**

Append to `game/fx/pixel_shell.gd`:

```gdscript
var _container: SubViewportContainer
var _viewport: SubViewport

## Build the shell under `cove` and move every child NOT named in keep_at_root into the world
## viewport. Call FIRST in cove.gd._ready(), before any injection. Returns the WorldOffset node
## that all new world content must parent to (its transform reproduces the cove root's global
## transform — the coordinate contract).
func build(cove: Node2D, keep_at_root: Array) -> Node2D:
	var layer := CanvasLayer.new()
	layer.name = "WorldShell"
	layer.layer = -120                       # under every HUD CanvasLayer at the cove root
	_container = SubViewportContainer.new()
	_container.name = "WorldView"
	_container.stretch = true                # shrink stays 1: _resize sizes the viewport directly
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport = SubViewport.new()
	_viewport.name = "World"
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.disable_3d = true
	var world := Node2D.new()
	world.name = "WorldOffset"
	world.transform = cove.global_transform  # the coordinate contract: world coords == today's
	_viewport.add_child(world)
	_container.add_child(_viewport)
	layer.add_child(_container)
	add_child(layer)
	for c in cove.get_children():            # get_children() returns a copy — safe to reparent in-loop
		if c == self or String(c.name) in keep_at_root:
			continue
		c.reparent(world)                    # keep_global default: Node2D locals recompute to identical values
	_resize()
	get_tree().root.size_changed.connect(_resize)
	return world

## Integer scaling in PHYSICAL pixels, counter-scaled against the canvas_items stretch factor
## (design/phys) so world texels land on exact physical pixels on every device.
func _resize() -> void:
	var phys := DisplayServer.window_get_size()
	var lay := compute_layout(phys)
	_container.size = Vector2(lay["view"])   # local units == world pixels (stretch, shrink 1)
	var design := get_viewport().get_visible_rect().size
	var f := (design.y / float(phys.y)) if (phys.y > 0 and design.y > 0.0) else 1.0
	_container.scale = Vector2.ONE * (float(lay["scale"]) * f)
	_container.position = Vector2.ZERO
```

- [ ] **Step 2: Rewire cove.gd through the shell**

In `game/cove/cove.gd`:

(a) Add below the existing preloads and `_echo` var:

```gdscript
const PixelShell := preload("res://game/fx/pixel_shell.gd")

## HUD + native-res layers that STAY at the cove root (everything else moves into the
## 320x180 world viewport — including Shine, whose "+N" pops are world-anchored, and
## CoveAudio/ShoreHealth/TimeOfDay, whose relative sibling paths move with them).
const KEEP_AT_ROOT := ["RestorationBanner", "NewDay", "TouchControls", "RestorationMeter",
	"ShineHud", "FeatBanner", "PartnerHud", "HighScores", "Hints", "PerfOverlay"]

var _world: Node2D

## World-side child lookup (post-shell replacement for $Name / get_node_or_null on self).
func _w(n: String) -> Node:
	return _world.get_node_or_null(n) if _world else get_node_or_null(n)
```

(b) In `_ready()`, immediately after `WorldState.current_id = config.id`, build the shell BEFORE
the ReachField/injection block, and route the field into the world:

```gdscript
	# slice 3 (spec 2026-07-23): the pixel shell wraps every world child into a 320x180
	# SubViewport FIRST; HUD stays at root; world coords are contract-identical.
	var shell := PixelShell.new()
	shell.name = "PixelShell"
	add_child(shell)
	_world = shell.build(self, KEEP_AT_ROOT)
	var field := ReachField.new()
	field.setup_rect(config)
	_world.add_child(field)
```

(remove the old `var field := ReachField.new() … add_child(field)` lines).

(c) Convert every child lookup in cove.gd to `_w`:
- the 21 `_inject($X)` calls → `_inject(_w("X"))` (same names, e.g. `_inject(_w("ReachMap"))`)
- `_spawn_travellers`: `get_node_or_null("Axolotl")` → `_w("Axolotl")`; `add_child(t)` → `_world.add_child(t)`
- `_live(n)`: `var node := get_node_or_null(n)` → `var node := _w(n)`
- `_exit_tree`: `get_node_or_null("OilSpill")` → `_w("OilSpill")`
- `_arrive`: `$Axolotl` → `_w("Axolotl")`
- `_arrive_wipe`: `add_child(wipe)` → `_world.add_child(wipe)` (the arrival iris renders in-world, pixelated per spec)
- `_apply_environment`: `get_node_or_null("Water")` → `_w("Water")` (the land loop already uses `_live`, now world-routed)

(d) Audit the OTHER IrisWipe creators so every wipe lands world-side:

Run: `Grep pattern "iris_wipe" in game/ (files_with_matches)`
For each hit besides cove.gd (expected: `game/cove/cove_portal.gd`, possibly `game/hud/new_day.gd`):
if the wipe is added to the cove root or a world node, route it to the world (world scripts:
`get_tree().get_first_node_in_group("cove_root")._world.add_child(wipe)` is WRONG — private; instead
add a tiny public accessor on cove.gd:

```gdscript
## World-side parent for runtime FX (iris wipes, spawned world nodes). Shell-aware.
func world_node() -> Node2D:
	return _world if _world else self
```

and call `cove_root.world_node().add_child(wipe)` from those scripts).

- [ ] **Step 3: Camera to ×1**

In `game/axolotl/axolotl.tscn`, delete line 20 (`zoom = Vector2(3, 3)`) so the camera renders 1
world pixel = 1 viewport pixel.

- [ ] **Step 4: Contract + full suite must stay green**

Run:
```powershell
& $godot --headless --path . --script res://tests/test_pixel_contract.gd
foreach ($t in (Get-ChildItem tests -Filter "test_*.gd").Name) { & $godot --headless --path . --script "res://tests/$t"; if ($LASTEXITCODE -ne 0) { Write-Host "SUITE FAILED: $t" } }
```
Expected: every suite prints `ALL PASS` (or its own pass marker), no `SUITE FAILED` lines.
The contract test passing post-restructure IS the coordinate contract, executable.

- [ ] **Step 5: Boot lint**

Run: `& $godot --headless --path . --quit-after 180 2>&1 | Select-String -Pattern "ERROR|SCRIPT ERROR"`
Expected: only the known MetSys `Map data file does not exist` noise — nothing new.

- [ ] **Step 6: Manual smoke (windowed)**

Run: `& $godot --path .`
Verify by eye: world renders chunky (×4 at 720p) with the axolotl ~33% larger on screen; HUD
(score, chips, meter, title) stays crisp; mouse-aimed spray hits where the cursor points;
click-to-command works; portal crossing plays a PIXELATED iris; window resize keeps pixels square
(drag to odd sizes). If mouse aim is offset, the SubViewportContainer input transform is the
suspect — check that no HUD Control with `mouse_filter != IGNORE` covers the screen.

- [ ] **Step 7: Commit**

```bash
git add game/fx/pixel_shell.gd game/cove/cove.gd game/axolotl/axolotl.tscn game/cove/cove_portal.gd game/hud/new_day.gd
git commit -m "feat(slice3): runtime pixel shell — world in a 320x180 SubViewport, HUD native, camera x1"
```

---

### Task 4: the Apollo snap + dither post-pass

**Files:**
- Create: `shaders/apollo_post.gdshader`
- Modify: `game/fx/pixel_shell.gd` (ApolloSnap layer inside the viewport)
- Test: `tests/test_apollo_post.gd`

**Interfaces:**
- Consumes: `_viewport` from Task 3's shell.
- Produces: the `ApolloSnap` CanvasLayer (layer 250, above the world's PostFX at 100 and IrisWipe at 200) with uniforms `dither_strength: float` and `enabled: bool`.

- [ ] **Step 1: Write the shader smoke test (failing)**

```gdscript
extends SceneTree
## Smoke test: the apollo_post shader loads, compiles into a material, and takes its uniforms.
## Run: & $godot --headless --path . --script res://tests/test_apollo_post.gd

var _fails := 0

func _init() -> void:
	var sh := load("res://shaders/apollo_post.gdshader")
	_check("shader loads", sh is Shader)
	if sh is Shader:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("dither_strength", 0.5)
		mat.set_shader_parameter("enabled", true)
		_check("uniform round-trip", is_equal_approx(float(mat.get_shader_parameter("dither_strength")), 0.5))
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
```

Run: `& $godot --headless --path . --script res://tests/test_apollo_post.gd`
Expected: FAIL (`shader loads`).

- [ ] **Step 2: Write the shader**

`shaders/apollo_post.gdshader`:

```glsl
shader_type canvas_item;
render_mode unshaded;
// Slice-3 global palette pass (spec 2026-07-23): runs LAST inside the 320x180 world viewport,
// snapping every pixel — procedural gradients, day/night Mood tints, god-rays, grain, iris —
// to its nearest Apollo swatch, with an ordered Bayer 4x4 dither between the two nearest
// swatches so gradients keep depth as retro texture. Sprites are already Apollo-authored, so
// the snap is a near-no-op for them. dither_strength 0 = hard posterize.
#include "res://shaders/apollo.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool enabled = true;

const int PAL_N = 29;
const vec3 PAL[PAL_N] = vec3[](
	SW_INK, SW_SLATE, SW_STEEL, SW_MIST, SW_FOAM,
	SW_AQUA, SW_CYAN, SW_SKY, SW_BLUE, SW_DEEP, SW_ABYSS, SW_TEAL,
	SW_MOSS, SW_GREEN, SW_FERN, SW_LEAF, SW_SPROUT,
	SW_SOIL, SW_LOAM, SW_CLAY, SW_SAND,
	SW_EMBER, SW_AMBER, SW_GOLD,
	SW_ROSE, SW_CORAL, SW_PLUM, SW_PINK, SW_BLOSSOM
);

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	if (!enabled) {
		COLOR = vec4(src, 1.0);
	} else {
		float d1 = 1e9; float d2 = 1e9;
		vec3 c1 = src; vec3 c2 = src;
		for (int i = 0; i < PAL_N; i++) {
			vec3 dv = PAL[i] - src;
			float d = dot(dv, dv);
			if (d < d1)      { d2 = d1; c2 = c1; d1 = d; c1 = PAL[i]; }
			else if (d < d2) { d2 = d;  c2 = PAL[i]; }
		}
		// how far src sits from its nearest swatch toward the runner-up (0 = exactly on c1)
		float t = sqrt(d1) / max(sqrt(d1) + sqrt(d2), 1e-5);
		ivec2 px = ivec2(FRAGCOORD.xy);
		float th = (BAYER[(px.y % 4) * 4 + (px.x % 4)] + 0.5) / 16.0;
		COLOR = vec4(th < (t * 2.0 * dither_strength) ? c2 : c1, 1.0);
	}
}
```

- [ ] **Step 3: Mount it in the shell**

In `game/fx/pixel_shell.gd build()`, after `_container.add_child(_viewport)` add:

```gdscript
	var snap_layer := CanvasLayer.new()
	snap_layer.name = "ApolloSnap"
	snap_layer.layer = 250                   # above world PostFX (100) and the iris wipe (200)
	var snap_rect := ColorRect.new()
	snap_rect.name = "Snap"
	snap_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	snap_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var snap_mat := ShaderMaterial.new()
	snap_mat.shader = preload("res://shaders/apollo_post.gdshader")
	snap_rect.material = snap_mat
	snap_layer.add_child(snap_rect)
	_viewport.add_child(snap_layer)
```

- [ ] **Step 4: Tests + lint green**

Run: `& $godot --headless --path . --script res://tests/test_apollo_post.gd` → `ALL PASS`
Run the full suite loop from Task 3 Step 4 → all green.
Run boot lint from Task 3 Step 5 → nothing new.

- [ ] **Step 5: Manual visual check**

Run: `& $godot --path .`
Sky/water/clouds show visible Apollo bands with a fine dither weave between them; day/night dusk
stays readable; toggling `enabled` off via the remote tree (or temporarily hardcoding `false`)
A/Bs the raw low-res look. Watch the F3 perf overlay: FPS should be ≥ the pre-slice number.

- [ ] **Step 6: Commit**

```bash
git add shaders/apollo_post.gdshader game/fx/pixel_shell.gd tests/test_apollo_post.gd
git commit -m "feat(slice3): global Apollo snap + Bayer-dither post pass inside the world viewport"
```

---

### Task 5: low-res feel pass (bounded tuning, no rewrites)

**Files:**
- Modify: `game/cove/shine.gd:250` (pop font size)
- Modify: shader-parameter values only, in `game/cove/cove.tscn` sub-resources (as needed per eyeball)

**Interfaces:** none new — uniform/constant tuning only.

- [ ] **Step 1: Right-size the world-anchored score pops**

In `game/cove/shine.gd _spawn_pop()`, the Label now rasterizes INTO the 320×180 grid (×4 on a
720p screen vs ×3 before → pops read ~78% bigger than pre-slice). Restore the old on-screen size:

```gdscript
		l.add_theme_font_size_override("font_size", 13 + int(9.0 * warm))   # was 18 + 12*warm — pre-shell screen size at x4
```

(leave `l.scale = Vector2(1.5, 1.5)` — the pop-in tween is transient; revisit only if Maram flags shimmer).

- [ ] **Step 2: Eyeball-driven uniform dial (with Maram or via screenshots)**

Run the game windowed at 1280×720 and check each against "reads as composed pixel art, not shrunk":
- `Clouds` (`cove.tscn` ShaderMaterial_bhunq): if bands read mushy, nudge `puffiness` 0.65 → 0.5 and `coverage` 1.35 → 1.2.
- `Water` (ShaderMaterial_fnfnh): `wave_amp` 4.0 is 4 world px (was 12 screen px pre-slice ×3; now 16 at ×4) — if the surface line jitters too tall, drop to 3.0.
- `Post` grain 0.035: film grain is now chunky 1-world-px grain — if noisy, halve to 0.018.
- `ApolloSnap.dither_strength` 0.35: dial 0.2–0.5 to taste (0 = flat bands).
Change ONLY values that fail the eyeball; record each change in the commit message.

- [ ] **Step 3: Suite + lint still green**

Run the full suite loop + boot lint. Expected: all green, nothing new.

- [ ] **Step 4: Commit**

```bash
git add game/cove/shine.gd game/cove/cove.tscn
git commit -m "tune(slice3): low-res feel pass — pop sizing + shader dials for the 320x180 grid"
```

---

### Task 6: docs wave (D-0018, STATUS, master edit-note)

**Files:**
- Modify: `docs/DECISIONS.md` (append D-0018)
- Modify: `docs/STATUS.md` (BUILT entry, palette-line fix, DESIGNED/NOT-BUILT + P-6 resolution)
- Modify: `docs/superpowers/specs/2026-07-07-living-watershed-master-design.md` (§5 edit-note)

- [ ] **Step 1: Append D-0018 to DECISIONS.md** (house format, after D-0017):

```markdown
## D-0018 — Full-pixel base grid is 320×180, integer + expand, dithered Apollo bands (2026-07-23, Maram — slice 3, amends master §5)
The master spec's 640×360 would have zoomed the framing OUT ~1.5× (today's zoom-3 camera shows a
~427×240 world window); Maram ruled **320×180** (×4 → 720p, ×6 → 1080p) — characters read ~33%
BIGGER, the Animal Well / Celeste grid. Companion rulings: (1) **HUD/text stays native-res**
(master §5 letter — no pixel-font re-theme); (2) fill policy = **integer + expand** — biggest
integer scale that fits the physical window, viewport extends to fill, no letterbox, matching the
game's existing `expand` behavior; (3) color = **dithered Apollo bands** — one global post pass
(`shaders/apollo_post.gdshader`, Bayer 4×4, tunable `dither_strength`, a tuned constant not a user
setting) runs last inside the world viewport so even day/night Mood tints land on-palette.
Architecture: a **runtime pixel shell** (`game/fx/pixel_shell.gd`, built by `cove.gd` at `_ready`)
— scene files stay flat, wrappers untouched, world coordinates contract-identical (locked by
`tests/test_pixel_contract.gd`). Spec:
`docs/superpowers/specs/2026-07-23-slice3-full-pixel-unification-design.md`.
```

- [ ] **Step 2: STATUS.md updates**
- Header game-state line: note slice 3 shipped (grid 320×180, integer+expand, Apollo post-pass).
- In BUILT, add a "Pixel shell (slice 3)" bullet: runtime SubViewport shell in cove.gd, world @320×180,
  HUD native, `apollo_post` global quantizer, camera ×1, coordinate contract test.
- Fix the stale palette line: `**Palette** (palette.gd + shaders/sweetie16.gdshaderinc) — Sweetie-16
  master, single-source (D-0010)` → `**Palette** (palette.gd + shaders/apollo.gdshaderinc) — Apollo
  master, single-source (D-0010, migrated 2026-07-04); slice 3 adds the global apollo_post quantizer`.
- DESIGNED-NOT-BUILT: remove the Slice-3 entry; AWAITING MARAM: resolve **P-6** (ruled: done now, this slice).
- KNOWN GAPS: add "lit addon shader globals still track the window, not the world viewport — harmless
  (no Lit lights in game code); wire only if Lit ever ships a light."

- [ ] **Step 3: Master spec §5 edit-note** — insert directly under the `## 5. Art unification — full pixel @ 640×360` heading:

```markdown
> **AMENDED 2026-07-23 (D-0018, slice 3 shipped):** base grid is **320×180** (not 640×360) —
> ×4 → 720p / ×6 → 1080p, integer + expand fill, global Apollo snap+dither post-pass. See
> `2026-07-23-slice3-full-pixel-unification-design.md`.
```

- [ ] **Step 4: Commit**

```bash
git add docs/DECISIONS.md docs/STATUS.md docs/superpowers/specs/2026-07-07-living-watershed-master-design.md
git commit -m "docs(slice3): D-0018 + STATUS + master-spec amendment for the 320x180 pixel shell"
```

---

### Task 7: export, deploy, phone eyeball (GATED on Maram)

**Files:** none (build artifacts are gitignored).

- [ ] **Step 1: Web export**

```powershell
& $godot --headless --path . --export-release "Web"
```
Expected: `build/lilaxol/` refreshed, no export errors. (Preset gotchas already configured:
explicit custom_template paths for the Steam build; `vram_texture_compression/for_mobile=false`.)

- [ ] **Step 2: Local web smoke** — serve `build/lilaxol/` (`python -m http.server` or equivalent)
and load in a browser: shell scales, HUD crisp, touch emulation via mouse OK, FPS via F3.

- [ ] **Step 3: STOP — confirm with Maram before production deploy** (replaces the live game).
On the go-ahead:

```powershell
cd build/lilaxol; vercel deploy --prod --scope marios-projects-481b4b4e
```

Remind Maram: a deploy never updates an already-running tab — full reload on the phone.

- [ ] **Step 4: Maram's phone checklist** (from the spec): axolotl size feel · water/sky band +
dither strength · HUD crispness · touch aim + drag-to-swim · portal transition · FPS (F3) vs
pre-slice. Findings loop back into Task 5's dials.

---

## Plan Self-Review (done at write time)

- **Spec coverage:** shell+contract (T1–T3), post-pass (T4), feel pass (T5), lit-addon note +
  STATUS/D-0018/master amendment (T6), deploy+checklist (T7), scale-math + contract + smoke tests
  (T1/T2/T4). Spec's "lit investigation" resolved at plan time: no Lit usage in game code (grep) →
  documented as a KNOWN GAPS note, nothing wired.
- **Placeholders:** Task 2's `EXPECTED_*` constants are deliberately probe-filled (Step 1 produces
  them — a measurement, not a TBD).
- **Type consistency:** `compute_layout` keys `"scale"`/`"view"` used identically in T1/T3;
  `build(cove, keep_at_root) -> Node2D` consumed in T3(b); `world_node()` accessor matches its
  T3(d) call sites; `PAL_N`/uniform names consistent between T4 shader and smoke test.
