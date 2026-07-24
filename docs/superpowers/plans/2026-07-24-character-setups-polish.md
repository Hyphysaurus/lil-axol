# Character Setups Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rescues become moments, joining never steals the active partner (D-0019), followers gain presence, and CompanionLibrary becomes the one-record character path — per `docs/superpowers/specs/2026-07-24-character-setups-polish-design.md`.

**Architecture:** Four bounded tasks: (1) the D-0019 ruling + the library's full character records + a headless lint suite; (2) the RescueCard ceremony layer + wake pop; (3) chip glint + swap-teach hint; (4) follow presence (mirrored spring slots, idle variety, face-the-player). All verification headless (Maram pre-authorized the autonomous run).

**Tech Stack:** Godot 4.7 GL Compatibility, GDScript. No new dependencies.

## Global Constraints

- No movement-tuning changes (D-0003); companion `FOLLOW_SPEED`/`FOLLOW_GAP`/lift constants untouched; the >300px re-fan hard snap at `companion.gd:346-348` STAYS.
- No runtime fractional scaling of pixel art (library `scale` stays 1.0).
- New scripts use the preload pattern, NOT `class_name`.
- Palette discipline: any new color = `Palette.*` swatch, never a literal; UI panels via `UiTheme`.
- New HUD layers must join `cove.gd`'s `KEEP_AT_ROOT` (the pixel shell pulls everything else into the world viewport).
- Autoload wall: headless `--script` tests must never reference `Settings`/`WorldState` as bare identifiers — instantiate `settings_store.gd` fresh via `load()` instead.
- All 12 existing suites + the new suite green after every task; boot lint (`--quit-after 180`) shows nothing beyond the known MetSys line.
- Godot binary: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`; run from the project root; quote paths (spaces). Suite loop gates on the printed `RESULT` line, NOT `$LASTEXITCODE` (unreliable under redirection in this sandbox).
- SPEC CORRECTION (verified in code): sleeping-friend "zzz motes" already exist (`companion.gd _make_zzz`, emitting while asleep, stopped on wake) — that spec item is DONE, do not re-add.

**Facts** (verified 2026-07-24): `Settings.roster_add` (`game/hud/settings_store.gd:35-38`) unconditionally sets `run_active = kind` — the D-0019 steal. `roster_include` (`:46-50`) already has the polite semantics. `partner_hud.gd` rebuilds chips on `Settings.roster_changed`; chip tooltip reads `Library.NAMES`. `companion.gd:218-248` `_wake()` fires fright anim → `wake_up` feat → (dragonfly card) → `Settings.roster_add` → `woke.emit()`. Follow motion applies at `companion.gd:329` (slot target) and `:366` (lerp); `_spr.scale` settles via `:385`; `anims.idle_blink` exists on every CharacterAnimSet (frog maps it to croak).

---

### Task 1: D-0019 no-steal + CompanionLibrary records + lint suite

**Files:**
- Modify: `game/hud/settings_store.gd:35-38` (roster_add)
- Modify: `game/companion/companion_library.gd` (INFO records; NAMES retired)
- Modify: `game/hud/partner_hud.gd:65` (tooltip reads INFO)
- Test: `tests/test_companion_library.gd` (new)

**Interfaces:**
- Produces: `Library.INFO: Dictionary` — `kind:int -> {"name": String, "species": String, "verb_name": String, "verb_teach": String}`; `static func info(kind: int) -> Dictionary` (empty Dictionary for unknown kinds). Tasks 2–3 consume `info()`.
- Produces: `Settings.roster_add(kind)` that no longer steals (claims active only when `run_active == -1`).

- [ ] **Step 1: Write the failing test** — `tests/test_companion_library.gd`:

```gdscript
extends SceneTree
## Headless lint for the character record (companion_library INFO + art) and the D-0019
## no-steal roster ruling. Settings is an AUTOLOAD — under --script it is not compile-visible,
## so the roster checks instantiate settings_store.gd fresh via load() (pure state math).
## Run: & $godot --headless --path . --script res://tests/test_companion_library.gd

const Library := preload("res://game/companion/companion_library.gd")

var _fails := 0

func _init() -> void:
	_test_art()
	_test_info()
	_test_no_steal()
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _test_art() -> void:
	for kind in Library.ART:
		var row: Dictionary = Library.ART[kind]
		var frames := row["frames"] as SpriteFrames
		_check("kind %d frames load" % kind, frames != null and frames.get_animation_names().size() > 0)
		_check("kind %d anims load" % kind, row["anims"] != null)
		_check("kind %d integer scale" % kind, is_equal_approx(float(row["scale"]), 1.0))

func _test_info() -> void:
	const VERBLESS := [2]   # otter: verb lands with slice 6
	for kind in Library.ART:
		var info := Library.info(kind)
		_check("kind %d has info" % kind, not info.is_empty())
		_check("kind %d name" % kind, info.get("name", "") != "")
		_check("kind %d species" % kind, info.get("species", "") != "")
		if not kind in VERBLESS:
			_check("kind %d verb_name" % kind, info.get("verb_name", "") != "")
			_check("kind %d verb_teach" % kind, info.get("verb_teach", "") != "")
	_check("unknown kind -> empty", Library.info(99).is_empty())

func _test_no_steal() -> void:
	var s: Node = (load("res://game/hud/settings_store.gd") as GDScript).new()
	s.roster_add(0)
	_check("first rescue claims the empty slot", s.run_active == 0)
	s.roster_add(1)
	_check("second rescue joins the roster", s.run_roster == [0, 1] as Array[int])
	_check("D-0019: second rescue does NOT steal active", s.run_active == 0)
	s.roster_add(1)
	_check("re-rescue is idempotent", s.run_roster == [0, 1] as Array[int] and s.run_active == 0)
	s.free()
```

- [ ] **Step 2: Run to verify it fails**
Run: `& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://tests/test_companion_library.gd`
Expected: FAIL lines for `has info` (no `INFO`/`info()` yet) and `does NOT steal active` (current roster_add steals).

- [ ] **Step 3: Implement.** In `game/hud/settings_store.gd`, keep the function's existing `roster_changed` emit exactly as it is today and change only the active-claim:

```gdscript
func roster_add(kind: int) -> void:
	if not run_roster.has(kind):
		run_roster.append(kind)
	if run_active == -1:
		run_active = kind   # D-0019: joining NEVER steals the active slot; claim only when alone
	# (keep whatever emit follows in the current body — the chips HUD rebuilds off it)
```

In `game/companion/companion_library.gd`, replace the `NAMES` const with the full record + accessor (keep `ART` and `has_kind` untouched):

```gdscript
## The one-record character sheet (spec D, 2026-07-24): everything a UI needs to introduce a
## partner. RescueCard + chips + hints all read from here — author a character ONCE.
## verb_name/verb_teach stay "" for kinds whose verb hasn't shipped (otter -> slice 6).
const INFO := {
	0: { "name": "Tola", "species": "Mexican mud turtle", "verb_name": "Shell Spin",
		"verb_teach": "Hold the SPIN button to pilot the spinning shell through rubble." },
	1: { "name": "Meno", "species": "Montezuma leopard frog", "verb_name": "Tongue Snap",
		"verb_teach": "Keep Meno near floating debris — the tongue does the rest." },
	2: { "name": "Nutria", "species": "Neotropical river otter", "verb_name": "",
		"verb_teach": "" },
	3: { "name": "Zuni", "species": "Great darner dragonfly", "verb_name": "Survey",
		"verb_teach": "Press the SPIN button to sweep the reach and reveal what hides." },
}

static func info(kind: int) -> Dictionary:
	return INFO.get(kind, {})
```

In `game/hud/partner_hud.gd:65`, the tooltip line becomes:

```gdscript
		tooltip_text = str(Library.info(kind).get("name", "?"))
```

(Remove the now-unreferenced `NAMES` const; grep `Library.NAMES` first — `partner_hud.gd` is the only consumer today; if another appears, convert it the same way.)

- [ ] **Step 4: Run to verify it passes** — same command, expect `RESULT: ALL PASS`, exit 0. Then run the full suite loop (all `tests/test_*.gd`, gate on RESULT lines) + boot lint.

- [ ] **Step 5: Commit**
```bash
git add game/hud/settings_store.gd game/companion/companion_library.gd game/hud/partner_hud.gd tests/test_companion_library.gd
git commit -m "feat(chars): D-0019 rescues never steal the active slot + CompanionLibrary character records + lint suite"
```

---

### Task 2: RescueCard ceremony + wake pop

**Files:**
- Create: `game/hud/rescue_card.gd`
- Modify: `game/cove/cove.tscn` (ext_resource + one CanvasLayer node in the HUD block)
- Modify: `game/cove/cove.gd` (KEEP_AT_ROOT + one `_inject` line)
- Modify: `game/companion/companion.gd:218-241` (`_wake`: card group-call + wake pop)

**Interfaces:**
- Consumes: `Library.info(kind)` from Task 1.
- Produces: group `"rescue_card"` with method `show_rescue(kind: int)`.

- [ ] **Step 1: Write `game/hud/rescue_card.gd`** (hints.gd's toast pattern, non-blocking):

```gdscript
extends CanvasLayer
## The Waking (spec A, 2026-07-24): a rescue deserves a MOMENT. Non-blocking bottom-center
## card — "<Name> the <Species> joins you!" + the verb teach — that fades in on a friend's
## wake and melts away. Fired via group "rescue_card" from companion._wake(); reads everything
## from CompanionLibrary.info() (one-record character sheet). Travellers arriving already
## rescued never fire it. Styled with UiTheme; never locks input.

const Library := preload("res://game/companion/companion_library.gd")
const HOLD := 4.0
const FADE := 0.4

var _root: Control
var _title: Label
var _teach: Label
var _timer := 0.0
var _fade := 0.0

func _ready() -> void:
	layer = 94                 # over hints (93), under the restoration banner (95)
	add_to_group("rescue_card")
	_build()

func setup(_cfg) -> void:
	pass                       # injection no-op: the card is stateless, config-free

## The ceremony entry point (group-called from companion._wake()).
func show_rescue(kind: int) -> void:
	var info := Library.info(kind)
	if info.is_empty():
		return
	_title.text = "%s the %s joins you!" % [info["name"], info["species"]]
	var teach: String = info.get("verb_teach", "")
	_teach.text = teach
	_teach.visible = teach != ""
	_timer = HOLD
	Sfx.play("chime", -6.0, 1.2)

func _process(delta: float) -> void:
	var target := 0.0
	if _timer > 0.0:
		_timer -= delta
		target = 0.0 if Settings.ui_locked() else 1.0
	_fade = move_toward(_fade, target, delta / FADE)
	_root.modulate.a = _fade
	_root.visible = _fade > 0.01

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -128.0            # a row above the hints toast (-74) so both can show
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.panel())
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 27)
	_title.add_theme_color_override("font_color", Color(Palette.GOLD))
	_title.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.9))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(_title)
	_teach = Label.new()
	_teach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_teach.add_theme_font_size_override("font_size", 21)
	_teach.add_theme_color_override("font_color", Color(Palette.FOAM))
	_teach.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.9))
	_teach.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(_teach)
```

- [ ] **Step 2: Wire the scene + shell.** In `game/cove/cove.tscn`: add `[ext_resource type="Script" path="res://game/hud/rescue_card.gd" id="49_rescue"]` after id 48, and this node in the HUD block (right after the `Hints` node):

```
[node name="RescueCard" type="CanvasLayer" parent="."]
script = ExtResource("49_rescue")
```

In `game/cove/cove.gd`: append `"RescueCard"` to `KEEP_AT_ROOT`, and add `_inject(_w("RescueCard"))`? — NO: RescueCard stays at the ROOT (not world-side), so inject via the root path: add the line `_inject(get_node_or_null("RescueCard"))` beside the existing `_inject($Hints)`-equivalent root lookups (match how the file handles the three root-side lookups post-shell — plain self-resolution, NOT `_w()`).

- [ ] **Step 3: Fire it from the wake + add the pop.** In `game/companion/companion.gd` `_wake()`, immediately after `Settings.roster_add(_kind)` (line ~240) insert:

```gdscript
	get_tree().call_group("rescue_card", "show_rescue", _kind)   # the Waking ceremony card
	_spr.scale = Vector2(1.35, 0.7)   # wake POP: a big stretch the standard settle eases out
```

(`_spr.scale` settles via the existing lerp at `:385`; `wake_instant()` and `setup_traveller()` are NOT touched — no ceremony for already-rescued spawns.)

- [ ] **Step 4: Gates.** Full suite loop (13 files now) green; boot lint on `--quit-after 180` clean; plus a parse sanity boot of all three wrappers is covered by the main-scene lint.

- [ ] **Step 5: Commit**
```bash
git add game/hud/rescue_card.gd game/cove/cove.tscn game/cove/cove.gd game/companion/companion.gd
git commit -m "feat(chars): the Waking - RescueCard ceremony + wake pop on every live rescue"
```

---

### Task 3: chip glint + swap-teach hint

**Files:**
- Modify: `game/hud/partner_hud.gd` (glint on newly joined chips)
- Modify: `game/hud/hints.gd` (`_check_triggers` swap teach)

**Interfaces:** consumes nothing new; no producers.

- [ ] **Step 1: Glint.** In `partner_hud.gd`: track seen kinds and pass freshness into chips —

```gdscript
var _seen: Array[int] = []     # kinds that already had a chip (glint = a kind we've not seen)
```

In `_refresh()`, replace the chip-add loop with:

```gdscript
	for kind in Settings.run_roster:
		if Library.has_kind(kind):
			_chips.add_child(Chip.new(kind, kind == Settings.run_active, not _seen.has(kind)))
			if not _seen.has(kind):
				_seen.append(kind)
```

In `class Chip`: add `var _glint_t := 0.0`, extend the constructor signature to `_init(kind: int, active: bool, fresh: bool = false)` with `_glint_t = 3.0 if fresh else 0.0`, and at the TOP of `_process` (before the `if not _active: return` early-out) add:

```gdscript
		if _glint_t > 0.0:
			_glint_t -= delta
			queue_redraw()
```

At the end of `_draw()` add:

```gdscript
		if _glint_t > 0.0:
			var pulse := 0.5 + 0.5 * sin(_glint_t * 9.0)
			draw_arc(c, CHIP * 0.5 + 4.0, 0.0, TAU, 32,
				Color(Palette.GOLD, 0.25 + 0.55 * pulse), 2.0, true)
```

- [ ] **Step 2: Swap teach.** In `hints.gd` `_check_triggers()` (after the existing "command" nudge) add:

```gdscript
		# two rescued friends = the swap becomes real; teach the chips exactly once
		if Settings.run_roster.size() >= 2:
			nudge("swap", "Two friends travel with you now! Tap a partner chip (top-left) to choose who's active.")
```

- [ ] **Step 3: Gates.** Full suite loop green (no suite exercises the HUD — this is a parse/boot gate); boot lint clean.

- [ ] **Step 4: Commit**
```bash
git add game/hud/partner_hud.gd game/hud/hints.gd
git commit -m "feat(chars): new-partner chip glint + one-time swap teach hint"
```

---

### Task 4: follow presence — mirrored slots + idle variety + face-the-player

**Files:**
- Modify: `game/companion/companion.gd` (slot mirroring at :329; idle branch at :384)

**Interfaces:** consumes nothing new; no producers. Movement constants UNTOUCHED (global constraints).

- [ ] **Step 1: Mirrored spring slots.** The crew currently fans on FIXED offsets — turn the formation with the player. Add near the other follow vars:

```gdscript
var _mirror := 1.0             # smoothed slot mirror: eases toward the player's facing so the
                               # crew re-fans BEHIND the tidekeeper on turns instead of snapping
```

At `:329`, replace the target line with:

```gdscript
	var p_face := (axo._face as float) if "_face" in axo else 1.0
	_mirror = move_toward(_mirror, signf(p_face), 3.0 * delta)
	var slot := SLOT_OFFSETS[_slot]
	var target := (get_parent() as Node2D).to_local(axo.global_position) \
		+ Vector2(0.0, lift) + Vector2(slot.x * -_mirror * signf(p_face) if false else slot.x * _mirror, slot.y)
```

WAIT — that expression is wrong; use exactly:

```gdscript
	var p_face := (axo._face as float) if "_face" in axo else 1.0
	_mirror = move_toward(_mirror, signf(p_face), 3.0 * delta)
	var slot := SLOT_OFFSETS[_slot]
	var target := (get_parent() as Node2D).to_local(axo.global_position) \
		+ Vector2(0.0, lift) + Vector2(slot.x * _mirror, slot.y)
```

(The authored offsets assume a RIGHT-facing player; `* _mirror` flips the fan to trail a
left-facing one, eased so turns glide. `_mirror` starts at 1.0 = today's layout.)

- [ ] **Step 2: Idle variety + face the player.** Add near the other timers:

```gdscript
var _idle_beat := 0.0          # staggered idle-variety timer (blink/croak) — offset per slot
```

Replace the final `else` idle branch at `:384` (`_anims.play(anims.swim_idle if in_water else anims.idle, _face)`) with:

```gdscript
			else:
				# PRESENCE: settled followers look AT the tidekeeper and blink/croak on their own
				# staggered beat (slot-offset so the crew never syncs like a metronome)
				if absf(gap.x) < 60.0:
					_face = signf((axo.global_position.x - global_position.x)) if absf(axo.global_position.x - global_position.x) > 6.0 else _face
				_idle_beat -= delta
				if _idle_beat <= 0.0:
					_idle_beat = 3.2 + float(_slot) * 0.9 + randf() * 1.6
					_anims.play(anims.idle_blink, _face)
				elif _anims.current() != anims.idle_blink or _anims.finished():
					_anims.play(anims.swim_idle if in_water else anims.idle, _face)
```

CAUTION: `_anims` is the shared AnimationController — check its API first (`game/` grep for
`class AnimationController`): if it has no `current()`/`finished()` reads, use this simpler
form instead (blink clips loop back visually anyway since `_anims.play` restarts on change):

```gdscript
			else:
				if absf(axo.global_position.x - global_position.x) > 6.0 and absf(gap.x) < 60.0:
					_face = signf(axo.global_position.x - global_position.x)
				_idle_beat -= delta
				if _idle_beat <= 0.0:
					_idle_beat = 3.2 + float(_slot) * 0.9 + randf() * 1.6
					_blink_t = 0.7                        # the blink owns the sprite briefly
					_anims.play(anims.idle_blink, _face)
				_blink_t = maxf(0.0, _blink_t - delta)
				if _blink_t <= 0.0:
					_anims.play(anims.swim_idle if in_water else anims.idle, _face)
```

(adding `var _blink_t := 0.0` beside `_idle_beat`). Pick whichever matches the real
AnimationController API; the `_blink_t` form needs no new API.

- [ ] **Step 3: Gates.** Full suite loop green — `test_companion_survey.gd` and
`test_dragonfly_handoff.gd` exercise companion.gd headless and will catch parse/logic breaks;
boot lint clean.

- [ ] **Step 4: Commit**
```bash
git add game/companion/companion.gd
git commit -m "feat(chars): follow presence - mirrored formation, staggered idle beats, face the tidekeeper"
```

---

### Task 5 (controller): final review, docs, deploy

- [ ] Final whole-branch review (opus) over the four tasks; fix wave if needed.
- [ ] Append **D-0019** to `docs/DECISIONS.md` (house format): rescues never steal the active
  slot; ruled 2026-07-24 during the autonomous character-polish run; supersedes the slice-4
  review's open ruling; softened exactly along the review's proposed lever.
- [ ] STATUS.md: BUILT gains a "Character setups polish" bullet (RescueCard ceremony, D-0019,
  chip glint + swap teach, follow presence, CompanionLibrary one-record path + lint suite).
- [ ] Export Web, `vercel deploy --prod`, verify `target=production status=Ready`, `git push`,
  ledger.

## Plan Self-Review (done at write time)

- Spec coverage: A→T2, B→T1+T3, C→T4 (zzz already built — recorded as spec correction),
  D→T1; docs/deploy→T5. No gaps.
- Placeholders: none; the one deliberately-flagged WAIT block in T4 Step 1 shows the wrong and
  right forms explicitly to prevent a transcription slip; T4 Step 2 offers two complete forms
  gated on a named API check.
- Type consistency: `Library.info(kind) -> Dictionary` used identically in T1/T2;
  `Chip._init(kind, active, fresh := false)` matches its call site; group name
  `"rescue_card"`/`show_rescue(kind)` consistent between T2's card and companion hook.
