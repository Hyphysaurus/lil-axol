extends Node
## Shine — the arcade heart of restoration. Scrubbing real oil off (OilSpill's `scrubbed`
## signal) earns Shine: a full clean is worth BASE points, multiplied by a combo that grows
## while you keep scrubbing and gently relaxes when you stop (decay, never penalty).
## Shine also charges the Bubble Bomb — but at UNmultiplied base value, so a bubble's own
## pop can never pay for the next bubble (no runaway chain). Floating "+N" pops rise from
## the scrub spot, throttled and colored by combo warmth. Group "shine": the axolotl spends
## charges here and the banner reads the final tally.
##
## FEATS + FLOW (the SSX-Tricky layer): named skilful moments — a Geyser, a Bank Shot, a Deep
## Clean — are recognised with a callout + bonus Shine and fill a FLOW meter. Fill it and the cove
## enters TIDAL FLOW for a few seconds where every award DOUBLES. Feats are data (see FEATS) and are
## reported here via feat() by whoever detects them; combo-based feats (Deep Clean, Combo Keeper,
## Chain Bloom) are detected in this node since it already owns the combo/streak state.

signal score_changed(score: int, mult: int)
signal charge_changed(frac: float)
signal bubble_ready
signal feat_called(title: String, points: int)   # a named feat landed -> the callout banner shows it
signal flow_changed(frac: float, active: bool)    # Flow meter fill (0..1) + whether TIDAL FLOW is live

const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne.ttf")   # chunky rounded font for the "+N" pops
const BASE := 10000.0          # Shine for scrubbing the whole spill at x1
const CHARGE_COST := 1500.0    # unmultiplied base-Shine per Bubble Bomb
const CHARGE_EVENT_CAP := 60.0 # max charge from any single scrub event: a bubble pop is ONE
                               # huge event, so this stops pops paying for the next bubble
const COMBO_STEP := 0.8        # sustained scrub seconds per combo tier
const COMBO_HOLD := 1.5        # grace after the last scrub before the combo relaxes
const MAX_MULT := 4
const POP_EVERY := 0.4         # floating "+N" throttle

## Feat catalog: id -> [display title, Shine bonus, Flow fill 0..1]. Data-driven — a new feat is one
## row here plus one `feat(id, at)` call from wherever it's detected. Bonus is doubled in TIDAL FLOW.
const FEATS := {
	&"deep_clean":   ["Deep Clean",   1500.0, 0.30],
	&"combo_keeper": ["Combo Keeper", 1200.0, 0.22],
	&"chain_bloom":  ["Chain Bloom",  2000.0, 0.34],
	&"geyser":       ["Geyser!",      3000.0, 0.40],
	&"wake_up":      ["Wake-Up Call",  500.0, 0.25],
	&"bank_shot":    ["Bank Shot",    1800.0, 0.34],
	&"trove":        ["Trove",        1800.0, 0.28],
	&"spring_clean": ["Spring Clean", 1100.0, 0.22],
	&"curio":        ["Curio Found",   800.0, 0.18],
	&"cascade":      ["The Cascade!", 2400.0, 0.38],   # bubble bounce -> gill-kick -> dive-splash,
}                                                      # one flight (detected by the axolotl)
const FLOW_DURATION := 8.0     # seconds of TIDAL FLOW once the meter fills
const FLOW_MULT := 2.0         # award multiplier while TIDAL FLOW is live
const DEEP_CLEAN_FRAC := 0.14  # coverage lifted in ONE unbroken combo streak that earns Deep Clean
const COMBO_KEEP_SECS := 4.0   # seconds held at max combo that earns Combo Keeper
const CHAIN_WINDOW := 6.0      # two cleanliness milestones within this many seconds = Chain Bloom

var score := 0.0
var mult := 1

var _sustain := 0.0
var _hold := 0.0
var _charge := 0.0
var _ready_fired := false
var _trickle_acc := 0.0        # 4Hz accumulator for the ambient bubble recharge
var _milestone := 0
var _mgr: Node                 # the oil manager — kept so _on_clean can read its is_seeding flag
var _pop_acc := 0.0
var _pop_at := Vector2.ZERO
var _pop_cd := 0.0
# --- feats + flow ---
var _elapsed := 0.0            # monotonic seconds (Time.* would break resume; we just accumulate)
var _flow := 0.0              # Flow meter 0..1
var _flow_t := 0.0           # remaining TIDAL FLOW seconds (drains the bar visually)
var _flow_active := false
var _streak_clean := 0.0     # coverage lifted in the current combo streak (Deep Clean)
var _streak_fired := false   # one Deep Clean per streak
var _maxcombo_t := 0.0       # seconds held at MAX_MULT (Combo Keeper)
var _combo_fired := false
var _last_milestone_t := -100.0   # _elapsed when the previous milestone crossed (Chain Bloom)

func _ready() -> void:
	add_to_group("shine")
	score = Settings.run_score   # resume the run's total if we arrived here through a pathway
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr:
		_mgr = mgr
		if mgr.has_signal("scrubbed"):
			mgr.scrubbed.connect(_on_scrubbed)
		if mgr.has_signal("cleanliness"):
			mgr.cleanliness.connect(_on_clean)

func _on_scrubbed(frac: float, at: Vector2) -> void:
	_hold = COMBO_HOLD
	var base_pts := frac * BASE
	var gained := base_pts * float(mult) * _flow_mult()
	_award(gained, minf(base_pts, CHARGE_EVENT_CAP))
	_pop_acc += gained
	_pop_at = at
	# Deep Clean: a lot of oil lifted inside a single unbroken combo streak (mult >= 2)
	if mult >= 2 and not _streak_fired:
		_streak_clean += frac
		if _streak_clean >= DEEP_CLEAN_FRAC:
			_streak_fired = true
			feat(&"deep_clean", at)

func _on_clean(v: float) -> void:
	# escalating MILESTONE bonuses at 25/50/75% — a real reward (2.5k/5k/7.5k) with a celebratory
	# chime + a big "+N" pop, so hitting a quarter reads as an event, not a rounding error.
	if _mgr and "is_seeding" in _mgr and _mgr.is_seeding:
		# this cleanliness value arrived from a reload re-seed (OilSpill.set_clean_fraction), not
		# live scrubbing — a scene-local Shine's _milestone cursor always resets to 0 on load, so
		# without this guard every cove revisit with saved progress >= 25% replays every crossed
		# milestone's Shine + chime (score farm via reload/portal-hop, D-0007). Seed the cursor to
		# match instead of awarding — same idiom as OilSpill's own milestone-cursor recompute.
		_milestone = 0
		for m in [0.25, 0.5, 0.75]:
			if v >= m:
				_milestone += 1
		return
	while _milestone < 3 and v >= [0.25, 0.5, 0.75][_milestone]:
		_milestone += 1
		var reward := 2500.0 * float(_milestone) * _flow_mult()
		_award(reward, 0.0)
		_pop_acc += reward                      # show it as a fat "+N" at the last scrub spot
		Sfx.play("whimsy", -3.0, 1.1 + 0.12 * float(_milestone))   # rising celebratory sparkle
		# Chain Bloom: this milestone landed within CHAIN_WINDOW of the previous one
		if _elapsed - _last_milestone_t <= CHAIN_WINDOW:
			feat(&"chain_bloom", _pop_at)
		_last_milestone_t = _elapsed

func _award(score_pts: float, charge_pts: float) -> void:
	score += score_pts
	Settings.run_score = score   # keep the carried total current, so a pathway crossing resumes it
	_charge += charge_pts
	if _charge >= CHARGE_COST and not _ready_fired:
		_ready_fired = true
		bubble_ready.emit()
		Sfx.play("chime", -8.0, 1.6)
	charge_changed.emit(clampf(_charge / CHARGE_COST, 0.0, 1.0))
	score_changed.emit(int(score), mult)

## One-off bonus (small pickups like shore splats): score + an optional dab of bubble charge, pops at
## the spot. `charge` lets the frog's fly-catches provision the Hydro Pack — capped at the same
## per-event ceiling as scrubbing so no pickup loop can out-charge the core verb (D-0006 stays true).
## For NAMED, celebrated moments use feat() instead — that adds a callout + Flow. Doubled in TIDAL FLOW.
func bonus(points: float, at: Vector2, charge := 0.0) -> void:
	var pts := points * _flow_mult()
	_award(pts, minf(charge, CHARGE_EVENT_CAP))
	_pop_acc += pts
	_pop_at = at
	Sfx.play("coin", -5.0)   # a little pickup whoosh for any one-off award

## Report a named FEAT (called by whoever detects it — a vent opening, a bank-shot bubble, etc.).
## Awards its catalog bonus (x2 in TIDAL FLOW), fires the callout banner, and fills the Flow meter —
## which tips the cove into TIDAL FLOW when it tops out. Unknown ids are ignored so callers stay safe.
func feat(id: StringName, at: Vector2) -> void:
	if not FEATS.has(id):
		return
	var f: Array = FEATS[id]
	var pts: float = float(f[1]) * _flow_mult()
	_award(pts, 0.0)
	_pop_acc += pts
	_pop_at = at
	feat_called.emit(str(f[0]), int(pts))
	Sfx.play("whimsy", -1.0, 1.35)      # a bright feat sting over the normal chimes
	if not _flow_active:                 # feats during TIDAL FLOW just score double; they don't refill
		_flow = minf(1.0, _flow + float(f[2]))
		flow_changed.emit(_flow, false)
		if _flow >= 1.0:
			_enter_flow()

func _flow_mult() -> float:
	return FLOW_MULT if _flow_active else 1.0

## Tip into TIDAL FLOW: a fixed window where every award doubles. The bar then drains over the window.
func _enter_flow() -> void:
	_flow_active = true
	_flow_t = FLOW_DURATION
	flow_changed.emit(1.0, true)
	feat_called.emit("TIDAL FLOW!", 0)   # points == 0 -> the banner renders the big mode callout
	Sfx.play("win", -6.0)                # a soft euphoric swell as the cove blooms

## Called by the axolotl when the bubble action fires. False = not charged yet.
func spend_bubble() -> bool:
	if _charge < CHARGE_COST:
		return false
	_charge -= CHARGE_COST
	_ready_fired = _charge >= CHARGE_COST
	charge_changed.emit(clampf(_charge / CHARGE_COST, 0.0, 1.0))
	return true

func _process(delta: float) -> void:
	_elapsed += delta
	# ambient recharge: clean water slowly refills the Hydro Pack on its own (full in ~45s). Caps at
	# ONE charge and is dwarfed by active scrubbing — it exists so the bomb can never be STARVED
	# (a 100%-restored cove has no oil left to scrub, which used to dead-end the bubble forever).
	# Ticked at 4Hz so the HUD signals _award emits don't churn every frame.
	if _charge < CHARGE_COST:
		_trickle_acc += delta
		if _trickle_acc >= 0.25:
			_award(0.0, _trickle_acc * CHARGE_COST / 45.0)
			_trickle_acc = 0.0
	# TIDAL FLOW countdown: the Flow bar drains across the window, then the mode ends and resets.
	if _flow_active:
		_flow_t -= delta
		_flow = maxf(0.0, _flow_t / FLOW_DURATION)
		flow_changed.emit(_flow, true)
		if _flow_t <= 0.0:
			_flow_active = false
			_flow = 0.0
			flow_changed.emit(0.0, false)
	if _hold > 0.0:
		_hold -= delta
		_sustain += delta
		var target := mini(1 + int(_sustain / COMBO_STEP), MAX_MULT)
		if target != mult:
			if target > mult:
				Sfx.play("whimsy", -8.0, 1.0 + 0.16 * float(target))   # rising pitch each combo tier up
			mult = target
			score_changed.emit(int(score), mult)
	elif mult != 1 or _sustain > 0.0:
		mult = 1
		_sustain = 0.0
		_streak_clean = 0.0          # combo streak ended -> re-arm the Deep Clean latch
		_streak_fired = false
		score_changed.emit(int(score), mult)
	# Combo Keeper: hold the top multiplier for a good stretch
	if mult >= MAX_MULT:
		_maxcombo_t += delta
		if _maxcombo_t >= COMBO_KEEP_SECS and not _combo_fired:
			_combo_fired = true
			feat(&"combo_keeper", _pop_at)
	else:
		_maxcombo_t = 0.0
		_combo_fired = false
	_pop_cd -= delta
	if _pop_acc >= 1.0 and _pop_cd <= 0.0:
		_pop_cd = POP_EVERY
		_spawn_pop(int(round(_pop_acc)), _pop_at)
		_pop_acc = 0.0

## A "+N" that BOUNCES up from the scrub spot and melts away — bigger, warmer, and bouncier the
## higher your combo. On the chunky Lilita One font so the numbers feel good.
func _spawn_pop(amount: int, at: Vector2) -> void:
	var cove := get_parent() as Node2D
	if cove == null:
		return
	var warm := clampf(float(mult - 1) / 3.0, 0.0, 1.0)
	var l := Label.new()
	l.text = "+%d" % amount
	l.add_theme_font_override("font", DISPLAY_FONT)
	l.add_theme_font_size_override("font_size", 18 + int(12.0 * warm))   # bigger with combo
	l.add_theme_color_override("font_color", Palette.FOAM.lerp(Palette.GOLD, warm))
	l.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.z_index = 8
	l.position = cove.to_local(at) + Vector2(-10.0, -14.0)
	l.pivot_offset = Vector2(12.0, 10.0)
	l.scale = Vector2(1.5, 1.5)
	cove.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 26.0, 0.85).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
