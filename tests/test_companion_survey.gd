extends SceneTree
## Headless tests for the Survey verb core (slice 4 T1): active-partner gating (the Kirby rule,
## spec REVIEW AMENDMENT Critical), the Survey cooldown machine, and the worst-oxygen density pick
## (spec REVIEW AMENDMENT Important) — all pure static functions on companion.gd, so no Input
## simulation is needed. Kind values are plain ints (0 Turtle / 1 Frog / 2 Otter / 3 Dragonfly,
## companion.gd's own enum order) written as literals here, matching companion_library.gd's
## established convention of never reaching into companion.gd's enum from outside it.
## Run: & $godot --headless --path $proj --script tests/test_companion_survey.gd
var fails := 0
var _done := false
func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok: fails += 1
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var Companion = load("res://game/companion/companion.gd")
	var Roster = load("res://tests/settings_roster_helper.gd")
	const TURTLE := 0
	const DRAGONFLY := 3
	const FROG := 1
	const OTTER := 2

	# --- gating truth table (spec REVIEW AMENDMENT, Critical) ---
	_check("turtle active -> shell", Companion.verb_for(TURTLE, TURTLE) == Companion.VERB_SHELL)
	_check("turtle active -> not survey", Companion.verb_for(TURTLE, TURTLE) != Companion.VERB_SURVEY)
	_check("dragonfly active -> survey", Companion.verb_for(DRAGONFLY, DRAGONFLY) == Companion.VERB_SURVEY)
	_check("dragonfly active -> not shell", Companion.verb_for(DRAGONFLY, DRAGONFLY) != Companion.VERB_SHELL)
	_check("turtle rescued but NOT active -> neither verb fires", Companion.verb_for(TURTLE, DRAGONFLY) == Companion.VERB_NONE)
	_check("dragonfly rescued but NOT active -> neither verb fires", Companion.verb_for(DRAGONFLY, TURTLE) == Companion.VERB_NONE)
	_check("frog has no button verb (registered, tongue is automatic)", Companion.verb_for(FROG, FROG) == Companion.VERB_NONE)
	_check("otter has no button verb yet (registered, lands slice 6)", Companion.verb_for(OTTER, OTTER) == Companion.VERB_NONE)

	# --- a solo-turtle roster always has the turtle active (legacy zero-behavior-change proof —
	# the real Settings autoload, not a stub, so this proves the actual roster_add() contract) ---
	Roster.reset()
	Roster.add(TURTLE)
	_check("solo-turtle roster: run_active == TURTLE", Roster.active() == TURTLE)
	_check("...and verb_for reads SHELL for it, exactly the legacy trigger", Companion.verb_for(TURTLE, Roster.active()) == Companion.VERB_SHELL)
	Roster.reset()

	# --- cooldown machine ---
	_check("SURVEY_COOLDOWN is 10s (spec)", is_equal_approx(Companion.SURVEY_COOLDOWN, 10.0))
	var cd: float = Companion.SURVEY_COOLDOWN
	for i in 100:
		cd = Companion.cooldown_tick(cd, Companion.SURVEY_COOLDOWN / 100.0)
	_check("cooldown drains to zero over its full duration", absf(cd) < 0.01)
	_check("cooldown never goes negative", Companion.cooldown_tick(0.0, 5.0) == 0.0)
	_check("charge frac at full cooldown == 0 (just fired)", absf(Companion.survey_charge_frac(Companion.SURVEY_COOLDOWN) - 0.0) < 0.01)
	_check("charge frac at zero cooldown == 1 (ready)", absf(Companion.survey_charge_frac(0.0) - 1.0) < 0.01)
	_check("charge frac at half cooldown == 0.5", absf(Companion.survey_charge_frac(Companion.SURVEY_COOLDOWN * 0.5) - 0.5) < 0.01)

	# --- worst-oxygen density pick (synthetic points, spec REVIEW AMENDMENT Important) ---
	var cluster: Array = [Vector2(0, 0), Vector2(10, 0), Vector2(0, 10), Vector2(400, 400)]
	var pick: Vector2 = Companion.densest_point(cluster, Companion.SURVEY_DENSITY_RADIUS)
	_check("density pick lands in the dense cluster, not the lone outlier", pick.distance_to(Vector2(0, 0)) < 50.0)
	_check("density pick on an empty set returns the INF sentinel", Companion.densest_point([], 90.0) == Vector2.INF)
	var uniform: Array = [Vector2(0, 0), Vector2(500, 0), Vector2(1000, 0)]   # no cluster: every point ties at n=1
	var upick: Vector2 = Companion.densest_point(uniform, 90.0)
	_check("density pick on a uniform field still returns a real member point", uniform.has(upick))

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
	return true
