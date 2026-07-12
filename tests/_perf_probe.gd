extends Node
## TEMP perf probe (not shipped): instances a scene passed via user args and prints engine
## monitors once per second for 10s, then quits. Run:
##   godot --path . res://tests/_perf_probe.tscn -- scene=res://canals.tscn

var _t := 0.0
var _acc := 0.0
var _frames := 0
var _min_fps := 99999.0
var _soak := false           # soak mode: simulate play (move/jump/spray) and run 60s
var _dur := 11.0

func _ready() -> void:
	var scene_path := "res://canals.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			scene_path = a.trim_prefix("scene=")
		if a == "soak":
			_soak = true
			_dur = 60.0
	print("[perf] probing %s (soak=%s)" % [scene_path, _soak])
	var packed: PackedScene = load(scene_path)
	add_child(packed.instantiate())

## Crude play simulation: swim around + spray in bursts so per-frame gameplay paths run.
func _drive_input() -> void:
	var phase := int(_t) % 8
	Input.action_release("move_left"); Input.action_release("move_right")
	Input.action_release("move_up"); Input.action_release("move_down")
	if phase < 3: Input.action_press("move_right")
	elif phase < 5: Input.action_press("move_left"); Input.action_press("move_up")
	else: Input.action_press("move_down")
	if int(_t * 2.0) % 3 == 0: Input.action_press("spray")
	else: Input.action_release("spray")
	if int(_t * 4.0) % 9 == 0: Input.action_press("jump")
	else: Input.action_release("jump")

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	_frames += 1
	if _soak and _t > 3.0:
		_drive_input()
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	if _t > 2.0:
		_min_fps = minf(_min_fps, fps)
	if _acc >= 1.0:
		_acc = 0.0
		print("[perf] t=%4.1f fps=%5.0f proc=%6.2fms phys=%6.2fms draws=%5.0f objs=%5.0f prims=%7.0f nodes=%5.0f" % [
			_t, fps,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		])
	if _t >= 3.0 and not _shot:
		_shot = true
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://_probe_shot.png")
		print("[perf] screenshot -> user://_probe_shot.png")
	if _t >= _dur:
		print("[perf] DONE min_fps(after 2s)=%.0f frames=%d" % [_min_fps, _frames])
		get_tree().quit()

var _shot := false
