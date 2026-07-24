extends Node
## Slice-3 pixel shell (spec 2026-07-23): wraps the cove's world subtree in a 320x180
## SubViewport at runtime so the whole world renders on one integer-scaled pixel grid while
## HUD layers stay native-res at the cove root. Layout math is pure + static for headless
## testing. Preloaded (not class_name) by cove.gd — same portable pattern as game/fx/spring.gd.

## 2026-07-24 grid retune (Maram's live verdict: "size is fine, texture feels crude"):
## the EFFECT grid is 640x360 while the camera runs x2, so the world framing and art-pixel
## size on screen are byte-identical to the 320x180 shell — only shaders, particles, and
## dither render at double resolution. Art pixels stay integer (1 art px = 2 viewport px).
const BASE := Vector2i(640, 360)

## Biggest integer scale that fits the physical window, view expanded to fill the remainder
## (ratified fill policy: integer + expand, never letterbox, never fractional world pixels).
static func compute_layout(phys: Vector2i) -> Dictionary:
	if phys.x <= 0 or phys.y <= 0:
		return {"scale": 1, "view": BASE}   # headless / degenerate window: neutral shell
	var k := maxi(1, mini(phys.x / BASE.x, phys.y / BASE.y))   # int division = floor
	return {"scale": k, "view": Vector2i(ceili(phys.x / float(k)), ceili(phys.y / float(k)))}

var _container: SubViewportContainer
var _viewport: SubViewport
var _snap_mat: ShaderMaterial

## Build the shell under `cove` and move every child NOT named in keep_at_root into the world
## viewport. Call FIRST in cove.gd._ready(), before any injection. Returns the WorldOffset node
## that all new world content must parent to (its transform reproduces the cove root's global
## transform — the coordinate contract).
func build(cove: Node2D, keep_at_root: Array) -> Node2D:
	var layer := CanvasLayer.new()
	layer.name = "WorldShell"
	layer.layer = -120                       # under every HUD CanvasLayer at the cove root
	_container = SubViewportContainer.new()
	_container.name = "WorldView"
	_container.stretch = true                # shrink stays 1: _resize sizes the viewport directly
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport = SubViewport.new()
	_viewport.name = "World"
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.disable_3d = true
	var world := Node2D.new()
	world.name = "WorldOffset"
	world.transform = cove.global_transform  # the coordinate contract: world coords == today's
	_viewport.add_child(world)
	_container.add_child(_viewport)
	# 2026-07-24 ruling (Maram: "not sure I want to keep this palette" + "world feels too
	# muted"; A/B screenshot bisect confirmed): the global snap's nearest-swatch mapping
	# desaturates and red-shifts the scene hard (warm terrain browns -> muted reds). The snap
	# ships OFF; the shader + dither stack stay mounted for a future palette dial session.
	const SNAP_ENABLED := false
	var snap_layer := CanvasLayer.new()
	snap_layer.visible = SNAP_ENABLED
	snap_layer.name = "ApolloSnap"
	snap_layer.layer = 90                    # BELOW PostFX (100) + iris (200): grain/vignette/iris
	                                         # stay smooth — quantizing them read as all-over noise
	                                         # (2026-07-24 eyeball retune; was 250)
	var snap_rect := ColorRect.new()
	snap_rect.name = "Snap"
	snap_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	snap_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snap_mat = ShaderMaterial.new()
	_snap_mat.shader = preload("res://shaders/apollo_post.gdshader")
	snap_rect.material = _snap_mat
	snap_layer.add_child(snap_rect)
	_viewport.add_child(snap_layer)
	layer.add_child(_container)
	add_child(layer)
	for c in cove.get_children():            # get_children() returns a copy — safe to reparent in-loop
		if c == self or String(c.name) in keep_at_root:
			continue
		c.reparent(world)                    # keep_global default: Node2D locals recompute to identical values
	_resize()
	get_tree().root.size_changed.connect(_resize)
	return world

## Integer scaling in PHYSICAL pixels, counter-scaled against the canvas_items stretch factor
## (design/phys) so world texels land on exact physical pixels on every device.
func _resize() -> void:
	var phys := DisplayServer.window_get_size()
	var lay := compute_layout(phys)
	_container.size = Vector2(lay["view"])   # local units == world pixels (stretch, shrink 1)
	var design := get_viewport().get_visible_rect().size
	var f := (design.y / float(phys.y)) if (phys.y > 0 and design.y > 0.0) else 1.0
	_container.scale = Vector2.ONE * (float(lay["scale"]) * f)
	_container.position = Vector2.ZERO

## Anchor the snap shader's Bayer pattern to WORLD pixels: push the camera's canvas translation
## each frame so the dither weave scrolls with the art instead of sitting on the screen like a
## fixed noise overlay (2026-07-24 eyeball retune).
func _process(_delta: float) -> void:
	if _snap_mat and _viewport:
		_snap_mat.set_shader_parameter("world_ofs", _viewport.canvas_transform.origin)
