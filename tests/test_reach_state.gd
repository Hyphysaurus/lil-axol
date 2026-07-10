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
