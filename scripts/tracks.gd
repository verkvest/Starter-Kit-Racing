class_name TrackLibrary
extends RefCounted

const STRAIGHT := 6
const CORNER := 3
const FINISH := 4
const DECO_EMPTY := 0
const DECO_FOREST := 1
const DECO_TENTS := 2
const RAMP := 5

const CELL := 9.99
const SCALE := 0.75
const CELL_WORLD := 9.99 * 0.75
const REACH := CELL_WORLD * 0.68

const DIRS := {
	"E": Vector2i(1, 0),
	"N": Vector2i(0, 1),
	"W": Vector2i(-1, 0),
	"S": Vector2i(0, -1),
}

# Openings of a corner, sorted as a two-letter key, mapped from the kit's GridMap.
const CORNER_ROT := {"EN": 16, "ES": 10, "NW": 0, "SW": 22}

static func all() -> Array:
	return [
		{
			"id": "pond",
			"name": "Pond Circuit",
			"laps": 3,
			"blurb": "Easy oval",
			"moves": "EEENNNNWWWWWSSSSEE",
		},
		{
			"id": "mill",
			"name": "Mill Bend",
			"laps": 3,
			"blurb": "Dogleg",
			"moves": "EEENNWWNNWWWSSSSEE",
		},
		{
			"id": "cinder",
			"name": "Cinder Loop",
			"laps": 3,
			"blurb": "Top chicane",
			"moves": "EEEENNNNWWSWWNWWSSSSEE",
		},
		{
			"id": "hearth",
			"name": "Hearth GP",
			"laps": 2,
			"blurb": "Kink and chicane",
			"moves": "ENEESEENNNNNNWWSWWWNWWWSSSSSSEEE",
		},
	]

static func get_track(id: String) -> Dictionary:
	for track in all():
		if track.id == id:
			return track
	return all()[0]

static func next_id(id: String) -> String:
	var list := all()
	for i in list.size():
		if list[i].id == id:
			return list[(i + 1) % list.size()].id
	return list[0].id

static func trace(moves: String) -> Dictionary:
	var cells: Array[Vector2i] = []
	var outs: Array[Vector2i] = []
	var p := Vector2i.ZERO
	for i in moves.length():
		var step: Vector2i = DIRS[moves[i]]
		cells.append(p)
		outs.append(step)
		p += step
	return {"cells": cells, "outs": outs, "end": p}

static func validate(def: Dictionary) -> String:
	var traced: Dictionary = trace(def.moves)
	var cells: Array = traced.cells
	var outs: Array = traced.outs
	var n := cells.size()
	if n < 8:
		return "too short"
	if traced.end != Vector2i.ZERO:
		return "not closed, ends at %s" % traced.end
	var seen := {}
	for cell in cells:
		if seen.has(cell):
			return "duplicate %s" % cell
		seen[cell] = true
	if outs[0] != outs[n - 1]:
		return "start is not a straight"
	for i in n:
		var nxt: Vector2i = cells[(i + 1) % n]
		var here: Vector2i = cells[i]
		if nxt - here != outs[i]:
			return "broken step at %d" % i
	for i in n:
		for j in range(i + 1, n):
			var gap := mini(absi(j - i), n - absi(j - i))
			if gap <= 1:
				continue
			var delta: Vector2i = cells[j] - cells[i]
			if absi(delta.x) + absi(delta.y) == 1:
				return "shortcut %s-%s" % [cells[i], cells[j]]
	return ""

static func yaw_of(dir: Vector2i) -> float:
	return atan2(float(dir.x), float(dir.y))

static func forward_of(dir: Vector2i) -> Vector3:
	return Vector3(dir.x, 0, dir.y).normalized()

static func right_of(fwd: Vector3) -> Vector3:
	return Vector3(fwd.z, 0, -fwd.x)

static func _pair(a: String, b: String) -> String:
	if a > b:
		return b + a
	return a + b

static func _from_side(incoming: Vector2i) -> String:
	if incoming == Vector2i(1, 0):
		return "W"
	if incoming == Vector2i(-1, 0):
		return "E"
	if incoming == Vector2i(0, 1):
		return "S"
	return "N"

static func _to_side(outgoing: Vector2i) -> String:
	if outgoing == Vector2i(1, 0):
		return "E"
	if outgoing == Vector2i(-1, 0):
		return "W"
	if outgoing == Vector2i(0, 1):
		return "N"
	return "S"

static func straight_rot(outgoing: Vector2i) -> int:
	if absi(outgoing.x) == 1:
		return 16
	return 0

static func corner_rot(incoming: Vector2i, outgoing: Vector2i) -> int:
	var key := _pair(_from_side(incoming), _to_side(outgoing))
	return int(CORNER_ROT.get(key, 0))

# Grid must already be inside the tree. Fills road, finish, and scenery.
static func build(grid: GridMap, def: Dictionary) -> Dictionary:
	grid.clear()
	var traced: Dictionary = trace(def.moves)
	var cells: Array = traced.cells
	var outs: Array = traced.outs
	var n: int = cells.size()
	var points := PackedVector3Array()
	var minx := 999
	var maxx := -999
	var minz := 999
	var maxz := -999
	var road := {}
	for i in n:
		var cell: Vector2i = cells[i]
		road[cell] = true
		minx = mini(minx, cell.x)
		maxx = maxi(maxx, cell.x)
		minz = mini(minz, cell.y)
		maxz = maxi(maxz, cell.y)
		var incoming: Vector2i = outs[(i - 1 + n) % n]
		var outgoing: Vector2i = outs[i]
		var item := STRAIGHT
		var rot := straight_rot(outgoing)
		if incoming != outgoing:
			item = CORNER
			rot = corner_rot(incoming, outgoing)
		if i == 0:
			item = FINISH
			rot = straight_rot(outgoing)
		grid.set_cell_item(Vector3i(cell.x, 0, cell.y), item, rot)
		var world: Vector3 = grid.to_global(grid.map_to_local(Vector3i(cell.x, 0, cell.y)))
		points.append(Vector3(world.x, 0.0, world.z))
	var blockers: Array[Vector3] = []
	for z in range(minz - 1, maxz + 2):
		for x in range(minx - 1, maxx + 2):
			var cell := Vector2i(x, z)
			if road.has(cell):
				continue
			var deep := _deep(x, z, road, minx, maxx, minz, maxz)
			var h := absi(x * 73856093 ^ z * 19349663)
			var item := DECO_FOREST
			if deep and h % 2 == 0:
				item = RAMP
			elif h % 11 == 0:
				item = DECO_TENTS
			elif h % 8 == 0:
				item = DECO_EMPTY
			var ori: int = [0, 10, 16, 22][h % 4]
			grid.set_cell_item(Vector3i(x, 0, z), item, ori)
			var world: Vector3 = grid.to_global(grid.map_to_local(Vector3i(x, 0, z)))
			blockers.append(Vector3(world.x, 0.0, world.z))
	var fwd := forward_of(outs[0])
	return {
		"points": points,
		"outs": outs,
		"cells": cells,
		"reach": REACH,
		"cell_world": CELL_WORLD,
		"start_yaw": yaw_of(outs[0]),
		"forward": fwd,
		"right": right_of(fwd),
		"blockers": blockers,
		"laps": int(def.laps),
		"name": def.name,
		"id": def.id,
	}

static func _adjacent_road(x: int, z: int, road: Dictionary) -> bool:
	return road.has(Vector2i(x + 1, z)) or road.has(Vector2i(x - 1, z)) or road.has(Vector2i(x, z + 1)) or road.has(Vector2i(x, z - 1))

static func _deep(x: int, z: int, road: Dictionary, minx: int, maxx: int, minz: int, maxz: int) -> bool:
	if x <= minx or x >= maxx or z <= minz or z >= maxz:
		return false
	return not _adjacent_road(x, z, road)

static func add_floor(parent: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(420, 2, 420)
	shape.shape = box
	shape.position = Vector3(0, -1, 0)
	body.add_child(shape)
	parent.add_child(body)
	return body

static func add_walls(parent: Node3D, blockers: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 1
	var cw := CELL_WORLD * 1.05
	for blocker in blockers:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(cw, 2.4, cw)
		shape.shape = box
		shape.position = Vector3(blocker.x, 1.25, blocker.z)
		body.add_child(shape)
	parent.add_child(body)
	return body
