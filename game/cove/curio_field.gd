extends Node2D
## The cove's CURIOS — hidden Field Guide collectibles (Living Watershed §8). Spawns a curio.gd at
## each config position, skipping ones already found (WorldState "curio_<i>" marks), and owns the
## card popup: on collect it files the mark (never during an Echo run — replays re-find for Shine
## but the world record stays), then shows the curio's Field Guide card with the reach tally.
## Self-contained in the cove idiom; zero positions = retire.

const CurioScript := preload("res://game/cove/curio.gd")
const FieldGuide := preload("res://game/log/field_guide.gd")
const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne.ttf")

const CARD_HOLD := 7.0        # seconds the card stays before melting away
const CARD_FADE := 0.4

var _cfg: CoveConfig
var _card: CanvasLayer
var _card_root: Control
var _title: Label
var _species: Label
var _fact: Label
var _tally: Label
var _card_t := 0.0
var _fade := 0.0

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.curios.is_empty():
		queue_free()
		return
	for i in cfg.curios.size():
		var cid := cfg.id + "_" + str(i)
		if bool(WorldState.get_cove(cfg.id, "curio_" + str(i), false)):
			continue                      # found on an earlier visit — it stays found
		var c := CurioScript.new()
		c.id = cid
		c.icon = int(FieldGuide.card(cid).get("icon", 0))
		c.position = cfg.curios[i]
		c.collected.connect(_on_collected)
		add_child(c)
	_build_card()
	add_to_group("curio_cards")

func _on_collected(cid: String) -> void:
	var idx := cid.trim_prefix(_cfg.id + "_")
	var root := get_tree().get_first_node_in_group("cove_root")
	var echo: bool = root != null and root.has_method("is_echo") and root.is_echo()
	if not echo:
		WorldState.mark(_cfg.id, "curio_" + idx, true)
	var card: Dictionary = FieldGuide.card(cid)
	if card.is_empty():
		return
	# tally = saved finds (this one just marked) or, in echo, just show the guide entry
	var found := 0
	var total := FieldGuide.count_for(_cfg.id)
	for i in total:
		if bool(WorldState.get_cove(_cfg.id, "curio_" + str(i), false)):
			found += 1
	# the SIT-AND-SKETCH beat (diegetic pass): the tidekeeper settles to study the find first;
	# the card fades in a moment later, reading as its own journal page instead of a popup
	var axo := get_tree().get_first_node_in_group("player")
	if axo and axo.has_method("study"):
		axo.study()
	await get_tree().create_timer(0.7).timeout
	show_card(card, "field guide — %d of %d found in this reach" % [maxi(found, 1), total])

## Show any Field Guide card (curios use it; the invasive school's encounter card too).
func show_card(card: Dictionary, tally_text: String) -> void:
	_title.text = card["name"]
	_species.text = card["species"]
	_fact.text = card["fact"]
	_tally.text = tally_text
	_card_t = CARD_HOLD
	Sfx.play("ui_open", -10.0)

func _process(delta: float) -> void:
	if _card_root == null:
		return
	var target := 1.0 if _card_t > 0.0 else 0.0
	_card_t = maxf(0.0, _card_t - delta)
	if is_equal_approx(_fade, target) and target == 0.0 and not _card_root.visible:
		return
	_fade = move_toward(_fade, target, delta / CARD_FADE)
	_card_root.modulate.a = _fade
	_card_root.visible = _fade > 0.01

## The Field Guide card: a soft bottom-left panel in the banner idiom — a find, not an interruption.
func _build_card() -> void:
	_card = CanvasLayer.new()
	_card.layer = 93
	add_child(_card)
	_card_root = Control.new()
	_card_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.visible = false
	_card_root.modulate.a = 0.0
	_card.add_child(_card_root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 16.0
	panel.offset_bottom = -96.0
	panel.offset_top = -260.0
	panel.custom_minimum_size = Vector2(340.0, 0.0)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.panel())
	_card_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)

	_title = Label.new()
	_title.add_theme_font_override("font", DISPLAY_FONT)
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Palette.GOLD)
	vb.add_child(_title)

	_species = Label.new()
	_species.add_theme_font_size_override("font_size", 18)
	_species.add_theme_color_override("font_color", Palette.CYAN)
	vb.add_child(_species)

	_fact = Label.new()
	_fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fact.custom_minimum_size = Vector2(320.0, 0.0)
	_fact.add_theme_font_size_override("font_size", 19)
	_fact.add_theme_color_override("font_color", Palette.FOAM)
	vb.add_child(_fact)

	_tally = Label.new()
	_tally.add_theme_font_size_override("font_size", 15)
	_tally.add_theme_color_override("font_color", Palette.MIST)
	vb.add_child(_tally)
