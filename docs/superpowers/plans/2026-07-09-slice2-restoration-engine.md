# Slice 2 — Restoration Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single cleanliness meter with the reach_state variable/recipe engine (spec `2026-07-09-slice2-restoration-engine.md`), retuned onto the two live reaches with zero visual regression on the hub.

**Architecture:** One injected `reach_state` component derives five variables from existing systems (oil mask = purity; `"grabbable"` group = oxygen; invasive count caps clarity; vegetation is a gated growth value), normalizes Health over config-authored in-play variables, and emits `state_changed`. The banner evaluates config win recipes; a new invasive school and Reclaim tokens extend the estuary; pips extend the meter.

**Tech Stack:** Godot 4.7 GDScript, headless `--script` tests, existing WorldState/config idioms.

## Global Constraints

- Cozy contract: no fail states; the school is shy, never a threat; spray scatters it, never deletes it.
- Apollo palette only (named `Palette.*`), TABS, `##` doc comments, preload-not-class_name for new scripts.
- WorldState writes milestone-cadence only; ALL new marks echo-guarded via `cove_root.is_echo()` (the `curio_field.gd:_on_collected` pattern).
- **Hub must play byte-identical:** in_play=[purity] ⇒ Health ≡ cleanliness; hub configs gain no counts.
- D-0003 frozen swim tuning; `axolotl.gd` untouched this slice.
- Parse gate after every task (zero SCRIPT ERROR/Parse Error lines) + WorldState suite stays ALL PASS:
```powershell
$godot = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$proj  = "C:\Users\maram\Dev\GODOT PROJECTS\LilAxol"
& $godot --headless --path $proj --import 2>&1 | Select-String -Pattern "SCRIPT ERROR|Parse Error|Compile error" -CaseSensitive:$false
& $godot --headless --path $proj --script res://tests/test_world_state.gd 2>&1 | Select-String -Pattern "RESULT"
```
- If a quoted anchor has drifted, STOP and report NEEDS_CONTEXT.

---

### Task 1: reach_state math + component + headless tests

**Files:**
- Create: `game/cove/reach_state.gd`
- Create: `tests/test_reach_state.gd`
- Modify: `game/cove/cove_config.gd` (engine fields)

**Interfaces:**
- Consumes: `oil_spill.current_clean`, group `"grabbable"`, `CoveConfig`.
- Produces (Tasks 2-5 rely on exact names): group `"reach_state"`; `signal state_changed(state: Dictionary)`; `func get_state() -> Dictionary` (keys `purity, oxygen, clarity, invasive, vegetation, health` all float); `func health() -> float`; `func recipe_met() -> bool`; static pure funcs `blend_health(state, in_play) -> float`, `clarity_cap(invasives_alive) -> float`, `veg_step(veg, gate_ok, delta) -> float`, `eval_recipe(state, recipe) -> bool`.

- [ ] **Step 1: Config fields.** In `game/cove/cove_config.gd`, after the `curios` export in the Ecosystem group, add:

```gdscript
## Murky invasive fish (tilapia/carp stand-ins) schooling in the deep — the pre-otter Clarity
## cap and the living face of the pollution. 0 = none (the hub default).
@export var invasive_count: int = 0

@export_group("Restoration Engine")
## Which variables count toward the Health meter (normalized blend) — ONLY variables the player
## can currently move. Hub = just purity (meter identical to the old cleanliness).
@export var in_play: Array[StringName] = [&"purity"]
## The win recipe: variable -> minimum value. The &"purity" key is special-cased to read
## win_threshold (single source of truth). Empty = purity-only (legacy behavior).
@export var win_recipe: Dictionary = {}
## What gates vegetation growth: "purity" (reeds/mud-bank rule) or "clarity" (eelgrass, post-otter).
@export_enum("purity", "clarity") var vegetation_gate: String = "purity"
```

- [ ] **Step 2: Write the failing tests.** Create `tests/test_reach_state.gd`:

```gdscript
extends SceneTree
## Headless tests for the reach_state math (pure functions — no scene needed).
## Run: & $godot --headless --path $proj --script res://tests/test_reach_state.gd

const RS := preload("res://game/cove/reach_state.gd")

var _fails := 0

func _init() -> void:
	_test_blend()
	_test_clarity_cap()
	_test_vegetation()
	_test_recipe()
	_test_debris_reachability()
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _test_blend() -> void:
	var s := {"purity": 0.3, "oxygen": 0.5, "clarity": 0.4, "invasive": 0.0, "vegetation": 0.0}
	_check("blend: purity-only == purity", absf(RS.blend_health(s, [&"purity"]) - 0.3) < 0.001)
	# estuary weights purity 0.7 / oxygen 0.3 -> (0.7*0.3 + 0.3*0.5) / 1.0 = 0.36
	_check("blend: purity+oxygen normalized", absf(RS.blend_health(s, [&"purity", &"oxygen"]) - 0.36) < 0.001)
	s["purity"] = 1.0
	s["oxygen"] = 1.0
	_check("blend: full in-play == 1", absf(RS.blend_health(s, [&"purity", &"oxygen"]) - 1.0) < 0.001)

func _test_clarity_cap() -> void:
	_check("clarity: none == 1", absf(RS.clarity_cap(0) - 1.0) < 0.001)
	_check("clarity: five fish cap 0.4", absf(RS.clarity_cap(5) - 0.4) < 0.001)
	_check("clarity: never below 0", RS.clarity_cap(20) >= 0.0)

func _test_vegetation() -> void:
	var v := 0.0
	for i in 100:                      # 10 simulated seconds with the gate held
		v = RS.veg_step(v, true, 0.1)
	_check("veg: grows toward 1 while gated", v > 0.45 and v <= 1.0)
	var v2 := v
	for i in 40:                       # 4 seconds gate failed — regresses at quarter rate
		v2 = RS.veg_step(v2, false, 0.1)
	_check("veg: regresses slowly when gate fails", v2 < v and v2 > v - 0.12)

func _test_recipe() -> void:
	var s := {"purity": 0.99, "oxygen": 0.92, "clarity": 0.4, "invasive": 0.0, "vegetation": 0.0}
	_check("recipe: empty passes", RS.eval_recipe(s, {}))
	_check("recipe: met", RS.eval_recipe(s, {&"purity": 0.98, &"oxygen": 0.9}))
	_check("recipe: one short fails", not RS.eval_recipe(s, {&"purity": 0.98, &"oxygen": 0.95}))

func _test_debris_reachability() -> void:
	# authoring invariant (spec §9 / review I2): every estuary debris spawn must sit within the
	# surface-clamped frog's tongue reach. debris y = surface + 8 + fmod(i*37, 40); frog rides at
	# surface - 2 with 56px reach -> deepest reachable = surface + 54.
	var cfg: CoveConfig = load("res://game/cove/estuary_a.tres")
	var ok := true
	for i in cfg.debris_count:
		var depth := 8.0 + fmod(float(i) * 37.0, 40.0)   # depth below the surface (mirrors debris_field)
		if depth > 54.0:
			ok = false
	_check("authoring: every estuary debris within frog reach", ok)
```

- [ ] **Step 3: Run to verify failure** (preload of reach_state.gd fails — file absent). Expected: script load error.

- [ ] **Step 4: Implement.** Create `game/cove/reach_state.gd`:

```gdscript
extends Node2D
## The RESTORATION ENGINE (Living Watershed slice 2): five ecological variables derived from the
## systems that already run the cove — the oil mask (purity), the "grabbable" choke load (oxygen,
## cleared via the frog), the invasive school (clarity cap — the pre-otter teased lock), and a
## gated vegetation growth value. Health = the blend normalized over the CONFIG's in-play set, so
## a reach's meter only counts variables its player can actually move (the hub stays byte-identical
## to the old cleanliness meter). Authoritative recompute on a 2Hz poll (pest buzz-off emits no
## signal); cleanliness signals poke it for instant response. Emits state_changed; the banner and
## the meter pips read it. No per-frame work, no saves (the sources already persist).

const POLL_HZ := 2.0
const WEIGHTS := { &"purity": 0.7, &"oxygen": 0.3, &"clarity": 0.2, &"invasive": 0.1, &"vegetation": 0.1 }
const STIR_PER_FISH := 0.12    # each live invasive caps clarity by this much
const VEG_GROW_SECS := 20.0    # gate held -> vegetation 0..1 over this long
const VEG_REGRESS := 0.25      # regression rate as a fraction of growth rate

signal state_changed(state: Dictionary)

var _cfg: CoveConfig
var _veg := 0.0
var _poll_t := 0.0
var _last: Dictionary = {}

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	add_to_group("reach_state")
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_signal("cleanliness"):
		mgr.cleanliness.connect(func(_v: float) -> void: _recompute())

func _process(delta: float) -> void:
	if _cfg == null:
		return
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 1.0 / POLL_HZ
		_veg = veg_step(_veg, _veg_gate_ok(), 1.0 / POLL_HZ)
		_recompute()

# --- pure math (static, headless-testable) ---

static func blend_health(state: Dictionary, in_play: Array) -> float:
	var num := 0.0
	var den := 0.0
	for key in in_play:
		var w: float = WEIGHTS.get(key, 0.1)
		num += w * float(state.get(key, 1.0))
		den += w
	return num / den if den > 0.0 else 1.0

static func clarity_cap(invasives_alive: int) -> float:
	return clampf(1.0 - STIR_PER_FISH * float(invasives_alive), 0.0, 1.0)

static func veg_step(veg: float, gate_ok: bool, delta: float) -> float:
	var rate := delta / VEG_GROW_SECS
	return clampf(veg + rate if gate_ok else veg - rate * VEG_REGRESS, 0.0, 1.0)

static func eval_recipe(state: Dictionary, recipe: Dictionary) -> bool:
	for key in recipe:
		if float(state.get(key, 0.0)) < float(recipe[key]):
			return false
	return true

# --- live derivation ---

func get_state() -> Dictionary:
	if _last.is_empty():
		_recompute()
	return _last

func health() -> float:
	return float(get_state().get("health", 0.0))

## The config win recipe against the live state — the &"purity" key reads win_threshold (single
## source of truth with the legacy gate).
func recipe_met() -> bool:
	var recipe := {}
	if _cfg.win_recipe.is_empty():
		recipe[&"purity"] = _cfg.win_threshold
	else:
		for key in _cfg.win_recipe:
			recipe[key] = _cfg.win_threshold if key == &"purity" else _cfg.win_recipe[key]
	return eval_recipe(get_state(), recipe)

func _veg_gate_ok() -> bool:
	var s := _last
	if s.is_empty():
		return false
	if _cfg.vegetation_gate == "clarity":
		return float(s.get("clarity", 0.0)) >= 0.7 and float(s.get("purity", 0.0)) >= 0.8
	return float(s.get("purity", 0.0)) >= 0.7

func _recompute() -> void:
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	var purity: float = mgr.current_clean if mgr and "current_clean" in mgr else 0.0
	var choke_total := _cfg.debris_count + _cfg.pest_count
	var choke_alive := get_tree().get_nodes_in_group("grabbable").size()
	var oxygen := 1.0 if choke_total == 0 else clampf(1.0 - float(choke_alive) / float(choke_total), 0.0, 1.0)
	var fish_alive := get_tree().get_nodes_in_group("invasive").size()
	var invasive := 1.0 if _cfg.invasive_count == 0 else clampf(1.0 - float(fish_alive) / float(_cfg.invasive_count), 0.0, 1.0)
	var state := {
		"purity": purity, "oxygen": oxygen, "clarity": clarity_cap(fish_alive),
		"invasive": invasive, "vegetation": _veg,
	}
	state["health"] = blend_health(state, _cfg.in_play)
	if _last.is_empty() or _dirty(state):
		_last = state
		state_changed.emit(state)
	else:
		_last = state

func _dirty(s: Dictionary) -> bool:
	for k in s:
		if absf(float(s[k]) - float(_last.get(k, -1.0))) > 0.002:
			return true
	return false
```

- [ ] **Step 5: Run tests → ALL PASS; parse gate + WorldState suite clean.**

- [ ] **Step 6: Commit:** `git add game/cove/reach_state.gd tests/test_reach_state.gd game/cove/cove_config.gd` → `git commit -m "feat: reach_state engine - variables, normalized health, recipes (headless-tested)"` (include generated `.uid` files if created).

---

### Task 2: Injection + restored-spawn skip + reach configs

**Files:**
- Modify: `game/cove/cove.tscn` (ReachState node), `game/cove/cove.gd` (inject line), `game/cove/debris_field.gd`, `game/cove/pest_field.gd`, `game/cove/estuary_a.tres`

**Interfaces:** Consumes Task 1. Produces: a live `"reach_state"` node in every cove.

- [ ] **Step 1:** `cove.tscn`: add ext_resource `[ext_resource type="Script" path="res://game/cove/reach_state.gd" id="43_reach"]` after `42_curios`; add after the `Curios` node block:

```ini
[node name="ReachState" type="Node2D" parent="."]
script = ExtResource("43_reach")
```

- [ ] **Step 2:** `cove.gd` `_ready()`: add `_inject($ReachState)` immediately after `_inject($Curios)`.

- [ ] **Step 3 (spec C2):** In `debris_field.gd` `setup()`, replace the guard `if cfg.debris_count <= 0:` block opener with:

```gdscript
	if cfg.debris_count <= 0 or WorldState.is_restored(cfg.id):
		return   # a RESTORED reach reloads restored: no chokes respawn (spec review C2)
```

In `pest_field.gd` `setup()`, replace `set_process(cfg.pest_count > 0)` with:

```gdscript
	set_process(cfg.pest_count > 0 and not WorldState.is_restored(cfg.id))
```

- [ ] **Step 4:** `estuary_a.tres`: after `curios = ...` add:

```ini
invasive_count = 5
in_play = Array[StringName]([&"purity", &"oxygen"])
win_recipe = {
&"oxygen": 0.9,
&"purity": 0.98
}
```

(Hub gets nothing — defaults are the legacy behavior.)

- [ ] **Step 5:** Parse gate + both suites. **Step 6: Commit** (`feat: reach_state wired into the coves; restored reaches skip choke spawns`).

---

### Task 3: Banner reads recipes (+ the asterisk subline)

**Files:**
- Modify: `game/cove/restoration_banner.gd`

**Interfaces:** Consumes `reach_state.recipe_met()` + `state_changed`. Companion/vent ANDs unchanged.

- [ ] **Step 1:** In `_ready()`, after the existing `mgr.cleanliness.connect(_on_clean)` wiring, add:

```gdscript
	_wire_reach.call_deferred()   # reach_state is a sibling: connect after the tree settles

func _wire_reach() -> void:
	var rs = get_tree().get_first_node_in_group("reach_state")
	if rs and rs.has_signal("state_changed"):
		rs.state_changed.connect(func(_s: Dictionary) -> void: _check_restored())
```

- [ ] **Step 2:** In `_check_restored()`, replace the cleanliness threshold check

```gdscript
	if _last_clean < _win_threshold():
		return
```

with:

```gdscript
	var rs = get_tree().get_first_node_in_group("reach_state")
	if rs and rs.has_method("recipe_met"):
		if not rs.recipe_met():
			return                      # the reach's full recipe (config win_recipe) gates the win
	elif _last_clean < _win_threshold():
		return                          # legacy fallback while reach_state is absent
```

- [ ] **Step 3 (asterisk):** In `_build()`, the subline label `sub.text = "the water runs clear again"` — replace the assignment with:

```gdscript
	sub.text = "the water runs clear again"
	_water_sub = sub                    # swapped at celebrate-time if shadows still school
```

Add `var _water_sub: Label` beside the other vars, and in `_celebrate()` after `is_restored = true` add:

```gdscript
	if not get_tree().get_nodes_in_group("invasive").is_empty():
		_water_sub.text = "the water runs clear — but shadows still school in the deep"
```

- [ ] **Step 4:** Parse gate + suites. **Step 5: Commit** (`feat: win gate reads the reach recipe; restored-with-an-asterisk subline`).

---

### Task 4: The invasive school + encounter card

**Files:**
- Create: `game/cove/invasive_school.gd`
- Modify: `game/cove/cove.tscn` (node + ext_resource `44_school`), `game/cove/cove.gd` (inject after ReachState), `game/log/field_guide.gd` (encounter card + type), `game/cove/curio_field.gd` (public `show_card`)

**Interfaces:** Consumes config `invasive_count`, group `"curio_cards"` → `show_card(card: Dictionary)`. Produces group `"invasive"` (one member per live fish — reach_state counts it).

- [ ] **Step 1:** `field_guide.gd`: add to `CARDS`:

```gdscript
	"enc_estuary_school": {
		"name": "Shadow in the Water",
		"species": "Oreochromis / Cyprinus — introduced",
		"fact": "Tilapia and carp were released here in the 1970s as a food program. They eat eggs and stir the silt — most of what swims these canals now was never meant to.",
		"icon": 1,
		"type": "encounter",
	},
```

and change `count_for()`'s accumulation line to skip encounters:

```gdscript
		if (k as String).begins_with(cove_id + "_") and CARDS[k].get("type", "curio") == "curio":
```

- [ ] **Step 2:** `curio_field.gd`: register the card group + expose the popup. In `setup()` after `_build_card()` add `add_to_group("curio_cards")`. Extract the card-filling block of `_on_collected` into:

```gdscript
## Show any Field Guide card (curios use it; the invasive school's encounter card too).
func show_card(card: Dictionary, tally_text: String) -> void:
	_title.text = card["name"]
	_species.text = card["species"]
	_fact.text = card["fact"]
	_tally.text = tally_text
	_card_t = CARD_HOLD
	Sfx.play("ui_open", -10.0)
```

and have `_on_collected` call `show_card(card, "field guide — %d of %d found in this reach" % [maxi(found, 1), total])`.

- [ ] **Step 3:** Create `game/cove/invasive_school.gd`:

```gdscript
extends Node2D
## The INVASIVE SCHOOL — murky tilapia/carp stand-ins patrolling the deep (Living Watershed §3.5,
## slice-2 ambient form). The pollution's living face and the pre-otter Clarity cap: shy (eases
## away from the axolotl — cozy, never a threat), scattered briefly by spray but never removed —
## your current verbs visibly don't solve this. Each fish joins group "invasive" (reach_state
## counts them). First close approach shows the "Shadow in the Water" encounter card (echo-safe,
## WorldState-marked once). Art: the Smolque goldfish (a domesticated carp), murk-tinted.

const FISH_TEX := preload("res://assets/critters/goldfish.png")
const FieldGuide := preload("res://game/log/field_guide.gd")

const SHY_DIST := 70.0        # eases away inside this
const SCATTER_TIME := 1.6
const ENCOUNTER_DIST := 90.0

var _cfg: CoveConfig
var _fish: Array = []          # per fish: {node, anchor: Vector2, phase: float, scatter: float}
var _t := 0.0
var _met := false

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.invasive_count <= 0:
		queue_free()
		return
	add_to_group("sprayable")   # custom spray_at: scatter, never delete
	z_index = 6
	_met = bool(WorldState.get_cove(cfg.id, "enc_school", false))
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in cfg.invasive_count:
		var s := Sprite2D.new()
		s.texture = FISH_TEX
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.modulate = Palette.LOAM.lerp(Palette.SLATE, 0.55)   # murk-tinted invader
		s.scale = Vector2(1.15, 1.15)                          # a touch bigger than the natives
		s.add_to_group("invasive")
		add_child(s)
		var t := (float(i) + 0.5) / float(cfg.invasive_count)
		var anchor := Vector2(lerpf(cfg.water_left + 80.0, cfg.water_right - 90.0, t),
			cfg.seabed_y - 14.0 - rng.randf_range(0.0, 10.0))
		s.position = anchor
		_fish.append({"node": s, "anchor": anchor, "phase": rng.randf_range(0.0, TAU), "scatter": 0.0})

func _process(delta: float) -> void:
	_t += delta
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	var axo_local := to_local(axo.global_position) if axo else Vector2(-9999, 0)
	for f in _fish:
		var s: Sprite2D = f["node"]
		f["scatter"] = maxf(0.0, f["scatter"] - delta)
		var target: Vector2 = f["anchor"] + Vector2(sin(_t * 0.7 + f["phase"]) * 26.0, sin(_t * 1.1 + f["phase"]) * 5.0)
		var away := s.position - axo_local
		if away.length() < SHY_DIST:                    # shy: ease away from the tidekeeper
			target += away.normalized() * (SHY_DIST - away.length())
		if f["scatter"] > 0.0:                          # sprayed: dart wide, then re-gather
			target += Vector2(sin(f["phase"] * 7.0) * 60.0, -12.0)
		s.position = s.position.lerp(target, clampf((3.0 if f["scatter"] > 0.0 else 1.2) * delta, 0.0, 1.0))
		s.flip_h = target.x < s.position.x
	# the encounter: first time the tidekeeper comes close, the log meets the antagonist
	if not _met and axo and _fish.size() > 0:
		var s0: Sprite2D = _fish[0]["node"]
		if axo_local.distance_to(s0.position) < ENCOUNTER_DIST:
			_met = true
			var root := get_tree().get_first_node_in_group("cove_root")
			if root == null or not root.has_method("is_echo") or not root.is_echo():
				WorldState.mark(_cfg.id, "enc_school", true)
			var card: Dictionary = FieldGuide.card("enc_estuary_school")
			get_tree().call_group("curio_cards", "show_card", card, "field guide — encounter logged")

## Spray scatters the school for a beat — and that's all it does (the otter herds them, slice 6).
func spray_at(world_pos: Vector2, _radius: float, _delta: float) -> void:
	for f in _fish:
		var s: Sprite2D = f["node"]
		if s.global_position.distance_to(world_pos) < 46.0:
			f["scatter"] = SCATTER_TIME
```

- [ ] **Step 4:** `cove.tscn`: ext_resource `44_school` for the script; node `InvasiveSchool` (Node2D, script `44_school`) after `ReachState`; `cove.gd`: `_inject($InvasiveSchool)` after `_inject($ReachState)`.
  **Check the goldfish path first:** `assets/critters/goldfish.png` must exist (it shipped with the Smolque school). If the actual filename differs (e.g. under a subfolder), use the real path and note it.

- [ ] **Step 5:** Parse gate + suites. **Step 6: Commit** (`feat: the invasive school - shy murky shadows cap the marsh's clarity (encounter card)`).

---

### Task 5: Meter pips (+ Health main bar, minis stay honest)

**Files:**
- Modify: `game/hud/restoration_meter.gd`

**Interfaces:** Consumes `reach_state` group (`get_state()`, `state_changed`) and existing cleanliness wiring.

- [ ] **Step 1:** Read the file first. It currently drives everything from the cleanliness value it receives. Changes:
  1. Keep the existing cleanliness subscription driving the kelp/fish MINI-gauges exactly as today (review I4).
  2. The MAIN bar value switches to `reach_state.health()` — subscribe to `state_changed` (deferred group lookup like the banner) and store `_health`; where the main bar reads the old value, read `_health` when a reach_state exists, else the legacy value.
  3. Add four PIPS under the bar (code-drawn, ~10px): purity (CYAN), oxygen (LEAF), clarity (MIST), vegetation (GREEN) — each a small arc that fills with its variable; skip pips whose variable isn't meaningful (draw clarity/vegetation at 40% alpha when not in `in_play` — the tease reads dimmed, not absent). Redraw at most on `state_changed` (the engine already rate-limits to 2Hz + 0.002 deltas).
- [ ] **Step 2:** Parse gate + suites; hub visual check deferred to Task 7 (main bar must read identically — in_play=[purity] makes health≡cleanliness by construction).
- [ ] **Step 3: Commit** (`feat: variable pips under the meter; main bar reads reach health`).

---

### Task 6: Reclaim tokens (barrel → material)

**Files:**
- Create: `game/cove/reclaim_token.gd`
- Modify: `game/cove/leak_source.gd` (in `_purify()`), `game/cove/shore_pollution.gd` (in `_purify_barrel()`), `game/hud/shine_hud.gd` (tally)

**Interfaces:** Consumes `WorldState.mark/get_cove`, `cove_root.is_echo()`. Produces per-cove `material` int in WorldState.

- [ ] **Step 1:** Create `game/cove/reclaim_token.gd`:

```gdscript
extends Node2D
## A RECLAIM — cleaned barrel metal, the seed of the §3.6 economy: pollution becomes the material
## the refugio will be built from (spending lands with the otter's Build, slice 6; this banks it).
## Floats up from a purified barrel, bobs, collected by touch: material +1 for this reach
## (WorldState, echo-guarded). Drawn, Apollo, self-contained.

const COLLECT_REACH := 16.0
const RISE := 26.0

var _t := 0.0
var _rise := 0.0

func _ready() -> void:
	z_index = 7

func _process(delta: float) -> void:
	_t += delta
	_rise = minf(RISE, _rise + delta * 30.0)
	queue_redraw()
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	if axo and axo.global_position.distance_to(global_position + Vector2(0, -_rise)) <= COLLECT_REACH:
		_collect()

func _collect() -> void:
	set_process(false)
	var root := get_tree().get_first_node_in_group("cove_root")
	if root and "config" in root:
		var id: String = root.config.id
		if not (root.has_method("is_echo") and root.is_echo()):
			WorldState.mark(id, "material", int(WorldState.get_cove(id, "material", 0)) + 1)
		get_tree().call_group("shine_hud", "flash_material", int(WorldState.get_cove(id, "material", 0)))
	Sfx.play("chime", -8.0, 0.9)
	queue_free()

func _draw() -> void:
	var p := Vector2(0.0, -_rise + sin(_t * 2.0) * 2.0)
	draw_arc(p, 6.0, 0.0, TAU, 16, Palette.STEEL, 2.5, true)     # a cleaned barrel ring
	draw_arc(p, 6.0, -0.9, 0.6, 8, Palette.FOAM, 1.5, true)      # glint
	draw_circle(p, 8.5, Color(Palette.GOLD, 0.10))               # soft find-me glow
```

- [ ] **Step 2:** `leak_source.gd` `_purify()` — after the `keeper` feat block (near `_purify_fx(self, Vector2(0.0, -16.0))`), add:

```gdscript
	var tok := preload("res://game/cove/reclaim_token.gd").new()
	tok.position = (get_parent() as Node2D).to_local(global_position)
	get_parent().add_child(tok)   # survives this node's later retirement
```

`shore_pollution.gd` `_purify_barrel(b)` — after the `keeper.feat(&"spring_clean", ...)` line, add:

```gdscript
	var tok := preload("res://game/cove/reclaim_token.gd").new()
	tok.position = to_local(s.global_position)
	add_child(tok)
```

- [ ] **Step 3:** `shine_hud.gd`: read the file; add `add_to_group("shine_hud")` in its ready, a small `_material := 0` + `flash_material(n: int)` that sets the count and pops a brief highlight, and draw/label "⬡ n" (a barrel-ring glyph + count) beside the Shine orb only when `_material > 0`. On scene load, initialize from `WorldState.get_cove(WorldState.current_id, "material", 0)`.
- [ ] **Step 4:** Parse gate + suites. **Step 5: Commit** (`feat: Reclaim tokens - purified barrels bank build material`).

---

### Task 7: Verify + deploy

- [ ] Both suites ALL PASS; import scan clean.
- [ ] Export Web + deploy (`vercel deploy build/lilaxol --prod --scope marios-projects-481b4b4e --yes`) + push.
- [ ] Manual checklist (user): hub meter opens at 0 and plays identically; estuary won't restore until ≥4 chokes cleared (frog required); school scatters/re-gathers, encounter card once; pips read; asterisk subline on marsh win; Reclaims collect + tally persists; restored marsh reloads healthy (no chokes).

## Deliberate scope cuts (do NOT "fix")
Spec §10 verbatim: no algae mats, no clarity/invasive resolution, no tooltips/log UI, no material spending or stall mechanics, eelgrass visual deferred to the art slice.
Plan-level cut vs spec §8: the exit-time `vars` snapshot is dropped — reach_state recomputes within 0.5s of load and the hub's health ≡ cleanliness by construction, so first-frame smoothing buys nothing; `material` is the only new persisted key.
