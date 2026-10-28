class_name TouchPad
extends TouchScreenButton
## Круглая экранная кнопка. Поддерживает мультитач:
## можно одновременно держать «вправо» и бить.

enum Icon { NONE, LEFT, RIGHT }

var label_text := ""
var radius := 60.0
var color := Color(1, 1, 1, 0.2)
var icon: Icon = Icon.NONE


func setup(text: String, action_name: String, r: float, col: Color, ico: Icon = Icon.NONE) -> TouchPad:
	label_text = text
	action = action_name
	radius = r
	color = col
	icon = ico
	var s := CircleShape2D.new()
	s.radius = r
	shape = s
	shape_centered = true
	passby_press = true
	visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	pressed.connect(queue_redraw)
	released.connect(queue_redraw)
	return self


func _draw() -> void:
	var c := color
	if is_pressed():
		c = Color(c.r, c.g, c.b, minf(1.0, c.a + 0.3)).lightened(0.3)
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)

	var w := radius * 0.38
	match icon:
		Icon.LEFT:
			draw_colored_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(w * 0.7, -w), Vector2(w * 0.7, w)]), Color.WHITE)
		Icon.RIGHT:
			draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(-w * 0.7, -w), Vector2(-w * 0.7, w)]), Color.WHITE)
		_:
			var font := ThemeDB.fallback_font
			var fs := int(radius * 0.36)
			var size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, Vector2(-size.x * 0.5, fs * 0.36), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
