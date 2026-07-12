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
const PLUG_ROWS := 9           # sized to the carved mouth (72px vs the rim's ~70) — no rubble sticking past rock
const TRIGGER_RADIUS := 28.0   # how close the axolotl must get to the OPEN passage to cross
const FADE_TIME := 0.6
# the throat's vanishing point, in local pre-squash space: each ring steps toward it so the
# passage recedes INTO the bank, and the portal light lives at its far end — a small bright
# promise deep in the tunnel, not a wall-sized glow at the mouth plane
const VANISH := Vector2(16.0, 0.0)

signal opened   # the way is clear (WorldState files portal_cleared off this)

## Scene-authored second exit (slice 5 T8): when true, setup() reads exit2_enabled/exit2_target/
## exit2_pos instead of the classic exit_*/exit_blocked fields — cove.tscn's shared $Portal2 node
## sets this true so it can carry the estuary's onward door to the canals without a second scene
## fork. false (every other cove) retires Portal2 the instant exit2_enabled is false (the default).
@export var use_second_exit := false
## Overrides _entry_key for a setup()-path portal (configure()'s map portals set _entry_key
## directly and never read this). Wired per-node in cove.tscn: Portal2 carries "west" so crossing
## the estuary's second door stamps Settings.arrive_entry = "west" — the canals' painted west
## portal marker edge_inward()'s crossings arrive facing right, matching the classic mouth.
## Harmless on every other cove's Portal2 (it retires before _cross() could ever read this).
@export var entry_key_out := ""

var _cfg: CoveConfig
var _open := false
var _crossing := false
var _glow := 0.0               # 0 sealed .. 1 open (the passage beckons once cleared)
var _pulse := 0.0
var _swirl: CPUParticles2D     # inward-spiralling motes: the current flowing into the passage

## the trigger arms only once the axolotl has been seen OUTSIDE the radius — a portal arrival
## lands INSIDE the destination door's radius (estuary Portal2 24px, canals nudge 20px vs radius
## 28) and would instantly re-cross forever. Both setup() and configure() instances (and every
## legacy scene) share this poll: the axolotl always starts outside a legacy portal's radius, so
## the latch arms on the first poll there — zero behavior change on those doors.
var _armed := false

# --- map-instance mode (slice 5): ReachMap builds these directly via configure(), never setup() ---
var _exit_to := ""        # instance destination (map reaches); falls back to _cfg.exit_target
var _entry_key := ""      # save key suffix + arrival identity ("west"/"east"/...)
var _dormant := false     # a promise, not a door: drawn dark, no swirl, no trigger

## ReachMap's construction path — a painted portal marker, never a scene-authored $Portal (which
## uses setup() instead; the two never both run on the same instance). No rubble plug of its own:
## the painted map's seal geometry (see reach_map._build_breakables) is the real gate, so the
## portal itself is always visually open the moment a destination is wired — an unwired edge
## spawns dormant (dark, inert) instead. already_open marks a REVISIT — WorldState already has this
## edge's portal_<edge> flag set — so the map reach was rebuilt fresh (as it is on every scene load)
## but the way was already cleared on an earlier visit: the state simply IS open, silently (no SFX,
## no glow tween, no opened re-emit), the same idiom force_open() uses for the legacy $Portal.
func configure(cfg: CoveConfig, exit_to: String, entry_key: String, dormant: bool, already_open := false) -> void:
	_cfg = cfg
	_exit_to = exit_to
	_entry_key = entry_key
	_dormant = dormant
	z_index = 8                        # over the map land quad (z-map); legacy stays z2
	if dormant:
		_glow = 0.0
	elif already_open:
		_open = true                   # silent reopen: the state simply IS open — no fanfare, no re-mark
		_glow = 1.0
		if _swirl:
			_swirl.emitting = true
	else:
		_on_open()                     # painted seals gate map portals; the portal itself is open
	queue_redraw()                     # draw right away, same idiom as setup()'s trailing redraw

## Injected by the Cove composition root. No exit configured -> this node just retires.
## use_second_exit swaps which CoveConfig fields this instance reads (see the export doc above);
## either way the resolved target is cached into _exit_to so _cross() (shared by both exit kinds)
## never has to branch on use_second_exit itself.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	var enabled: bool = cfg.exit2_enabled if use_second_exit else cfg.exit_enabled
	var target: String = cfg.exit2_target if use_second_exit else cfg.exit_target
	if not enabled or target.is_empty():
		queue_free()
		return
	_exit_to = target
	_entry_key = entry_key_out
	position = cfg.exit2_pos if use_second_exit else cfg.exit_pos
	z_index = 2
	if not use_second_exit and cfg.exit_blocked:
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
		# an already-open passage: the classic unblocked case, OR ANY second exit — exit2 is a
		# discovered doorway, never a cave-in, so it's plugless the moment it's enabled (spec §4.8)
		_on_open()
	# the whirlpool of motes spiralling INTO the mouth — the current flowing through the passage
	# (built now, switched on when the way opens)
	_swirl = CPUParticles2D.new()
	_swirl.emitting = false
	_swirl.amount = 12
	_swirl.lifetime = 1.4
	_swirl.position = Vector2(VANISH.x * 0.55, 0.0)   # motes gather at the far end (post-squash x)
	_swirl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_swirl.emission_sphere_radius = 16.0
	_swirl.spread = 180.0
	_swirl.initial_velocity_min = 4.0
	_swirl.initial_velocity_max = 12.0
	_swirl.radial_accel_min = -60.0        # pulled toward the throat...
	_swirl.radial_accel_max = -90.0
	_swirl.tangential_accel_min = 26.0     # ...while curling around it — an inward spiral
	_swirl.tangential_accel_max = 44.0
	_swirl.gravity = Vector2.ZERO
	_swirl.scale_amount_min = 0.4
	_swirl.scale_amount_max = 1.1
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

var _redraw_acc := 0.0

func _process(delta: float) -> void:
	if _dormant:
		return                          # a promise, not a door: no trigger poll, ever
	if not _open or _crossing or _cfg == null:
		return
	_pulse += delta
	_redraw_acc += delta
	if _redraw_acc >= 1.0 / 12.0:           # the beckoning glow breathes at 2.4 rad/s — 12Hz reads
		_redraw_acc = 0.0                   # identical, and WebGL pays per canvas rebuild
		queue_redraw()
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	if axo == null:
		return
	var dist := to_local(axo.global_position).length()
	if not _armed:
		if dist > TRIGGER_RADIUS:
			_armed = true
		return                          # never cross on the same poll that arms — even if outside
	if dist <= TRIGGER_RADIUS:
		_cross()

## Carry the run's Shine into the next scene, iris into tunnel-dark, then swap. The next scene reads
## Settings.arrive_via_portal and spawns the axolotl emerging at ITS passage mouth, still moving —
## so the crossing reads as one continuous swim through a dark tunnel, not a cut. change_scene frees
## this whole scene, so the wipe layer + tween die with it right after the callback fires.
func _cross() -> void:
	_crossing = true
	# a map-instance target (ReachMap.configure) wins; the legacy scene-authored $Portal has no
	# _exit_to, so it falls back to the single-target cfg field exactly as before
	var target := _exit_to if _exit_to != "" else _cfg.exit_target
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and "score" in keeper:
		Settings.run_score = keeper.score   # the arcade run spans coves (see shine.gd / new_day.gd)
	Settings.arrive_via_portal = true       # tells the next scene: continue the swim, don't reset
	Settings.arrive_entry = _entry_key      # which door we crossed through ("" on legacy passages)
	Sfx.play("chime", -4.0, 1.2)
	Sfx.play("splash", -10.0, 0.8)          # a low swallow of water as the tunnel takes you
	var wipe := IrisWipe.new()
	add_child(wipe)
	wipe.close(FADE_TIME, func() -> void: get_tree().change_scene_to_file(target))

func _draw() -> void:
	if _cfg == null:
		return
	# THE CARVED TUNNEL MOUTH — a dark opening in the bank, always drawn (the rubble plug sits
	# over it, so every chunk the turtle grinds away reveals more of the throat behind). Each ring
	# steps smaller AND toward the vanishing point, so the passage reads as a tunnel receding
	# into the rock with real depth — not concentric ovals painted on the face.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.55, 1.0))   # circles -> tall ovals
	draw_circle(Vector2.ZERO, 36.0, Palette.SOIL.darkened(0.25))                       # carved stone rim
	if _dormant:
		# a promise, not a door: mouth only, flat INK throat — no tunnel recession, no glow, no swirl
		draw_circle(Vector2.ZERO, 31.0, Palette.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_circle(Vector2.ZERO, 31.0, Palette.INK.lerp(Palette.DEEP, 0.4))               # mouth
	draw_circle(VANISH * 0.35, 23.0, Palette.INK.lerp(Palette.DEEP, 0.25))             # deeper...
	draw_circle(VANISH * 0.7, 15.0, Palette.INK.lerp(Palette.DEEP, 0.1))               # deeper still...
	draw_circle(VANISH, 9.0, Palette.INK)                                              # ...the far dark
	if _glow > 0.01:
		# THE PORTAL: a small ring of otherwater light at the END of the tunnel — the next reach
		# glimpsed through the passage. Small and far beats big and loud: it beckons, not shouts.
		var g := _glow * (0.7 + 0.3 * sin(_pulse * 2.4))
		draw_circle(VANISH, 8.0, Color(Palette.AQUA, 0.35 * g))       # light spilling into the throat
		draw_circle(VANISH, 5.0, Color(Palette.AQUA, 0.8 * g))        # the bright far ring
		draw_circle(VANISH, 2.5, Color(Palette.FOAM, 0.9 * g))        # daylight on the other side
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _glow <= 0.01:
		return
	# a faint spill washing out of the mouth onto the bank — the only glow at the mouth plane
	var g2 := _glow * (0.7 + 0.3 * sin(_pulse * 2.4))
	draw_circle(Vector2.ZERO, 16.0, Color(Palette.AQUA, 0.08 * g2))
