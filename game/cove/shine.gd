extends Node
## Shine — the arcade heart of restoration. Scrubbing real oil off (OilSpill's `scrubbed`
## signal) earns Shine: a full clean is worth BASE points, multiplied by a combo that grows
## while you keep scrubbing and gently relaxes when you stop (decay, never penalty).
## Shine also charges the Bubble Bomb — but at UNmultiplied base value, so a bubble's own
## pop can never pay for the next bubble (no runaway chain). Floating "+N" pops rise from
## the scrub spot, throttled and colored by combo warmth. Group "shine": the axolotl spends
## charges here and the banner reads the final tally.

signal score_changed(score: int, mult: int)
signal charge_changed(frac: float)
signal bubble_ready

const BASE := 10000.0          # Shine for scrubbing the whole spill at x1
const CHARGE_COST := 1500.0    # unmultiplied base-Shine per Bubble Bomb
const CHARGE_EVENT_CAP := 60.0 # max charge from any single scrub event: a bubble pop is ONE
                               # huge event, so this stops pops paying for the next bubble
const COMBO_STEP := 0.8        # sustained scrub seconds per combo tier
const COMBO_HOLD := 1.5        # grace after the last scrub before the combo relaxes
const MAX_MULT := 4
const POP_EVERY := 0.4         # floating "+N" throttle

var score := 0.0
var mult := 1

var _sustain := 0.0
var _hold := 0.0
var _charge := 0.0
var _ready_fired := false
var _milestone := 0
var _pop_acc := 0.0
var _pop_at := Vector2.ZERO
var _pop_cd := 0.0

func _ready() -> void:
	add_to_group("shine")
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr:
		if mgr.has_signal("scrubbed"):
			mgr.scrubbed.connect(_on_scrubbed)
		if mgr.has_signal("cleanliness"):
			mgr.cleanliness.connect(_on_clean)

func _on_scrubbed(frac: float, at: Vector2) -> void:
	_hold = COMBO_HOLD
	var base_pts := frac * BASE
	_award(base_pts * float(mult), minf(base_pts, CHARGE_EVENT_CAP))
	_pop_acc += base_pts * float(mult)
	_pop_at = at

func _on_clean(v: float) -> void:
	# escalating milestone bonuses alongside the chimes (score only, no charge)
	while _milestone < 3 and v >= [0.25, 0.5, 0.75][_milestone]:
		_milestone += 1
		_award(250.0 * float(_milestone), 0.0)

func _award(score_pts: float, charge_pts: float) -> void:
	score += score_pts
	_charge += charge_pts
	if _charge >= CHARGE_COST and not _ready_fired:
		_ready_fired = true
		bubble_ready.emit()
		Sfx.play("chime", -8.0, 1.6)
	charge_changed.emit(clampf(_charge / CHARGE_COST, 0.0, 1.0))
	score_changed.emit(int(score), mult)

## One-off bonus (rescues, discoveries): score only, no bubble charge, pops at the spot.
func bonus(points: float, at: Vector2) -> void:
	_award(points, 0.0)
	_pop_acc += points
	_pop_at = at
	Sfx.play("coin", -5.0)   # a little pickup whoosh for any one-off award (rescues, land splats)

## Called by the axolotl when the bubble action fires. False = not charged yet.
func spend_bubble() -> bool:
	if _charge < CHARGE_COST:
		return false
	_charge -= CHARGE_COST
	_ready_fired = _charge >= CHARGE_COST
	charge_changed.emit(clampf(_charge / CHARGE_COST, 0.0, 1.0))
	return true

func _process(delta: float) -> void:
	if _hold > 0.0:
		_hold -= delta
		_sustain += delta
		var target := mini(1 + int(_sustain / COMBO_STEP), MAX_MULT)
		if target != mult:
			mult = target
			score_changed.emit(int(score), mult)
	elif mult != 1 or _sustain > 0.0:
		mult = 1
		_sustain = 0.0
		score_changed.emit(int(score), mult)
	_pop_cd -= delta
	if _pop_acc >= 1.0 and _pop_cd <= 0.0:
		_pop_cd = POP_EVERY
		_spawn_pop(int(round(_pop_acc)), _pop_at)
		_pop_acc = 0.0

## A small "+N" that rises from the scrub spot and melts away. Warmer with higher combo.
func _spawn_pop(amount: int, at: Vector2) -> void:
	var cove := get_parent() as Node2D
	if cove == null:
		return
	var l := Label.new()
	l.text = "+%d" % amount
	l.add_theme_font_size_override("font_size", 16)
	var warm := clampf(float(mult - 1) / 3.0, 0.0, 1.0)
	l.add_theme_color_override("font_color",
		Color(0.95, 0.98, 1.0).lerp(Color(1.0, 0.84, 0.45), warm))
	l.add_theme_color_override("font_shadow_color", Color(0.02, 0.06, 0.10, 0.7))
	l.z_index = 8
	l.position = cove.to_local(at) + Vector2(-10.0, -14.0)
	cove.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)
