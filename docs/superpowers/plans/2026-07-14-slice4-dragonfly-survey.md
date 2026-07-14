# Slice 4: The Dragonfly — Survey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The dragonfly's SURVEY verb — a press-fired sweep that reveals the reach's hidden wounds
and secrets for a few seconds and finishes hovering over the worst-oxygen spot — built on a real
active-partner gate so the shared partner-action button answers only whoever is actually
travelling with you (the Kirby rule).

**Architecture:** T1 retrofits `Settings.run_active == kind` onto `companion.gd`'s single shared
input poll (today only the turtle's shell listens, ungated) via one pure static gate function
(`verb_for`), then adds a small non-interactive sweep state machine to the same script — the
dragonfly flies herself. T2 is a group contract: `get_tree().call_group("surveyable", "reveal",
6.0)` fans out to five existing components, each restoring its own captured prior state (never a
hardcoded baseline — legacy rocks and painted map seals sit at different z). T3 wires the scout's
retirement, a new Field Guide encounter card, and a one-time `first_survey` feat onto the existing
signal/WorldState idioms. T4 (reach 2 content) is blocked on Maram's map and is a sketch only.

**Tech Stack:** Godot 4.7 GDScript (TABS, `##` doc comments), headless `--script` tests following
`tests/test_reach_map.gd`'s `_process()`-deferred-load idiom, GL Compatibility / web no-threads
export.

**Spec:** `docs/superpowers/specs/2026-07-14-slice4-dragonfly-survey.md` (v2, design-reviewed — its
REVIEW AMENDMENT blocks are binding and are called out by name at each task they land in).

## Global Constraints

- **D-0003** (swim tuning + state machine): untouched. This plan never edits `game/axolotl/axolotl.gd`.
- **Cozy contract:** reveals light things up in-world, then fade — never a quest arrow, never a map
  pin. Nothing is killed, capped, or unlocked by a reveal; Survey is knowledge, not force.
- **WebGL perf:** every reveal is duration-bounded at **6 seconds** (`SURVEY_REVEAL_SECONDS`); no
  component adds a per-frame full-scene redraw — reused/boosted existing throttled redraw loops
  only (curio's 8Hz `REDRAW_HZ`, the rock's scar-fade 20Hz cadence, PartnerHud's new 4Hz poll).
- **GDScript style:** tabs, `##` doc comments, preload/load (not `class_name`) for scripts that
  don't already declare one — `companion.gd` has none today and this plan doesn't add one.
- **Apollo palette only** — named `Palette.*` swatches, never color literals, in any new drawing code.
- **Test harness idiom (mandatory for every new suite in this plan):** any headless `--script`
  target that itself references an autoload identifier (`Settings`, `WorldState`, `Sfx`) — or
  `load()`s a production script that does — must run its ENTIRE body from `_process()` (one-shot,
  `return true` after the first call) and hold zero literal autoload-identifier text at its own
  top level; anything that needs one is routed through a tiny helper script, itself only `load()`'d
  (never top-level `preload()`'d) from inside that first `_process()`. This is
  `tests/test_reach_map.gd`'s documented rule (its own header comment), verified true because
  `companion.gd`, `destructible_rock.gd`, `leak_source.gd`, `debris_field.gd`,
  `invasive_school.gd`, and `scout_dragonfly.gd` all reference `Settings`/`Sfx`/`WorldState`
  directly — every new test file in this plan follows it.
- Godot CLI: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`.
  Project: `c:\Users\maram\Dev\GODOT PROJECTS\LilAxol`.
- **Parse gate after every task:**
  ```powershell
  $godot = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
  $proj  = "C:\Users\maram\Dev\GODOT PROJECTS\LilAxol"
  & $godot --headless --path $proj --import 2>&1 |
    Select-String -Pattern "SCRIPT ERROR|Parse Error|Compile error" -CaseSensitive:$false
  ```
  Zero matches required.
- **All suites stay green every task** (counts verified by actually running them, 2026-07-13):
  `tests/test_world_state.gd` (17), `tests/test_reach_state.gd` (12), `tests/test_reach_field.gd`
  (15), `tests/test_reach_map.gd` (62), `tests/test_oil_roundtrip.gd` (10),
  `tests/test_shine_milestones.gd` (14) — each run via
  `& $godot --headless --path $proj --script tests/<name>.gd` and must print `RESULT: ALL PASS`.
  New suites created by this plan join the list from the task that creates them onward.
- **Three scene boots per task** (editor run or `godot --path . <scene>.tscn`, feel-check, no
  crash): `main.tscn` (hub), `estuary.tscn`, `canals.tscn` (the current `run/main_scene`).
- **No exports, no deploys, no commits beyond what each task's own step lists** — this is an
  implementation plan; a human/controller reviews between tasks (this plan itself was written
  read-mostly and does not commit anything).

---

### Task 1: Active-partner gating + Survey core

**Files:**
- Modify: `game/companion/companion.gd` (gate, Survey state machine, HUD read)
- Modify: `game/hud/partner_hud.gd` (Chip cooldown ring, throttled 4Hz)
- Create: `tests/settings_roster_helper.gd`
- Create: `tests/test_companion_survey.gd`

**Interfaces:**
- Consumes: `Settings.run_active` / `run_roster` / `roster_add` / `roster_reset` (existing,
  `game/hud/settings_store.gd`); group `"grabbable"` members' `global_position` (existing,
  `floating_debris.gd` / `pest_fly.gd`).
- Produces (consumed by Task 2 and Task 3):
  - `companion.gd` top-level consts `VERB_NONE := 0`, `VERB_SHELL := 1`, `VERB_SURVEY := 2`
    (plain consts, not an enum — no existing code in this repo accesses a nested enum through a
    `load()`/`preload()`'d script reference; `ReachField.WATER`-style flat consts are the proven
    pattern, confirmed via `tests/test_reach_map.gd`'s own `ReachFieldScript.WATER` usage).
  - `static func verb_for(kind: int, active_kind: int) -> int`
  - `static func cooldown_tick(cd: float, delta: float) -> float`
  - `static func survey_charge_frac(cd: float) -> float` (0 = just fired, 1 = ready)
  - `static func densest_point(points: Array, radius: float) -> Vector2` (`Vector2.INF` = no points)
  - `const SURVEY_COOLDOWN := 10.0`, `const SURVEY_DENSITY_RADIUS := 90.0`
  - instance methods `func kind() -> int` and `func survey_hud_charge() -> float` (Task 3 and the
    PartnerHud read these; -1.0 = "no cooldown to show right now")
  - group `"surveyable"` group-call target: `get_tree().call_group("surveyable", "reveal", 6.0)`
    fired once per completed sweep (Task 2's components join this group).

- [ ] **Step 1: Create the Settings test helper**

`tests/settings_roster_helper.gd`:

```gdscript
extends RefCounted
## Tiny indirection so tests/test_companion_survey.gd — the direct `--script` target, which under
## `--headless --script` is parsed by Godot BEFORE SceneTree.initialize() registers autoloads as
## GDScript globals — never carries a literal `Settings` identifier in its own source. Mirrors
## tests/reach_map_worldstate_helper.gd's rationale exactly, aimed at the Settings autoload
## instead of WorldState. Loaded lazily via load() from inside the test's first _process().

static func reset() -> void:
	Settings.roster_reset()

static func add(kind: int) -> void:
	Settings.roster_add(kind)

static func active() -> int:
	return Settings.run_active
```

- [ ] **Step 2: Write the failing test** — `tests/test_companion_survey.gd`:

```gdscript
extends SceneTree
## Headless tests for the Survey verb core (slice 4 T1): active-partner gating (the Kirby rule,
## spec REVIEW AMENDMENT Critical), the Survey cooldown machine, and the worst-oxygen density pick
## (spec REVIEW AMENDMENT Important) — all pure static functions on companion.gd, so no Input
## simulation is needed. Kind values are plain ints (0 Turtle / 1 Frog / 2 Otter / 3 Dragonfly,
## companion.gd's own enum order) written as literals here, matching companion_library.gd's
## established convention of never reaching into companion.gd's enum from outside it.
## Run: & $godot --headless --path $proj --script tests/test_companion_survey.gd
var fails := 0
var _done := false
func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok: fails += 1
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var Companion = load("res://game/companion/companion.gd")
	var Roster = load("res://tests/settings_roster_helper.gd")
	const TURTLE := 0
	const DRAGONFLY := 3
	const FROG := 1
	const OTTER := 2

	# --- gating truth table (spec REVIEW AMENDMENT, Critical) ---
	_check("turtle active -> shell", Companion.verb_for(TURTLE, TURTLE) == Companion.VERB_SHELL)
	_check("turtle active -> not survey", Companion.verb_for(TURTLE, TURTLE) != Companion.VERB_SURVEY)
	_check("dragonfly active -> survey", Companion.verb_for(DRAGONFLY, DRAGONFLY) == Companion.VERB_SURVEY)
	_check("dragonfly active -> not shell", Companion.verb_for(DRAGONFLY, DRAGONFLY) != Companion.VERB_SHELL)
	_check("turtle rescued but NOT active -> neither verb fires", Companion.verb_for(TURTLE, DRAGONFLY) == Companion.VERB_NONE)
	_check("dragonfly rescued but NOT active -> neither verb fires", Companion.verb_for(DRAGONFLY, TURTLE) == Companion.VERB_NONE)
	_check("frog has no button verb (registered, tongue is automatic)", Companion.verb_for(FROG, FROG) == Companion.VERB_NONE)
	_check("otter has no button verb yet (registered, lands slice 6)", Companion.verb_for(OTTER, OTTER) == Companion.VERB_NONE)

	# --- a solo-turtle roster always has the turtle active (legacy zero-behavior-change proof —
	# the real Settings autoload, not a stub, so this proves the actual roster_add() contract) ---
	Roster.reset()
	Roster.add(TURTLE)
	_check("solo-turtle roster: run_active == TURTLE", Roster.active() == TURTLE)
	_check("...and verb_for reads SHELL for it, exactly the legacy trigger", Companion.verb_for(TURTLE, Roster.active()) == Companion.VERB_SHELL)
	Roster.reset()

	# --- cooldown machine ---
	_check("SURVEY_COOLDOWN is 10s (spec)", is_equal_approx(Companion.SURVEY_COOLDOWN, 10.0))
	var cd: float = Companion.SURVEY_COOLDOWN
	for i in 100:
		cd = Companion.cooldown_tick(cd, Companion.SURVEY_COOLDOWN / 100.0)
	_check("cooldown drains to zero over its full duration", absf(cd) < 0.01)
	_check("cooldown never goes negative", Companion.cooldown_tick(0.0, 5.0) == 0.0)
	_check("charge frac at full cooldown == 0 (just fired)", absf(Companion.survey_charge_frac(Companion.SURVEY_COOLDOWN) - 0.0) < 0.01)
	_check("charge frac at zero cooldown == 1 (ready)", absf(Companion.survey_charge_frac(0.0) - 1.0) < 0.01)
	_check("charge frac at half cooldown == 0.5", absf(Companion.survey_charge_frac(Companion.SURVEY_COOLDOWN * 0.5) - 0.5) < 0.01)

	# --- worst-oxygen density pick (synthetic points, spec REVIEW AMENDMENT Important) ---
	var cluster: Array = [Vector2(0, 0), Vector2(10, 0), Vector2(0, 10), Vector2(400, 400)]
	var pick: Vector2 = Companion.densest_point(cluster, Companion.SURVEY_DENSITY_RADIUS)
	_check("density pick lands in the dense cluster, not the lone outlier", pick.distance_to(Vector2(0, 0)) < 50.0)
	_check("density pick on an empty set returns the INF sentinel", Companion.densest_point([], 90.0) == Vector2.INF)
	var uniform: Array = [Vector2(0, 0), Vector2(500, 0), Vector2(1000, 0)]   # no cluster: every point ties at n=1
	var upick: Vector2 = Companion.densest_point(uniform, 90.0)
	_check("density pick on a uniform field still returns a real member point", uniform.has(upick))

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
	return true
```

- [ ] **Step 3: Run to verify it fails**

`& $godot --headless --path $proj --script tests/test_companion_survey.gd` → expect a script/parse
error (`verb_for`/`VERB_SHELL`/etc. don't exist on `companion.gd` yet).

- [ ] **Step 4: Implement the gate + Survey state machine in `companion.gd`**

Insert a new consts/enum block right after the existing frog-hop consts (after line 63, before
`enum State { SLEEPING, WAKING, FOLLOWING }` at line 65):

```gdscript
# --- the shared partner-action button, keyed by who's ACTIVE (spec REVIEW AMENDMENT, Critical —
# the Kirby rule: one button, verbs keyed by who travels with you). Plain consts, not an enum: no
# code in this repo reaches a nested enum through a load()/preload()'d script reference — flat
# consts (ReachField.WATER's own pattern) are the proven, tested idiom. ---
const VERB_NONE := 0
const VERB_SHELL := 1
const VERB_SURVEY := 2

# --- SURVEY (dragonfly, non-interactive — she flies herself): press → ~1.8s spiral-out sweep →
# a 6s world-wide REVEAL → an optional ~2.5s hover over the reach's worst-oxygen point → back to
# following. Cooldown ~10s, shown on the PartnerHud portrait. ---
const SURVEY_SWEEP_TIME := 1.8         # spiral-out duration (the scout's flight language reused)
const SURVEY_SWEEP_RADIUS := 180.0     # how far out the spiral reaches
const SURVEY_REVEAL_SECONDS := 6.0     # group "surveyable" reveal window
const SURVEY_COOLDOWN := 10.0          # between presses
const SURVEY_FINISH_FLY := 0.6         # short hop to the worst-oxygen point after the sweep
const SURVEY_FINISH_HOVER := 2.5       # she hovers there before handing back to following
const SURVEY_DENSITY_RADIUS := 90.0    # neighborhood radius for the worst-oxygen density pick
```

Insert a new `SurveyPhase` enum next to the existing `Kind` enum (after line 68's `Kind` block, no
blank-line change needed — just append below it):

```gdscript
enum SurveyPhase { NONE, SWEEP, FINISH }   # the dragonfly's non-interactive sweep state machine
```

Add new member vars in the "shell-spin state" block area — append after line 107 (`var _flash :=
0.0`):

```gdscript
# survey state (dragonfly)
var _survey_phase := SurveyPhase.NONE
var _survey_t := 0.0
var _survey_cd := 0.0
var _survey_origin := Vector2.ZERO
var _survey_finish_start := Vector2.ZERO
var _survey_finish_pos := Vector2.ZERO
var _survey_has_finish := false
var _shell_was_held := false           # edge-detect for Survey's press-fire (shares _shell_held())
```

Old (`_process`, lines 239-250):

```gdscript
	if _piloting:
		_run_pilot(delta)                 # shell-spin demolition (the frog isn't piloted)
		return
	# recharge the shell between spins; tick down any dizzy lock
	_dizzy_t = maxf(0.0, _dizzy_t - delta)
	if _stamina < 1.0:
		_stamina = minf(1.0, _stamina + delta / REFILL_SECONDS)
		queue_redraw()
	# start a spin: HOLD Shell (turtle only) with enough charge, when no menu is up
	if _kind == Kind.TURTLE and _dizzy_t <= 0.0 and _stamina >= START_MIN \
			and not Settings.ui_locked() and _shell_held():
		_begin_pilot()
		return
```

New:

```gdscript
	if _piloting:
		_run_pilot(delta)                 # shell-spin demolition (the frog isn't piloted)
		return
	if _survey_phase != SurveyPhase.NONE:
		_run_survey(delta)                 # the dragonfly's non-interactive sweep (she flies herself)
		return
	# recharge the shell between spins; tick down any dizzy lock
	_dizzy_t = maxf(0.0, _dizzy_t - delta)
	if _stamina < 1.0:
		_stamina = minf(1.0, _stamina + delta / REFILL_SECONDS)
		queue_redraw()
	_survey_cd = cooldown_tick(_survey_cd, delta)
	var held := _shell_held()
	var pressed := held and not _shell_was_held
	_shell_was_held = held
	# the shared partner-action button, keyed by who's ACTIVE: only the rescued partner currently
	# travelling with you answers it, even while a non-active rescued partner is mid-follow right
	# beside you (spec REVIEW AMENDMENT, Critical). With this gate, Survey needs no tap/hold
	# disambiguation — it fires on PRESS, zero latency, shell-identical feel.
	var verb := verb_for(_kind, Settings.run_active)
	if verb == VERB_SHELL and _dizzy_t <= 0.0 and _stamina >= START_MIN \
			and not Settings.ui_locked() and held:
		_begin_pilot()
		return
	if verb == VERB_SURVEY and _survey_cd <= 0.0 and not Settings.ui_locked() and pressed:
		_begin_survey()
		return
```

Add the static gate/math functions — place them right before `func _shell_held() -> bool:` (the
"SHELL-SPIN" section header, line ~378), as their own small section:

```gdscript
# --- pure gate + math (headless-testable, no scene/Input needed) -------------------------------

## The shared partner-action button, keyed by who's ACTIVE (spec REVIEW AMENDMENT, Critical).
static func verb_for(kind: int, active_kind: int) -> int:
	if kind != active_kind:
		return VERB_NONE
	if kind == Kind.TURTLE:
		return VERB_SHELL
	if kind == Kind.DRAGONFLY:
		return VERB_SURVEY
	return VERB_NONE

static func cooldown_tick(cd: float, delta: float) -> float:
	return maxf(0.0, cd - delta)

## 0 = just fired, 1 = ready — mirrors the shell-spin stamina ring's fill-as-it-charges reading.
static func survey_charge_frac(cd: float) -> float:
	return 1.0 - cd / SURVEY_COOLDOWN

## The worst-oxygen finish (spec REVIEW AMENDMENT, Important — reach_state's oxygen is a single
## scalar with no positional data, so this is NEW WORK: the densest neighborhood among the reach's
## live "grabbable" chokes (debris/pests) by point count within `radius`). Pure + static; the
## instance wrapper below supplies the real group scan.
static func densest_point(points: Array, radius: float) -> Vector2:
	if points.is_empty():
		return Vector2.INF
	var best: Vector2 = points[0]
	var best_n := -1
	for p in points:
		var n := 0
		for q in points:
			if (p as Vector2).distance_to(q as Vector2) <= radius:
				n += 1
		if n > best_n:
			best_n = n
			best = p
	return best
```

Add the instance methods — place right after `func wants_input_lock() -> bool:` (line 230, before
`func _process`):

```gdscript
## Public read for the roster/HUD/Survey machinery: which Kind this instance is.
func kind() -> int:
	return _kind

## For the PartnerHud cooldown ring (throttled 4Hz poll, spec REVIEW AMENDMENT — real plumbing,
## no per-frame path): 0..1 charge fraction, or -1 if this instance has no Survey cooldown to show
## right now (not the dragonfly, or not yet following).
func survey_hud_charge() -> float:
	if _kind != Kind.DRAGONFLY or _state != State.FOLLOWING:
		return -1.0
	return survey_charge_frac(_survey_cd)
```

Add the sweep implementation — new section right after `_end_pilot()` closes (after line 533,
before the frog's `_auto_tongue` comment block):

```gdscript
# --- SURVEY (dragonfly, non-interactive: she flies herself) ------------------------------------

## Press Survey. Non-interactive from here — _run_survey drives the whole sweep.
func _begin_survey() -> void:
	_survey_phase = SurveyPhase.SWEEP
	_survey_t = 0.0
	_survey_cd = SURVEY_COOLDOWN
	_survey_origin = position
	_survey_has_finish = false
	Sfx.play("chime", -6.0, 1.6)

## The sweep state machine: spiral out (~1.8s, radius ~180 — the scout's flight language reused),
## fire the reveal, then (if the reach has a worst-oxygen spot) fly to it and hover ~2.5s.
func _run_survey(delta: float) -> void:
	_survey_t += delta
	match _survey_phase:
		SurveyPhase.SWEEP:
			var frac := clampf(_survey_t / SURVEY_SWEEP_TIME, 0.0, 1.0)
			var ang := frac * TAU * 2.2
			var rad := SURVEY_SWEEP_RADIUS * frac
			position = _survey_origin + Vector2(cos(ang) * rad, sin(ang) * rad * 0.55)
			if absf(cos(ang)) > 0.05:
				_face = signf(cos(ang))
			_anims.play(anims.swim, _face)          # her cruising flight clip (fly_forward)
			if frac >= 1.0:
				_survey_phase = SurveyPhase.FINISH
				_survey_t = 0.0
				get_tree().call_group("surveyable", "reveal", SURVEY_REVEAL_SECONDS)
				_survey_finish_pos = _pick_survey_finish()
				_survey_has_finish = _survey_finish_pos != Vector2.INF
				_survey_finish_start = position
		SurveyPhase.FINISH:
			if not _survey_has_finish:
				_end_survey()
				return
			if _survey_t <= SURVEY_FINISH_FLY:
				var f := clampf(_survey_t / SURVEY_FINISH_FLY, 0.0, 1.0)
				position = _survey_finish_start.lerp(_survey_finish_pos, f)
				_anims.play(anims.swim, _face)
			else:
				position = _survey_finish_pos + Vector2(0.0, sin(_t * 5.0) * 6.0)
				_anims.play(anims.swim_idle, _face)
				if _survey_t >= SURVEY_FINISH_FLY + SURVEY_FINISH_HOVER:
					_end_survey()
	queue_redraw()

## Worst-oxygen finish: densest cluster of live "grabbable" chokes; fallback the uncapped leak;
## fallback Vector2.INF (no finish — the sweep ends after the reveal alone, spec §3).
func _pick_survey_finish() -> Vector2:
	var pts: Array = []
	for g in get_tree().get_nodes_in_group("grabbable"):
		if g is Node2D:
			pts.append((g as Node2D).global_position)
	var densest := densest_point(pts, SURVEY_DENSITY_RADIUS)
	if densest != Vector2.INF:
		return densest
	var leak := get_tree().get_first_node_in_group("leak")
	if leak and not (leak as Node).is_queued_for_deletion():
		return (leak as Node2D).global_position
	return Vector2.INF

func _end_survey() -> void:
	_survey_phase = SurveyPhase.NONE
	_survey_t = 0.0
	_fire_first_survey()
	queue_redraw()
```

(`_fire_first_survey()` is implemented in Task 3 — for this task, add a temporary no-op stub so
the file compiles: `func _fire_first_survey() -> void: pass  ## replaced in Task 3` — placed right
after `_end_survey()`. Task 3's step 1 replaces this stub with the real body; do not skip adding
the stub now, or Task 1's parse gate fails.)

- [ ] **Step 5: Run the test** → `RESULT: ALL PASS`.

- [ ] **Step 6: PartnerHud — throttled 4Hz cooldown ring on the active chip**

Old (`game/hud/partner_hud.gd` lines 45-81, the whole `Chip` class):

```gdscript
	## One tappable partner chip: backing disc + the partner's idle frame + a gold ring when active.
	class Chip extends Control:
		var _kind: int
		var _active: bool
		var _tex: Texture2D

		func _init(kind: int, active: bool) -> void:
			_kind = kind
			_active = active
			custom_minimum_size = Vector2(CHIP, CHIP)
			texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var frames: SpriteFrames = Library.ART[kind]["frames"]
			if frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
				_tex = frames.get_frame_texture("idle", 0)
			tooltip_text = str(Library.NAMES.get(kind, "?")).capitalize()

		func _gui_input(event: InputEvent) -> void:
			var tap: bool = (event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed)
			if tap:
				accept_event()              # this tap is OURS — it must not leak a turtle command
				Settings.roster_swap(_kind)
				Sfx.play("ui_tap", -8.0)

		func _draw() -> void:
			var c := size / 2.0
			draw_circle(c, CHIP * 0.5, Color(Palette.INK, 0.4))                    # backing disc
			draw_circle(c, CHIP * 0.5 - 2.0, Color(Palette.DEEP, 0.6 if _active else 0.35))
			if _tex:
				var s := (CHIP - 12.0) / maxf(float(_tex.get_width()), float(_tex.get_height()))
				var sz := Vector2(_tex.get_width(), _tex.get_height()) * s
				draw_texture_rect(_tex, Rect2(c - sz * 0.5, sz), false,
					Color(1, 1, 1, 1.0 if _active else 0.55))
			draw_arc(c, CHIP * 0.5 - 1.0, 0.0, TAU, 32,
				Color(Palette.GOLD, 0.95) if _active else Color(Palette.MIST, 0.4),
				2.0 if _active else 1.0, true)
```

New:

```gdscript
	## One tappable partner chip: backing disc + the partner's idle frame + a gold ring when active,
	## plus (Survey's cooldown, spec REVIEW AMENDMENT Important) a small charge ring on the ACTIVE
	## chip when its companion has one. The cooldown is only actionable while she's the one you can
	## command, so only the active chip ever shows it. Throttled 4Hz poll — real plumbing, not a
	## per-frame path (the class stays a rebuild-on-signal Control otherwise).
	class Chip extends Control:
		const POLL_HZ := 4.0
		var _kind: int
		var _active: bool
		var _tex: Texture2D
		var _poll_t := 0.0
		var _charge := -1.0        # -1 = nothing to show; 0..1 once a companion answers kind()

		func _init(kind: int, active: bool) -> void:
			_kind = kind
			_active = active
			custom_minimum_size = Vector2(CHIP, CHIP)
			texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var frames: SpriteFrames = Library.ART[kind]["frames"]
			if frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
				_tex = frames.get_frame_texture("idle", 0)
			tooltip_text = str(Library.NAMES.get(kind, "?")).capitalize()

		func _process(delta: float) -> void:
			if not _active:
				return
			_poll_t -= delta
			if _poll_t > 0.0:
				return
			_poll_t = 1.0 / POLL_HZ
			var next := -1.0
			for c in get_tree().get_nodes_in_group("companion"):
				if c.has_method("kind") and c.kind() == _kind and c.has_method("survey_hud_charge"):
					var f: float = c.survey_hud_charge()
					if f >= 0.0:
						next = f
					break
			if not is_equal_approx(next, _charge):
				_charge = next
				queue_redraw()

		func _gui_input(event: InputEvent) -> void:
			var tap: bool = (event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed)
			if tap:
				accept_event()              # this tap is OURS — it must not leak a turtle command
				Settings.roster_swap(_kind)
				Sfx.play("ui_tap", -8.0)

		func _draw() -> void:
			var c := size / 2.0
			draw_circle(c, CHIP * 0.5, Color(Palette.INK, 0.4))                    # backing disc
			draw_circle(c, CHIP * 0.5 - 2.0, Color(Palette.DEEP, 0.6 if _active else 0.35))
			if _tex:
				var s := (CHIP - 12.0) / maxf(float(_tex.get_width()), float(_tex.get_height()))
				var sz := Vector2(_tex.get_width(), _tex.get_height()) * s
				draw_texture_rect(_tex, Rect2(c - sz * 0.5, sz), false,
					Color(1, 1, 1, 1.0 if _active else 0.55))
			draw_arc(c, CHIP * 0.5 - 1.0, 0.0, TAU, 32,
				Color(Palette.GOLD, 0.95) if _active else Color(Palette.MIST, 0.4),
				2.0 if _active else 1.0, true)
			if _active and _charge >= 0.0 and _charge < 0.999:
				draw_arc(c, CHIP * 0.5 + 3.0, -PI / 2.0, -PI / 2.0 + TAU * _charge, 20,
					Color(Palette.CYAN, 0.9), 2.0, true)
```

- [ ] **Step 7: Gates** — parse gate clean; the 6 existing suites + `test_companion_survey.gd` all
  `RESULT: ALL PASS`. Boot `main.tscn`: turtle shell-spin feels byte-identical (hold-to-spin, same
  stamina drain/refill). No dragonfly content exists yet (reach 2 is unbuilt), so there is nothing
  to press-fire Survey against in a live boot this task — the state machine is exercised entirely
  by the headless suite; Task 3 gets the first live dragonfly smoke (a `setup_traveller` instance
  can be spawned by temporarily seeding `Settings.run_roster/run_active` in the debugger if a
  visual spot-check is wanted, but is not required by this task's gate).

- [ ] **Step 8: Commit**

```bash
git add game/companion/companion.gd game/hud/partner_hud.gd tests/settings_roster_helper.gd tests/test_companion_survey.gd
git commit -m "$(cat <<'EOF'
feat(slice4): active-partner gating (Kirby rule) + Survey verb core

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: The reveal contract

**Files:**
- Modify: `game/cove/curio.gd` (z bump + amplified glint, unfound-only)
- Modify: `game/cove/destructible_rock.gd` (shimmer boost incl. locked-gate tone)
- Modify: `game/cove/leak_source.gd` (drip pulse + rising motes)
- Modify: `game/cove/debris_field.gd` (brightened modulate, captured-baseline restore)
- Modify: `game/cove/invasive_school.gd` (brightened modulate, captured-baseline restore)
- Create: `tests/test_reveal_contract.gd`

**Interfaces:**
- Consumes: group `"surveyable"` + `reveal(duration: float) -> void` contract (Task 1 fires it).
- Produces: every component below joins group `"surveyable"` and implements `reveal(duration)`,
  self-restoring on a `_process`-driven timer (never a `Tween` — chosen specifically so every
  reveal is exercised headless via a direct `._process(dt)` call, no real-frame stepping needed).

- [ ] **Step 1: Write the failing test** — `tests/test_reveal_contract.gd`:

```gdscript
extends SceneTree
## Headless tests for Survey's "surveyable" reveal contract (slice 4 T2): each component owns its
## own look but Survey only rings the bell; every component restores its EXACT captured prior
## state, never a hardcoded baseline (spec risk #1 — legacy rocks sit at z2, painted map seals at
## z7). reveal() drives a _process-owned timer (not a Tween) specifically so this suite can drive
## time with direct ._process(dt) calls instead of real engine frames. Same _process-deferred-load
## idiom as tests/test_reach_map.gd: zero literal `WorldState.*`/`Settings.*` text in this file's
## own source, routed through tests/reach_map_worldstate_helper.gd, load()'d here.
## Run: & $godot --headless --path $proj --script tests/test_reveal_contract.gd
var fails := 0
var _done := false
func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok: fails += 1
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
	WSHelper.reset_scratch("user://test_reveal_contract.save")
	var CoveConfigScript = load("res://game/cove/cove_config.gd")

	# --- curio.gd: reveal only answers UNFOUND curios; z restores to ITS captured baseline ---
	var CurioScript = load("res://game/cove/curio.gd")
	var root := Node2D.new(); get_root().add_child(root)
	var curio = CurioScript.new()
	root.add_child(curio)
	var base_z: int = curio.z_index
	curio.reveal(0.2)
	_check("curio: reveal bumps z to 8 (the portal/FX plane)", curio.z_index == 8)
	curio._process(0.3)
	_check("curio: z restores to its captured baseline (%d)" % base_z, curio.z_index == base_z)
	curio._revealed = true                        # simulate an already-unearthed curio
	var z_before_noop := curio.z_index
	curio.reveal(0.2)
	_check("curio: reveal is a no-op once unearthed (unfound-only contract)", curio.z_index == z_before_noop)
	curio.free()

	# --- destructible_rock.gd: legacy z (2) vs a map-seal z (7) restore to THEIR OWN baseline ---
	var RockScript = load("res://game/cove/destructible_rock.gd")
	var legacy_rock = RockScript.new()
	legacy_rock.cols = 3; legacy_rock.rows = 3
	root.add_child(legacy_rock)                    # _ready() sets z_index = 2 (legacy default)
	_check("rock: legacy default z is 2 before any reveal", legacy_rock.z_index == 2)
	legacy_rock.reveal(0.2)
	_check("rock: reveal bumps z to 8", legacy_rock.z_index == 8)
	legacy_rock._process(0.3)
	_check("rock: legacy rock restores to z 2 (its own baseline)", legacy_rock.z_index == 2)
	legacy_rock.free()

	var seal_rock = RockScript.new()
	seal_rock.cols = 3; seal_rock.rows = 3
	root.add_child(seal_rock)
	seal_rock.z_index = 7                           # mirrors reach_map.gd._build_breakables()'s post-add override
	seal_rock.reveal(0.2)
	_check("rock: seal reveal bumps z to 8 too", seal_rock.z_index == 8)
	seal_rock._process(0.3)
	_check("rock: map-seal rock restores to z 7 (ITS baseline, not the legacy 2)", seal_rock.z_index == 7)
	seal_rock.free()

	var locked_rock = RockScript.new()
	locked_rock.cols = 3; locked_rock.rows = 3; locked_rock.locked = true
	root.add_child(locked_rock)
	locked_rock.reveal(0.2)
	_check("rock: a locked gate answers reveal too (z bump identical)", locked_rock.z_index == 8)
	locked_rock.free()

	# --- leak_source.gd: reveal boosts the drip + starts the survey motes, both settle after ---
	var LeakScript = load("res://game/cove/leak_source.gd")
	var cfg_leak = CoveConfigScript.new()
	cfg_leak.leak_enabled = true
	var leak = LeakScript.new()
	root.add_child(leak)
	leak.setup(cfg_leak)
	leak.reveal(0.2)
	_check("leak: reveal speeds up the drip", leak._drip.speed_scale > 1.0)
	_check("leak: reveal starts the survey motes", leak._survey_motes.emitting)
	leak._process(0.3)
	_check("leak: drip settles back to normal speed", is_equal_approx(leak._drip.speed_scale, 1.0))
	_check("leak: survey motes stop", not leak._survey_motes.emitting)
	leak.free()

	var cfg_capped = CoveConfigScript.new()
	cfg_capped.leak_enabled = true
	var capped_leak = LeakScript.new()
	root.add_child(capped_leak)
	capped_leak.setup(cfg_capped)
	capped_leak._capped = true
	capped_leak.reveal(0.2)
	_check("leak: a capped (already-purified) leak ignores reveal", not capped_leak._survey_motes.emitting)
	capped_leak.free()

	# --- debris_field.gd: brightens live clumps' modulate, restores to their captured baseline ---
	var DebrisFieldScript = load("res://game/cove/debris_field.gd")
	var cfg_debris = CoveConfigScript.new()
	cfg_debris.id = "test_reveal_debris"
	cfg_debris.debris_count = 2
	var debris_root := Node2D.new(); get_root().add_child(debris_root)
	var field = DebrisFieldScript.new()
	debris_root.add_child(field)
	field.setup(cfg_debris)
	_check("debris_field: spawned its configured clump count", field.get_child_count() == 2)
	var clump: Node2D = field.get_child(0)
	var base_mod: Color = clump.modulate
	field.reveal(0.4)
	_check("debris_field: a clump brightens immediately on reveal", clump.modulate != base_mod)
	field._process(0.5)
	_check("debris_field: clump restores to its exact captured baseline", clump.modulate == base_mod)
	debris_root.free()

	# --- invasive_school.gd: brightens the school, restores to the murk-tinted baseline exactly ---
	var SchoolScript = load("res://game/cove/invasive_school.gd")
	var cfg_school = CoveConfigScript.new()
	cfg_school.id = "test_reveal_school"
	cfg_school.invasive_count = 2
	var school_root := Node2D.new(); get_root().add_child(school_root)
	var school = SchoolScript.new()
	school_root.add_child(school)
	school.setup(cfg_school)
	var fish0: Sprite2D = school._fish[0]["node"]
	var base_fish_mod: Color = fish0.modulate
	school.reveal(0.4)
	_check("invasive_school: a fish brightens immediately on reveal", fish0.modulate != base_fish_mod)
	school._process(0.5)
	_check("invasive_school: fish restores to its exact captured (murk-tinted) baseline", fish0.modulate == base_fish_mod)
	school_root.free()

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
	return true
```

- [ ] **Step 2: Run to verify it fails** (no `reveal()` method on any of the five scripts yet).

- [ ] **Step 3: `curio.gd`**

Old (line 25-28):

```gdscript
func _ready() -> void:
	add_to_group("sprayable")
	z_index = 4                 # in the silt, under creatures (frog 9 / axolotl 10)
```

New:

```gdscript
var _reveal_t := 0.0
var _reveal_base_z := 0
var _reveal_captured := false

func _ready() -> void:
	add_to_group("sprayable")
	add_to_group("surveyable")
	z_index = 4                 # in the silt, under creatures (frog 9 / axolotl 10)

## Survey's reveal contract: ONLY unfound curios answer (spec §4 — "unfound curios glint through
## terrain"; a revealed-but-not-collected or already-collected curio ignores this). Lifts to the
## portal/FX plane (z 8) so the glint reads through the land quad, restoring to whatever z it
## actually had (4 today — captured lazily on first use, never hardcoded, spec risk #1).
func reveal(duration: float) -> void:
	if _revealed or _done:
		return
	if not _reveal_captured:
		_reveal_base_z = z_index
		_reveal_captured = true
	z_index = 8
	_reveal_t = duration
	queue_redraw()
```

Old (`_process`, lines 42-56):

```gdscript
func _process(delta: float) -> void:
	_t += delta
	if _done:
		return
	if _revealed:
		# unearthed: the curio floats free, bobbing — collect by coming close
		position.y += sin(_t * 2.2) * 2.4 * delta
		var axo := get_tree().get_first_node_in_group("player") as Node2D
		if axo and axo.global_position.distance_to(global_position) <= COLLECT_REACH:
			_collect()
			return
	_acc += delta
	if _acc >= 1.0 / REDRAW_HZ:
		_acc = 0.0
		queue_redraw()          # the buried glint + the revealed bob (throttled — WebGL churn rule)
```

New:

```gdscript
func _process(delta: float) -> void:
	_t += delta
	if _done:
		return
	if _reveal_t > 0.0:
		_reveal_t = maxf(0.0, _reveal_t - delta)
		if _reveal_t <= 0.0:
			z_index = _reveal_base_z
			queue_redraw()
	if _revealed:
		# unearthed: the curio floats free, bobbing — collect by coming close
		position.y += sin(_t * 2.2) * 2.4 * delta
		var axo := get_tree().get_first_node_in_group("player") as Node2D
		if axo and axo.global_position.distance_to(global_position) <= COLLECT_REACH:
			_collect()
			return
	_acc += delta
	if _acc >= 1.0 / REDRAW_HZ:
		_acc = 0.0
		queue_redraw()          # the buried glint + the revealed bob (throttled — WebGL churn rule)
```

Old (`_draw`, the not-revealed glint block, lines 78-82):

```gdscript
			var glint := maxf(0.0, sin(_t * 1.4))
			glint = maxf(0.0, glint * glint * glint - 0.15)   # a brief sparkle every ~4.5s, dark between
			if glint > 0.0:
				draw_line(Vector2(-3.0, -4.0), Vector2(3.0, -4.0), Color(Palette.FOAM, glint), 1.5)
				draw_line(Vector2(0.0, -7.0), Vector2(0.0, -1.0), Color(Palette.FOAM, glint), 1.5)
```

New:

```gdscript
			var glint := maxf(0.0, sin(_t * 1.4))
			glint = maxf(0.0, glint * glint * glint - 0.15)   # a brief sparkle every ~4.5s, dark between
			if _reveal_t > 0.0:
				glint = maxf(glint, 0.55 + 0.35 * sin(_t * 6.0))   # Survey holds a steady bright sparkle
			if glint > 0.0:
				draw_line(Vector2(-3.0, -4.0), Vector2(3.0, -4.0), Color(Palette.FOAM, glint), 1.5)
				draw_line(Vector2(0.0, -7.0), Vector2(0.0, -1.0), Color(Palette.FOAM, glint), 1.5)
				if _reveal_t > 0.0:
					draw_circle(Vector2.ZERO, 12.0, Color(Palette.GOLD, 0.12 * glint))   # a soft halo so it reads through terrain (z8)
```

- [ ] **Step 4: `destructible_rock.gd`**

Old (member vars, lines 43-47):

```gdscript
var _glow_t := 0.0               # drives the breakable aura's slow pulse
var _redraw_acc := 0.0           # throttles the pulse redraw to ~10 Hz
var _scars: Array = []           # [local cell centre, age] — fresh-break craters, fading ~1.2s
var _lock_tween: Tween           # guards against stacking tweens on rapid blasts
const SCAR_LIFE := 1.2
```

New:

```gdscript
var _glow_t := 0.0               # drives the breakable aura's slow pulse
var _redraw_acc := 0.0           # throttles the pulse redraw to ~10 Hz
var _scars: Array = []           # [local cell centre, age] — fresh-break craters, fading ~1.2s
var _lock_tween: Tween           # guards against stacking tweens on rapid blasts
const SCAR_LIFE := 1.2
var _reveal_t := 0.0             # Survey's reveal window remaining (0 = not revealing)
var _reveal_base_z := 0          # z_index to restore to — CAPTURED, not hardcoded (spec risk #1:
var _reveal_captured := false    # legacy rocks sit at z2, reach_map.gd's painted seals at z7)

## Survey's reveal contract: boosts the mineral shimmer (and, for a locked gate, flashes its own
## tone) so a sealed gate visibly answers the sweep even with breakable_glow off. Lifts briefly to
## z 8 (the portal/FX plane, spec risk #1) so the boost reads through the land quad on a map reach,
## then restores to WHATEVER z this rock actually had — never a hardcoded restore point.
func reveal(duration: float) -> void:
	if not _reveal_captured:
		_reveal_base_z = z_index
		_reveal_captured = true
	z_index = 8
	_reveal_t = duration
	queue_redraw()
```

Old (`_process`, lines 87-103):

```gdscript
func _process(delta: float) -> void:
	var shimmer := breakable_glow and _remaining > 0
	if not shimmer and _scars.is_empty():
		return
	_glow_t += delta
	for s in _scars:
		s[1] += delta
	while not _scars.is_empty() and _scars[0][1] > SCAR_LIFE:   # appended in order — oldest first
		_scars.pop_front()
	# WEB PERF: canvas-item rebuilds are the expensive part on WebGL, and every intact rock runs
	# this loop. The slow mineral shimmer only needs ~8Hz; the brief scar fades get 20Hz while
	# any are alive, then the rock settles back to the cheap cadence.
	_redraw_acc += delta
	var period := 0.05 if not _scars.is_empty() else 0.125
	if _redraw_acc >= period:
		_redraw_acc = 0.0
		queue_redraw()
```

New:

```gdscript
func _process(delta: float) -> void:
	if _reveal_t > 0.0:
		_reveal_t = maxf(0.0, _reveal_t - delta)
		if _reveal_t <= 0.0:
			z_index = _reveal_base_z
			queue_redraw()
	var shimmer := (breakable_glow and _remaining > 0) or _reveal_t > 0.0
	if not shimmer and _scars.is_empty():
		return
	_glow_t += delta
	for s in _scars:
		s[1] += delta
	while not _scars.is_empty() and _scars[0][1] > SCAR_LIFE:   # appended in order — oldest first
		_scars.pop_front()
	# WEB PERF: canvas-item rebuilds are the expensive part on WebGL, and every intact rock runs
	# this loop. The slow mineral shimmer only needs ~8Hz; the brief scar fades AND an active
	# Survey reveal get 20Hz (bounded to the reveal's 6s window), then the rock settles back down.
	_redraw_acc += delta
	var period := 0.05 if (not _scars.is_empty() or _reveal_t > 0.0) else 0.125
	if _redraw_acc >= period:
		_redraw_acc = 0.0
		queue_redraw()
```

Old (`_draw`, the shimmer term, lines 127-129):

```gdscript
			if breakable_glow and j > 0.68:   # ~1/3 of cells shimmer, each at its own phase
				var tw := 0.5 + 0.5 * sin(_glow_t * 2.0 + j * TAU + pz)
				tone = tone.lightened(0.10 * tw)
```

New:

```gdscript
			if (breakable_glow and j > 0.68) or _reveal_t > 0.0:   # Survey: every cell answers
				var tw := 0.5 + 0.5 * sin(_glow_t * 2.0 + j * TAU + pz)
				# a locked gate glows its OWN tone under Survey (the "not yet" colour reading
				# through); everything else just shimmers harder than its idle ~1/3-cells pulse
				if locked and _reveal_t > 0.0:
					tone = tone_a.lerp(tone, 0.70)
				else:
					var boost: float = 0.30 if _reveal_t > 0.0 else 0.10
					tone = tone.lightened(boost * tw)
```

- [ ] **Step 5: `leak_source.gd`**

Old (`_ready`, lines 33-49):

```gdscript
func _ready() -> void:
	add_to_group("sprayable")
	add_to_group("leak")         # so the hint system can nudge the player toward capping it
	z_index = 4                  # over the water/oil, under FX
	_spr = Sprite2D.new()
	_spr.texture = BARREL
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
	_spr.scale = Vector2(PROP_SCALE, PROP_SCALE)
	_spr.offset = Vector2(0.0, -float(BARREL.get_height()) * 0.5)   # bottom sits on leak_pos
	add_child(_spr)
	_add_solid()                 # the barrel is solid — the axolotl bumps it, doesn't pass through
	_drip = _make_drip()
	add_child(_drip)
	_ring = CapRing.new()
	add_child(_ring)
	_pool = _make_pool()         # an oil-shader pool at the barrel's base (real oil, not a flat blob)
	add_child(_pool)
```

New:

```gdscript
func _ready() -> void:
	add_to_group("sprayable")
	add_to_group("leak")         # so the hint system can nudge the player toward capping it
	add_to_group("surveyable")
	z_index = 4                  # over the water/oil, under FX
	_spr = Sprite2D.new()
	_spr.texture = BARREL
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
	_spr.scale = Vector2(PROP_SCALE, PROP_SCALE)
	_spr.offset = Vector2(0.0, -float(BARREL.get_height()) * 0.5)   # bottom sits on leak_pos
	add_child(_spr)
	_add_solid()                 # the barrel is solid — the axolotl bumps it, doesn't pass through
	_drip = _make_drip()
	add_child(_drip)
	_ring = CapRing.new()
	add_child(_ring)
	_pool = _make_pool()         # an oil-shader pool at the barrel's base (real oil, not a flat blob)
	add_child(_pool)
	_survey_motes = _make_survey_motes()
	add_child(_survey_motes)
```

Add member vars — after line 31 (`var _spray_cd := 0.0`):

```gdscript
var _reveal_t := 0.0
var _survey_motes: CPUParticles2D   # a rising trail while Survey reveals the leak — ADDS to, never
                                     # replaces, the barrel's own constant drip
```

Add the `reveal()` method — anywhere after `setup()` (e.g. right before `spray_at`):

```gdscript
## Survey's reveal contract: a temporary drip-rate pulse + rising motes over the source — nothing
## new is drawn (the existing drip/pool already sell "this leaks"); Survey just intensifies the
## tell for the window. A capped (already-purified) leak ignores it — there's nothing left to point at.
func reveal(duration: float) -> void:
	if _capped:
		return
	_reveal_t = duration
	_drip.speed_scale = 2.2
	_survey_motes.emitting = true
```

Old (`_process`, lines 88-98):

```gdscript
func _process(delta: float) -> void:
	if _capped:
		return
	# trickle fresh oil back into the water at the shoreline, down-right from the barrel
	if _oil:
		_oil.stain_at(global_position + DRIP, STAIN_RADIUS, _cfg.leak_rate * delta)
	# the cap meter drains when you stop spraying the barrel (no penalty, just not-yet-sealed)
	_spray_cd -= delta
	if _spray_cd <= 0.0:
		_cap_t = move_toward(_cap_t, 0.0, delta * 1.5)
	(_ring as CapRing).progress = _cap_t / CAP_SECONDS
```

New:

```gdscript
func _process(delta: float) -> void:
	if _reveal_t > 0.0:
		_reveal_t = maxf(0.0, _reveal_t - delta)
		if _reveal_t <= 0.0:
			_drip.speed_scale = 1.0
			_survey_motes.emitting = false
	if _capped:
		return
	# trickle fresh oil back into the water at the shoreline, down-right from the barrel
	if _oil:
		_oil.stain_at(global_position + DRIP, STAIN_RADIUS, _cfg.leak_rate * delta)
	# the cap meter drains when you stop spraying the barrel (no penalty, just not-yet-sealed)
	_spray_cd -= delta
	if _spray_cd <= 0.0:
		_cap_t = move_toward(_cap_t, 0.0, delta * 1.5)
	(_ring as CapRing).progress = _cap_t / CAP_SECONDS
```

Add `_make_survey_motes()` — right after `_make_drip()`:

```gdscript
## A rising trail of pale motes over the leak while Survey reveals it. Off (not emitting) until
## reveal() flips it on; created once in _ready() rather than lazily so reveal() never allocates.
func _make_survey_motes() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = 8
	p.lifetime = 1.1
	p.position = Vector2(0.0, -10.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 14.0
	p.gravity = Vector2(0.0, -18.0)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	p.color = Color(Palette.CYAN, 0.85)
	p.z_index = 8
	return p
```

- [ ] **Step 6: `debris_field.gd`** — full new file (small; shown whole for clarity):

```gdscript
extends Node2D
## Scatters floating debris across the water for the frog's tongue to clear — config-driven count
## (debris_count; 0 = none, so the cove has none and the estuary has a handful). Injected by the Cove
## composition root, exactly like the other cove components. Self-contained: it just spawns; each clump
## owns its own bob + grab (floating_debris.gd). Also answers Survey's "surveyable" reveal contract by
## brightening every live clump for the window (see reveal() below).

const DEBRIS := preload("res://game/cove/floating_debris.gd")

var _reveal_t := 0.0
var _reveal_bases: Array = []   # [{node: CanvasItem, base: Color}, ...] — captured per reveal() call

func setup(cfg: CoveConfig) -> void:
	if cfg.debris_count <= 0 or WorldState.is_restored(cfg.id):
		return   # a RESTORED reach reloads restored: no chokes respawn (spec review C2)
	add_to_group("surveyable")
	# field-true placement on a painted map only (spec 4.6/T7) — legacy keeps the exact lerp so a
	# hand-built reach's layout never shifts.
	var field: ReachField = get_tree().get_first_node_in_group("reach_field")
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for i in cfg.debris_count:
		var d := DEBRIS.new()
		# spread across the middle of the water span (kept off the shore so it's genuinely out of the
		# axolotl's reach — a job for the frog), with staggered depth near the surface
		var x: float
		if cfg.has_map and field != null:
			x = field.random_surface_x(rng)     # guaranteed an actual open-water column
		else:
			var t := (float(i) + 0.5) / float(cfg.debris_count)
			x = lerpf(cfg.water_left + 70.0, cfg.water_right - 60.0, t)
		var y := cfg.surface_y + 8.0 + fmod(float(i) * 37.0, 40.0)
		d.position = Vector2(x, y)
		add_child(d)

## Survey's reveal contract: brighten every LIVE clump's modulate for the duration, restoring to
## whatever it was (captured per-node, not a hardcoded WHITE — floating_debris.gd stays untouched,
## the boost lives entirely at this spawner level). Driven by _process (not a Tween) so a mid-reveal
## grab (queue_free) is handled by a plain is_instance_valid check, and the whole contract is
## headless-testable with a direct ._process(dt) call.
func reveal(duration: float) -> void:
	_reveal_t = duration
	_reveal_bases.clear()
	for c in get_children():
		var base: Color = (c as CanvasItem).modulate
		_reveal_bases.append({"node": c, "base": base})
		(c as CanvasItem).modulate = base.lightened(0.6)

func _process(delta: float) -> void:
	if _reveal_t <= 0.0:
		return
	_reveal_t = maxf(0.0, _reveal_t - delta)
	if _reveal_t <= 0.0:
		for entry in _reveal_bases:
			if is_instance_valid(entry["node"]):
				(entry["node"] as CanvasItem).modulate = entry["base"]
		_reveal_bases.clear()
```

- [ ] **Step 7: `invasive_school.gd`**

Old (`setup`, lines 21-27):

```gdscript
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.invasive_count <= 0:
		queue_free()
		return
	add_to_group("sprayable")   # custom spray_at: scatter, never delete
	z_index = 6
```

New:

```gdscript
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.invasive_count <= 0:
		queue_free()
		return
	add_to_group("sprayable")   # custom spray_at: scatter, never delete
	add_to_group("surveyable")
	z_index = 6
```

Add member vars — after line 19 (`var _met := false`):

```gdscript
var _reveal_t := 0.0
var _reveal_bases: Array = []   # [{node: Sprite2D, base: Color}, ...] — captured per reveal() call

## Survey's reveal contract: brighten the whole school's silhouette for the duration (the invasive
## presence answers the sweep, same as everything else "surveyable" — cozy: this never harms them,
## just shows them). Restores to each fish's EXACT captured murk-tinted baseline.
func reveal(duration: float) -> void:
	_reveal_t = duration
	_reveal_bases.clear()
	for f in _fish:
		var s: Sprite2D = f["node"]
		var base: Color = s.modulate
		_reveal_bases.append({"node": s, "base": base})
		s.modulate = base.lightened(0.5)
```

Old (`_process`, lines 52-56 and 66-76 — insert the reveal countdown, keep everything else):

```gdscript
func _process(delta: float) -> void:
	_t += delta
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	var axo_local := to_local(axo.global_position) if axo else Vector2(-9999, 0)
	for f in _fish:
```

New:

```gdscript
func _process(delta: float) -> void:
	_t += delta
	if _reveal_t > 0.0:
		_reveal_t = maxf(0.0, _reveal_t - delta)
		if _reveal_t <= 0.0:
			for entry in _reveal_bases:
				if is_instance_valid(entry["node"]):
					(entry["node"] as CanvasItem).modulate = entry["base"]
			_reveal_bases.clear()
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	var axo_local := to_local(axo.global_position) if axo else Vector2(-9999, 0)
	for f in _fish:
```

(The rest of `_process` — fish movement, then the encounter check at the bottom — is unchanged.)

- [ ] **Step 8: Run the test** → `RESULT: ALL PASS`.

- [ ] **Step 9: Gates** — parse gate clean; all 6 existing suites + `test_companion_survey.gd` +
  `test_reveal_contract.gd` all `RESULT: ALL PASS`. Boot the three scenes: no visual change at
  rest (reveals only fire from `_begin_survey`, which nothing calls yet outside the headless
  suite — a live spot-check of the reveal look itself is deferred to Task 3, once a dragonfly can
  actually exist in a booted scene via `setup_traveller`).

- [ ] **Step 10: Commit**

```bash
git add game/cove/curio.gd game/cove/destructible_rock.gd game/cove/leak_source.gd game/cove/debris_field.gd game/cove/invasive_school.gd tests/test_reveal_contract.gd
git commit -m "$(cat <<'EOF'
feat(slice4): the "surveyable" reveal contract - curio/rock/leak/debris/school

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Scout hand-off + rescue polish

**Files:**
- Modify: `game/cove/scout_dragonfly.gd` (retire when the dragonfly is rostered)
- Modify: `game/log/field_guide.gd` (new encounter card)
- Modify: `game/cove/shine.gd` (new `first_survey` feat)
- Modify: `game/companion/companion.gd` (replace Task 1's stub with the real `_fire_first_survey`,
  wire the dragonfly's Field Guide card into `_wake()`)
- Create: `tests/test_dragonfly_handoff.gd`

**Interfaces:**
- Consumes: Task 1's `_end_survey()` call site (currently a stub); `Settings.run_roster` /
  `roster_changed` (existing); `FieldGuide.card(id) -> Dictionary` (existing,
  `game/log/field_guide.gd`); group `"curio_cards"` + `show_card(card, tally_text)` (existing,
  `game/cove/curio_field.gd`); `Shine.feat(id, at)` (existing, `game/cove/shine.gd`).
- Produces: `FieldGuide.CARDS[&"enc_dragonfly_rescue"]`; `Shine.FEATS[&"first_survey"]`; the
  `WorldState` pseudo cove-id `"meta"` for account-wide (not per-reach) one-time marks — documented
  design decision below.

**Design decision — keying the rescue card and the one-time feat (both without a real reach-2 id):**
Reach 2's cove `id` isn't authored yet (blocked on Maram's map, Task 4). Two things in this task
would normally be keyed by cove id and can't be:
1. The dragonfly's Field Guide card. Curios key `"<cove_id>_<index>"`; the estuary school's
   encounter keys `"enc_estuary_school"` — both cove-id-scoped. The rescue card instead gets a
   **fixed, cove-id-independent key**, `"enc_dragonfly_rescue"`, exactly like `wake_up` is a
   global feat catalog row, not a per-cove one. This means the card is authored NOW, correctly,
   and never needs renaming once reach 2's real id lands — it fires generically off `_kind ==
   Kind.DRAGONFLY` in `_wake()`, regardless of which reach hosts her.
2. The `first_survey` feat's one-time WorldState mark. `WorldState.mark(id, key, value)` is always
   per-cove (`_cfg.set_value("cove_" + id, key, value)`); there is no existing global-mark
   facility, because nothing before this needed one — every prior one-time flag (`friend_awake`,
   `portal_cleared`, `enc_school`, seal ids) is legitimately per-reach. Survey is different: once
   the dragonfly is rescued she follows you into every reach (the travelling-party rule), so "first
   survey ever" must not reset each time you enter a new cove. This plan reserves the **pseudo
   cove-id `"meta"`** for account-wide marks: `WorldState.mark("meta", "first_survey", true)` writes
   ConfigFile section `"cove_meta"` — distinct from WorldState's own internal bare `"meta"` section
   (used only for the save-format version, via a direct `_cfg.set_value` call that never goes
   through the `"cove_"` prefix), and no real reach will ever be named literally `"meta"`. Echo
   runs are exempt via the same `is_echo()` check `reach_map.gd`'s seal-mark idiom uses.

- [ ] **Step 1: Write the failing test** — `tests/test_dragonfly_handoff.gd`:

```gdscript
extends SceneTree
## Headless tests for the dragonfly's scout hand-off + Field Guide card + first_survey feat (slice
## 4 T3). Same _process-deferred-load idiom as tests/test_reach_map.gd: zero literal
## `Settings.*`/`WorldState.*` text in this file's own source, routed through
## tests/settings_roster_helper.gd and tests/reach_map_worldstate_helper.gd, both load()'d here.
## Kind 3 == DRAGONFLY (companion.gd's own enum order), written as a literal — see
## companion_library.gd for the established convention of never dotting into that enum externally.
## Run: & $godot --headless --path $proj --script tests/test_dragonfly_handoff.gd
var fails := 0
var _done := false
func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok: fails += 1
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	const DRAGONFLY := 3
	var Roster = load("res://tests/settings_roster_helper.gd")
	var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
	var ScoutScript = load("res://game/cove/scout_dragonfly.gd")
	var CoveConfigScript = load("res://game/cove/cove_config.gd")
	var FieldGuide = load("res://game/log/field_guide.gd")
	var ShineScript = load("res://game/cove/shine.gd")
	var Companion = load("res://game/companion/companion.gd")
	WSHelper.reset_scratch("user://test_dragonfly_handoff.save")
	Roster.reset()

	# --- scout retirement: already-rostered dragonfly -> the scout never even shows itself ---
	var cfg := CoveConfigScript.new()
	cfg.id = "test_scout_handoff"
	Roster.add(DRAGONFLY)
	var root := Node2D.new(); get_root().add_child(root)
	var scout = ScoutScript.new()
	root.add_child(scout)
	scout.setup(cfg)
	_check("scout: retires at setup when the dragonfly is already rostered", scout.is_queued_for_deletion())
	Roster.reset()

	# --- scout retirement: rescued MID-VISIT (roster_changed fires after setup) ---
	var scout2 = ScoutScript.new()
	root.add_child(scout2)
	scout2.setup(cfg)
	_check("scout: alive before the dragonfly is rescued", not scout2.is_queued_for_deletion())
	Roster.add(DRAGONFLY)
	_check("scout: retires the moment the roster gains the dragonfly", scout2.is_queued_for_deletion())
	Roster.reset()
	root.free()

	# --- Field Guide: the dragonfly rescue's own encounter card, keyed cove-id-independently ---
	var card: Dictionary = FieldGuide.card(&"enc_dragonfly_rescue")
	_check("field guide: enc_dragonfly_rescue exists", not card.is_empty())
	_check("field guide: it's an encounter card (same type as enc_estuary_school)", card.get("type", "") == "encounter")
	_check("field guide: follows the existing card format (name/species/fact)",
		card.has("name") and card.has("species") and card.has("fact"))

	# --- first_survey feat: catalogued, and the "meta" pseudo cove-id round-trips + stays isolated ---
	_check("shine: first_survey feat is catalogued", ShineScript.FEATS.has(&"first_survey"))
	_check("meta mark: unset by default", not bool(WSHelper.get_cove("meta", "first_survey", false)))
	WSHelper.mark("meta", "first_survey", true)
	_check("meta mark: set after marking", bool(WSHelper.get_cove("meta", "first_survey", false)))
	_check("meta mark: does not leak into a real cove id", not bool(WSHelper.get_cove("hub", "first_survey", false)))

	# --- companion.gd: _end_survey() fires first_survey via the REAL WorldState mark (not just
	# the guard mechanism proven above) — exercises the actual production call site ---
	WSHelper.reset_scratch("user://test_dragonfly_handoff_wiring.save")
	var comp_root := Node2D.new(); get_root().add_child(comp_root)
	var comp = Companion.new()
	comp_root.add_child(comp)
	comp._kind = DRAGONFLY
	comp._end_survey()
	_check("companion: _end_survey() fires first_survey via the real WorldState mark",
		bool(WSHelper.get_cove("meta", "first_survey", false)))
	comp_root.free()

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
	return true
```

- [ ] **Step 2: Run to verify it fails** (`enc_dragonfly_rescue` card missing, `first_survey` feat
  missing, scout doesn't check the roster yet, `_fire_first_survey` is still Task 1's no-op stub).

- [ ] **Step 3: `scout_dragonfly.gd`**

Old (`setup`, lines 24-31):

```gdscript
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if WorldState.is_restored(cfg.id):
		queue_free()
		return
	z_index = 8
	visible = false
```

New:

```gdscript
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if WorldState.is_restored(cfg.id):
		queue_free()
		return
	if Settings.run_roster.has(3):    # Kind.DRAGONFLY (companion.gd's enum; a literal here avoids
		queue_free()                  # a cross-script dependency, same convention as companion_library.gd)
		return
	z_index = 8
	visible = false
	Settings.roster_changed.connect(_on_roster_changed)

## The dragonfly joined the roster (rescued here, or already rostered and just arriving as this
## reach's own dragonfly's rescue moment on THIS visit) — she's taken over the pointing, on your
## command instead of on a timer (spec §5). One-shot: the node frees itself the instant it happens.
func _on_roster_changed() -> void:
	if Settings.run_roster.has(3):
		queue_free()
```

- [ ] **Step 4: `field_guide.gd`** — add to `CARDS` (after the `"enc_estuary_school"` entry, before
  the closing `}` at line 53):

```gdscript
	"enc_dragonfly_rescue": {
		"name": "Dragonfly, Rescued",
		"species": "Odonata",
		"fact": "Dragonflies only breed where the water is clean and oxygen-rich — her return isn't just a friend found, it's a reading on the whole reach.",
		"icon": 2,
		"type": "encounter",
	},
```

- [ ] **Step 5: `shine.gd`** — add to `FEATS` (after the `&"curio"` row, before `&"cascade"`, line 44):

```gdscript
		&"first_survey": ["First Survey",  700.0, 0.20],
```

- [ ] **Step 6: `companion.gd`** — replace Task 1's stub and wire the card into `_wake()`.

Old (Task 1's stub, added at the end of `_end_survey()`'s section):

```gdscript
func _fire_first_survey() -> void: pass  ## replaced in Task 3
```

New:

```gdscript
## Guarded like reach_map.gd's seal-mark idiom (slice 5 T5): echo runs never mark, and the catalog
## Shine only pays out once, ever, world-wide — not once per reach, since Survey follows you
## everywhere the moment she's rescued. "meta" is the pseudo cove-id reserved for account-wide
## marks (see this task's design-decision note; WorldState.mark prefixes it "cove_meta", never
## colliding with a real reach id).
func _fire_first_survey() -> void:
	var root := get_tree().get_first_node_in_group("cove_root")
	var echo: bool = root != null and root.has_method("is_echo") and root.is_echo()
	if echo or bool(WorldState.get_cove("meta", "first_survey", false)):
		return
	WorldState.mark("meta", "first_survey", true)
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("feat"):
		keeper.feat(&"first_survey", global_position)
```

Add `const FieldGuide := preload("res://game/log/field_guide.gd")` to the top-of-file const block
(next to `const Spring := preload(...)` at line 15).

Old (`_wake()`, lines 187-199):

```gdscript
func _wake() -> void:
	_state = State.WAKING
	_zzz.emitting = false              # no longer matted — the sleepy oil bubbles stop
	_oil_a = 0.0                       # the oil stain is gone
	queue_redraw()
	_spr.modulate = clean_tint
	_anims.play(anims.fright, _face)   # startles awake first — a little jolt before it settles
	Sfx.play("chirp", -4.0)            # a cute vocal chirp as the friend wakes (GameBurp)
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("feat"):
		keeper.feat(&"wake_up", global_position)   # "Wake-Up Call" feat: callout + Flow + Shine
	Settings.roster_add(_kind)   # the rescued friend joins the roster (chips HUD); was never wired
	woke.emit()
```

New:

```gdscript
func _wake() -> void:
	_state = State.WAKING
	_zzz.emitting = false              # no longer matted — the sleepy oil bubbles stop
	_oil_a = 0.0                       # the oil stain is gone
	queue_redraw()
	_spr.modulate = clean_tint
	_anims.play(anims.fright, _face)   # startles awake first — a little jolt before it settles
	Sfx.play("chirp", -4.0)            # a cute vocal chirp as the friend wakes (GameBurp)
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("feat"):
		keeper.feat(&"wake_up", global_position)   # "Wake-Up Call" feat: callout + Flow + Shine
	if _kind == Kind.DRAGONFLY:
		# her rescue doubles as a Field Guide encounter (spec T3) — a fixed, cove-id-independent
		# key (see this task's design-decision note), so it never needs renaming once reach 2's
		# real id lands. Every other companion's rescue is unchanged (wake_up feat only, no card).
		var card: Dictionary = FieldGuide.card(&"enc_dragonfly_rescue")
		if not card.is_empty():
			get_tree().call_group("curio_cards", "show_card", card, "field guide — encounter logged")
	Settings.roster_add(_kind)   # the rescued friend joins the roster (chips HUD); was never wired
	woke.emit()
```

- [ ] **Step 7: Run the test** → `RESULT: ALL PASS`.

- [ ] **Step 8: Gates + live smoke** — parse gate clean; all 6 existing suites +
  `test_companion_survey.gd` + `test_reveal_contract.gd` + `test_dragonfly_handoff.gd` all
  `RESULT: ALL PASS`. Boot `canals.tscn`: in the debugger, seed `Settings.run_roster = [0, 3]` and
  `Settings.run_active = 3` before the scene's `_ready()` chain runs (or via a breakpoint) to spawn
  a travelling dragonfly instance via `_spawn_travellers()`; confirm she follows, Survey fires on
  press (spiral, then the reveal contract from Task 2 visibly lights up nearby rubble/leak/curios),
  the cooldown ring appears on her PartnerHud chip, and the scout (if present in that scene) is
  absent because she's already rostered. This is a manual spot-check, not a new headless assert —
  it is the first point in this plan a live dragonfly can exist in a booted scene at all.

- [ ] **Step 9: Commit**

```bash
git add game/cove/scout_dragonfly.gd game/log/field_guide.gd game/cove/shine.gd game/companion/companion.gd tests/test_dragonfly_handoff.gd
git commit -m "$(cat <<'EOF'
feat(slice4): scout hand-off + dragonfly rescue Field Guide card + first_survey feat

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Reach 2 integration — SKETCH ONLY (blocked on Maram's map)

**Status: BLOCKED.** Reach 2 does not exist — there is no painted terrain/marker PNG pair for it
yet (spec §7: "Reach 2 doesn't exist yet"). Nothing in this task can be implemented, tested, or
committed until Maram delivers the map. This section is a procedure to follow once it lands, not
an executable task — it deliberately does not meet this plan's "no placeholders / complete code in
every step" bar, because there is no real content yet to write complete code against. Do not start
this task without the PNG pair in hand.

**Files (once unblocked):**
- Create: `assets/maps/<reach2>_terrain.png`, `assets/maps/<reach2>_markers.png` (Maram's paint)
- Create: `game/cove/<reach2>_a.tres`
- Create: `<reach2>.tscn` (mirror `canals.tscn`'s structure exactly — see
  `docs/superpowers/plans/2026-07-11-slice5-reach-map-ingester.md` Task 8 Step 2 for the template)
- Modify: `game/cove/canals_a.tres` (add the east exit)
- Modify: `tests/test_reach_map.gd` (append a ground-truth block for the new map, mirroring the
  existing `marsh_draft`/`canals_a.tres`/`estuary_a.tres` smoke checks at its tail)
- Modify: `project.godot` only if reach 2 becomes the new `run/main_scene` (unlikely — canals stays
  the entry point; reach 2 is reached BY canals, not instead of it)

**Procedure once the PNG pair lands:**

1. **Ingest + audit.** Run `tools/audit_reach_map.ps1` against the new PNGs (edit its `$maps` path
   or parameterize it) BEFORE authoring the `.tres`. Confirm: exactly one spawn marker, a friend
   marker (gold) sitting in water or ≤4 cells above it (footing rule, same as v1 companions — she's
   a flier but still obeys it per spec §2), a west portal marker, terrain tallies sane, no
   off-legend colors, no buried markers. **The curio spray-reach lint (spec §2's "every curio must
   sit within spray reach (~30px) of open space" authoring rule) is ALREADY IMPLEMENTED** — verify
   before planning any new work here: `tools/audit_reach_map.ps1` lines 136-150 already flag
   `"curio beyond spray reach of open space (Survey tease rule)"` for any curio whose 4-cell
   (~32px) radius contains no water/air cell (shipped in commit `898e819`, predating this plan).
   The spec's phrasing ("the audit tool should gain this check when reach 2 lands") describes work
   that is already done — see this plan's final report for the full note on this discrepancy.

2. **`.tres`.** Mirror `game/cove/canals_a.tres`'s exact shape (read it first — it is the current,
   real template, not the slice5 plan's pre-implementation draft, which differs in exact field
   values). Reach-2-specific fields: `friend_kind = 3` (DRAGONFLY), `map_exits = { "west":
   "res://<reach2>.tscn"... }` wait — reach 2's OWN `map_exits` west entry points back at the
   CANALS: `map_exits = { "west": "res://canals.tscn" }` (the canals' east door leads here, spec
   §2). `in_play = Array[StringName]([&"purity", &"oxygen"])` (spec's authoring suggestion —
   oxygen matters here since the dragonfly's bioindicator finish stars in it; per
   `reach_state.gd`'s `WEIGHTS` dict this automatically pulls oxygen into the blended health meter
   with weight 0.3, no code change needed — `blend_health()` already normalizes over whatever
   `in_play` lists). Set `debris_count`/`pest_count` > 0 so there's something for the "grabbable"
   density pick (Task 1) to find — a reach with zero grabbables always falls to the leak fallback
   in `_pick_survey_finish()`, which still works but under-sells the bioindicator finish's point.

3. **Canals' east wiring.** `game/cove/canals_a.tres`: change

   ```
   map_exits = {
   "west": "res://estuary.tscn"
   }
   ```

   to

   ```
   map_exits = {
   "west": "res://estuary.tscn",
   "east": "res://<reach2>.tscn"
   }
   ```

   `reach_map.gd`'s existing `_build_portals()` already handles multi-entry `map_exits` dicts (it
   iterates `_cfg.portal_markers`, looking up each marker's `edge` in `map_exits` — no code change
   needed, this is a pure content wire). The canals' EAST edge must already have a portal marker
   painted in `marsh_draft_markers.png` for this to do anything — confirm via the audit tool's `==
   EDGES ==` section (it already flags "water at edge with NO portal within 4 cells"); if the east
   edge has no portal today, that marker needs painting into the EXISTING canals map too (a canals
   content change, not a reach-2-only one).

4. **Travel loop probes.** Extend `tests/test_reach_map.gd`'s tail (after its existing
   `estuary_a.tres exit2` smoke checks, following the exact same pattern) with: `<reach2>_a.tres`
   loads, `id` matches, `map_terrain`/`map_markers` wired, `friend_kind == 3`, `map_exits["west"]
   == "res://canals.tscn"`; and re-verify `canals_a.tres`'s `map_exits["east"] ==
   "res://<reach2>.tscn"` (mirrors the existing `map_exits["west"]` check already in the suite).

5. **Deploy gate.** Identical shape to slice 5's Task 8 Step 5 (full loop playtest) and Step 6
   (export + deploy): new game boots in the canals, turtle rescue unchanged, cross east into reach
   2, dragonfly sleeps at her marker, spray-rescue wakes her (scout in THIS reach retires per Task
   3's wiring — if reach 2 ships its own `ScoutDragonfly` node before she's rescued, confirm it
   free()s the instant `_wake()` fires, same signal path proven in Task 3's suite), Survey presses
   and reveals correctly against reach 2's real content (not the synthetic points Task 1/2's suites
   used), cross west back to the canals, canals → estuary → hub unchanged, all suites + parse gate
   green, web export, `vercel deploy --prod`, verify, commit, push.

**Do not attempt to fabricate reach 2's terrain/marker PNGs, curio positions, or portal
coordinates to "complete" this task early** — that is Maram's authored content per the spec's own
framing ("Maram's next painted map"), not implementation work.

---

## Self-Review (done at write time)

**Spec coverage:**
- §2 (unlock/content contract) → Task 4 (blocked, sketched).
- §3 (the SURVEY verb: input/sweep/bioindicator finish/cooldown/cozy contract) → Task 1 in full;
  the "one-button verb collision" risk (§7) is resolved BY the active-partner gate itself (Task 1),
  not by a separate hold/tap rule — the REVIEW AMENDMENT text explicitly retires that plan.
- §4 (reveal contract) → Task 2 in full, one subsection per named component.
- §5 (scout hand-off) → Task 3 step 3.
- §6 (tests & gates) → the cooldown state machine / reveal fan-out / worst-oxygen pick / scout
  retirement are each a named suite (Tasks 1-3); "all suites + 3 scene boots + reach-2 audit green"
  is in every task's gate step and Task 4's procedure step 1.
- §7 (risks) → reveal-through-terrain z-plane pin (z8, duration-bounded) lands in every Task 2
  component; the one-button collision risk is resolved structurally in Task 1 (see above); "reach 2
  doesn't exist yet" is why Task 4 is a sketch.
- §8 (task seeds 1-4) → map 1:1 onto this plan's Tasks 1-4.

**Placeholder scan:** Task 4 is explicitly, deliberately not code-complete — flagged in bold at its
own header as the one sanctioned exception, per this plan's brief ("SKETCH ONLY... blocked"). Every
other task (1-3) has complete code in every step, no `TBD`, no "add appropriate handling" — verified
by re-reading each step above. Task 1's `_fire_first_survey()` stub is a deliberate, temporary,
fully-specified placeholder with an exact one-line body and an explicit note of which task's step
replaces it (Task 3 Step 6) — not an open placeholder.

**Type consistency:** `VERB_NONE/VERB_SHELL/VERB_SURVEY`, `verb_for`, `cooldown_tick`,
`survey_charge_frac`, `densest_point`, `kind()`, `survey_hud_charge()` are each defined once (Task
1) and every later reference (Task 1's own `_process`/PartnerHud, Task 3's `test_dragonfly_handoff`
instantiation of `companion.gd`) uses the exact same names and signatures. `reveal(duration: float)
-> void` is implemented identically-shaped across all five Task 2 components and called identically
by Task 1's `get_tree().call_group("surveyable", "reveal", SURVEY_REVEAL_SECONDS)`. `"meta"` as the
pseudo cove-id is introduced once (Task 3's design-decision note) and used consistently in both the
production code (`_fire_first_survey`) and its test.

**Spec contradictions found while reading code (reported, not silently resolved):**
1. **§2's curio spray-reach audit check is already shipped.** The spec (v2, design-reviewed) says
   "the audit tool should gain this check when reach 2 lands" as future work. `tools/audit_reach_map.ps1`
   already contains it (lines 136-150, the "Survey rule (slice 4 spec)" block, shipped in commit
   `898e819 chore: portal2_cleared dead wiring removed + curio spray-reach audit lint`, which
   predates this plan). Task 4's procedure step 1 calls this out explicitly so nobody re-implements
   it or is confused when it's already there.
2. **§3's "HOLD vs TAP" risk (§7) is superseded by the REVIEW AMENDMENT inside the same spec
   document** — §3's own Critical amendment says the former policy "is deleted" in favor of the
   active-partner gate. Both sections are read; Task 1 implements the amendment, not the original
   §7 fallback plan (the spec is internally consistent about this — §7 lists it as a risk whose
   resolution the REVIEW AMENDMENT already supplies, not a contradiction requiring a judgment
   call — flagged here only so the deviation from §7's literal fallback text is visible, not silent).

No other contradictions between the spec and the actual current code were found; every file this
plan touches was read in full before its edit steps were written (`companion.gd`, `partner_hud.gd`,
`curio.gd`, `destructible_rock.gd`, `leak_source.gd`, `debris_field.gd`, `invasive_school.gd`,
`scout_dragonfly.gd`, `reach_state.gd`, `field_guide.gd`, `shine.gd`, `cove.gd`, `cove_config.gd`,
`cove_portal.gd`, `settings_store.gd`, `world_state.gd`, `companion_library.gd`,
`tests/test_reach_map.gd`, `tests/reach_map_worldstate_helper.gd`), and every suite count in Global
Constraints was captured from an actual run, not transcribed from the spec or an earlier plan.
