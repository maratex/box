extends Node2D
## Фон боя: картинка ring_bg.png, а если её нет — ринг, нарисованный кодом.

var floor_y := 610.0
var view_size := Vector2(1280, 720)
var _bg: Texture2D


func _ready() -> void:
	_bg = Game.load_texture("ring_bg.png")


func set_view(sz: Vector2, ground: float) -> void:
	view_size = sz
	floor_y = ground
	queue_redraw()


func _draw() -> void:
	var w := view_size.x
	var h := view_size.y
	if _bg:
		# Заполнить экран с сохранением пропорций (лишнее обрезается)
		var tex_size := _bg.get_size()
		var k := maxf(w / tex_size.x, h / tex_size.y)
		var draw_size := tex_size * k
		draw_texture_rect(_bg, Rect2((Vector2(w, h) - draw_size) * 0.5, draw_size), false)
		return

	# Зал
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.05, 0.07))
	for i in 7:
		var y := 120.0 + i * 50.0
		draw_rect(Rect2(0, y, w, 50), Color(0.07 + i * 0.012, 0.06 + i * 0.01, 0.08 + i * 0.01))
	# Зрители — силуэты
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := -20.0
	while x < w + 40.0:
		var r := rng.randf_range(16, 24)
		var y := floor_y - 175.0 + rng.randf_range(-8, 8)
		var c := Color(0.02, 0.02, 0.03).lerp(Color(0.12, 0.1, 0.12), rng.randf())
		draw_circle(Vector2(x, y), r, c)
		draw_rect(Rect2(x - r * 1.3, y + r * 0.6, r * 2.6, 80), c)
		x += rng.randf_range(28, 44)
	# Прожектор
	var spot := PackedVector2Array([Vector2(w * 0.5 - 60, 0), Vector2(w * 0.5 + 60, 0), Vector2(w * 0.5 + 420, floor_y), Vector2(w * 0.5 - 420, floor_y)])
	draw_colored_polygon(spot, Color(1, 0.95, 0.8, 0.06))

	# Помост
	draw_rect(Rect2(0, floor_y - 40, w, 40), Color(0.32, 0.36, 0.48))
	draw_rect(Rect2(0, floor_y, w, h - floor_y), Color(0.18, 0.2, 0.3))
	draw_rect(Rect2(0, floor_y + 10, w, 34), Color(0.55, 0.08, 0.1))
	# Канаты и стойки
	var post_l := 60.0
	var post_r := w - 60.0
	for p in [post_l, post_r]:
		draw_rect(Rect2(p - 10, floor_y - 230, 20, 230), Color(0.75, 0.75, 0.78))
	var rope_cols := [Color(0.85, 0.15, 0.15), Color(0.95, 0.95, 0.95), Color(0.15, 0.3, 0.85)]
	for i in 3:
		var y := floor_y - 205.0 + i * 55.0
		draw_line(Vector2(post_l, y), Vector2(post_r, y), rope_cols[i], 6.0)
