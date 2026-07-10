extends Node2D
## A RECLAIM — cleaned barrel metal, the seed of the §3.6 economy: pollution becomes the material
## the refugio will be built from (spending lands with the otter's Build, slice 6; this banks it).
## Floats up from a purified barrel, bobs, collected by touch: material +1 for this reach
## (WorldState, echo-guarded). Drawn, Apollo, self-contained.

const COLLECT_REACH := 16.0
const RISE := 26.0
const REDRAW_HZ := 15.0

var _t := 0.0
var _rise := 0.0
var _acc := 0.0

func _ready() -> void:
	z_index = 7

func _process(delta: float) -> void:
	_t += delta
	_rise = minf(RISE, _rise + delta * 30.0)
	_acc += delta
	if _acc >= 1.0 / REDRAW_HZ:
		_acc = 0.0
		queue_redraw()
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	if axo and axo.global_position.distance_to(global_position + Vector2(0, -_rise)) <= COLLECT_REACH:
		_collect()

func _collect() -> void:
	set_process(false)
	var root := get_tree().get_first_node_in_group("cove_root")
	if root and "config" in root:
		var id: String = root.config.id
		if not (root.has_method("is_echo") and root.is_echo()):
			WorldState.mark(id, "material", int(WorldState.get_cove(id, "material", 0)) + 1)
		get_tree().call_group("shine_hud", "flash_material", int(WorldState.get_cove(id, "material", 0)))
	Sfx.play("chime", -8.0, 0.9)
	queue_free()

func _draw() -> void:
	var p := Vector2(0.0, -_rise + sin(_t * 2.0) * 2.0)
	draw_arc(p, 6.0, 0.0, TAU, 16, Palette.STEEL, 2.5, true)     # a cleaned barrel ring
	draw_arc(p, 6.0, -0.9, 0.6, 8, Palette.FOAM, 1.5, true)      # glint
	draw_circle(p, 8.5, Color(Palette.GOLD, 0.10))               # soft find-me glow
