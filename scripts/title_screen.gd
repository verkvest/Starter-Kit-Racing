extends Control

func _ready() -> void:
	if GameState.self_test:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.make_theme()
	var bg := ColorRect.new()
	bg.color = UiStyle.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	var title := Label.new()
	title.text = "VELDASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", UiStyle.AMBER)
	var sub := Label.new()
	sub.text = "Pocket circuits. Three laps. One rival."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	box.add_child(sub)
	box.add_child(_spacer(12))
	var play := UiStyle.button("Play", 340)
	play.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/track_select.tscn")
	)
	var credits := UiStyle.button("Credits", 340)
	credits.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/credits.tscn")
	)
	box.add_child(play)
	box.add_child(credits)
	box.add_child(_spacer(8))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.add_child(_check("Tilt steering", GameState.tilt, func(on: bool) -> void:
		GameState.tilt = on
		GameState.save_state()
	))
	row.add_child(_check("Invert tilt", GameState.tilt_invert, func(on: bool) -> void:
		GameState.tilt_invert = on
		GameState.save_state()
	))
	row.add_child(_check("Sound", GameState.sound, func(on: bool) -> void:
		GameState.sound = on
		GameState.apply_audio()
		GameState.save_state()
	))
	box.add_child(row)
	if GameState.shot == "menu":
		_shoot()

func _process(_delta: float) -> void:
	var ins := UiStyle.insets(self)
	if get_child_count() > 1 and get_child(1) is MarginContainer:
		var margin: MarginContainer = get_child(1)
		margin.add_theme_constant_override("margin_left", int(ins.x) + 12)
		margin.add_theme_constant_override("margin_right", int(ins.z) + 12)
		margin.add_theme_constant_override("margin_top", int(ins.y) + 8)
		margin.add_theme_constant_override("margin_bottom", int(ins.w) + 8)

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _check(text: String, on: bool, cb: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = on
	check.toggled.connect(cb)
	return check

func _shoot() -> void:
	for _i in 6:
		await get_tree().process_frame
	await GameState.capture(GameState.shot_file("menu.png"))
	get_tree().quit()
