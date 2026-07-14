extends Node2D
## THE SCOUT — a lone dragonfly that now and then lifts off near the tidekeeper, drifts toward
## the nearest wound (the uncapped leak, else the closest sealed rubble) and hovers there a
## breath before slipping away: guidance the wetland performs itself, no arrows (diegetic pass).
## Ecologically true — odonates are water-quality indicators, exactly what its Field Guide card
## says. Retires on restored reaches (their dragonflies dance for joy instead, see pest_field).

const CRUISE := 85.0           # px/s toward the target
const HOVER_T := 2.6           # seconds it lingers over the wound
const REST_MIN := 16.0         # quiet seconds between flights...
const REST_MAX := 28.0
const FIRST_FLIGHT := 7.0      # ...but the first one comes soon — it IS the guide
const REDRAW_HZ := 15.0        # wings flutter cheap (WebGL pays per canvas rebuild)

var _cfg: CoveConfig
var _state := 0                # 0 resting (hidden), 1 flying, 2 hovering, 3 fading
var _rest := FIRST_FLIGHT
var _target := Vector2.ZERO
var _hover := 0.0
var _alpha := 0.0
var _t := 0.0
var _acc := 0.0

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if WorldState.is_restored(cfg.id):
		queue_free()
		return
	z_index = 8
	visible = false

func _process(delta: float) -> void:
	_t += delta
	match _state:
		0:
			_rest -= delta
			if _rest <= 0.0 and not Settings.ui_locked():
				_launch()
		1:
			_alpha = move_toward(_alpha, 1.0, delta * 3.0)
			var to := _target - position
			# a gentle sine weave so it reads as an insect, not a cursor
			var step := to.normalized() * CRUISE * delta
			position += step + Vector2(0.0, sin(_t * 7.0) * 22.0 * delta)
			if to.length() < 10.0:
				_state = 2
				_hover = HOVER_T
		2:
			position.y += sin(_t * 5.0) * 8.0 * delta   # hover bob over the wound
			_hover -= delta
			if _hover <= 0.0:
				_state = 3
		3:
			_alpha = move_toward(_alpha, 0.0, delta * 1.6)
			position += Vector2(28.0, -34.0) * delta     # drifts up and away
			if _alpha <= 0.0:
				_state = 0
				visible = false
				_rest = randf_range(REST_MIN, REST_MAX)
	if _state != 0:
		_acc += delta
		if _acc >= 1.0 / REDRAW_HZ:
			_acc = 0.0
			queue_redraw()

## Lift off beside the player if there's a wound left to point at.
func _launch() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not _pick_target(player):
		_rest = randf_range(REST_MIN, REST_MAX)
		return
	position = to_local(player.global_position) + Vector2(-14.0, -34.0)
	_alpha = 0.0
	visible = true
	_state = 1

## The uncapped leak first (the source is always the truest lead), else the sealed rock
## closest to the player. No wound -> no flight (a clean reach needs no pointing).
func _pick_target(player: Node2D) -> bool:
	var leak := get_tree().get_first_node_in_group("leak")
	if leak and not (leak as Node).is_queued_for_deletion():
		_target = to_local((leak as Node2D).global_position) + Vector2(0.0, -16.0)
		return true
	var best: Node2D = null
	var bd := INF
	for r in get_tree().get_nodes_in_group("blastable"):
		if r is Node2D and not (r as Node).is_queued_for_deletion():
			var d: float = (r as Node2D).global_position.distance_squared_to(player.global_position)
			if d < bd:
				bd = d
				best = r
	if best == null:
		return false
	_target = to_local(best.global_position) + Vector2(0.0, -18.0)
	return true

func _draw() -> void:
	if _alpha <= 0.01:
		return
	var body := Color(Palette.CYAN, _alpha)
	var wing := Color(Palette.FOAM, 0.55 * _alpha)
	# slim two-segment body with a brighter thorax dot
	draw_line(Vector2(-5.0, 0.0), Vector2(6.0, 0.0), body, 1.6)
	draw_circle(Vector2(-4.0, 0.0), 1.6, Color(Palette.AQUA, _alpha))
	# two wing pairs, fluttering: lens shapes via a squashed transform, beat ~fast
	var beat := 0.22 + 0.16 * absf(sin(_t * 34.0))
	for side in [-1.0, 1.0]:
		draw_set_transform(Vector2(-1.0, -1.0), side * 0.5, Vector2(1.0, beat))
		draw_circle(Vector2.ZERO, 5.0, wing)
		draw_set_transform(Vector2(2.0, -1.0), side * 0.35, Vector2(1.0, beat))
		draw_circle(Vector2.ZERO, 4.2, wing)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
