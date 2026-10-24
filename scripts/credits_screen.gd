extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.make_theme()
	var bg := ColorRect.new()
	bg.color = UiStyle.INK_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Credits"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UiStyle.AMBER)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var body := RichTextLabel.new()
	body.bbcode_enabled = false
	body.scroll_active = false
	body.fit_content = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 18)
	body.add_theme_color_override("default_color", UiStyle.CREAM)
	body.text = _license_text()
	scroll.add_child(body)
	var back := UiStyle.button("Back", 220)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	box.add_child(back)

func _license_text() -> String:
	var file := FileAccess.open("res://THIRD_PARTY_LICENSES.md", FileAccess.READ)
	if file == null:
		return "License text is missing."
	var text := file.get_as_text()
	file.close()
	return text

func _process(_delta: float) -> void:
	var margin := get_node_or_null("Margin")
	if margin == null:
		return
	var ins := UiStyle.insets(self)
	margin.add_theme_constant_override("margin_left", int(ins.x) + 16)
	margin.add_theme_constant_override("margin_right", int(ins.z) + 16)
	margin.add_theme_constant_override("margin_top", int(ins.y) + 12)
	margin.add_theme_constant_override("margin_bottom", int(ins.w) + 12)
