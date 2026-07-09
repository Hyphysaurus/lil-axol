extends Node2D
## A pollution PEST-FLY — a little oil-gnat hovering over dirty water, a living symptom of the spill
## (SeethingSwarm's fly sprite, tinted dark). It gently re-oils the water beneath it (stain_at, which is
## hard-capped at the level's original coverage — D-0005 — so pests slow restoration, never undo it).
## The FROG auto-tongues pests (group "grabbable", same contract as floating debris): each gulp turns
## the pest into a small CLEANSE pulse + Shine + a dab of bubble charge — blight becomes healing.
## When the water below heals, the pest gives up and buzzes away. DRAGONFLY mode is the reward skin:
## bright, harmless, NOT grabbable — healthy wings over healed water. One scene-facing knob: `mode`.

enum Mode { PEST, DRAGONFLY }

const FLY_TEX := preload("res://assets/critters/frog/fly_fly_strip2.png")   # 2 frames, 8x6 each
const FLY_SHINE := 150.0       # Shine per catch (a snack, not a debris-grab's 450)
const FLY_CHARGE := 50.0       # bubble charge per catch — the frog provisions the Hydro Pack (capped
                               # by shine.bonus at the same per-event ceiling as scrubbing)
const STAIN_EVERY := 2.5       # seconds between a pest's re-oil drips
const STAIN_RADIUS := 14.0
const STAIN_AMOUNT := 0.05     # very gentle — and stain_at can never exceed the level's start coverage
const GIVE_UP_CLEAN := 0.05    # oil below this for a stretch -> the pest buzzes off
const WING_FPS := 14.0

var mode := Mode.PEST
var _spr: Sprite2D
var _base := Vector2.ZERO      # hover anchor (position drifts around it)
var _phase := 0.0
var _wing_t := 0.0
var _stain_t := 0.0
var _clean_t := 0.0            # how long the water below has been clean (drives the give-up)
var _caught := false
var _leaving := false

func _ready() -> void:
	z_index = 6                 # above the water + oil film, below FX
	_base = position
	_phase = position.x * 0.11 + position.y * 0.07   # desync per instance
	_spr = Sprite2D.new()
	_spr.texture = FLY_TEX
	_spr.hframes = 2            # the strip's two wing frames, flipped by hand in _process
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(2.0, 2.0)                   # 8x6 art -> a readable 16x12 gnat
	add_child(_spr)
	if mode == Mode.PEST:
		add_to_group("grabbable")                    # the frog's auto-tongue finds us here
		_spr.modulate = Palette.SLATE.lerp(Palette.INK, 0.4)   # dark oily gnat
	else:
		_spr.modulate = Palette.AQUA.lerp(Palette.CYAN, 0.4)   # bright healthy dragonfly
		_spr.scale = Vector2(2.6, 2.6)               # dragonflies read a touch larger

func _process(delta: float) -> void:
	_phase += delta
	_wing_t += delta
	_spr.frame = int(_wing_t * WING_FPS) % 2         # wing buzz
	if _caught:
		return
	# hover: a lazy figure-eight around the anchor (cheap sin/cos, no physics)
	position = _base + Vector2(sin(_phase * 1.3) * 14.0, sin(_phase * 2.1) * 5.0 + cos(_phase * 0.7) * 3.0)
	_spr.flip_h = cos(_phase * 1.3) < 0.0            # face the drift direction
	if mode != Mode.PEST or _leaving:
		return
	# the pest's mischief: a gentle re-oil drip on the water below (capped at original coverage)
	_stain_t -= delta
	if _stain_t <= 0.0:
		_stain_t = STAIN_EVERY
		get_tree().call_group("oil_manager", "stain_at",
			global_position + Vector2(0.0, 14.0), STAIN_RADIUS, STAIN_AMOUNT)
	# healed water below? the pest loses interest and buzzes away (the field replaces it with joy)
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_method("oil_at"):
		if mgr.oil_at(global_position + Vector2(0.0, 14.0)) < GIVE_UP_CLEAN:
			_clean_t += delta
			if _clean_t > 3.0:
				_buzz_off()
		else:
			_clean_t = 0.0

## The frog's tongue got us (same contract as floating_debris) — gulp: reel to the frog's mouth,
## then a cleanse pulse + Shine + a dab of bubble charge where we were. Blight becomes healing.
func grab(to: Vector2) -> void:
	if _caught:
		return
	_caught = true
	remove_from_group("grabbable")
	var at := global_position
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("bonus"):
		keeper.bonus(FLY_SHINE, at, FLY_CHARGE)
	get_tree().call_group("oil_manager", "spray_at", at + Vector2(0.0, 14.0), 22.0, 0.5)   # cleanse pulse
	Sfx.play("chime", -9.0, 1.6)   # a tiny bright gulp-chime
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", to, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.16)
	tw.chain().tween_callback(queue_free)

## The water below healed — the pest gives up and buzzes up out of the scene, then frees itself.
func _buzz_off() -> void:
	if _leaving:
		return
	_leaving = true
	remove_from_group("grabbable")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 90.0, 1.4).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 1.4)
	tw.chain().tween_callback(queue_free)
