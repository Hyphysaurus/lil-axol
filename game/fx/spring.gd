extends RefCounted
## A critically-damped spring: a value that chases a target with a natural ease-in + follow-through.
## Preloaded (not class_name) by its users so it resolves without an editor pass / global-class cache.
## The workhorse for "offset transform" juice — lean-into-motion, squash settle, secondary motion —
## kept SEPARATE from the gameplay transform so the art can be lively without touching movement. Uses
## semi-implicit Euler with a clamped timestep so a web frame-hitch can't blow it up. Frame-rate
## independent. One line to opt in: keep a Spring, feed it a target each frame, apply value as a skew /
## scale / offset on the SPRITE (never the physics body).

var value: float
var vel := 0.0
var stiffness: float          # how hard it pulls toward target — higher = snappier

func _init(start := 0.0, k := 90.0) -> void:
	value = start
	stiffness = k

## Advance one step toward `target`, return the new value. Critically damped (damping = 2*sqrt(k)), so
## it settles without wobble unless you kick() the velocity — then it springs and overshoots naturally.
func update(target: float, delta: float) -> float:
	var dt := minf(delta, 0.05)                 # a big hitch can't explode the spring
	var accel := (target - value) * stiffness - vel * (2.0 * sqrt(stiffness))
	vel += accel * dt
	value += vel * dt
	return value

## Punch the velocity — for impact pops (a landing squash, a bash recoil): kick(), then let it settle.
func kick(v: float) -> void:
	vel += v
