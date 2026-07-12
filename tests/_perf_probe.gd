extends Node
## TEMP perf probe (not shipped): instances a scene passed via user args and prints engine
## monitors once per second for 10s, then quits. Run:
##   godot --path . res://tests/_perf_probe.tscn -- scene=res://canals.tscn

var _t := 0.0
var _acc := 0.0
var _frames := 0
var _min_fps := 99999.0

func _ready() -> void:
	var scene_path := "res://canals.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			scene_path = a.trim_prefix("scene=")
	print("[perf] probing %s" % scene_path)
	var packed: PackedScene = load(scene_path)
	add_child(packed.instantiate())

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	_frames += 1
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
	if _t >= 11.0:
		print("[perf] DONE min_fps(after 2s)=%.0f frames=%d" % [_min_fps, _frames])
		get_tree().quit()

var _shot := false
