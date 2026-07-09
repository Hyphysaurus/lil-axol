extends CanvasLayer
## A tunnel-dark IRIS WIPE that sells the pathway between coves as one continuous passage: the
## screen's darkness closes to a shrinking circle as you swim into the tunnel (close), and opens
## back out from the player as you emerge on the other side (open). Ink-dark with a faint aqua rim
## (shaders/iris.gdshader) so it reads as rock-and-water, not an abstract fade.
## Preloaded (not class_name) by its users, like game/fx/spring.gd. Add to the tree, then call
## close()/open(); the layer frees itself after an open() completes.

const IRIS_SHADER := preload("res://shaders/iris.gdshader")

const OPEN_T := 1.3        # shader t when fully open (no darkness on screen)

var _mat: ShaderMaterial

func _init() -> void:
	layer = 200                     # over everything, including PostFX
	_mat = ShaderMaterial.new()
	_mat.shader = IRIS_SHADER
	var r := ColorRect.new()        # the shader ignores the rect colour; it just needs the pixels
	r.material = _mat
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	_set_t(OPEN_T)

## Swallow the screen into tunnel-dark, then fire `done` (e.g. the scene change).
func close(dur: float, done: Callable) -> void:
	var tw := create_tween()
	tw.tween_method(_set_t, OPEN_T, 0.0, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(done)

## Start fully dark (call right after adding, for an arrival).
func set_closed() -> void:
	_set_t(0.0)

## Emerge from the tunnel: the opening grows from the centre, then this layer frees itself.
func open(dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_t, 0.0, OPEN_T, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)

func _set_t(v: float) -> void:
	_mat.set_shader_parameter("t", v)
