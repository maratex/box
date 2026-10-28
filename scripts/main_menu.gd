extends Control
## Главное меню.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg_tex := Game.load_texture("faceoff.png")
	if bg_tex:
		var tr := TextureRect.new()
		tr.texture = bg_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(tr)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.5)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.09, 0.05, 0.06)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	add_child(box)

	var title := Label.new()
	title.text = "БОКС"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 16)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "%s  против  %s" % [Game.player_name, Game.enemy_name]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30)
	box.add_child(sub)

	var play := Button.new()
	play.text = "В БОЙ"
	play.custom_minimum_size = Vector2(320, 90)
	play.add_theme_font_size_override("font_size", 40)
	play.pressed.connect(Game.start_match)
	box.add_child(play)

	var help := Label.new()
	help.text = "Слева: шаги и уклон.  Справа: джеб, кросс, хук и блок (держать).\nКлавиатура: A/D, J/K/L, пробел — блок, Shift — уклон."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 18)
	help.modulate = Color(1, 1, 1, 0.7)
	box.add_child(help)

	play.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
