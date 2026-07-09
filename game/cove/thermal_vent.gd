extends Node2D
class_name ThermalVent
## A seabed thermal vent, capped by rubble. The turtle (or a bubble bomb) clears the cap and the
## vent OPENS: warm water billows up (a rising bubble plume + a warm glow), and the cove gets a
## restoration surge — a Shine reward plus a burst of oil-clearing in the water column above it
## (warmth dispersing the oil, the ecosystem coming back). Fills the deep floor AND gives the
## turtle's demolition a purpose. Self-contained: it spawns its own rubble cap and listens for the
## rock's `cleared` signal — drop as many as you like along the seabed.

const RockScript := preload("res://game/cove/destructible_rock.gd")
const SURGE_RADIUS := 100.0    # oil cleared in the column above the vent when it opens
# Shine for opening a vent lives in the "geyser" feat (shine.FEATS) — it's a celebrated feat now.

@export var cap_cols := 11
@export var cap_rows := 7

var _open := false
var _plume: CPUParticles2D
var _glow := 0.0               # 0 dormant .. 1 fully open (tweened up on opening)
var _pulse := 0.0

func _ready() -> void:
	z_index = 1
	add_to_group("thermal_vent")   # the restoration banner polls this group for the "all vents open" win gate
	_plume = _make_plume()
	_plume.emitting = false
	add_child(_plume)
	# the rubble cap sits directly over the vent mouth, extending UP from the seabed
	var rock := RockScript.new()
	rock.cols = cap_cols
	rock.rows = cap_rows
	rock.position = Vector2(-cap_cols * DestructibleRock.CELL * 0.5, -cap_rows * DestructibleRock.CELL)
	add_child(rock)
	rock.cleared.connect(_open_vent)
	queue_redraw()

func _open_vent() -> void:
	if _open:
		return
	_open = true
	_plume.emitting = true
	Sfx.play("break", -9.0, 0.55)    # a low rumble as pressure escapes
	Sfx.play("vent_open", -5.0)      # a warm ascending sparkle as the vent wells up (GameBurp)
	# restoration surge: disperse oil up the water column above the vent + a Shine reward
	get_tree().call_group("oil_manager", "spray_at", global_position, SURGE_RADIUS, 1.4)
	get_tree().call_group("oil_manager", "spray_at", global_position + Vector2(0.0, -190.0), SURGE_RADIUS, 1.4)
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("feat"):
		keeper.feat(&"geyser", global_position)   # a celebrated feat: callout + Flow + Shine
	create_tween().tween_property(self, "_glow", 1.0, 0.7)
	get_tree().call_group("restoration", "notify_progress")   # a vent opening may complete the win

## Public read for the win gate — is this vent broken open? (the banner needs ALL vents open.)
func is_vent_open() -> bool:
	return _open

func _process(delta: float) -> void:
	if _open:
		_pulse += delta
		queue_redraw()                # the warm glow breathes while open

func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color(Palette.INK, 0.7))    # the vent mouth (a dark fissure)
	if _glow > 0.01:
		var g := _glow * (0.75 + 0.25 * sin(_pulse * 2.4))
		for i in 3:                                            # a soft warm glow welling up
			draw_circle(Vector2(0.0, -3.0), 12.0 + i * 9.0, Color(Palette.GOLD, 0.16 * g / float(i + 1)))

func _make_plume() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 22
	p.lifetime = 2.4
	p.position = Vector2(0.0, -3.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 16.0
	p.gravity = Vector2(0.0, -22.0)       # warm bubbles rise toward the surface
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 30.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.9
	p.color = Color(Palette.GOLD, 0.45)   # warm
	p.z_index = 2
	return p
