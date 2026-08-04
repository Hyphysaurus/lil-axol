extends Node2D
## Cove composition root. Owns the CoveConfig and injects it into each component in
## _ready() so children depend on the config's interface — never on each other or on
## walking the scene tree. One-way dependency: the parent hands data down.
##
## Child _ready() runs before this (bottom-up), so setup() lands after each child has
## initialised but before the first physics frame — config is always present in time.
##
## PERSISTENCE (Living Watershed slice 1): after injection the root consults WorldState —
## a restored cove spawns clean (oil gone, friend awake, portal open, leak retired); a
## partially-cleaned one re-seeds its saved cleanliness. Milestone saves are wired via
## signals (restored / opened / woke) + a cleanliness save on scene exit. An ECHO run
## (WorldState.echo, set by New Day on a restored cove) skips BOTH: fresh spill, no saves —
## the score replay leaves the world untouched (spec §7).

@export var config: CoveConfig

const IrisWipe := preload("res://game/fx/iris_wipe.gd")
const CompanionScript := preload("res://game/companion/companion.gd")
const ReachMapScript := preload("res://game/cove/reach_map.gd")
const PixelShell := preload("res://game/fx/pixel_shell.gd")

var _echo := false

## HUD + native-res layers that STAY at the cove root (everything else moves into the
## 320x180 world viewport — including Shine, whose "+N" pops are world-anchored, and
## CoveAudio/ShoreHealth/TimeOfDay, whose relative sibling paths move with them).
const KEEP_AT_ROOT := ["RestorationBanner", "NewDay", "TouchControls", "RestorationMeter",
	"ShineHud", "FeatBanner", "PartnerHud", "HighScores", "Hints", "PerfOverlay", "RescueCard"]

var _world: Node2D

## World-side child lookup (post-shell replacement for $Name / get_node_or_null on self).
func _w(n: String) -> Node:
	return _world.get_node_or_null(n) if _world else get_node_or_null(n)

## Is this visit an Echo run? (High-scores board keys off this.)
func is_echo() -> bool:
	return _echo

func _ready() -> void:
	add_to_group("cove_root")
	_echo = WorldState.echo
	WorldState.echo = false          # one reload only; consuming it here makes crossings normal
	WorldState.current_id = config.id
	if not _echo:
		WorldState.mark_visited(config.id)   # the map's memory; echo replays leave the world untouched
	# slice 3 (spec 2026-07-23): the pixel shell wraps every world child into a 320x180
	# SubViewport FIRST; HUD stays at root; world coords are contract-identical.
	var shell := PixelShell.new()
	shell.name = "PixelShell"
	add_child(shell)
	_world = shell.build(self, KEEP_AT_ROOT)
	# the water/footing oracle — FIRST, so every injected component can find it (slice 5).
	# Rect-backed here; a map reach's ReachMap upgrades it to the painted mask in its setup.
	var field := ReachField.new()
	field.setup_rect(config)
	_world.add_child(field)
	_inject(_w("ReachMap"))
	_inject(_w("Axolotl"))
	_inject(_w("OilSpill"))
	_inject(_w("CoveLife"))
	_inject(_w("SeabedBackdrop"))
	_inject(_w("BenthicDress"))   # floor dressing reads the field AFTER ReachMap's mask upgrade
	# thermal vents place themselves on THIS reach's seabed (see thermal_vent.setup). By group, not
	# by name, so adding a fourth vent to the scene needs no edit here. After ReachMap's inject
	# above, which queue_frees the legacy vents on a painted map reach — skip those.
	for vent in get_tree().get_nodes_in_group("thermal_vent"):
		if not vent.is_queued_for_deletion():
			_inject(vent)
	_inject($RestorationBanner)
	_inject($NewDay)
	_inject(_w("CoveAudio"))
	_inject(_w("Friend"))
	_inject(_w("LeakSource"))
	_inject(_w("ShorePollution"))
	_inject(_w("Portal"))
	_inject(_w("Portal2"))
	_inject(_w("DebrisField"))
	_inject(_w("PestField"))
	_inject(_w("LilyPads"))
	_inject(_w("Reeds"))
	_inject(_w("Curios"))
	_inject(_w("ReachState"))
	_inject(_w("InvasiveSchool"))
	_inject($Hints)      # needs the cove id for the once-per-world Cascade tutorial mark
	_inject(get_node_or_null("RescueCard"))   # HUD ceremony card: stateless, but stays root-side (KEEP_AT_ROOT)
	_inject(_w("ScoutDragonfly"))
	_inject(_w("FeatEcho"))
	_apply_environment()
	if Settings.arrive_via_portal:
		var entry_key := Settings.arrive_entry
		Settings.arrive_via_portal = false
		Settings.arrive_entry = ""      # one-shot, same idiom as arrive_via_portal above
		if config.has_map:
			# ReachMap._place_spawn() (run earlier, inside _inject(_w("ReachMap"))) already positioned
			# the axolotl at the painted entry portal marker — a map reach's hardcoded left-edge water
			# reposition below would land it inside solid earth, so only the cosmetic half runs here.
			# entry_key IS the edge just crossed (cove_portal._cross() stamps it straight from the
			# marker's edge) — edge_inward() turns that into the swim-out direction, so east/top/
			# bottom doors send the axolotl IN, not outward/sideways.
			_arrive_wipe(_w("Axolotl") as CharacterBody2D, ReachMapScript.edge_inward(entry_key))
		else:
			_arrive()
	if not _echo:
		_wire_saves()      # wires FIRST: if a re-seed ever crosses the win gate, it must save/score
		_apply_saved()
	# Rebuild the party from world memory BEFORE spawning travellers. Without this the roster only
	# ever held the friend of the reach you were standing in, so a page reload stranded every other
	# rescued partner (and left nothing to toggle back to). Echo runs stay partnerless by design.
	if not _echo:
		for k in WorldState.awake_friend_kinds():
			Settings.roster_include(k)
	_spawn_travellers()    # the party follows everywhere (TotK rule) — after apply, so a restored
	                       # cove's wake_instant has already re-derived the roster

## THE TRAVELLING PARTY (TotK rule): every rescued partner journeys with you — one companion
## instance per roster kind that isn't this cove's own friend. They arrive awake at the
## tidekeeper's side, fanned into follow slots. (An Echo run's New Day resets the roster, so
## echo replays naturally start partnerless — no extra gating needed.)
func _spawn_travellers() -> void:
	var axo := _w("Axolotl") as Node2D
	if axo == null:
		return
	var local_kind := -1
	var friend := _live("Friend")
	if friend and "friend_kind" in config:
		local_kind = config.friend_kind
	# the party ceiling is the number of authored follow slots (four, by design). Say so out loud
	# rather than letting clampi quietly stack two companions on one offset.
	if Settings.run_roster.size() > CompanionScript.SLOT_OFFSETS.size():
		push_warning("Cove: party of %d exceeds the %d follow slots — add SLOT_OFFSETS entries before growing the roster." % [
			Settings.run_roster.size(), CompanionScript.SLOT_OFFSETS.size()])
	# slot 0 belongs to the scene's own friend ONLY when that friend is actually in your party. If
	# it's still asleep (or this reach has no friend at all) nobody is following from slot 0, so the
	# travellers may use it — otherwise a full four-companion party in such a reach needs slots 1..4,
	# and SLOT_OFFSETS only defines four, so clampi would silently stack the last two on one spot.
	var slot := 1 if (local_kind >= 0 and Settings.run_roster.has(local_kind)) else 0
	for kind in Settings.run_roster:
		if kind == local_kind:
			continue                           # the local friend IS this partner — no double
		var t := CompanionScript.new()
		_world.add_child(t)
		t.setup_traveller(config, kind, slot, axo.position)
		slot += 1

## A live (not queued-for-deletion) world-side child by name, or null. Components retire
## themselves in setup() (friend_enabled false, no exit configured...) — never poke a retiring
## node. World-side only (post-shell): RestorationBanner stays at the cove root (KEEP_AT_ROOT)
## and never retires, so its two call sites below look it up directly instead of through here.
func _live(n: String) -> Node:
	var node := _w(n)
	return node if node != null and not node.is_queued_for_deletion() else null

## Spawn-time restore from WorldState (spec §7): the world as you left it.
func _apply_saved() -> void:
	var id := config.id
	var friend := _live("Friend")
	var portal := _live("Portal")
	var oil := _live("OilSpill")
	if WorldState.is_restored(id):
		var banner := get_node_or_null("RestorationBanner")   # KEEP_AT_ROOT: not world-side, bypass _live
		if banner:
			banner.is_restored = true          # latch: no duplicate celebration on re-entry
		if friend and friend.has_method("wake_instant"):
			friend.wake_instant()
			_heal_friend_marks()
			_seat_friend_with_party(friend)
		if oil and oil.has_method("set_clean_fraction"):
			oil.set_clean_fraction(1.0)
		if portal and portal.has_method("force_open"):
			portal.force_open()
		# NOTE: Portal2 needs no restore path — exit2 is plugless BY SPEC (a discovered doorway,
		# never a cave-in), so it self-opens in setup() on every load; there is nothing to remember.
		var leak := _live("LeakSource")
		if leak:
			leak.queue_free()                  # a healed cove's leak stays capped
		return
	# partial progress: re-seed cleanliness + the flags that were individually earned
	if friend and friend.has_method("wake_instant") and bool(WorldState.get_cove(id, "friend_awake", false)):
		friend.wake_instant()
		_heal_friend_marks()
		_seat_friend_with_party(friend)
	if oil and oil.has_method("set_clean_fraction"):
		var f := float(WorldState.get_cove(id, "cleanliness", 0.0))
		if f > 0.02:
			oil.set_clean_fraction(f)
	if portal and portal.has_method("force_open") and bool(WorldState.get_cove(id, "portal_cleared", false)):
		portal.force_open()

## An ALREADY-rescued friend belongs at your side, not back in the corner where you first found it.
## wake_instant restores its rescued STATE but left it standing on friend_pos, so re-entering a reach
## re-materialised the frog ~650px down the estuary (and the hub's turtle likewise) and it had to
## swim the whole reach to catch up — while every OTHER party member spawned beside you, because
## travellers are seated off the axolotl. Seats the local friend the same way, on its own slot 0.
func _seat_friend_with_party(friend: Node) -> void:
	var axo := _w("Axolotl") as Node2D
	if axo == null or not (friend is Node2D):
		return
	(friend as Node2D).position = axo.position + CompanionScript.SLOT_OFFSETS[0]

## Back-fill the friend marks a cold-boot party rebuild needs (WorldState.awake_friend_kinds) for
## saves written before friend_kind was recorded — including a fully restored reach, whose friend is
## awake by definition even if no friend_awake flag was ever written. One disk write per reach, only
## when a key is genuinely missing, so a healed save costs nothing on later visits.
func _heal_friend_marks() -> void:
	if not config.friend_enabled:
		return
	if not bool(WorldState.get_cove(config.id, "friend_awake", false)):
		WorldState.mark(config.id, "friend_awake", true)
	if int(WorldState.get_cove(config.id, "friend_kind", -1)) < 0:
		WorldState.mark(config.id, "friend_kind", config.friend_kind)

## Milestone saves: each signal writes one flag the moment it's earned.
func _wire_saves() -> void:
	var id := config.id
	var banner := get_node_or_null("RestorationBanner")   # KEEP_AT_ROOT: not world-side, bypass _live
	if banner and banner.has_signal("restored"):
		banner.restored.connect(func() -> void: WorldState.mark(id, "restored", true))
	var portal := _live("Portal")
	if portal and portal.has_signal("opened"):
		portal.opened.connect(func() -> void: WorldState.mark(id, "portal_cleared", true))
	# (Portal2 deliberately unwired: it opens synchronously in setup() BEFORE this runs, so a
	# mark here could never fire — and a plugless door has no cleared-state to persist anyway.)
	var friend := _live("Friend")
	if friend and friend.has_signal("woke"):
		# friend_kind rides alongside friend_awake so the party can be rebuilt on a cold boot
		# (WorldState.awake_friend_kinds) instead of dying with the session.
		friend.woke.connect(func() -> void:
			WorldState.mark(id, "friend_awake", true)
			WorldState.mark(id, "friend_kind", config.friend_kind))

## Scene exit (portal cross, New Day, quit): file the scrub progress of an unfinished cove.
func _exit_tree() -> void:
	if _echo:
		return
	if WorldState.is_restored(config.id):
		return
	var oil := _w("OilSpill")
	if oil and "current_clean" in oil:
		WorldState.mark(config.id, "cleanliness", oil.current_clean)

## A tunnel crossing brought us here (legacy/classic reach): the axolotl emerges at THIS cove's
## passage mouth (the left edge of the water — you exited the last cove travelling right), already
## swimming, behind an opening iris — the two coves read as one continuous passage.
func _arrive() -> void:
	var axo := _w("Axolotl") as CharacterBody2D
	axo.position = Vector2(config.water_left + 34.0, config.surface_y + 46.0)
	_arrive_wipe(axo)

## The arrival flourish shared by both reach kinds: still-swimming velocity + an opening iris wipe.
## The legacy path (_arrive above) repositions the axolotl to a hardcoded waterline mouth first; a
## map reach is already positioned by ReachMap._place_spawn() at the painted entry portal marker,
## so it calls straight in here with nothing else to do. dir is the swim-out direction — which way
## "into the map" points from the door just crossed (ReachMap.edge_inward). The legacy classic-reach
## mouth is always the west edge, so _arrive() above omits dir and gets the RIGHT default —
## byte-equivalent to the pre-edge-aware behavior.
func _arrive_wipe(axo: CharacterBody2D, dir: Vector2 = Vector2.RIGHT) -> void:
	var speed: float = axo.tuning.run_speed if axo.tuning else 150.0
	axo.velocity = dir * speed              # still swimming, in whatever direction is "into" the reach
	var wipe := IrisWipe.new()
	_world.add_child(wipe)
	wipe.set_closed()
	wipe.open(0.7)

func _inject(n: Node) -> void:
	# has_method guard keeps the scene runnable while components are migrated one at a time
	if n and n.has_method("setup"):
		n.setup(config)

## Per-cove environment overrides (spec §9): the marsh reads green-tea and muddy without forking
## the scene. Water + soil tints ride shader UNIFORMS (the modulate chain also carries the
## day/night CanvasModulate these shaders ignore). ALWAYS written — white when unset — because
## the water ShaderMaterial is a shared sub-resource cached across cove instances, so an estuary
## visit would otherwise leak its green onto the hub's water for the rest of the session.
func _apply_environment() -> void:
	var wt := config.env_water_tint if config.env_water_tint.a > 0.0 else Color(1.0, 1.0, 1.0, 1.0)
	var water := _w("Water") as Sprite2D
	if water and water.material is ShaderMaterial:
		var wm := water.material as ShaderMaterial
		wm.set_shader_parameter("env_tint", wt)
		# shared sub-resource cached across cove instances: ALWAYS re-assert size, or a canals
		# visit leaks 944px waves onto the hub (same leak class as env_tint — spec I3)
		wm.set_shader_parameter("rect_size", water.scale)
	var lt := config.env_land_tint if config.env_land_tint.a > 0.0 else Color(1.0, 1.0, 1.0, 1.0)
	for n in ["BlockLand", "BlockLandRight", "ReachMap"]:
		var land := _live(n)      # skip nodes queued_for_deletion — ReachMap frees BlockLand/
		if land:                  # BlockLandRight on map reaches before this loop runs
			(land as Node2D).modulate = lt
			if land.has_method("set_env_tint"):
				land.set_env_tint(lt)
