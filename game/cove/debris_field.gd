extends Node2D
## Scatters floating debris across the water for the frog's tongue to clear — config-driven count
## (debris_count; 0 = none, so the cove has none and the estuary has a handful). Injected by the Cove
## composition root, exactly like the other cove components. Self-contained: it just spawns; each clump
## owns its own bob + grab (floating_debris.gd).

const DEBRIS := preload("res://game/cove/floating_debris.gd")

func setup(cfg: CoveConfig) -> void:
	if cfg.debris_count <= 0 or WorldState.is_restored(cfg.id):
		return   # a RESTORED reach reloads restored: no chokes respawn (spec review C2)
	for i in cfg.debris_count:
		var d := DEBRIS.new()
		# spread across the middle of the water span (kept off the shore so it's genuinely out of the
		# axolotl's reach — a job for the frog), with staggered depth near the surface
		var t := (float(i) + 0.5) / float(cfg.debris_count)
		var x := lerpf(cfg.water_left + 70.0, cfg.water_right - 60.0, t)
		var y := cfg.surface_y + 8.0 + fmod(float(i) * 37.0, 40.0)
		d.position = Vector2(x, y)
		add_child(d)
