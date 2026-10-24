extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.make_theme()
	var bg := ColorRect.new()
	bg.color = UiStyle.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	var title := Label.new()
	title.text = "Choose a circuit"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UiStyle.AMBER)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for track in TrackLibrary.all():
		var best := GameState.best_total(track.id)
		var mark := "Last  ·  " if track.id == GameState.track_id else ""
		var btn := Button.new()
		btn.text = "%s%s\n%s  ·  %d laps\nBest %s" % [mark, track.name, track.blurb, int(track.laps), UiStyle.format_time(best)]
		btn.custom_minimum_size = Vector2(280, 120)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id := str(track.id)
		btn.pressed.connect(func() -> void:
			GameState.track_id = id
			GameState.save_state()
			get_tree().change_scene_to_file("res://scenes/race.tscn")
		)
		grid.add_child(btn)
	var back := UiStyle.button("Back", 220)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	box.add_child(back)

func _process(_delta: float) -> void:
	var margin := get_node_or_null("Margin")
	if margin == null:
		return
	var ins := UiStyle.insets(self)
	margin.add_theme_constant_override("margin_left", int(ins.x) + 16)
	margin.add_theme_constant_override("margin_right", int(ins.z) + 16)
	margin.add_theme_constant_override("margin_top", int(ins.y) + 12)
	margin.add_theme_constant_override("margin_bottom", int(ins.w) + 12)
