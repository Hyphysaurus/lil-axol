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
var _checks := 0   # executed-check tally: guards against a silently-empty suite reading as green
func _check(name: String, ok: bool) -> void:
	_checks += 1
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
	var z_before_noop: int = curio.z_index
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

	# --- capping MID-reveal (review Finding 2, Important): _purify() must settle the reveal state
	# immediately, or the sped-up drip + rising motes keep going over an already-purified barrel
	# until the 6s window naturally times out — contradicting reveal()'s own "a capped leak ignores
	# it" contract just above, since a leak capped BEFORE its window opened is already covered ---
	var cfg_midcap = CoveConfigScript.new()
	cfg_midcap.leak_enabled = true
	var midcap_leak = LeakScript.new()
	root.add_child(midcap_leak)
	midcap_leak.setup(cfg_midcap)
	midcap_leak.reveal(6.0)
	_check("leak: mid-window sanity check — drip sped up before capping", midcap_leak._drip.speed_scale > 1.0)
	midcap_leak._purify()
	_check("leak: capping mid-reveal settles the drip speed immediately", is_equal_approx(midcap_leak._drip.speed_scale, 1.0))
	_check("leak: capping mid-reveal stops the survey motes immediately", not midcap_leak._survey_motes.emitting)
	_check("leak: capping mid-reveal zeroes the reveal timer immediately", is_equal_approx(midcap_leak._reveal_t, 0.0))
	midcap_leak.free()

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

	# --- re-entrant reveal: a repeat call mid-window must NOT capture the boosted state as "prior" ---
	var cfg_reentrant = CoveConfigScript.new()
	cfg_reentrant.id = "test_reveal_reentrant_debris"
	cfg_reentrant.debris_count = 1
	var reentrant_root := Node2D.new(); get_root().add_child(reentrant_root)
	var reentrant_field = DebrisFieldScript.new()
	reentrant_root.add_child(reentrant_field)
	reentrant_field.setup(cfg_reentrant)
	var re_clump: Node2D = reentrant_field.get_child(0)
	var re_base_mod: Color = re_clump.modulate
	reentrant_field.reveal(1.0)
	reentrant_field._process(0.3)                   # still mid-window (0.7s left)
	reentrant_field.reveal(1.0)                      # Survey re-triggers before the window closed
	_check("debris_field: a re-entrant reveal doesn't re-boost past the first boost",
		re_clump.modulate == Color(re_base_mod.r + 0.6, re_base_mod.g + 0.6, re_base_mod.b + 0.6, re_base_mod.a))
	reentrant_field._process(1.1)                    # past the (extended) window
	_check("debris_field: re-entrant reveal still restores to the TRUE original baseline",
		re_clump.modulate == re_base_mod)
	reentrant_root.free()

	var cfg_reentrant_school = CoveConfigScript.new()
	cfg_reentrant_school.id = "test_reveal_reentrant_school"
	cfg_reentrant_school.invasive_count = 1
	var reentrant_school_root := Node2D.new(); get_root().add_child(reentrant_school_root)
	var reentrant_school = SchoolScript.new()
	reentrant_school_root.add_child(reentrant_school)
	reentrant_school.setup(cfg_reentrant_school)
	var re_fish: Sprite2D = reentrant_school._fish[0]["node"]
	var re_base_fish_mod: Color = re_fish.modulate
	reentrant_school.reveal(1.0)
	reentrant_school._process(0.3)                   # still mid-window
	reentrant_school.reveal(1.0)                      # Survey re-triggers before the window closed
	_check("invasive_school: a re-entrant reveal doesn't re-boost past the first boost",
		re_fish.modulate == re_base_fish_mod.lightened(0.5))
	reentrant_school._process(1.1)                    # past the (extended) window
	_check("invasive_school: re-entrant reveal still restores to the TRUE original baseline",
		re_fish.modulate == re_base_fish_mod)
	reentrant_school_root.free()

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails) + " (%d checks)" % _checks)
	quit(1 if fails > 0 else 0)
	return true
