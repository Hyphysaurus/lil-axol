# Slice 1 — Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The world remembers itself — per-cove persistence (WorldState) with Echo runs for score replays — plus the frog's surface-pivot, the marsh estuary's first real identity, and the mud-turtle restyle.

**Architecture:** A new `WorldState` autoload (ConfigFile at `user://world.save`) stores per-cove flags; the Cove composition root (`cove.gd`) applies saved state after injection and wires milestone saves via signals. Echo runs are a session flag set by New Day on a restored cove — the root then skips apply and suppresses saves. Everything else is config + small self-contained components in the established cove idiom (setup-injected, code-drawn, Apollo palette).

**Tech Stack:** Godot 4.7 (Steam), GDScript, ConfigFile persistence, headless `--script` tests, Python/PIL for the sprite restyle, web export → Vercel.

## Global Constraints

- **Cozy contract:** no fail states for the player; nothing here punishes.
- **Frozen swim tuning (D-0003):** never touch `axolotl.gd` movement numbers.
- **Apollo palette only** — named `Palette.*` swatches, never literal colors (except where a task explicitly derives a tint).
- **Preload, not `class_name`,** for new scripts (`class_name` doesn't resolve headless/export without an editor pass — house rule, see `game/fx/spring.gd`).
- **No runtime fractional scaling of pixel art** (spec §9).
- **Web no-threads export target** — no threads, no blocking IO in `_process`.
- **GDScript style:** tabs, `##` doc comments, self-contained components injected by the root via `setup(cfg)`.
- Godot CLI for verification: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe` (call as `$godot` below). Project path: `C:\Users\maram\Dev\GODOT PROJECTS\LilAxol`.
- Parse gate after every task: run the import scan below; **zero** SCRIPT ERROR / Parse Error lines.

```powershell
$godot = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$proj  = "C:\Users\maram\Dev\GODOT PROJECTS\LilAxol"
& $godot --headless --path $proj --import 2>&1 |
  Select-String -Pattern "SCRIPT ERROR|Parse Error|Compile error" -CaseSensitive:$false
```

---

### Task 1: WorldState autoload + headless tests + cove identity

**Files:**
- Create: `game/world/world_state.gd`
- Create: `tests/test_world_state.gd`
- Modify: `project.godot` (autoload section, line ~22)
- Modify: `game/cove/cove_config.gd` (add `id` export)
- Modify: `game/cove/cove_a.tres`, `game/cove/estuary_a.tres` (set ids)

**Interfaces:**
- Consumes: nothing (leaf module).
- Produces (used by Tasks 2–3):
  - autoload `WorldState` with: `var echo: bool`, `var current_id: String`, `var save_path: String`,
    `func load_file() -> void`, `func get_cove(id: String, key: String, default: Variant) -> Variant`,
    `func mark(id: String, key: String, value: Variant) -> void`, `func is_restored(id: String) -> bool`
  - `CoveConfig.id: String` (`"hub"` / `"estuary"`)

- [ ] **Step 1: Write the failing test**

Create `tests/test_world_state.gd`:

```gdscript
extends SceneTree
## Headless tests for WorldState (run BEFORE the autoload exists -> first run must FAIL to load).
## Run: & $godot --headless --path $proj --script res://tests/test_world_state.gd
## Prints one line per case; exits 1 on any failure (CI-friendly).

const WS := preload("res://game/world/world_state.gd")

var _fails := 0

func _init() -> void:
	_test_fresh_defaults()
	_test_round_trip()
	_test_corrupt_quarantine()
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _fresh(path: String) -> Node:
	# instantiate directly (no tree, no _ready) and load explicitly — same code path the game uses
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs)
	if FileAccess.file_exists(path + ".bad"):
		DirAccess.remove_absolute(abs + ".bad")
	var ws: Node = WS.new()
	ws.save_path = path
	ws.load_file()
	return ws

func _test_fresh_defaults() -> void:
	var ws := _fresh("user://test_ws_fresh.save")
	_check("fresh: not restored", ws.is_restored("hub") == false)
	_check("fresh: default returned", float(ws.get_cove("hub", "cleanliness", 0.25)) == 0.25)
	ws.free()

func _test_round_trip() -> void:
	var path := "user://test_ws_round.save"
	var a := _fresh(path)
	a.mark("hub", "restored", true)
	a.mark("hub", "cleanliness", 0.42)
	a.mark("estuary", "friend_awake", true)
	a.free()
	var b: Node = WS.new()
	b.save_path = path
	b.load_file()
	_check("round: restored persists", b.is_restored("hub"))
	_check("round: float persists", absf(float(b.get_cove("hub", "cleanliness", 0.0)) - 0.42) < 0.001)
	_check("round: other cove isolated", b.is_restored("estuary") == false)
	_check("round: other cove key persists", bool(b.get_cove("estuary", "friend_awake", false)))
	b.free()

func _test_corrupt_quarantine() -> void:
	var path := "user://test_ws_bad.save"
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path + ".bad"):
		DirAccess.remove_absolute(abs + ".bad")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{{{ this is not a config file }}}")
	f.close()
	var ws: Node = WS.new()
	ws.save_path = path
	ws.load_file()                       # must not crash
	_check("corrupt: defaults after quarantine", ws.is_restored("hub") == false)
	_check("corrupt: .bad backup exists", FileAccess.file_exists(path + ".bad"))
	ws.mark("hub", "restored", true)     # store still writable after quarantine
	_check("corrupt: writable after quarantine", ws.is_restored("hub"))
	ws.free()
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
& $godot --headless --path $proj --script res://tests/test_world_state.gd 2>&1 | Select-Object -Last 8
```
Expected: FAILS to even run (preload of `res://game/world/world_state.gd` — file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `game/world/world_state.gd`:

```gdscript
extends Node
## WorldState — the persistent world memory (Living Watershed spec §7). One ConfigFile at
## user://world.save (IndexedDB-backed on web, so lilaxol.vercel.app keeps saves): a section per
## cove keyed by CoveConfig.id, plus a meta section for versioning. Writes are milestone-driven
## (the cove root calls mark() on rescue/portal/restore and on scene exit) — never per-frame.
## Corrupt or future-versioned files are quarantined to `<file>.bad` and replaced with a fresh
## store: never crash, never silently clobber the evidence (spec §7).

const SAVE_VERSION := 1

## Injectable for tests; the game always uses the default.
var save_path := "user://world.save"

## SESSION flags (not persisted):
## echo — the next scene load is an ECHO RUN (score replay of a restored cove): the root skips
## applying saved state and suppresses saves, so the world stays untouched (spec §7).
var echo := false
## current_id — the live scene's cove id, set by the cove root (New Day reads it).
var current_id := ""

var _cfg := ConfigFile.new()

func _ready() -> void:
	load_file()

## Load (or re-load) the store. Missing file = fresh defaults; unreadable or future-versioned
## file = quarantine + fresh.
func load_file() -> void:
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(save_path):
		var err := _cfg.load(save_path)
		var v := int(_cfg.get_value("meta", "version", SAVE_VERSION)) if err == OK else SAVE_VERSION + 1
		if err != OK or v > SAVE_VERSION:
			_quarantine()
	_cfg.set_value("meta", "version", SAVE_VERSION)

func _quarantine() -> void:
	var abs := ProjectSettings.globalize_path(save_path)
	DirAccess.rename_absolute(abs, abs + ".bad")   # keep the evidence, exactly once (overwrites older .bad)
	_cfg = ConfigFile.new()

func get_cove(id: String, key: String, default: Variant) -> Variant:
	return _cfg.get_value("cove_" + id, key, default)

## Set one per-cove value and flush to disk. Milestone-cadence only — never call per frame.
func mark(id: String, key: String, value: Variant) -> void:
	_cfg.set_value("cove_" + id, key, value)
	_cfg.save(save_path)

func is_restored(id: String) -> bool:
	return bool(get_cove(id, "restored", false))
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
& $godot --headless --path $proj --script res://tests/test_world_state.gd 2>&1 | Select-Object -Last 12
```
Expected: every line `PASS`, final line `RESULT: ALL PASS`, exit code 0.

- [ ] **Step 5: Register the autoload**

In `project.godot`, the `[autoload]` section currently reads:

```ini
[autoload]

MetSys="*uid://c01ibpvrp2wsd"
LitManager="*uid://brf2hvdtyyw3q"
Sfx="*res://game/audio/sfx.gd"
Settings="*res://game/hud/settings_store.gd"
Leaderboard="*res://game/net/leaderboard.gd"
```

Add after the `Settings` line:

```ini
WorldState="*res://game/world/world_state.gd"
```

- [ ] **Step 6: Give coves identities**

In `game/cove/cove_config.gd`, directly under `class_name CoveConfig` doc block (before `@export_group("Water Geometry")`), add:

```gdscript
@export_group("Identity")
## Stable save key for this cove ("hub", "estuary", ...). WorldState files all progress under it —
## never rename once players have saves.
@export var id: String = "hub"
```

In `game/cove/cove_a.tres`, add under `script = ExtResource("1_cfg")`:

```ini
id = "hub"
```

In `game/cove/estuary_a.tres`, likewise add:

```ini
id = "estuary"
```

- [ ] **Step 7: Parse gate**

Run the Global Constraints import scan. Expected: no error lines.

- [ ] **Step 8: Commit**

```powershell
cd $proj
git add game/world/world_state.gd tests/test_world_state.gd project.godot game/cove/cove_config.gd game/cove/cove_a.tres game/cove/estuary_a.tres
git commit -m "feat: WorldState persistence autoload with headless tests + cove ids"
```

---

### Task 2: Apply saved state + milestone save wiring (the world remembers)

**Files:**
- Modify: `game/cove/oil_spill.gd` (add `set_clean_fraction`)
- Modify: `game/companion/companion.gd` (add `woke` signal, `wake_instant()`, roster fix)
- Modify: `game/cove/cove_portal.gd` (add `opened` signal, `force_open()`)
- Modify: `game/cove/cove.gd` (apply + wire + exit save)

**Interfaces:**
- Consumes: `WorldState.get_cove/mark/is_restored/echo/current_id`, `CoveConfig.id` (Task 1).
- Produces (used by Task 3):
  - cove root joins group `"cove_root"`, exposes `config: CoveConfig` (already `@export`) and `func is_echo() -> bool`
  - `OilSpill.set_clean_fraction(f: float) -> void`
  - `Companion.wake_instant() -> void`, `signal woke`
  - `Portal.force_open() -> void`, `signal opened`

- [ ] **Step 1: `set_clean_fraction` on the oil spill**

In `game/cove/oil_spill.gd`, add after `oil_at()` (before `_vis`):

```gdscript
## Jump the whole spill to a cleanliness fraction (0 = untouched, 1 = fully clean) — the
## persistence spawn path (WorldState). Scales every cell uniformly; the visibility floor
## applies, so thin residue snaps clean exactly as scrubbing would. Recomputes the milestone
## cursor so re-seeded progress doesn't replay milestone bursts/chimes.
func set_clean_fraction(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if _mask == null or f <= 0.0:
		return
	var keep := 1.0 - f
	_remaining = 0.0
	for my in MASK_H:
		for mx in MASK_W:
			var i := my * MASK_W + mx
			var nr := _cov[i] * keep
			if nr < VIS_FLOOR:
				nr = 0.0
			_cov[i] = nr
			_mask.set_pixel(mx, my, Color(nr, 0.0, 0.0, 1.0))
			_remaining += _vis(nr)
	_mask_tex.update(_mask)
	_set_clean()
	_milestone = 0
	for m in MILESTONES:
		if current_clean >= float(m):
			_milestone += 1
```

- [ ] **Step 2: `woke` signal + `wake_instant()` + the roster fix on the companion**

In `game/companion/companion.gd`:

(a) Add under the existing `signal`-free top (after the `enum Kind` line):

```gdscript
signal woke   # emitted once when the rescue ceremony completes (WorldState files friend_awake off this)
```

(b) In `_wake()`, after the `keeper.feat(&"wake_up", global_position)` line, add:

```gdscript
	Settings.roster_add(_kind)   # the rescued friend joins the roster (chips HUD); was never wired
	woke.emit()
```

(c) Add after `is_awake()`:

```gdscript
## Persistence spawn path: start this friend already rescued — no ceremony, no feat, no Shine,
## straight to FOLLOWING. Mirrors _wake()'s end state (tint, stain, zzz, roster).
func wake_instant() -> void:
	if _state != State.SLEEPING:
		return
	_state = State.FOLLOWING
	_progress = RESCUE_SECONDS
	_zzz.emitting = false
	_oil_a = 0.0
	_spr.modulate = clean_tint
	Settings.roster_add(_kind)
	queue_redraw()
```

- [ ] **Step 3: `opened` signal + `force_open()` on the portal**

In `game/cove/cove_portal.gd`:

(a) Add under `signal`-less top (after the `const` block, before `var _cfg`):

```gdscript
signal opened   # the way is clear (WorldState files portal_cleared off this)
```

(b) In `_on_open()`, after `_open = true`, add:

```gdscript
	opened.emit()
```

(c) Add after `_on_open()`:

```gdscript
## Persistence spawn path: this passage was cleared on an earlier visit — open it silently
## (no SFX, no glow tween; the state simply IS open). Frees any rubble plug.
func force_open() -> void:
	for c in get_children():
		if c is DestructibleRock:
			c.queue_free()
	if not _open:
		_open = true
		_glow = 1.0
		if _swirl:
			_swirl.emitting = true
	queue_redraw()
```

- [ ] **Step 4: Apply + wire in the composition root**

Replace `game/cove/cove.gd`'s `_ready()` and add the new functions (full file becomes):

```gdscript
extends Node2D
## Cove composition root. Owns the CoveConfig and injects it into each component in
## _ready() so children depend on the config's interface — never on each other or on
## walking the scene tree. One-way dependency: the parent hands data down.
##
## Child _ready() runs before this (bottom-up), so setup() lands after each child has
## initialised but before the first physics frame — config is always present in time.
##
## PERSISTENCE (Living Watershed slice 1): after injection the root consults WorldState —
## a restored cove spawns clean (oil gone, friend awake, portal open, leak retired); a
## partially-cleaned one re-seeds its saved cleanliness. Milestone saves are wired via
## signals (restored / opened / woke) + a cleanliness save on scene exit. An ECHO run
## (WorldState.echo, set by New Day on a restored cove) skips BOTH: fresh spill, no saves —
## the score replay leaves the world untouched (spec §7).

@export var config: CoveConfig

const IrisWipe := preload("res://game/fx/iris_wipe.gd")

var _echo := false

## Is this visit an Echo run? (High-scores board keys off this.)
func is_echo() -> bool:
	return _echo

func _ready() -> void:
	add_to_group("cove_root")
	_echo = WorldState.echo
	WorldState.echo = false          # one reload only; consuming it here makes crossings normal
	WorldState.current_id = config.id
	_inject($Axolotl)
	_inject($OilSpill)
	_inject($CoveLife)
	_inject($SeabedBackdrop)
	_inject($RestorationBanner)
	_inject($NewDay)
	_inject($CoveAudio)
	_inject($Friend)
	_inject($LeakSource)
	_inject($ShorePollution)
	_inject($Portal)
	_inject($DebrisField)
	_inject($PestField)
	if Settings.arrive_via_portal:
		Settings.arrive_via_portal = false
		_arrive()
	if not _echo:
		_apply_saved()
		_wire_saves()

## A live (not queued-for-deletion) child by name, or null. Components retire themselves in
## setup() (friend_enabled false, no exit configured...) — never poke a retiring node.
func _live(n: String) -> Node:
	var node := get_node_or_null(n)
	return node if node != null and not node.is_queued_for_deletion() else null

## Spawn-time restore from WorldState (spec §7): the world as you left it.
func _apply_saved() -> void:
	var id := config.id
	var friend := _live("Friend")
	var portal := _live("Portal")
	var oil := _live("OilSpill")
	if WorldState.is_restored(id):
		var banner := _live("RestorationBanner")
		if banner:
			banner.is_restored = true          # latch: no duplicate celebration on re-entry
		if friend and friend.has_method("wake_instant"):
			friend.wake_instant()
		if oil and oil.has_method("set_clean_fraction"):
			oil.set_clean_fraction(1.0)
		if portal and portal.has_method("force_open"):
			portal.force_open()
		var leak := _live("LeakSource")
		if leak:
			leak.queue_free()                  # a healed cove's leak stays capped
		return
	# partial progress: re-seed cleanliness + the flags that were individually earned
	if friend and friend.has_method("wake_instant") and bool(WorldState.get_cove(id, "friend_awake", false)):
		friend.wake_instant()
	if oil and oil.has_method("set_clean_fraction"):
		var f := float(WorldState.get_cove(id, "cleanliness", 0.0))
		if f > 0.02:
			oil.set_clean_fraction(f)
	if portal and portal.has_method("force_open") and bool(WorldState.get_cove(id, "portal_cleared", false)):
		portal.force_open()

## Milestone saves: each signal writes one flag the moment it's earned.
func _wire_saves() -> void:
	var id := config.id
	var banner := _live("RestorationBanner")
	if banner and banner.has_signal("restored"):
		banner.restored.connect(func() -> void: WorldState.mark(id, "restored", true))
	var portal := _live("Portal")
	if portal and portal.has_signal("opened"):
		portal.opened.connect(func() -> void: WorldState.mark(id, "portal_cleared", true))
	var friend := _live("Friend")
	if friend and friend.has_signal("woke"):
		friend.woke.connect(func() -> void: WorldState.mark(id, "friend_awake", true))

## Scene exit (portal cross, New Day, quit): file the scrub progress of an unfinished cove.
func _exit_tree() -> void:
	if _echo:
		return
	if WorldState.is_restored(config.id):
		return
	var oil := get_node_or_null("OilSpill")
	if oil and "current_clean" in oil:
		WorldState.mark(config.id, "cleanliness", oil.current_clean)

## A tunnel crossing brought us here: the axolotl emerges at THIS cove's passage mouth (the left
## edge of the water — you exited the last cove travelling right), already swimming, behind an
## opening iris — the two coves read as one continuous passage.
func _arrive() -> void:
	var axo := $Axolotl as CharacterBody2D
	axo.position = Vector2(config.water_left + 34.0, config.surface_y + 46.0)
	var speed: float = axo.tuning.run_speed if axo.tuning else 150.0
	axo.velocity = Vector2(speed, 0.0)      # still swimming out of the tunnel
	var wipe := IrisWipe.new()
	add_child(wipe)
	wipe.set_closed()
	wipe.open(0.7)

func _inject(n: Node) -> void:
	# has_method guard keeps the scene runnable while components are migrated one at a time
	if n and n.has_method("setup"):
		n.setup(config)
```

- [ ] **Step 5: Parse gate + manual verification**

Run the import scan (no errors). Then run the game in the editor and verify the loop **manually**:
1. Fresh run: hub behaves exactly as before (no save file influence).
2. Rescue the turtle → quit the game entirely → relaunch → the turtle is already awake and following; the partner chip shows.
3. Scrub ~half the oil → quit → relaunch → the meter resumes near where you left it (uniform re-seed, not the exact pixels — expected).
4. Fully restore + open the portal → quit → relaunch → cove spawns clean, portal open, no celebration replay, leak gone.
5. Cross to the estuary and back → the hub is still restored.

- [ ] **Step 6: Commit**

```powershell
cd $proj
git add game/cove/oil_spill.gd game/companion/companion.gd game/cove/cove_portal.gd game/cove/cove.gd
git commit -m "feat: coves persist via WorldState (apply on spawn, milestone saves, exit save)"
```

---

### Task 3: Echo runs — score replays that leave the world untouched

**Files:**
- Modify: `game/hud/new_day.gd:36-44` (the `_restarting` branch)
- Modify: `game/hud/high_scores.gd:19-33,39-45` (re-enable, echo-gated)

**Interfaces:**
- Consumes: `WorldState.echo/current_id/is_restored` (Task 1); cove root group `"cove_root"` + `is_echo()` (Task 2).
- Produces: New Day on a restored cove = Echo run; Tide Board shows only on Echo-run wins.

- [ ] **Step 1: New Day sets the echo flag on restored coves**

In `game/hud/new_day.gd`, inside `_process`, the `_restarting` branch currently ends:

```gdscript
		if _black >= 1.0:
			set_process(false)  # one reload only; this node dies with the old scene
			Settings.run_score = 0.0   # New Day = a fresh run; don't carry the old Shine total
			Settings.roster_reset()    # ...and the friends return to their corners to be met again
			get_tree().reload_current_scene()
```

Replace with:

```gdscript
		if _black >= 1.0:
			set_process(false)  # one reload only; this node dies with the old scene
			Settings.run_score = 0.0   # New Day = a fresh run; don't carry the old Shine total
			Settings.roster_reset()    # ...and the friends return to their corners to be met again
			# On a RESTORED cove, a new day is an ECHO RUN: replay the restoration for score while
			# the persistent world stays healed (spec §7 — the arcade layer's home). On an
			# unfinished cove it keeps meaning "restart the attempt".
			WorldState.echo = WorldState.is_restored(WorldState.current_id)
			get_tree().reload_current_scene()
```

- [ ] **Step 2: Re-enable the Tide Board, gated on Echo runs**

In `game/hud/high_scores.gd`, `_ready()` currently ends with the disabled wire:

```gdscript
	# TIDE BOARD DISABLED FOR NOW (Maram, 2026-07-05): the initials modal blocks progress on restoration
	# — you finish the cove and want to head to the estuary, not get trapped in a leaderboard prompt. The
	# node stays here inert (nothing connects it to the win) so it's a one-line re-enable later. To bring
	# it back, uncomment `_wire.call_deferred()` and route it somewhere non-blocking (e.g. a menu button).
	#_wire.call_deferred()
```

Replace those five lines with:

```gdscript
	# The Tide Board interrupts ECHO RUNS ONLY (spec §7): a score replay of an already-restored
	# cove ends in the initials card, while a FIRST restoration stays unblocked — you finish the
	# cove and head for the estuary, not a leaderboard prompt (Maram, 2026-07-05).
	_wire.call_deferred()
```

And in `_on_restored()`, insert at the very top (before `if _shown:`):

```gdscript
	var root := get_tree().get_first_node_in_group("cove_root")
	if root == null or not root.has_method("is_echo") or not root.is_echo():
		return   # first restorations celebrate without a modal; only Echo replays score-chase
```

- [ ] **Step 3: Parse gate + manual verification**

Import scan (no errors), then in the editor:
1. Restore the hub fully (or use the save from Task 2's test) → hold R → **Echo run**: fresh spill, feats/Shine live.
2. Finish the Echo run → the **Tide Board appears** (initials card) — submit or skip.
3. Quit + relaunch → hub is **still restored** (echo suppressed all saves).
4. On an *unrestored* cove, hold R → plain restart, no Tide Board on the eventual win.

- [ ] **Step 4: Commit**

```powershell
cd $proj
git add game/hud/new_day.gd game/hud/high_scores.gd
git commit -m "feat: Echo runs — New Day on a restored cove replays for score, world untouched"
```

---

### Task 4: Frog surface pivot + integer scale

**Files:**
- Modify: `game/companion/companion.gd` (follow target clamp)
- Modify: `game/cove/estuary_a.tres` (`friend_scale`)
- Modify: `game/companion/companion_library.gd:15-19` (frog `scale`)

**Interfaces:**
- Consumes: `CoveConfig.surface_y`, `Kind.FROG` (existing).
- Produces: nothing new — behavioral change only.

- [ ] **Step 1: Clamp the frog to the surface**

In `game/companion/companion.gd`, in `_process`'s follow block, right after:

```gdscript
	var target := (get_parent() as Node2D).to_local(axo.global_position) + Vector2(0.0, lift)
```

add:

```gdscript
	if _kind == Kind.FROG:
		# the frog is a SURFACE-AND-LAND creature (spec §9): it rides the waterline and hops the
		# banks/lilypads — never dives. Clamping the follow target here retires the deep-water
		# swim jank at the source; the axolotl remains free to dip under alone.
		target.y = minf(target.y, _cfg.surface_y - 2.0)
```

- [ ] **Step 2: Integer scale**

In `game/cove/estuary_a.tres`, change:

```ini
friend_scale = 0.85
```
to:
```ini
friend_scale = 1.0
```

In `game/companion/companion_library.gd`, in the `ART` dictionary's frog entry, change `"scale": 0.85,` to:

```gdscript
		"scale": 1.0,   # no runtime fractional scaling of pixel art (spec §9); resize in ART if too big
```

- [ ] **Step 3: Parse gate + manual verification**

Import scan, then in the editor: enter the estuary, rescue the frog, swim deep — the frog stays riding the waterline (hopping/kicking along the surface), crisp with square pixels. If it visually reads too large beside the 40px turtle, note it for an art-level resize — do NOT reintroduce fractional scale.

- [ ] **Step 4: Commit**

```powershell
cd $proj
git add game/companion/companion.gd game/cove/estuary_a.tres game/companion/companion_library.gd
git commit -m "feat: frog rides the surface (never dives) + integer pixel scale"
```

---

### Task 5: Mud-turtle restyle (ecology pillar-blocker)

The shipped green/red slider **is an invasive species in Mexico** (spec §4.1). Recolor the strips in place — `turtle_frames.tres` references the same PNGs, so no resource changes.

**Files:**
- Create: `tools/restyle_mud_turtle.py`
- Modify (binary, in place): `assets/critters/turtle/turtle_*.png`

**Interfaces:** none (art-only).

- [ ] **Step 1: Verify Python + PIL**

```powershell
python -c "import PIL; print(PIL.__version__)"
```
Expected: a version prints. If not: `pip install pillow`.

- [ ] **Step 2: Write the restyle script**

Create `tools/restyle_mud_turtle.py`:

```python
"""Restyle the SeethingSwarm turtle into a Mexican mud turtle (Kinosternon integrum).

The shipped green/red-striped slider is itself an INVASIVE species in Mexico — the ally must
not be an invader (Living Watershed spec §4.1, pillar-blocker). Hue-window remap:
  greens (H 60-180, saturated)  -> drab olive-umber shell/skin, darker
  red/orange ear stripe (H<=25 or >=340, high sat) -> dark mud skin
Outline, alpha, and everything else untouched. Runs in place over assets/critters/turtle.
Run once from the repo root:  python tools/restyle_mud_turtle.py
(Git is the undo button: `git checkout -- assets/critters/turtle` restores the slider.)
"""
import colorsys
import pathlib

from PIL import Image

DIR = pathlib.Path(__file__).resolve().parent.parent / "assets" / "critters" / "turtle"


def remap(r: int, g: int, b: int) -> tuple[int, int, int]:
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    deg = h * 360
    if 60 <= deg <= 180 and s > 0.18:            # greens -> olive-umber, drabber + darker
        h, s, v = 40 / 360, min(1.0, s * 0.75), v * 0.82
    elif (deg <= 25 or deg >= 340) and s > 0.45:  # red ear stripe -> dark mud skin
        h, s, v = 30 / 360, s * 0.5, v * 0.55
    r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
    return int(r2 * 255), int(g2 * 255), int(b2 * 255)


def main() -> None:
    pngs = sorted(DIR.glob("turtle_*.png"))
    assert pngs, f"no turtle strips found in {DIR}"
    for png in pngs:
        img = Image.open(png).convert("RGBA")
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                px[x, y] = (*remap(r, g, b), a)
        img.save(png)
        print("restyled", png.name)


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Run it**

```powershell
cd $proj
python tools/restyle_mud_turtle.py
```
Expected: one `restyled turtle_*.png` line per strip (~16 files).

- [ ] **Step 4: Re-import + visual verification**

Run the import scan (re-imports the changed PNGs; no errors expected). Open the editor and eyeball `assets/critters/turtle/turtle_idle_strip*.png` (or run the game): the turtle should read as a **dark, drab olive-brown mud turtle** — no green shell, no red ear stripe, outline crisp. If the hue windows missed pixels (stray green specks), widen the green window to `50 <= deg <= 190` and re-run **on a fresh checkout** (`git checkout -- assets/critters/turtle` first — the remap is not idempotent for re-widened windows).

- [ ] **Step 5: Commit**

```powershell
cd $proj
git add tools/restyle_mud_turtle.py assets/critters/turtle
git commit -m "feat: mud-turtle restyle — the ally is no longer an invasive slider (ecology pillar)"
```

---

### Task 6: Marsh geometry + environment tints (the estuary stops being a green-washed cove)

**Files:**
- Modify: `game/cove/cove_config.gd` (environment exports)
- Modify: `game/cove/cove.gd` (`_apply_environment`)
- Modify: `game/cove/estuary_a.tres` (geometry + tints)
- Modify: `estuary.tscn` (mud bed body + softer wash)

**Interfaces:**
- Consumes: cove root `_ready` (Task 2 shape).
- Produces: `CoveConfig.env_water_tint/env_land_tint: Color` (alpha 0 = unset), consumed only by the root.

- [ ] **Step 1: Environment exports on the config**

In `game/cove/cove_config.gd`, after the `@export_group("Ecosystem")` block's last member (`friend_scale`), add:

```gdscript
@export_group("Environment")
## Optional per-cove looks, applied by the composition root (alpha 0 = unset, keep defaults).
## Water tint multiplies the water sprite's shader output (green-tea marsh water); land tint
## the block-land soil. Real per-cove identity instead of a whole-scene CanvasModulate wash.
@export var env_water_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var env_land_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
```

- [ ] **Step 2: Root applies the environment**

In `game/cove/cove.gd` `_ready()`, insert immediately after the last `_inject(...)` line (before the `arrive_via_portal` check):

```gdscript
	_apply_environment()
```

and add the function after `_inject`:

```gdscript
## Per-cove environment overrides (spec §9): tints applied to the shared kit's surfaces so the
## marsh reads green-tea and muddy without forking the scene. Alpha 0 = keep defaults.
func _apply_environment() -> void:
	if config.env_water_tint.a > 0.0:
		var water := get_node_or_null("Water") as Sprite2D
		if water:
			water.self_modulate = config.env_water_tint
	if config.env_land_tint.a > 0.0:
		for n in ["BlockLand", "BlockLandRight"]:
			var land := get_node_or_null(n)
			if land:
				(land as Node2D).modulate = config.env_land_tint
```

- [ ] **Step 3: Marsh numbers**

In `game/cove/estuary_a.tres`, change/add these values (keep everything else):

```ini
seabed_y = 96.0
kelp_count = 2
env_water_tint = Color(0.72, 0.9, 0.68, 1)
env_land_tint = Color(0.88, 0.84, 0.66, 1)
```

(`seabed_y` 166 → 96: the marsh water column is ~120px instead of ~190 — kelp bases, fish, and companions all read the new shallow floor from config.)

- [ ] **Step 4: The physical mud bed (real shallowness) + softer wash**

The scene collision floor is authored in the shared `cove.tscn` (Seabed at cove-local y≈166) — the estuary needs its own raised bed. `estuary.tscn` wraps the cove instance at `position = Vector2(402, 28)`, so cove-local (x, y) = estuary-local (x+402, y+28). Cove-local water spans x −142..377; the mud bed tops at seabed_y 96 → estuary-local: x 260..779, top y 124, down to the old floor at y 269.

In `estuary.tscn`, add after the `[node name="Cove" ...]` block:

```ini
[node name="MudBed" type="StaticBody2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="MudBed"]
position = Vector2(519.5, 196.5)
shape = SubResource("RectangleShape2D_mud")

[node name="Polygon2D" type="Polygon2D" parent="MudBed"]
z_index = 2
color = Color(0.23, 0.19, 0.14, 1)
polygon = PackedVector2Array(260, 124, 779, 124, 779, 269, 260, 269)
```

and add the sub_resource above the node blocks (after the `ext_resource` lines):

```ini
[sub_resource type="RectangleShape2D" id="RectangleShape2D_mud"]
size = Vector2(519, 145)
```

Also soften the whole-scene wash now that the water carries the green — change the existing `Tint` node's color:

```ini
color = Color(0.9, 0.97, 0.88, 1)
```

- [ ] **Step 5: Parse gate + manual verification**

Import scan, then run: the estuary should read **shallow** (you touch mud bottom quickly), water green-tea, soil sandier, hub completely unchanged (alpha-0 sentinels). Cross hub → estuary through the tunnel to confirm arrival still works over the raised bed (arrival y = surface+46 = cove-local 19, well above the 96 bed ✓).

- [ ] **Step 6: Commit**

```powershell
cd $proj
git add game/cove/cove_config.gd game/cove/cove.gd game/cove/estuary_a.tres estuary.tscn
git commit -m "feat: marsh estuary — shallow mud bed, green-tea water, per-cove environment tints"
```

---

### Task 7: Lilypads + reeds (marsh set-dressing, frog perches)

**Files:**
- Create: `game/cove/lily_pads.gd`, `game/cove/reeds.gd`
- Modify: `game/cove/cove_config.gd` (counts), `game/cove/cove.tscn` (nodes), `game/cove/cove.gd` (inject), `game/cove/estuary_a.tres` (counts)

**Interfaces:**
- Consumes: `CoveConfig` (`water_left/right`, `surface_y`, `seabed_y`, new counts), root `_inject`.
- Produces: `CoveConfig.lilypad_count/reed_count: int` (0 = component retires — hub default).

- [ ] **Step 1: Config counts**

In `game/cove/cove_config.gd`, inside `@export_group("Ecosystem")` after `pest_count`, add:

```gdscript
## Marsh set-dressing: lilypads riding the waterline (frog perches) and cattail reeds rooted in
## the shallows near each bank. 0 = none (the component retires) — the hub default.
@export var lilypad_count: int = 0
@export var reed_count: int = 0
```

- [ ] **Step 2: The lilypads component**

Create `game/cove/lily_pads.gd`:

```gdscript
extends Node2D
## Lilypads riding the waterline — marsh dressing and the frog's hop points (group "perch",
## reserved for future perch logic). Self-contained in the cove idiom: injected config, drawn
## pads (Apollo greens) bobbing gently on the surface. Zero pads = retire.

var _cfg: CoveConfig
var _pads: Array = []   # [x, radius, phase] per pad
var _t := 0.0

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.lilypad_count <= 0:
		queue_free()
		return
	add_to_group("perch")
	z_index = 6                       # on the water surface (water 5), under FX (7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7                      # stable layout per cove — pads don't reshuffle each visit
	for i in cfg.lilypad_count:
		var frac := (float(i) + 0.5) / float(cfg.lilypad_count)
		_pads.append([
			lerpf(cfg.water_left + 30.0, cfg.water_right - 40.0, frac) + rng.randf_range(-14.0, 14.0),
			rng.randf_range(7.0, 12.0),
			rng.randf_range(0.0, TAU),
		])

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()                    # a few pads bobbing — a per-frame redraw is cheap

func _draw() -> void:
	if _cfg == null:
		return
	for p in _pads:
		var c := Vector2(p[0], _cfg.surface_y - 1.0 + sin(_t * 1.3 + p[2]) * 1.5)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.45))   # circles -> floating oval pads
		draw_circle(Vector2.ZERO, p[1], Palette.MOSS)
		draw_circle(Vector2.ZERO, p[1] - 2.0, Palette.GREEN)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# the classic notch: a seam from centre to rim
		draw_line(c, c + Vector2(p[1] * 0.9, -p[1] * 0.28), Palette.MOSS, 2.0)
```

- [ ] **Step 3: The reeds component**

Create `game/cove/reeds.gd`:

```gdscript
extends Node2D
## Cattail reeds rooted in the shallows near each bank — tall two-tone blades breaking the
## surface, brown seed heads on some, all swaying in a field-wide wind wave (the GrassLayer
## idiom: throttled redraw, a few dozen polygons). Zero reeds = retire.

const REDRAW_HZ := 15.0

var _cfg: CoveConfig
var _reeds: Array = []   # [x, height, phase, has_head] per reed
var _t := 0.0
var _acc := 0.0

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.reed_count <= 0:
		queue_free()
		return
	z_index = 4                       # behind the water surface tint (5): reeds read IN the water
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in cfg.reed_count:
		# root alternately near the left and right water edges (the marsh margins)
		var left := i % 2 == 0
		var x := rng.randf_range(cfg.water_left + 6.0, cfg.water_left + 76.0) if left \
			else rng.randf_range(cfg.water_right - 76.0, cfg.water_right - 6.0)
		_reeds.append([x, rng.randf_range(95.0, 145.0), rng.randf_range(0.0, TAU), rng.randf() < 0.55])

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 1.0 / REDRAW_HZ:
		_acc = 0.0
		queue_redraw()

func _draw() -> void:
	if _cfg == null:
		return
	for r in _reeds:
		var base := Vector2(r[0], _cfg.seabed_y)
		var sway: float = sin(_t * 1.4 + r[2] + r[0] * 0.08) * 3.5
		var tip := base + Vector2(sway, -r[1])
		# tapered two-tone blade (rooted wide in the mud, bright at the tip)
		draw_polygon(
			PackedVector2Array([base + Vector2(-2.2, 0.0), base + Vector2(2.2, 0.0), tip]),
			PackedColorArray([Palette.MOSS, Palette.MOSS, Palette.LEAF]))
		if r[3]:
			# the cattail seed head: a fat brown capsule just below the tip
			draw_line(tip + Vector2(0.0, 10.0), tip + Vector2(0.0, 22.0), Palette.LOAM, 4.5)
```

- [ ] **Step 4: Wire into the scene + root + config**

In `game/cove/cove.tscn`, add to the `ext_resource` block (after `38_ground`):

```ini
[ext_resource type="Script" path="res://game/cove/lily_pads.gd" id="39_lily"]
[ext_resource type="Script" path="res://game/cove/reeds.gd" id="40_reeds"]
```

and after the `GroundFill` node block:

```ini
[node name="LilyPads" type="Node2D" parent="."]
script = ExtResource("39_lily")

[node name="Reeds" type="Node2D" parent="."]
script = ExtResource("40_reeds")
```

In `game/cove/cove.gd` `_ready()`, add after `_inject($PestField)`:

```gdscript
	_inject($LilyPads)
	_inject($Reeds)
```

In `game/cove/estuary_a.tres`, add:

```ini
lilypad_count = 7
reed_count = 26
```

- [ ] **Step 5: Parse gate + manual verification**

Import scan, then run: hub unchanged (components retire at count 0); estuary shows bobbing pads on the waterline and swaying cattails at both margins, on-palette. The frog (surface-clamped from Task 4) reads as living among the pads.

- [ ] **Step 6: Commit**

```powershell
cd $proj
git add game/cove/lily_pads.gd game/cove/reeds.gd game/cove/cove_config.gd game/cove/cove.tscn game/cove/cove.gd game/cove/estuary_a.tres
git commit -m "feat: marsh set-dressing — lilypads on the waterline, cattail reeds at the margins"
```

---

### Task 8: Full verification + deploy

**Files:** none new (verification + release).

- [ ] **Step 1: Run the automated suite**

```powershell
& $godot --headless --path $proj --script res://tests/test_world_state.gd 2>&1 | Select-Object -Last 12
```
Expected: `RESULT: ALL PASS`.

- [ ] **Step 2: Full manual checklist (editor or deployed build)**

1. **Fresh profile** (delete `%APPDATA%\Godot\app_userdata\<project>\world.save` if present): game behaves exactly as before persistence.
2. **Persistence round-trip:** rescue turtle + scrub half → quit → relaunch → both remembered.
3. **Restored spawn:** fully restore hub → relaunch → clean cove, turtle following, portal open, leak gone, no celebration replay.
4. **Cross-scene:** hub → estuary → back: hub still restored; estuary progress files under its own id.
5. **Echo run:** New Day on restored hub → fresh spill, score run, Tide Board on the win, world untouched after.
6. **Frog:** surface-riding, never dives, square pixels.
7. **Marsh:** shallow mud bed, green-tea water, pads + reeds; hub visually unchanged.
8. **Turtle:** reads as a dark olive-brown mud turtle everywhere (idle, swim, shell-spin).

- [ ] **Step 3: Export + deploy**

```powershell
& $godot --headless --path $proj --export-release "Web" 2>&1 | Select-String -Pattern "\[ DONE \]" | Select-Object -Last 1
vercel deploy "$proj\build\lilaxol" --prod --scope marios-projects-481b4b4e --yes 2>&1 | Select-String -Pattern "Aliased|readyState|Error" | Select-Object -Last 3
```
Expected: `[ DONE ] savepack`, `readyState: READY`, aliased to lilaxol.vercel.app. **Web save note:** `user://` persists via IndexedDB — verify checklist item 2 once on the deployed build too.

- [ ] **Step 4: Final commit + push**

```powershell
cd $proj
git add -A
git commit -m "chore: slice 1 verification pass" --allow-empty
git push
```

---

## Deliberate Slice-1 scope cuts (do NOT "fix" these)

- **Leak-cap state is per-visit on unfinished coves** — an uncapped leak returns on reload until
  the cove is fully restored (restored spawns retire the leak). Persisting the mid-run cap joins
  the Slice 2 variable engine, where leaks become Toxicity sources anyway.
- **Vents + land nooks are per-visit** — they re-seal on every load, restored or not. Full per-vent persistence arrives with the Slice 2 variable engine; a restored cove's banner already fired, so the win never re-gates on them.
- **Cleanliness re-seeds uniformly**, not pixel-exact — the mask bitmap is deliberately not saved (spec §7 v1).
- **The frog hop-animates across the water surface** (its walk clip = hop) rather than surface-kicking — reads as lilypad-hopping; revisit only if it looks wrong in play.
- **No "ECHO" HUD tell** during Echo runs — polish later if replays confuse.
