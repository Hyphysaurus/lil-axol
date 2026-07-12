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

var _echo := false

## Is this visit an Echo run? (High-scores board keys off this.)
func is_echo() -> bool:
	return _echo

func _ready() -> void:
	add_to_group("cove_root")
	_echo = WorldState.echo
	WorldState.echo = false          # one reload only; consuming it here makes crossings normal
	WorldState.current_id = config.id
	# the water/footing oracle — FIRST, so every injected component can find it (slice 5).
	# Rect-backed here; a map reach's ReachMap upgrades it to the painted mask in its setup.
	var field := ReachField.new()
	field.setup_rect(config)
	add_child(field)
	_inject($ReachMap)
	_inject($Axolotl)
	_inject($OilSpill)
	_inject($CoveLife)
	_inject($SeabedBackdrop)
	_inject($RestorationBanner)
	_inject($NewDay)
	_inject($CoveAudio)
	_inject($Friend)
	_inject($LeakSource)
	_inject($ShorePollution)
	_inject($Portal)
	_inject($Portal2)
	_inject($DebrisField)
	_inject($PestField)
	_inject($LilyPads)
	_inject($Reeds)
	_inject($Curios)
	_inject($ReachState)
	_inject($InvasiveSchool)
	_inject($Hints)      # needs the cove id for the once-per-world Cascade tutorial mark
	_apply_environment()
	if Settings.arrive_via_portal:
		var entry_key := Settings.arrive_entry
		Settings.arrive_via_portal = false
		Settings.arrive_entry = ""      # one-shot, same idiom as arrive_via_portal above
		if config.has_map:
			# ReachMap._place_spawn() (run earlier, inside _inject($ReachMap)) already positioned the
			# axolotl at the painted entry portal marker — a map reach's hardcoded left-edge water
			# reposition below would land it inside solid earth, so only the cosmetic half runs here.
			# entry_key IS the edge just crossed (cove_portal._cross() stamps it straight from the
			# marker's edge) — edge_inward() turns that into the swim-out direction, so east/top/
			# bottom doors send the axolotl IN, not outward/sideways.
			_arrive_wipe($Axolotl as CharacterBody2D, ReachMapScript.edge_inward(entry_key))
		else:
			_arrive()
	if not _echo:
		_wire_saves()      # wires FIRST: if a re-seed ever crosses the win gate, it must save/score
		_apply_saved()
	_spawn_travellers()    # the party follows everywhere (TotK rule) — after apply, so a restored
	                       # cove's wake_instant has already re-derived the roster

## THE TRAVELLING PARTY (TotK rule): every rescued partner journeys with you — one companion
## instance per roster kind that isn't this cove's own friend. They arrive awake at the
## tidekeeper's side, fanned into follow slots. (An Echo run's New Day resets the roster, so
## echo replays naturally start partnerless — no extra gating needed.)
func _spawn_travellers() -> void:
	var axo := get_node_or_null("Axolotl") as Node2D
	if axo == null:
		return
	var local_kind := -1
	var friend := _live("Friend")
	if friend and "friend_kind" in config:
		local_kind = config.friend_kind
	var slot := 1                              # slot 0 belongs to the scene's own friend
	for kind in Settings.run_roster:
		if kind == local_kind:
			continue                           # the local friend IS this partner — no double
		var t := CompanionScript.new()
		add_child(t)
		t.setup_traveller(config, kind, slot, axo.position)
		slot += 1

## A live (not queued-for-deletion) child by name, or null. Components retire themselves in
## setup() (friend_enabled false, no exit configured...) — never poke a retiring node.
func _live(n: String) -> Node:
	var node := get_node_or_null(n)
	return node if node != null and not node.is_queued_for_deletion() else null

## Spawn-time restore from WorldState (spec §7): the world as you left it.
func _apply_saved() -> void:
	var id := config.id
	var friend := _live("Friend")
	var portal := _live("Portal")
	var portal2 := _live("Portal2")
	var oil := _live("OilSpill")
	if WorldState.is_restored(id):
		var banner := _live("RestorationBanner")
		if banner:
			banner.is_restored = true          # latch: no duplicate celebration on re-entry
		if friend and friend.has_method("wake_instant"):
			friend.wake_instant()
		if oil and oil.has_method("set_clean_fraction"):
			oil.set_clean_fraction(1.0)
		if portal and portal.has_method("force_open"):
			portal.force_open()
		if portal2 and portal2.has_method("force_open") and config.exit2_enabled:
			portal2.force_open()
		var leak := _live("LeakSource")
		if leak:
			leak.queue_free()                  # a healed cove's leak stays capped
		return
	# partial progress: re-seed cleanliness + the flags that were individually earned
	if friend and friend.has_method("wake_instant") and bool(WorldState.get_cove(id, "friend_awake", false)):
		friend.wake_instant()
	if oil and oil.has_method("set_clean_fraction"):
		var f := float(WorldState.get_cove(id, "cleanliness", 0.0))
		if f > 0.02:
			oil.set_clean_fraction(f)
	if portal and portal.has_method("force_open") and bool(WorldState.get_cove(id, "portal_cleared", false)):
		portal.force_open()
	if portal2 and portal2.has_method("force_open") and config.exit2_enabled \
			and bool(WorldState.get_cove(id, "portal2_cleared", false)):
		portal2.force_open()

## Milestone saves: each signal writes one flag the moment it's earned.
func _wire_saves() -> void:
	var id := config.id
	var banner := _live("RestorationBanner")
	if banner and banner.has_signal("restored"):
		banner.restored.connect(func() -> void: WorldState.mark(id, "restored", true))
	var portal := _live("Portal")
	if portal and portal.has_signal("opened"):
		portal.opened.connect(func() -> void: WorldState.mark(id, "portal_cleared", true))
	var portal2 := _live("Portal2")
	if portal2 and portal2.has_signal("opened") and config.exit2_enabled:
		portal2.opened.connect(func() -> void: WorldState.mark(id, "portal2_cleared", true))
	var friend := _live("Friend")
	if friend and friend.has_signal("woke"):
		friend.woke.connect(func() -> void: WorldState.mark(id, "friend_awake", true))

## Scene exit (portal cross, New Day, quit): file the scrub progress of an unfinished cove.
func _exit_tree() -> void:
	if _echo:
		return
	if WorldState.is_restored(config.id):
		return
	var oil := get_node_or_null("OilSpill")
	if oil and "current_clean" in oil:
		WorldState.mark(config.id, "cleanliness", oil.current_clean)

## A tunnel crossing brought us here (legacy/classic reach): the axolotl emerges at THIS cove's
## passage mouth (the left edge of the water — you exited the last cove travelling right), already
## swimming, behind an opening iris — the two coves read as one continuous passage.
func _arrive() -> void:
	var axo := $Axolotl as CharacterBody2D
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
	add_child(wipe)
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
	var water := get_node_or_null("Water") as Sprite2D
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
