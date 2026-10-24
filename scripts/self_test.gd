extends Node

const RAYS := {
	"E": Vector3(1, 0, 0),
	"N": Vector3(0, 0, 1),
	"W": Vector3(-1, 0, 0),
	"S": Vector3(0, 0, -1),
}

func run() -> int:
	var failed := 0
	failed += _orient()
	failed += _tracks()
	failed += await _rays()
	failed += await _drive()
	failed += await _ai()
	print("SELFTEST failures ", failed)
	return 1 if failed > 0 else 0

func _orient() -> int:
	var grid := GridMap.new()
	var samples := [
		[0.0, 0],
		[PI / 2.0, 16],
		[PI, 10],
		[-PI / 2.0, 22],
	]
	var bad := 0
	for pair in samples:
		var idx := grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, float(pair[0])))
		print("ORTHO angle ", pair[0], " index ", idx, " expected ", pair[1])
		if idx != int(pair[1]):
			bad += 1
	grid.free()
	return bad

func _tracks() -> int:
	var bad := 0
	for track in TrackLibrary.all():
		var reason := TrackLibrary.validate(track)
		print("TRACK ", track.id, " ", "OK" if reason == "" else reason, " cells ", str(track.moves).length())
		if reason != "":
			bad += 1
	return bad

func _rays() -> int:
	var host := Node3D.new()
	add_child(host)
	var grid := GridMap.new()
	grid.mesh_library = load("res://models/Library/mesh-library.tres")
	grid.cell_size = Vector3(TrackLibrary.CELL, 1, TrackLibrary.CELL)
	grid.scale = Vector3.ONE * TrackLibrary.SCALE
	grid.position = Vector3(0, -0.5, 0)
	host.add_child(grid)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bad := 0
	var cases := [
		["straight", TrackLibrary.STRAIGHT, 0, ["N", "S"]],
		["straight", TrackLibrary.STRAIGHT, 16, ["E", "W"]],
		["corner", TrackLibrary.CORNER, 0, ["N", "W"]],
		["corner", TrackLibrary.CORNER, 16, ["E", "N"]],
		["corner", TrackLibrary.CORNER, 10, ["E", "S"]],
		["corner", TrackLibrary.CORNER, 22, ["S", "W"]],
	]
	for case in cases:
		grid.clear()
		grid.set_cell_item(Vector3i.ZERO, int(case[1]), int(case[2]))
		await get_tree().physics_frame
		var center: Vector3 = grid.to_global(grid.map_to_local(Vector3i.ZERO))
		var open := _open_sides(grid, center + Vector3(0, 1.0, 0))
		var expect: Array = case[3].duplicate()
		expect.sort()
		var got := open.duplicate()
		got.sort()
		var ok := str(got) == str(expect)
		print("RAY ", case[0], " rot ", case[2], " open ", got, " expected ", expect, " ", "OK" if ok else "FAIL")
		if not ok:
			bad += 1
	host.queue_free()
	return bad

func _open_sides(grid: GridMap, origin: Vector3) -> Array:
	var space := grid.get_world_3d().direct_space_state
	var reach := TrackLibrary.CELL_WORLD * 0.9
	var scored: Array = []
	for key in ["E", "N", "W", "S"]:
		var dir: Vector3 = RAYS[key]
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		var dist := 999.0
		if not hit.is_empty():
			dist = origin.distance_to(hit.position)
		scored.append([dist, key])
		print("  dist ", key, " ", snapped(dist, 0.01))
	scored.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	return [scored[0][1], scored[1][1]]

func _drive() -> int:
	var host := Node3D.new()
	add_child(host)
	TrackLibrary.add_floor(host)
	var car: Vehicle = load("res://scenes/vehicle.tscn").instantiate()
	host.add_child(car)
	car.read_player_input = false
	car.throttle_input = 1.0
	car.steer_input = 0.0
	car.relocate(Vector3(0, 1.2, 0), 0.0)
	for _i in 220:
		car.throttle_input = 1.0
		car.steer_input = 0.0
		await get_tree().physics_frame
	var pos := car.get_vehicle_position()
	print("DRIVE pos ", pos, " speed ", car.sphere.linear_velocity)
	var bad := 0
	if pos.z < 2.0:
		print("DRIVE expected +Z > 2")
		bad = 1
	host.queue_free()
	return bad

func _ai() -> int:
	var host := Node3D.new()
	add_child(host)
	TrackLibrary.add_floor(host)
	var grid := GridMap.new()
	grid.mesh_library = load("res://models/Library/mesh-library.tres")
	grid.cell_size = Vector3(TrackLibrary.CELL, 1, TrackLibrary.CELL)
	grid.scale = Vector3.ONE * TrackLibrary.SCALE
	grid.position = Vector3(0, -0.5, 0)
	host.add_child(grid)
	var info: Dictionary = TrackLibrary.build(grid, TrackLibrary.get_track("pond"))
	TrackLibrary.add_walls(host, info.blockers)
	var ai := AiDriver.new()
	var car: Vehicle = load("res://scenes/vehicle.tscn").instantiate()
	host.add_child(ai)
	host.add_child(car)
	car.sphere.collision_mask = 1 | 8
	var base: Vector3 = info.points[0]
	car.relocate(base + Vector3(0, 0.85, 0), float(info.start_yaw))
	ai.setup(car, info, 0.9)
	ai.active = true
	for _i in 20:
		await get_tree().physics_frame
	car.relocate(base + Vector3(0, 0.85, 0), float(info.start_yaw))
	ai.next_i = 1
	ai.laps = 0
	for _i in 500:
		await get_tree().physics_frame
	var moved := car.get_vehicle_position().distance_to(base)
	print("AI next ", ai.next_i, " laps ", ai.laps, " moved ", snapped(moved, 0.1), " pos ", car.get_vehicle_position())
	var bad := 0
	if ai.next_i == 1 and ai.laps == 0 and moved < 8.0:
		print("AI did not advance")
		bad = 1
	var start_item := grid.get_cell_item(Vector3i(info.cells[0].x, 0, info.cells[0].y))
	print("FINISH item ", start_item)
	if start_item != TrackLibrary.FINISH:
		bad += 1
	host.queue_free()
	return bad
