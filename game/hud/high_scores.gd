extends CanvasLayer
## The Tide Board — post-win high scores. After "Cove Restored" hands off to its corner
## sun, an arcade initials card appears: type up to 3 letters, send your Shine to the
## shared board (Leaderboard autoload -> Supabase), then see the top ten. Skippable,
## one-shot per day (New Day reloads rebuild it fresh). Holds a UI lock while open.

const SHOW_DELAY := 3.4        # let the banner celebrate first

var _root: Control
var _entry: VBoxContainer
var _board: VBoxContainer
var _list: VBoxContainer
var _input: LineEdit
var _status: Label
var _score := 0
var _shown := false

func _ready() -> void:
	layer = 94                  # under the banner's corner sun (95), over the meters (92)
	_build()
	_root.visible = false
	var banner = get_tree().get_first_node_in_group("restoration")
	if banner and banner.has_signal("restored"):
		banner.restored.connect(_on_restored)

func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")):
		_close()
		get_viewport().set_input_as_handled()

func _on_restored() -> void:
	if _shown:
		return
	_shown = true
	var keeper = get_tree().get_first_node_in_group("shine")
	_score = int(keeper.score) if keeper and "score" in keeper else 0
	await get_tree().create_timer(SHOW_DELAY).timeout
	Settings.push_ui_lock()
	_score_line().text = "your shine: %d" % _score
	_root.visible = true
	Sfx.play("ui_open", -6.0)
	_input.grab_focus()

func _submit() -> void:
	var player := _input.text.strip_edges().to_upper()
	if player.is_empty():
		player = "AXO"
	_status.text = "sending..."
	Sfx.play("scrub", -12.0, 1.4)
	var ok: bool = await Leaderboard.submit(player, _score)
	if not ok:
		_status.text = "couldn't reach the tide board"
	await _show_board()

func _show_board() -> void:
	_entry.visible = false
	_board.visible = true
	if _status.text.is_empty():
		_status.text = "reading the tide..."
	var rows: Array = await Leaderboard.fetch_top(10)
	for c in _list.get_children():
		c.queue_free()
	if rows.is_empty():
		if _status.text == "reading the tide...":
			_status.text = "the tide board is out of reach"
	else:
		_status.text = ""
		var rank := 1
		for row in rows:
			var l := Label.new()
			l.text = "%d.  %s - %d" % [rank, str(row.get("name", "?")), int(row.get("score", 0))]
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_color",
				Color(1.0, 0.87, 0.55) if rank == 1 else Color(0.85, 0.93, 0.96))
			_list.add_child(l)
			rank += 1

func _close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	Settings.pop_ui_lock()

func _score_line() -> Label:
	return _entry.get_node("ScoreLine") as Label

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.45)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340.0, 0.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UiTheme.panel())   # shared watery/cozy theme
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var head := Label.new()
	head.text = "~ the tide board ~"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55))
	vb.add_child(head)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color(0.70, 0.85, 0.90))
	vb.add_child(_status)

	# --- entry: initials + submit/skip ---
	_entry = VBoxContainer.new()
	_entry.add_theme_constant_override("separation", 8)
	vb.add_child(_entry)

	var score_line := Label.new()
	score_line.name = "ScoreLine"
	score_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_line.add_theme_font_size_override("font_size", 22)
	score_line.add_theme_color_override("font_color", Color(0.95, 0.99, 1.0))
	_entry.add_child(score_line)

	_input = LineEdit.new()
	_input.max_length = 3
	_input.placeholder_text = "AAA"
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.custom_minimum_size = Vector2(140.0, 44.0)
	_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_input.add_theme_font_size_override("font_size", 30)
	_input.text_changed.connect(func(t: String) -> void:
		_input.text = t.to_upper()
		_input.caret_column = _input.text.length())
	_input.text_submitted.connect(func(_t: String) -> void: _submit())
	_entry.add_child(_input)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 10)
	_entry.add_child(btns)
	btns.add_child(_button("set my mark", _submit))
	btns.add_child(_button("skip", _show_board))

	# --- the board: top ten + close ---
	_board = VBoxContainer.new()
	_board.visible = false
	_board.add_theme_constant_override("separation", 4)
	vb.add_child(_board)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_board.add_child(_list)
	var close := _button("keep swimming", _close)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board.add_child(close)

func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(130.0, 38.0)
	b.add_theme_font_size_override("font_size", 20)
	UiTheme.style_button(b)       # shared watery/cozy button look
	b.pressed.connect(on_pressed)
	return b
