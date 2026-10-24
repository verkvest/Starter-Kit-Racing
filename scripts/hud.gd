class_name Hud
extends CanvasLayer

var _root: Control
var _top: Panel
var _lap: Label
var _time: Label
var _best: Label
var _pos: Label
var _banner: Label
var _tilt_label: Label
var _left: ColorRect
var _right: ColorRect
var _brake: ColorRect
var _gas: ColorRect
var _pause_panel: Control
var _results: Control
var _result_title: Label
var _result_body: Label
var _pause_button: Button
var _touches := {}
var _neutral := 0.0
var _neutral_ready := false
var _show_results := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiStyle.make_theme()
	add_child(_root)
	_build_top()
	_build_zones()
	_build_banner()
	_build_pause()
	_build_results()

func _build_top() -> void:
	_top = Panel.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiStyle.INK_DEEP, 0.72)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	_top.add_theme_stylebox_override("panel", style)
	_root.add_child(_top)
	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.custom_minimum_size = Vector2(64, 56)
	_pause_button.pressed.connect(_toggle_pause)
	_top.add_child(_pause_button)
	_lap = _hud_label()
	_time = _hud_label()
	_best = _hud_label()
	_pos = _hud_label()
	_tilt_label = _hud_label()
	for label in [_lap, _time, _best, _pos, _tilt_label]:
		_top.add_child(label)

func _hud_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _build_zones() -> void:
	_left = _zone("LEFT", Color(UiStyle.CREAM, 0.28))
	_right = _zone("RIGHT", Color(UiStyle.CREAM, 0.28))
	_brake = _zone("BRAKE", Color(UiStyle.BRAKE, 0.78))
	_gas = _zone("GAS", Color(UiStyle.GAS, 0.82))

func _zone(text: String, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UiStyle.INK_DEEP)
	rect.add_child(label)
	_root.add_child(rect)
	return rect

func _build_banner() -> void:
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_font_size_override("font_size", 96)
	_banner.add_theme_color_override("font_color", UiStyle.AMBER)
	_root.add_child(_banner)

func _build_pause() -> void:
	_pause_panel = _overlay()
	var box := _center_box(_pause_panel)
	var title := _title_label("Paused")
	box.add_child(title)
	var resume := UiStyle.button("Resume")
	resume.pressed.connect(_toggle_pause)
	var restart := UiStyle.button("Restart")
	restart.pressed.connect(func() -> void: _go("res://scenes/race.tscn"))
	var quit := UiStyle.button("Quit to menu")
	quit.pressed.connect(func() -> void: _go("res://scenes/title.tscn"))
	box.add_child(resume)
	box.add_child(restart)
	box.add_child(quit)
	box.add_child(_check("Tilt steering", GameState.tilt, func(on: bool) -> void:
		GameState.tilt = on
		GameState.save_state()
	))
	box.add_child(_check("Invert tilt", GameState.tilt_invert, func(on: bool) -> void:
		GameState.tilt_invert = on
		GameState.save_state()
	))
	box.add_child(_check("Sound", GameState.sound, func(on: bool) -> void:
		GameState.sound = on
		GameState.apply_audio()
		GameState.save_state()
	))
	_pause_panel.visible = false

func _build_results() -> void:
	_results = _overlay()
	var box := _center_box(_results)
	_result_title = _title_label("Finish")
	_result_body = Label.new()
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_body.custom_minimum_size = Vector2(420, 120)
	box.add_child(_result_title)
	box.add_child(_result_body)
	var retry := UiStyle.button("Retry")
	retry.pressed.connect(func() -> void: _go("res://scenes/race.tscn"))
	var nxt := UiStyle.button("Next circuit")
	nxt.pressed.connect(func() -> void:
		GameState.track_id = TrackLibrary.next_id(GameState.track_id)
		GameState.save_state()
		_go("res://scenes/race.tscn")
	)
	var menu := UiStyle.button("Menu")
	menu.pressed.connect(func() -> void: _go("res://scenes/title.tscn"))
	box.add_child(retry)
	box.add_child(nxt)
	box.add_child(menu)
	_results.visible = false

func _overlay() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK_DEEP, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	return dim

func _center_box(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	return box

func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", UiStyle.AMBER)
	return label

func _check(text: String, on: bool, cb: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = on
	check.toggled.connect(cb)
	return check

func _go(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)

func _toggle_pause() -> void:
	if _show_results:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause_panel.visible = paused

func calibrate_tilt() -> void:
	var axis := _tilt_axis()
	if not _neutral_ready:
		_neutral = axis
		_neutral_ready = true
	else:
		_neutral = lerpf(_neutral, axis, 0.15)

func drive() -> Vector2:
	if get_tree().paused or _show_results:
		return Vector2.ZERO
	var touch_steer := 0.0
	var touch_throttle := 0.0
	for zone in _touches.values():
		if zone == "left":
			touch_steer -= 1.0
		elif zone == "right":
			touch_steer += 1.0
		elif zone == "gas":
			touch_throttle += 1.0
		elif zone == "brake":
			touch_throttle -= 1.0
	var steer := touch_steer
	var key_steer := Input.get_axis("left", "right")
	if absf(touch_steer) < 0.01:
		if absf(key_steer) > 0.01:
			steer = key_steer
		elif GameState.tilt:
			steer = _tilt_steer()
	var throttle := touch_throttle
	if absf(touch_throttle) < 0.01:
		throttle = Input.get_axis("back", "forward")
	return Vector2(clampf(steer, -1.0, 1.0), clampf(throttle, -1.0, 1.0))

func _tilt_axis() -> float:
	var g := Input.get_gravity()
	var axis := g.y
	match DisplayServer.screen_get_orientation():
		DisplayServer.SCREEN_REVERSE_LANDSCAPE:
			axis = -g.y
		DisplayServer.SCREEN_PORTRAIT, DisplayServer.SCREEN_SENSOR_PORTRAIT:
			axis = g.x
		DisplayServer.SCREEN_REVERSE_PORTRAIT:
			axis = -g.x
		_:
			axis = g.y
	return axis

func _tilt_steer() -> float:
	if Input.get_gravity().length() < 0.2:
		return 0.0
	var delta := _tilt_axis() - _neutral
	if GameState.tilt_invert:
		delta = -delta
	if absf(delta) < 0.7:
		return 0.0
	return clampf(delta / 3.3, -1.0, 1.0)

func show_results(title: String, body: String) -> void:
	_show_results = true
	_result_title.text = title
	_result_body.text = body
	_results.visible = true
	_pause_panel.visible = false
	get_tree().paused = true

func _process(_delta: float) -> void:
	_layout()
	_refresh()
	if Input.is_action_just_pressed("pause") and not _show_results:
		_toggle_pause()

func _layout() -> void:
	var s := _root.size
	if s.x < 10.0:
		return
	var ins := UiStyle.insets(self)
	var top_h := 68.0
	_top.position = Vector2(ins.x, ins.y)
	_top.size = Vector2(s.x - ins.x - ins.z, top_h)
	_pause_button.position = Vector2(8, 6)
	_pause_button.size = Vector2(64, 56)
	var inner_w := _top.size.x - 84.0
	var col := inner_w / 4.0
	_place(_lap, 80, col)
	_place(_time, 80 + col, col)
	_place(_best, 80 + col * 2.0, col)
	_place(_pos, 80 + col * 3.0, col)
	_tilt_label.visible = false
	_banner.position = Vector2(0, s.y * 0.28)
	_banner.size = Vector2(s.x, 120)
	var h := clampf(s.y * 0.30, 108, 230)
	var w := clampf((s.x - ins.x - ins.z) * 0.15, 96, 210)
	var y := s.y - ins.w - h - 10.0
	_left.position = Vector2(ins.x + 8, y)
	_left.size = Vector2(w, h)
	_right.position = Vector2(ins.x + 18 + w, y)
	_right.size = Vector2(w, h)
	_gas.position = Vector2(s.x - ins.z - 8 - w, y)
	_gas.size = Vector2(w, h)
	_brake.position = Vector2(s.x - ins.z - 18 - w * 2.0, y)
	_brake.size = Vector2(w, h)
	_tint(_left, "left")
	_tint(_right, "right")
	_tint(_brake, "brake")
	_tint(_gas, "gas")

func _place(label: Label, x: float, w: float) -> void:
	label.position = Vector2(x, 6)
	label.size = Vector2(w - 8, 56)

func _tint(rect: ColorRect, zone: String) -> void:
	var down := false
	for held in _touches.values():
		if held == zone:
			down = true
	rect.modulate = Color(1.15, 1.15, 1.15) if down else Color.WHITE

func _refresh() -> void:
	var race := get_parent()
	if race == null or not ("phase" in race):
		return
	_lap.text = "Lap %d/%d" % [int(race.show_lap), int(race.total_laps)]
	_time.text = UiStyle.format_time(float(race.race_time))
	_best.text = "Best " + UiStyle.format_time(float(race.best_total))
	_pos.text = "P%d" % int(race.race_place)
	var banner := ""
	if str(race.phase) == "countdown" and not GameState.autopilot:
		banner = str(maxi(int(ceil(float(race.countdown))), 1))
	elif float(race.go_left) > 0.0 and not GameState.autopilot:
		banner = "GO"
	elif bool(race.wrong_way):
		banner = "WRONG WAY"
	elif float(race.lap_flash) > 0.0:
		banner = "LAP %d" % int(race.show_lap)
	_banner.text = banner

func _input(event: InputEvent) -> void:
	if _pause_panel.visible or _show_results:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var zone := _zone_at(event.position)
			if zone != "":
				_touches[event.index] = zone
				get_viewport().set_input_as_handled()
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		var zone := _zone_at(event.position)
		if zone != "":
			_touches[event.index] = zone
			get_viewport().set_input_as_handled()
		else:
			_touches.erase(event.index)

func _zone_at(pos: Vector2) -> String:
	if _left.get_global_rect().has_point(pos):
		return "left"
	if _right.get_global_rect().has_point(pos):
		return "right"
	if _brake.get_global_rect().has_point(pos):
		return "brake"
	if _gas.get_global_rect().has_point(pos):
		return "gas"
	return ""
