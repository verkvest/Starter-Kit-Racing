class_name AiDriver
extends Node

# Positive steer is a right turn (vehicle yaws the other way). Positive angle
# means the target sits to the left, so the sign starts negative.
const STEER_SIGN := -1.0

var vehicle: Vehicle
var points: PackedVector3Array
var outs: Array = []
var reach := 5.0
var throttle_scale := 0.8
var active := true
var next_i := 1
var laps := 0

func setup(car: Vehicle, info: Dictionary, scale: float) -> void:
	vehicle = car
	points = info.points
	outs = info.outs
	reach = float(info.reach)
	throttle_scale = scale
	next_i = 1
	laps = 0
	car.read_player_input = false

func _physics_process(_delta: float) -> void:
	if not active or vehicle == null or points.is_empty():
		return
	_advance()
	var pos := vehicle.get_vehicle_position()
	var aim := _aim_point()
	var fwd: Vector3 = vehicle.vehicle_model.global_transform.basis.z
	fwd.y = 0.0
	var to := aim - pos
	to.y = 0.0
	var steer := 0.0
	if fwd.length() > 0.001 and to.length() > 0.001:
		fwd = fwd.normalized()
		to = to.normalized()
		var signed := atan2(fwd.cross(to).y, fwd.dot(to))
		steer = clampf(STEER_SIGN * signed / 0.75, -1.0, 1.0)
	var throttle := throttle_scale
	if absf(steer) > 0.45:
		throttle = throttle_scale * 0.62
	vehicle.steer_input = steer
	vehicle.throttle_input = throttle

func _aim_point() -> Vector3:
	var n := points.size()
	var immediate: Vector3 = points[next_i]
	var after: Vector3 = points[(next_i + 1) % n]
	var prev := (next_i - 1 + n) % n
	var turning := false
	if outs.size() == n:
		turning = outs[next_i] != outs[prev]
	if turning:
		return immediate
	return immediate.lerp(after, 0.4)

func _advance() -> void:
	var pos := vehicle.get_vehicle_position()
	var n := points.size()
	var guard := 0
	while guard < 3:
		var target: Vector3 = points[next_i]
		var flat := Vector3(pos.x, target.y, pos.z)
		if flat.distance_to(target) > reach:
			break
		var crossed := next_i == 0
		next_i = (next_i + 1) % n
		if crossed:
			laps += 1
		guard += 1
