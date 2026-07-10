extends Node2D
## The RESTORATION ENGINE (Living Watershed slice 2): five ecological variables derived from the
## systems that already run the cove — the oil mask (purity), the "grabbable" choke load (oxygen,
## cleared via the frog), the invasive school (clarity cap — the pre-otter teased lock), and a
## gated vegetation growth value. Health = the blend normalized over the CONFIG's in-play set, so
## a reach's meter only counts variables its player can actually move (the hub stays byte-identical
## to the old cleanliness meter). Authoritative recompute on a 2Hz poll (pest buzz-off emits no
## signal); cleanliness signals poke it for instant response. Emits state_changed; the banner and
## the meter pips read it. No per-frame work, no saves (the sources already persist).

const POLL_HZ := 2.0
const WEIGHTS := { &"purity": 0.7, &"oxygen": 0.3, &"clarity": 0.2, &"invasive": 0.1, &"vegetation": 0.1 }
const STIR_PER_FISH := 0.12    # each live invasive caps clarity by this much
const VEG_GROW_SECS := 20.0    # gate held -> vegetation 0..1 over this long
const VEG_REGRESS := 0.25      # regression rate as a fraction of growth rate

signal state_changed(state: Dictionary)

var _cfg: CoveConfig
var _veg := 0.0
var _poll_t := 0.0
var _last: Dictionary = {}

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	add_to_group("reach_state")
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_signal("cleanliness"):
		mgr.cleanliness.connect(func(_v: float) -> void: _recompute())

func _process(delta: float) -> void:
	if _cfg == null:
		return
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 1.0 / POLL_HZ
		_veg = veg_step(_veg, _veg_gate_ok(), 1.0 / POLL_HZ)
		_recompute()

# --- pure math (static, headless-testable) ---

static func blend_health(state: Dictionary, in_play: Array) -> float:
	var num := 0.0
	var den := 0.0
	for key in in_play:
		var w: float = WEIGHTS.get(key, 0.1)
		num += w * float(state.get(key, 1.0))
		den += w
	return num / den if den > 0.0 else 1.0

static func clarity_cap(invasives_alive: int) -> float:
	return clampf(1.0 - STIR_PER_FISH * float(invasives_alive), 0.0, 1.0)

static func veg_step(veg: float, gate_ok: bool, delta: float) -> float:
	var rate := delta / VEG_GROW_SECS
	return clampf(veg + rate if gate_ok else veg - rate * VEG_REGRESS, 0.0, 1.0)

static func eval_recipe(state: Dictionary, recipe: Dictionary) -> bool:
	for key in recipe:
		if float(state.get(key, 0.0)) < float(recipe[key]):
			return false
	return true

# --- live derivation ---

func get_state() -> Dictionary:
	if _last.is_empty():
		_recompute()
	return _last

func health() -> float:
	return float(get_state().get("health", 0.0))

## The config win recipe against the live state — the &"purity" key reads win_threshold (single
## source of truth with the legacy gate).
func recipe_met() -> bool:
	var recipe := {}
	if _cfg.win_recipe.is_empty():
		recipe[&"purity"] = _cfg.win_threshold
	else:
		for key in _cfg.win_recipe:
			recipe[key] = _cfg.win_threshold if key == &"purity" else _cfg.win_recipe[key]
	return eval_recipe(get_state(), recipe)

func _veg_gate_ok() -> bool:
	var s := _last
	if s.is_empty():
		return false
	if _cfg.vegetation_gate == "clarity":
		return float(s.get("clarity", 0.0)) >= 0.7 and float(s.get("purity", 0.0)) >= 0.8
	return float(s.get("purity", 0.0)) >= 0.7

func _recompute() -> void:
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	var purity: float = mgr.current_clean if mgr and "current_clean" in mgr else 0.0
	var choke_total := _cfg.debris_count + _cfg.pest_count
	var choke_alive := get_tree().get_nodes_in_group("grabbable").size()
	var oxygen := 1.0 if choke_total == 0 else clampf(1.0 - float(choke_alive) / float(choke_total), 0.0, 1.0)
	var fish_alive := get_tree().get_nodes_in_group("invasive").size()
	var invasive := 1.0 if _cfg.invasive_count == 0 else clampf(1.0 - float(fish_alive) / float(_cfg.invasive_count), 0.0, 1.0)
	var state := {
		"purity": purity, "oxygen": oxygen, "clarity": clarity_cap(fish_alive),
		"invasive": invasive, "vegetation": _veg,
	}
	state["health"] = blend_health(state, _cfg.in_play)
	if _last.is_empty() or _dirty(state):
		_last = state
		state_changed.emit(state)
	else:
		_last = state

func _dirty(s: Dictionary) -> bool:
	for k in s:
		if absf(float(s[k]) - float(_last.get(k, -1.0))) > 0.002:
			return true
	return false
