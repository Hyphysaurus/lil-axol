extends CanvasLayer
## Contextual onboarding hints. The cove's objective (scrub the oil until the cove is restored)
## was there but invisible — this makes it APPARENT: one soft bottom-centre toast that states the
## goal up front, then teaches each verb the FIRST time it's relevant (a friend to wake, a leak to
## cap, a bubble bomb charged, rubble the turtle can smash). Every hint fires once per session and
## watches game state through groups, so it never hard-wires another node. Styled with UiTheme so
## it matches every other overlay. Purely a nudge — non-interactive, hidden while a menu is up.

const HOLD := 5.5              # seconds a hint stays before it fades out
const FADE := 0.35            # fade in/out time
const NEAR := 150.0           # how close the player must be for a proximity hint

var _root: Control
var _panel: PanelContainer
var _label: RichTextLabel
var _seen := {}               # id -> true (already nudged this session)
var _queue: Array = []        # pending {id, text}
var _cur := ""
var _timer := 0.0
var _fade := 0.0
var _bubble_hooked := false

func _ready() -> void:
	layer = 93                 # over the meter/HUD, under the banner (95) + menus (97+)
	_build()

## Queue a hint the first time it's asked for. `id` dedupes it for the session.
func nudge(id: String, text: String) -> void:
	if _seen.has(id):
		return
	_seen[id] = true
	_queue.append({"id": id, "text": text})

func _process(delta: float) -> void:
	_lazy_hook_bubble()
	_drive_toast(delta)
	if Settings.title_shown and not Settings.ui_locked():
		_check_triggers()

# --- when to nudge ---

func _check_triggers() -> void:
	# The objective, stated plainly the moment play begins.
	nudge("objective", "Restore the cove! Hold %s to spray and scrub the oil away." % _prompt("spray", "Spray"))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var here := player.global_position
	# A sleeping friend nearby — teach the rescue.
	var friend := get_tree().get_first_node_in_group("companion") as Node2D
	if friend and _asleep(friend) and here.distance_to(friend.global_position) < NEAR:
		nudge("friend", "A friend sleeps here! Spray to wash the oil off and wake them.")
	# The leaking barrel nearby — teach capping it.
	var leak := get_tree().get_first_node_in_group("leak") as Node2D
	if leak and here.distance_to(leak.global_position) < NEAR:
		nudge("leak", "That red barrel keeps leaking oil. Spray it to cap the leak for good.")
	# Turtle awake + rubble around — teach the point-and-click demolish.
	if friend and _following(friend) and not get_tree().get_nodes_in_group("blastable").is_empty():
		var how := "[color=#ffcd75][b]Tap[/b][/color] the open water" if _touch() else "[color=#ffcd75][b]Click[/b][/color] a spot"
		nudge("command", "Your turtle can smash rubble! %s to send it there." % how)

func _lazy_hook_bubble() -> void:
	if _bubble_hooked:
		return
	var keeper := get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_signal("bubble_ready"):
		keeper.bubble_ready.connect(func() -> void:
			nudge("bubble", "Bubble Bomb charged! Hold %s to aim, release to blast a wide patch of oil." % _prompt("bubble", "Bomb")))
		_bubble_hooked = true

func _asleep(friend: Node) -> bool:
	return "_state" in friend and int(friend._state) == 0

func _following(friend: Node) -> bool:
	return "_state" in friend and int(friend._state) == 2

func _key(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			# as_text() can suffix "C - Physical" or "C (Physical)" depending on binding kind
			return (e as InputEventKey).as_text().trim_suffix(" - Physical").trim_suffix(" (Physical)")
	return action

## Are the on-screen touch controls the active input? Mirrors touch_controls' visibility rule so
## hints name a BUTTON on a phone (no keyboard to press) and a KEY on a desktop.
func _touch() -> bool:
	var mode: int = Settings.get_setting("controls", "touch_mode", 0)
	if mode == 1:
		return true
	if mode == 2:
		return false
	return DisplayServer.is_touchscreen_available()

## A gold-highlighted prompt for an action: the on-screen button's name on touch, else its key.
func _prompt(action: String, button_word: String) -> String:
	var label := ("the [b]%s[/b] button" % button_word) if _touch() else ("[b]%s[/b]" % _key(action))
	return "[color=#ffcd75]%s[/color]" % label

# --- the toast ---

func _drive_toast(delta: float) -> void:
	if _cur == "" and not _queue.is_empty():
		var h: Dictionary = _queue.pop_front()
		_cur = h["id"]
		_timer = HOLD
		_label.text = "[center]%s[/center]" % h["text"]
	var target := 0.0
	if _cur != "":
		_timer -= delta
		target = 1.0 if _timer > 0.0 else 0.0
		if _timer <= 0.0 and _fade <= 0.01:
			_cur = ""
	_fade = move_toward(_fade, target, delta / FADE)
	_root.modulate.a = _fade
	_root.visible = _fade > 0.01 and not Settings.ui_locked()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN   # grow upward from the pinned bottom
	_panel.offset_bottom = -74.0                          # clear of the touch controls / bottom edge
	_panel.custom_minimum_size = Vector2(460.0, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UiTheme.panel())
	_root.add_child(_panel)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(420.0, 0.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# bigger + bright + shadowed so it reads at a glance, not small and muted
	_label.add_theme_font_size_override("normal_font_size", 25)
	_label.add_theme_font_size_override("bold_font_size", 25)
	_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.06, 0.10, 0.95))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_panel.add_child(_label)
