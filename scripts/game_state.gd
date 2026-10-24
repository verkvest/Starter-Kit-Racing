extends Node

const SAVE_PATH := "user://veldash.cfg"
const RIVAL_NAME := "Rook"

var tilt := false
var tilt_invert := false
var sound := true
var track_id := "pond"
var self_test := false
var shot := ""
var shot_dir := ""
var autopilot := false

var best_totals := {}
var best_laps := {}

func _ready() -> void:
	_parse_args()
	load_save()
	apply_audio()
	if DisplayServer.has_method("screen_set_keep_on"):
		DisplayServer.screen_set_keep_on(true)
	if shot != "":
		_prepare_window()
	if self_test:
		call_deferred("_begin_self_test")
	elif shot == "gameplay":
		autopilot = true
		track_id = "pond"
		call_deferred("_goto_race")

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		if arg == "--self-test":
			self_test = true
		elif arg == "--shot" and i + 1 < args.size():
			i += 1
			shot = str(args[i])
		elif arg == "--shot-dir" and i + 1 < args.size():
			i += 1
			shot_dir = str(args[i])
		i += 1
	if shot == "gameplay":
		autopilot = true

func _prepare_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(1280, 720)
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(2400, 1080)

func _goto_race() -> void:
	get_tree().change_scene_to_file("res://scenes/race.tscn")

func _begin_self_test() -> void:
	var node: Node = load("res://scripts/self_test.gd").new()
	node.name = "SelfTest"
	add_child(node)
	var code: int = await node.run()
	print("SELFTEST ", "OK" if code == 0 else "FAIL")
	get_tree().quit(code)

func shot_file(file_name: String) -> String:
	var dir := shot_dir
	if dir == "":
		dir = ProjectSettings.globalize_path("res://screenshots")
	return dir.path_join(file_name)

func capture(path: String) -> void:
	if shot != "" and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(2400, 1080))
		for _i in 8:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("WINDOW ", DisplayServer.window_get_size(), " VIEW ", get_viewport().get_visible_rect().size)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	print("CAPTURE ", path, " ", err, " ", image.get_width(), "x", image.get_height())

func load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	tilt = bool(cf.get_value("settings", "tilt", false))
	tilt_invert = bool(cf.get_value("settings", "tilt_invert", false))
	sound = bool(cf.get_value("settings", "sound", true))
	track_id = str(cf.get_value("settings", "last_track", "pond"))
	best_totals = cf.get_value("best", "totals", {})
	best_laps = cf.get_value("best", "laps", {})
	if typeof(best_totals) != TYPE_DICTIONARY:
		best_totals = {}
	if typeof(best_laps) != TYPE_DICTIONARY:
		best_laps = {}

func save_state() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("settings", "tilt", tilt)
	cf.set_value("settings", "tilt_invert", tilt_invert)
	cf.set_value("settings", "sound", sound)
	cf.set_value("settings", "last_track", track_id)
	cf.set_value("best", "totals", best_totals)
	cf.set_value("best", "laps", best_laps)
	cf.save(SAVE_PATH)

func apply_audio() -> void:
	if AudioServer.bus_count > 0:
		AudioServer.set_bus_mute(0, not sound)

func best_total(id: String) -> float:
	if best_totals.has(id):
		return float(best_totals[id])
	return -1.0

func best_lap(id: String) -> float:
	if best_laps.has(id):
		return float(best_laps[id])
	return -1.0

func record_race(id: String, total: float, lap: float) -> void:
	var changed := false
	if total > 0.0 and (not best_totals.has(id) or total < float(best_totals[id])):
		best_totals[id] = total
		changed = true
	if lap > 0.0 and (not best_laps.has(id) or lap < float(best_laps[id])):
		best_laps[id] = lap
		changed = true
	if changed:
		save_state()
