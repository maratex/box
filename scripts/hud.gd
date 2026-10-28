extends Control
## Шкалы здоровья и выносливости, раунд и таймер.

var player: Fighter
var enemy: Fighter
var round_num := 1
var rounds_total := 3
var time_left := 60.0

var _player_portrait: Texture2D
var _enemy_portrait: Texture2D
var _shown_health := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_portrait = Game.load_texture("player_portrait.png")
	_enemy_portrait = Game.load_texture("enemy_portrait.png")


func _process(delta: float) -> void:
	# Плавно «догоняющая» белая полоса урона
	for b in [player, enemy]:
		if b == null:
			continue
		var cur: float = _shown_health.get(b, b.health)
		_shown_health[b] = move_toward(cur, b.health, 40.0 * delta) if cur > b.health else b.health
	queue_redraw()


func _draw() -> void:
	if player == null or enemy == null:
		return
	var w := size.x
	var bar_w := minf(440.0, w * 0.34)
	var portrait := 76.0
	var margin := 18.0

	_draw_side(player, _player_portrait, Vector2(margin, margin), bar_w, portrait, false)
	_draw_side(enemy, _enemy_portrait, Vector2(w - margin, margin), bar_w, portrait, true)

	# Центр: раунд и время
	var font := ThemeDB.fallback_font
	var secs := int(ceil(time_left))
	var timer_text := "%d:%02d" % [secs / 60, secs % 60]
	_draw_centered(font, "РАУНД %d/%d" % [round_num, rounds_total], Vector2(w * 0.5, 30), 20, Color(1, 1, 1, 0.85))
	_draw_centered(font, timer_text, Vector2(w * 0.5, 70), 40, Color.WHITE if time_left > 10.0 else Color(1, 0.45, 0.35))


func _draw_side(b: Fighter, tex: Texture2D, anchor: Vector2, bar_w: float, portrait: float, mirrored: bool) -> void:
	var font := ThemeDB.fallback_font
	var dir := -1.0 if mirrored else 1.0
	var p_rect := Rect2(anchor.x - (portrait if mirrored else 0.0), anchor.y, portrait, portrait)

	# Портрет (или заглушка цвета перчаток)
	draw_rect(p_rect.grow(3), Color(0, 0, 0, 0.6))
	if tex:
		draw_texture_rect(tex, p_rect, false)
	else:
		draw_rect(p_rect, b.glove_color.darkened(0.3))
		_draw_centered(font, b.display_name.substr(0, 1), p_rect.get_center() + Vector2(0, 14), 40, Color.WHITE)

	var bar_x := anchor.x + dir * (portrait + 12.0)
	var hp_rect := Rect2(bar_x - (bar_w if mirrored else 0.0), anchor.y + 4, bar_w, 26)
	var st_rect := Rect2(hp_rect.position.x, hp_rect.end.y + 6, bar_w, 10)

	var hp_k := b.health / Fighter.MAX_HEALTH
	var shown_k: float = _shown_health.get(b, b.health) / Fighter.MAX_HEALTH
	var st_k := b.stamina / Fighter.MAX_STAMINA
	var hp_col := Color(0.9, 0.2, 0.15).lerp(Color(0.95, 0.8, 0.2), hp_k)

	draw_rect(hp_rect.grow(2), Color(0, 0, 0, 0.7))
	draw_rect(hp_rect, Color(0.18, 0.05, 0.05))
	draw_rect(_part(hp_rect, shown_k, mirrored), Color(1, 1, 1, 0.8))
	draw_rect(_part(hp_rect, hp_k, mirrored), hp_col)
	draw_rect(st_rect.grow(2), Color(0, 0, 0, 0.7))
	draw_rect(_part(st_rect, st_k, mirrored), Color(0.25, 0.65, 1.0) if st_k > 0.25 else Color(0.6, 0.6, 0.7))

	var name_pos := Vector2(hp_rect.position.x if not mirrored else hp_rect.end.x, st_rect.end.y + 26)
	var align_w := font.get_string_size(b.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	if mirrored:
		name_pos.x -= align_w
	draw_string(font, name_pos, b.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


func _part(r: Rect2, k: float, from_right: bool) -> Rect2:
	var w := r.size.x * clampf(k, 0.0, 1.0)
	if from_right:
		return Rect2(r.end.x - w, r.position.y, w, r.size.y)
	return Rect2(r.position, Vector2(w, r.size.y))


func _draw_centered(font: Font, text: String, center: Vector2, fs: int, col: Color) -> void:
	var s := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2(center.x - s.x * 0.5, center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
