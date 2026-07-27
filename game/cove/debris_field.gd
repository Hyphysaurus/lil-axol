extends Node2D
## Scatters floating debris across the water for the frog's tongue to clear — config-driven count
## (debris_count; 0 = none, so the cove has none and the estuary has a handful). Injected by the Cove
## composition root, exactly like the other cove components. Self-contained: it just spawns; each clump
## owns its own bob + grab (floating_debris.gd). Also answers Survey's "surveyable" reveal contract by
## brightening every live clump for the window (see reveal() below).

const DEBRIS := preload("res://game/cove/floating_debris.gd")

var _cfg: CoveConfig
var _reveal_t := 0.0
var _reveal_bases: Array = []   # [{node: CanvasItem, base: Color}, ...] — captured per reveal() call

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.debris_count <= 0 or WorldState.is_restored(cfg.id):
		return   # a RESTORED reach reloads restored: no chokes respawn (spec review C2)
	add_to_group("surveyable")
	# field-true placement on a painted map only (spec 4.6/T7) — legacy keeps the exact lerp so a
	# hand-built reach's layout never shifts.
	var field: ReachField = get_tree().get_first_node_in_group("reach_field")
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for i in cfg.debris_count:
		# spread across the middle of the water span (kept off the shore so it's genuinely out of the
		# axolotl's reach — a job for the frog), with staggered depth near the surface.
		# NOTE: x is drawn BEFORE the already-cleared skip below, because random_surface_x advances
		# the rng — skipping the draw would shift every surviving clump's column on reload.
		var x: float
		if cfg.has_map and field != null:
			x = field.random_surface_x(rng)     # guaranteed an actual open-water column
		else:
			var t := (float(i) + 0.5) / float(cfg.debris_count)
			x = lerpf(cfg.water_left + 70.0, cfg.water_right - 60.0, t)
		if bool(WorldState.get_cove(cfg.id, "debris_" + str(i), false)):
			continue   # eaten on an earlier visit — it stays eaten (D-0020)
		var d := DEBRIS.new()
		var y := cfg.surface_y + 8.0 + fmod(float(i) * 37.0, 40.0)
		d.position = Vector2(x, y)
		d.idx = i
		d.cleared.connect(_on_cleared)
		add_child(d)

## A clump dissolved — file it so the frog's work survives leaving the reach. Echo-guarded exactly
## like curio_field: a replay re-eats for Shine, but the world record stays put.
func _on_cleared(i: int) -> void:
	if i < 0 or _cfg == null:
		return
	var root := get_tree().get_first_node_in_group("cove_root")
	var echo: bool = root != null and root.has_method("is_echo") and root.is_echo()
	if not echo:
		WorldState.mark(_cfg.id, "debris_" + str(i), true)

## Survey's reveal contract: brighten every LIVE clump's modulate for the duration, restoring to
## whatever it was (captured per-node, not a hardcoded WHITE — floating_debris.gd stays untouched,
## the boost lives entirely at this spawner level). Driven by _process (not a Tween) so a mid-reveal
## grab (queue_free) is handled by a plain is_instance_valid check, and the whole contract is
## headless-testable with a direct ._process(dt) call.
## NOTE: additive, not Color.lightened() — a clump's modulate defaults to plain white (untouched by
## floating_debris.gd), and lightened() lerps TOWARD white, so it's a no-op from an already-white
## base. Adding pushes brightness up regardless of the starting tone.
## Only captures if NOT already mid-reveal: a repeat call (Survey re-triggering before the previous
## window closes) must extend the timer, never re-capture the already-boosted modulate as "prior" —
## that would strand every clump lit forever once the reveal finally ends.
func reveal(duration: float) -> void:
	if _reveal_t <= 0.0:
		_reveal_bases.clear()
		for c in get_children():
			var base: Color = (c as CanvasItem).modulate
			_reveal_bases.append({"node": c, "base": base})
			(c as CanvasItem).modulate = Color(base.r + 0.6, base.g + 0.6, base.b + 0.6, base.a)
	_reveal_t = duration

func _process(delta: float) -> void:
	if _reveal_t <= 0.0:
		return
	_reveal_t = maxf(0.0, _reveal_t - delta)
	if _reveal_t <= 0.0:
		for entry in _reveal_bases:
			if is_instance_valid(entry["node"]):
				(entry["node"] as CanvasItem).modulate = entry["base"]
		_reveal_bases.clear()
