extends Node2D
## Keeps the cove's insect life honest: while the water is dirty, PEST-FLIES swarm over the oily
## patches (up to config pest_count, respawning where oil remains); once the cove is mostly healed,
## the pests stop coming and DRAGONFLIES take their place — the same wings, recolored by recovery.
## Config-driven + injected by the composition root, like every cove component. Each fly owns its own
## behavior (pest_fly.gd); this node only manages the population on a slow tick.

const PestFly := preload("res://game/cove/pest_fly.gd")

const TICK := 1.6              # population check cadence (slow — this is ambience, not a sim)
const DRAGONS_AT := 0.6        # cleanliness where pests give way to dragonflies
const HOVER := 16.0            # how far above the waterline the swarm hovers

var _cfg: CoveConfig
var _tick_t := 0.0
var _dragons_out := false      # dragonflies released once, when the water turns

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.pest_count > 0 and WorldState.is_restored(cfg.id):
		# a RESTORED reach spawns no pests — but its healed-water dragonflies are part of the
		# "it stays alive" payoff (spec §7): release them straight away, then stay idle
		_dragons_out = true
		_release_dragonflies.call_deferred()   # deferred: children spawn after the tree settles
		set_process(false)
		return
	set_process(cfg.pest_count > 0)

func _process(delta: float) -> void:
	_tick_t -= delta
	if _tick_t > 0.0:
		return
	_tick_t = TICK
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr == null:
		return
	var clean: float = mgr.current_clean if "current_clean" in mgr else 0.0
	if clean >= DRAGONS_AT:
		if not _dragons_out:
			_dragons_out = true
			_release_dragonflies()
		return
	# dirty water: keep the pest population topped up, spawning only over columns that still have oil
	var pests := 0
	for c in get_children():
		if c is PestFly and c.mode == PestFly.Mode.PEST:
			pests += 1
	if pests >= _cfg.pest_count:
		return
	var x := _find_dirty_x(mgr)
	if is_nan(x):
		return                                   # nowhere oily enough right now — try next tick
	var fly := PestFly.new()
	fly.mode = PestFly.Mode.PEST
	fly.position = Vector2(x, _cfg.surface_y - HOVER - fmod(absf(x) * 0.37, 8.0))
	add_child(fly)

## Sample a handful of spots along the water and return one with real oil under it (NAN = none found).
func _find_dirty_x(mgr) -> float:
	for i in 6:
		var x := randf_range(_cfg.water_left + 40.0, _cfg.water_right - 40.0)
		var probe := to_global(Vector2(x, _cfg.surface_y + 14.0))
		if mgr.has_method("oil_at") and mgr.oil_at(probe) > 0.15:
			return x
	return NAN

## The water has turned: the healthy wings arrive — bright dragonflies spread across the whole span.
func _release_dragonflies() -> void:
	for i in _cfg.pest_count:
		var fly := PestFly.new()
		fly.mode = PestFly.Mode.DRAGONFLY
		var t := (float(i) + 0.5) / float(_cfg.pest_count)
		fly.position = Vector2(lerpf(_cfg.water_left + 30.0, _cfg.water_right - 30.0, t),
			_cfg.surface_y - HOVER - fmod(float(i) * 5.3, 10.0))
		add_child(fly)
