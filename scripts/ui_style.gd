class_name UiStyle
extends RefCounted

const INK := Color("14343c")
const INK_DEEP := Color("102027")
const AMBER := Color("f0a202")
const CREAM := Color("f6f1e7")
const GAS := Color("2f9e62")
const BRAKE := Color("d4533e")
const GRASS := Color("5f8a48")

static func make_theme() -> Theme:
	var theme := Theme.new()
	var normal := _box(INK, AMBER, 3)
	var hover := _box(Color("1c4650"), AMBER, 3)
	var pressed := _box(AMBER, AMBER, 3)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "Button", _box(Color("102027"), Color("5c6b70"), 2))
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", CREAM)
	theme.set_color("font_pressed_color", "Button", INK_DEEP)
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "CheckButton", CREAM)
	theme.set_color("font_hover_color", "CheckButton", CREAM)
	theme.set_color("font_pressed_color", "CheckButton", CREAM)
	theme.set_font_size("font_size", "Button", 26)
	theme.set_font_size("font_size", "Label", 22)
	theme.set_font_size("font_size", "CheckButton", 22)
	theme.set_color("default_color", "RichTextLabel", CREAM)
	theme.set_font_size("normal_font_size", "RichTextLabel", 20)
	return theme

static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(20)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func button(text: String, min_w: float = 280.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, 72)
	return btn

static func format_time(t: float) -> String:
	if t < 0.0:
		return "--:--.--"
	var cs := int(round(t * 100.0))
	var m := int(cs / 6000.0)
	var s := int(cs / 100.0) % 60
	var c := cs % 100
	return "%d:%02d.%02d" % [m, s, c]

# Left, top, right, bottom padding in viewport pixels, including a minimum margin.
static func insets(node: Node) -> Vector4:
	var vp := Vector2(1280, 720)
	var win := node.get_viewport()
	if win:
		vp = win.get_visible_rect().size
	var screen := DisplayServer.screen_get_size()
	var left := 18.0
	var top := 16.0
	var right := 18.0
	var bottom := 16.0
	if screen.x > 0 and screen.y > 0:
		var area := Rect2i(0, 0, screen.x, screen.y)
		if DisplayServer.has_method("get_display_safe_area"):
			area = DisplayServer.get_display_safe_area()
		if area.size.x > 0 and area.size.y > 0:
			var sx := vp.x / float(screen.x)
			var sy := vp.y / float(screen.y)
			left = maxf(left, area.position.x * sx)
			top = maxf(top, area.position.y * sy)
			right = maxf(right, (screen.x - area.end.x) * sx)
			bottom = maxf(bottom, (screen.y - area.end.y) * sy)
	return Vector4(left, top, right, bottom)
