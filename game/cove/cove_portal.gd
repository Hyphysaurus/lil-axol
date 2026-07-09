extends Node2D
## A one-way PATHWAY out of this cove to the next scene, data-driven via CoveConfig.exit_* — the seam
## the multi-cove world (cove -> estuary -> ...) is built on. A rubble PLUG blocks the passage; break it
## open (the turtle's ram OR a bubble bomb, since it joins "blastable") and the way clears — swim into
## it and the game fades to black and loads exit_target. Self-contained: it spawns its own
## DestructibleRock and listens for `cleared`, exactly like the thermal vents + land nooks. Injected by
## the composition root; one per cove. The running Shine total is carried into the next scene so an
## arcade run spans coves.

const RockScript := preload("res://game/cove/destructible_rock.gd")
const IrisWipe := preload("res://game/fx/iris_wipe.gd")

const PLUG_COLS := 5
const PLUG_ROWS := 11
const TRIGGER_RADIUS := 28.0   # how close the axolotl must get to the OPEN passage to cross
const FADE_TIME := 0.6

signal opened   # the way is clear (WorldState files portal_cleared off this)

var _cfg: CoveConfig
var _open := false
var _crossing := false
var _glow := 0.0               # 0 sealed .. 1 open (the passage beckons once cleared)
var _pulse := 0.0
var _swirl: CPUParticles2D     # inward-spiralling motes: the current flowing into the passage

## Injected by the Cove composition root. No exit configured -> this node just retires.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if not cfg.exit_enabled or cfg.exit_target.is_empty():
		queue_free()
		return
	position = cfg.exit_pos
	z_index = 2
	if cfg.exit_blocked:
		# a rubble plug over the passage — reuses the destructible-rock system (breaks on turtle ram or
		# bubble bomb; "blastable", not "sprayable", so spray alone won't open the way)
		var rock = RockScript.new()
		rock.cols = PLUG_COLS
		rock.rows = PLUG_ROWS
		rock.edge = 1.25                    # fuller than a round boulder so it reads as a cave-in plug
		rock.tone_a = Palette.SLATE         # cool stone rubble (matches the vent caps)
		rock.tone_b = Palette.STEEL
		rock.position = Vector2(-PLUG_COLS * DestructibleRock.CELL * 0.5, -PLUG_ROWS * DestructibleRock.CELL * 0.5)
		add_child(rock)
		rock.cleared.connect(_on_open)
	else:
		_on_open()                          # an already-open passage (e.g. a return route)
	# the whirlpool of motes spiralling INTO the mouth — the current flowing through the passage
	# (built now, switched on when the way opens)
	_swirl = CPUParticles2D.new()
	_swirl.emitting = false
	_swirl.amount = 14
	_swirl.lifetime = 1.4
	_swirl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_swirl.emission_sphere_radius = 40.0
	_swirl.spread = 180.0
	_swirl.initial_velocity_min = 4.0
	_swirl.initial_velocity_max = 12.0
	_swirl.radial_accel_min = -60.0        # pulled toward the throat...
	_swirl.radial_accel_max = -90.0
	_swirl.tangential_accel_min = 26.0     # ...while curling around it — an inward spiral
	_swirl.tangential_accel_max = 44.0
	_swirl.gravity = Vector2.ZERO
	_swirl.scale_amount_min = 0.6
	_swirl.scale_amount_max = 1.6
	_swirl.color = Color(Palette.AQUA, 0.75)
	_swirl.z_index = 3                     # over the mouth, under the axolotl
	add_child(_swirl)
	queue_redraw()                          # draw the carved mouth right away (behind any plug)

func _on_open() -> void:
	if _open:
		return
	_open = true
	opened.emit()
	Sfx.play("vent_open", -8.0)             # a warm "the way is clear" cue
	create_tween().tween_property(self, "_glow", 1.0, 0.6)
	if _swirl:
		_swirl.emitting = true              # the current begins to visibly flow through

## Persistence spawn path: this passage was cleared on an earlier visit — open it silently
## (no SFX, no glow tween; the state simply IS open). Frees any rubble plug.
func force_open() -> void:
	for c in get_children():
		if c is DestructibleRock:
			c.queue_free()
	if not _open:
		_open = true
		_glow = 1.0
		if _swirl:
			_swirl.emitting = true
	queue_redraw()

func _process(delta: float) -> void:
	if not _open or _crossing or _cfg == null:
		return
	_pulse += delta
	queue_redraw()                          # the open passage breathes a soft beckoning glow
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	if axo and to_local(axo.global_position).length() <= TRIGGER_RADIUS:
		_cross()

## Carry the run's Shine into the next scene, iris into tunnel-dark, then swap. The next scene reads
## Settings.arrive_via_portal and spawns the axolotl emerging at ITS passage mouth, still moving —
## so the crossing reads as one continuous swim through a dark tunnel, not a cut. change_scene frees
## this whole scene, so the wipe layer + tween die with it right after the callback fires.
func _cross() -> void:
	_crossing = true
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and "score" in keeper:
		Settings.run_score = keeper.score   # the arcade run spans coves (see shine.gd / new_day.gd)
	Settings.arrive_via_portal = true       # tells the next scene: continue the swim, don't reset
	Sfx.play("chime", -4.0, 1.2)
	Sfx.play("splash", -10.0, 0.8)          # a low swallow of water as the tunnel takes you
	var wipe := IrisWipe.new()
	add_child(wipe)
	wipe.close(FADE_TIME, func() -> void: get_tree().change_scene_to_file(_cfg.exit_target))

func _draw() -> void:
	if _cfg == null:
		return
	# THE CARVED TUNNEL MOUTH — a tall dark opening in the bank, always drawn (the rubble plug sits
	# over it, so every chunk the turtle grinds away reveals more of the throat behind). Concentric
	# ovals darken toward the centre so the passage reads as going INTO the rock, not painted on it.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.55, 1.0))   # circles -> tall ovals
	draw_circle(Vector2.ZERO, 47.0, Palette.SOIL.darkened(0.25))            # carved stone rim
	draw_circle(Vector2.ZERO, 41.0, Palette.INK.lerp(Palette.DEEP, 0.35))   # mouth
	draw_circle(Vector2.ZERO, 30.0, Palette.INK.lerp(Palette.DEEP, 0.15))   # deeper...
	draw_circle(Vector2.ZERO, 19.0, Palette.INK)                            # ...the dark throat
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _glow <= 0.01:
		return
	var g := _glow * (0.7 + 0.3 * sin(_pulse * 2.4))
	for i in 3:                             # a soft aqua beckoning glow once the way is open
		draw_circle(Vector2.ZERO, 10.0 + float(i) * 9.0, Color(Palette.AQUA, 0.14 * g / float(i + 1)))
