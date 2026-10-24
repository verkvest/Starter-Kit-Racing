extends Node3D

@export_group("Properties")
@export var target: Vehicle

@onready var camera: Camera3D = $Camera

var _snap := true

func snap() -> void:
	_snap = true

func _ready() -> void:
	if camera:
		camera.current = true
		camera.fov = 56.0
		camera.near = 0.08
		camera.far = 180.0
	_follow(1.0)

func _physics_process(delta: float) -> void:
	_follow(delta)

func _follow(delta: float) -> void:
	if target == null or target.vehicle_model == null:
		return
	var fwd: Vector3 = target.vehicle_model.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.001:
		fwd = Vector3(0, 0, 1)
	fwd = fwd.normalized()
	var focus := target.get_vehicle_position()
	var speed := clampf(absf(target.linear_speed), 0.0, 1.0)
	var back := lerpf(7.2, 9.4, speed)
	var want := focus - fwd * back + Vector3(0, 3.35, 0)
	if _snap:
		global_position = want
		_snap = false
	else:
		var blend := 1.0 - exp(-5.0 * delta)
		global_position = global_position.lerp(want, blend)
	var look := focus + fwd * 5.5 + Vector3(0, 1.05, 0)
	if global_position.distance_to(look) > 0.2:
		look_at(look, Vector3.UP)
