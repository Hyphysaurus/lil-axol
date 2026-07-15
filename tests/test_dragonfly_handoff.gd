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
	var cfg = CoveConfigScript.new()
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
