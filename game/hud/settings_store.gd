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

func bus_volume(bus: String) -> float:
	return clampf(_cfg.get_value("audio", bus, 1.0), 0.0, 1.0)

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
