extends Node
## Settings — persisted app settings (user://settings.cfg) + tiny session UI state.
## Applies audio bus volumes, window mode, and custom InputMap bindings itself; visual FX
## and the touch overlay pull from here (postfx.gd, touch_controls.gd) so they re-apply
## across scene reloads and future level swaps. Also owns the UI lock: while any menu
## (title / settings / rest card) is up, gameplay treats input as neutral.

signal changed                       # some persisted setting changed; readers re-pull
signal ui_lock_changed(locked: bool)

const PATH := "user://settings.cfg"
const BUSES := ["Master", "SFX", "Ambience", "Music"]
## Rebindable gameplay actions, in menu display order.
const ACTIONS := ["move_left", "move_right", "move_up", "move_down",
	"jump", "run", "spray", "dash", "bubble", "restart"]

var title_shown := false             # session-only: New Day reloads skip the title veil
var run_score := 0.0                 # session-only: the running Shine total, carried across a pathway
                                     # to the next cove (see shine.gd + cove_portal.gd); reset on New Day

# --- the partner ROSTER (session-only, carried across scenes like run_score) ---
# Rescued partners persist for the whole run; ONE is active and travels with you (cozy + readable —
# the roster gives the party fantasy, the single follower keeps the screen calm). Kinds are the
# companion's Kind enum ints (0=Turtle, 1=Frog, 2=Otter). Reset on New Day with the score.
signal roster_changed                # a partner joined or the active partner swapped; HUD re-reads

var run_roster: Array[int] = []      # rescued partner kinds, in rescue order
var run_active := -1                 # the kind travelling with you (-1 = alone)
var arrive_via_portal := false       # session-only: the next scene load is a tunnel crossing — spawn
                                     # the axolotl at the passage mouth, moving, behind an iris reveal
var arrive_entry := ""               # which edge/door we arrive through on a map reach ("" = legacy)

## A partner was rescued: add it to the roster and make it the active traveller (meeting a new
## friend = they join you now; you can swap back to an old friend any time).
func roster_add(kind: int) -> void:
	if not run_roster.has(kind):
		run_roster.append(kind)
	run_active = kind
	roster_changed.emit()

## Register a partner in the roster WITHOUT stealing the active slot — the persistence spawn
## path (re-entering a cove whose friend was rescued on an earlier visit must not undo the
## player's chosen traveller). Becomes active only when nobody is (fresh-session default).
func roster_include(kind: int) -> void:
	var changed := false
	if not run_roster.has(kind):
		run_roster.append(kind)
		changed = true
	if run_active == -1:
		run_active = kind
		changed = true
	if changed:
		roster_changed.emit()

## Swap which rescued partner travels with you. Ignored for kinds you haven't rescued yet.
func roster_swap(kind: int) -> void:
	if run_roster.has(kind) and run_active != kind:
		run_active = kind
		roster_changed.emit()

func roster_reset() -> void:
	run_roster.clear()
	run_active = -1
	roster_changed.emit()

var _cfg := ConfigFile.new()
var _locks := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # settings must work over the rest card's pause
	_cfg.load(PATH)                            # missing file is fine — defaults rule
	_apply_audio()
	_apply_window()
	_apply_bindings()

# --- UI lock (counter, so title -> settings stacking can't unlock early) ---

func push_ui_lock() -> void:
	_locks += 1
	if _locks == 1:
		ui_lock_changed.emit(true)

func pop_ui_lock() -> void:
	_locks = maxi(0, _locks - 1)
	if _locks == 0:
		ui_lock_changed.emit(false)

func ui_locked() -> bool:
	return _locks > 0

## Is the on-screen touch overlay active? One source of truth for the touch controls, the title's
## control legend, the joystick ghost, and the reset ring — touch_mode 0 = auto (has touchscreen),
## 1 = always on, 2 = off. Keeps the "which controls am I showing" test from being copy-pasted.
func touch_active() -> bool:
	var mode: int = get_setting("controls", "touch_mode", 0)
	if mode == 0:                      # AUTO = the PLATFORM, not merely "a touch panel exists"
		return is_touch_platform()
	return mode == 1                   # 1 = always on, 2 = always off

## A genuine touch platform: a native mobile export, or a MOBILE browser (web_android / web_ios).
## A desktop — even a Windows touchscreen laptop or a desktop browser — is NOT a touch platform
## (keyboard + mouse is primary there), so "auto" no longer forces the on-screen controls on next
## to the mouse. This is the auto-detect that recognizes the platform.
func is_touch_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

## True when the mouse is the aiming pointer — spray/bubble aim, the reticle, and the turtle's
## shell-spin steer toward the cursor. Tied to the touch overlay: if the on-screen joystick is up
## (touch platform, or forced on), aim by the joystick instead of the mouse.
func aim_with_mouse() -> bool:
	return not touch_active()

# --- generic persisted values (visual flags, touch mode) ---

func get_setting(section: String, key: String, default: Variant) -> Variant:
	return _cfg.get_value(section, key, default)

func set_setting(section: String, key: String, v: Variant) -> void:
	_cfg.set_value(section, key, v)
	if section == "visual":
		_apply_window()
	_save()
	changed.emit()

# --- audio (stored linear 0..1 per bus) ---

## Softer-than-unity defaults so the mix isn't hot out of the box (user-adjustable in settings).
const DEFAULT_VOL := {"Master": 0.55, "SFX": 0.85, "Ambience": 0.9, "Music": 0.8}

func bus_volume(bus: String) -> float:
	return clampf(_cfg.get_value("audio", bus, DEFAULT_VOL.get(bus, 1.0)), 0.0, 1.0)

## save=false lets sliders apply live every tick without hammering the disk;
## call flush() once on drag-end.
func set_bus_volume(bus: String, v: float, save := true) -> void:
	_cfg.set_value("audio", bus, clampf(v, 0.0, 1.0))
	_apply_audio()
	if save:
		_save()
	changed.emit()

func flush() -> void:
	_save()

func _apply_audio() -> void:
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			# 0.0001 linear ≈ -80 dB — effectively mute without AudioServer complaints
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(bus_volume(b), 0.0001)))

# --- window / display ---

func _apply_window() -> void:
	var full: bool = get_setting("visual", "fullscreen", false)
	var mode := DisplayServer.window_get_mode()
	if full and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not full and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var vsync: bool = get_setting("visual", "vsync", true)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

# --- input bindings (InputEvents serialize straight into the ConfigFile) ---

## Snapshot the live InputMap for the rebindable actions. Called by the settings menu
## after it swaps an event.
func save_bindings() -> void:
	for a in ACTIONS:
		_cfg.set_value("input", a, InputMap.action_get_events(a))
	_save()
	changed.emit()

func reset_bindings() -> void:
	InputMap.load_from_project_settings()
	if _cfg.has_section("input"):
		_cfg.erase_section("input")
	_save()
	changed.emit()

func _apply_bindings() -> void:
	if not _cfg.has_section("input"):
		return
	for a in ACTIONS:
		var events: Variant = _cfg.get_value("input", a, null)
		if events is Array and InputMap.has_action(a):
			InputMap.action_erase_events(a)
			for e in events:
				if e is InputEvent:
					InputMap.action_add_event(a, e)

func _save() -> void:
	_cfg.save(PATH)
