extends SceneTree
## Smoke test: the apollo_post shader loads, compiles into a material, and takes its uniforms.
## Run: & $godot --headless --path . --script res://tests/test_apollo_post.gd

var _fails := 0

func _init() -> void:
	var sh := load("res://shaders/apollo_post.gdshader")
	_check("shader loads", sh is Shader)
	if sh is Shader:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("dither_strength", 0.5)
		mat.set_shader_parameter("enabled", true)
		_check("uniform round-trip", is_equal_approx(float(mat.get_shader_parameter("dither_strength")), 0.5))
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
