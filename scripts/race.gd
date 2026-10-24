extends Node3D

const RED_TRUCK := preload("res://models/vehicle-truck-red.glb")
const VEHICLE_SCENE := preload("res://scenes/vehicle.tscn")

var phase := "countdown"
var countdown := 3.0
var go_left := 0.0
var race_time := 0.0
var lap_time := 0.0
var completed_laps := 0
var total_laps := 3
var show_lap := 1
var race_place := 1
var wrong_way := false
var best_total := -1.0
var best_lap_time := -1.0
var lap_flash := 0.0
var track_name := ""
var new_best := false
var finish_position := 1

var _info: Dictionary = {}
var _player: Vehicle
var _rival: Vehicle
var _player_ai: AiDriver
var _rival_ai: AiDriver
var _view: Node3D
var _hud: Hud
var _next_i := 1
var _wrong_time := 0.0
var _stuck_player := 0.0
var _stuck_rival := 0.0
var _race_age := 0.0
var _shot_time := 0.0
var _shot_done := false

func _ready() -> void:
	var def: Dictionary = TrackLibrary.get_track(GameState.track_id)
	track_name = def.name
	total_laps = int(def.laps)
	best_total = GameState.best_total(def.id)
	best_lap_time = GameState.best_lap(def.id)
	if GameState.autopilot:
		countdown = 0.05
	_build_world(def)
	_hud = Hud.new()
	add_child(_hud)

func _build_world(def: Dictionary) -> void:
	var env := WorldEnvironment.new()
	env.environment = load("res://scenes/main-environment.tres")
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -42, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_bias = 0.15
	sun.directional_shadow_blend_splits = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 140, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.75, 0.86, 1.0)
	fill.shadow_enabled = false
	add_child(fill)

	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(420, 420)
	grass.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = UiStyle.GRASS
	mat.roughness = 1.0
	grass.material_override = mat
	grass.position = Vector3(0, -0.25, 0)
	add_child(grass)

	TrackLibrary.add_floor(self)

	var grid := GridMap.new()
	grid.name = "GridMap"
	grid.mesh_library = load("res://models/Library/mesh-library.tres")
	grid.cell_size = Vector3(TrackLibrary.CELL, 1, TrackLibrary.CELL)
	grid.scale = Vector3.ONE * TrackLibrary.SCALE
	grid.position = Vector3(0, -0.5, 0)
	var phys := PhysicsMaterial.new()
	phys.friction = 0.0
	phys.bounce = 0.05
	grid.physics_material = phys
	add_child(grid)
	_info = TrackLibrary.build(grid, def)
	TrackLibrary.add_walls(self, _info.blockers)

	_player = VEHICLE_SCENE.instantiate()
	_player.name = "Player"
	_rival_ai = AiDriver.new()
	_rival_ai.name = "RivalAI"
	_rival = VEHICLE_SCENE.instantiate()
	_rival.name = "Rook"
	if GameState.autopilot:
		_player_ai = AiDriver.new()
		_player_ai.name = "PlayerAI"
		add_child(_player_ai)
	add_child(_player)
	add_child(_rival_ai)
	add_child(_rival)

	_player.read_player_input = false
	_arm(_player)
	_arm(_rival)
	_rival.apply_model(RED_TRUCK)
	var base: Vector3 = _info.points[0]
	var right: Vector3 = _info.right
	var fwd: Vector3 = _info.forward
	var yaw := float(_info.start_yaw)
	_player.relocate(base + right * -1.6 + Vector3(0, 0.85, 0), yaw)
	_rival.relocate(base + right * 1.6 - fwd * 3.4 + Vector3(0, 0.85, 0), yaw)
	_rival_ai.setup(_rival, _info, 0.8)
	_rival_ai.active = false
	if _player_ai:
		_player_ai.setup(_player, _info, 1.0)
		_player_ai.active = false

	_view = Node3D.new()
	_view.name = "View"
	_view.set_script(load("res://scripts/view.gd"))
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	_view.add_child(camera)
	_view.target = _player
	add_child(_view)

func _arm(car: Vehicle) -> void:
	car.sphere.collision_mask = 1 | 8
	car.sphere.collision_layer = 8

func _physics_process(delta: float) -> void:
	if _info.is_empty():
		return
	if phase == "countdown":
		countdown -= delta
		_zero(_player)
		_zero(_rival)
		_rival_ai.active = false
		if _player_ai:
			_player_ai.active = false
		if _hud:
			_hud.calibrate_tilt()
		if countdown <= 0.0:
			phase = "racing"
			countdown = 0.0
			race_time = 0.0
			lap_time = 0.0
			go_left = 0.0 if GameState.autopilot else 0.7
			_rival_ai.active = true
			if _player_ai:
				_player_ai.active = true
	elif phase == "racing":
		_race_age += delta
		race_time += delta
		lap_time += delta
		if go_left > 0.0:
			go_left -= delta
		if lap_flash > 0.0:
			lap_flash -= delta
		if _player_ai == null and _hud:
			var drive := _hud.drive()
			_player.steer_input = drive.x
			_player.throttle_input = drive.y
		_update_player()
		_stuck(_player, -1.6, _stuck_player, true)
		_stuck(_rival, 1.6, _stuck_rival, false)
		_update_position()
		_shot_watch(delta)
		if completed_laps >= total_laps:
			_finish()

func _zero(car: Vehicle) -> void:
	car.steer_input = 0.0
	car.throttle_input = 0.0
	car.input = Vector3.ZERO
	car.linear_speed = lerpf(car.linear_speed, 0.0, 0.2)

func _update_player() -> void:
	var points: PackedVector3Array = _info.points
	var n := points.size()
	var pos := _player.get_vehicle_position()
	var guard := 0
	while guard < 3:
		var target: Vector3 = points[_next_i]
		if Vector2(pos.x, pos.z).distance_to(Vector2(target.x, target.z)) > float(_info.reach):
			break
		var crossed := _next_i == 0
		_next_i = (_next_i + 1) % n
		if crossed:
			if best_lap_time < 0.0 or lap_time < best_lap_time:
				best_lap_time = lap_time
			lap_time = 0.0
			completed_laps += 1
			show_lap = mini(completed_laps + 1, total_laps)
			lap_flash = 1.1
			if Input.has_method("vibrate_handheld"):
				Input.vibrate_handheld(35)
		guard += 1
	show_lap = mini(completed_laps + 1, total_laps)
	var prev := (_next_i - 1 + n) % n
	var a: Vector3 = points[prev]
	var b: Vector3 = points[_next_i]
	var seg := Vector3(b.x - a.x, 0, b.z - a.z)
	var vel := _player.sphere.linear_velocity
	vel.y = 0.0
	if vel.length() > 2.0 and seg.length() > 0.1 and vel.normalized().dot(seg.normalized()) < -0.35:
		_wrong_time += get_physics_process_delta_time()
	else:
		_wrong_time = 0.0
	wrong_way = _wrong_time > 0.45

func _stuck(car: Vehicle, side: float, timer: float, is_player: bool) -> void:
	var speed := car.sphere.linear_velocity.length()
	var fallen := car.get_vehicle_position().y < -2.0
	if fallen or (_race_age > 1.6 and speed < 1.1):
		timer += get_physics_process_delta_time()
	else:
		timer = 0.0
	if is_player:
		_stuck_player = timer
	else:
		_stuck_rival = timer
	if fallen or timer > 2.5:
		_respawn(car, side)
		if is_player:
			_stuck_player = 0.0
		else:
			_stuck_rival = 0.0

func _respawn(car: Vehicle, side: float) -> void:
	var points: PackedVector3Array = _info.points
	var n := points.size()
	var idx := _next_i if car == _player else _rival_ai.next_i
	var prev := (idx - 1 + n) % n
	var outs: Array = _info.outs
	var dir: Vector2i = outs[prev]
	var fwd := TrackLibrary.forward_of(dir)
	var right := TrackLibrary.right_of(fwd)
	var pos: Vector3 = points[prev] + right * side - fwd * 1.2 + Vector3(0, 0.85, 0)
	car.relocate(pos, TrackLibrary.yaw_of(dir))
	if car == _player and _view and _view.has_method("snap"):
		_view.snap()

func _progress(next_i: int, laps: int, pos: Vector3) -> float:
	var points: PackedVector3Array = _info.points
	var n := points.size()
	var prev := (next_i - 1 + n) % n
	var a: Vector3 = points[prev]
	var b: Vector3 = points[next_i]
	var seg := Vector3(b.x - a.x, 0, b.z - a.z)
	var rel := Vector3(pos.x - a.x, 0, pos.z - a.z)
	var along := 0.0
	var sl := seg.length()
	if sl > 0.01:
		along = clampf(rel.dot(seg) / (sl * sl), 0.0, 1.0)
	return float(laps * n + prev) + along

func _update_position() -> void:
	var player_p := _progress(_next_i, completed_laps, _player.get_vehicle_position())
	var rival_p := _progress(_rival_ai.next_i, _rival_ai.laps, _rival.get_vehicle_position())
	race_place = 1 if player_p >= rival_p else 2

func _finish() -> void:
	phase = "finished"
	finish_position = 1 if _rival_ai.laps < total_laps else 2
	race_place = finish_position
	var previous := GameState.best_total(GameState.track_id)
	new_best = previous < 0.0 or race_time < previous
	GameState.record_race(GameState.track_id, race_time, best_lap_time)
	best_total = GameState.best_total(GameState.track_id)
	var place := "1st" if finish_position == 1 else "2nd"
	var body := "%s place\nTime %s\nBest lap %s\nBest race %s" % [
		place,
		UiStyle.format_time(race_time),
		UiStyle.format_time(best_lap_time),
		UiStyle.format_time(best_total),
	]
	if new_best:
		body += "\nNew best"
	if _hud:
		_hud.show_results(track_name, body)

func _shot_watch(delta: float) -> void:
	if not GameState.autopilot or GameState.shot != "gameplay" or _shot_done:
		return
	_shot_time += delta
	if _next_i >= 3 or _shot_time > 12.0:
		_shot_done = true
		_capture_shot()

func _capture_shot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await GameState.capture(GameState.shot_file("gameplay.png"))
	get_tree().quit()
