extends Control
## Кат-сцена: видео (.ogv), иначе картинка с наездом камеры, иначе текст на тёмном фоне.
## Нажатие на экран пропускает сцену.

var _done := false
var _can_skip := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var data: Dictionary = Game.CUTSCENES.get(Game.current_cutscene, {})

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Контейнер 16:9, заполняющий экран (лишнее по краям обрезается)
	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	frame.stretch_mode = AspectRatioContainer.STRETCH_COVER
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var duration: float = data.get("duration", 3.0)
	var video := Game.load_video(data.get("video", ""))
	if video:
		var vp := VideoStreamPlayer.new()
		vp.stream = video
		vp.expand = true
		vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(vp)
		vp.finished.connect(_finish)
		vp.play()
	else:
		var tex := Game.load_texture(data.get("image", ""))
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(tr)
			_slow_zoom.call_deferred(tr, duration)
		else:
			bg.color = Color(0.08, 0.06, 0.07)
		get_tree().create_timer(duration).timeout.connect(_finish)

	# Затемнение снизу под текст
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 0.72
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := _label(Game.format_text(data.get("title", "")), 64, 0.74)
	var subtitle := _label(Game.format_text(data.get("subtitle", "")), 28, 0.86)
	subtitle.modulate = Color(1, 1, 1, 0.0)
	title.modulate = Color(1, 1, 1, 0.0)
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.5).set_delay(0.3)
	tw.tween_property(subtitle, "modulate:a", 0.85, 0.4)

	var hint := Label.new()
	hint.text = "нажми, чтобы пропустить"
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.position = Vector2(-260, 16)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	# Пропуск разрешаем через полсекунды, чтобы случайное касание не пролистало сцену
	get_tree().create_timer(0.5).timeout.connect(func(): _can_skip = true)


func _label(text: String, fs: int, anchor_y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _slow_zoom(tr: TextureRect, duration: float) -> void:
	tr.pivot_offset = tr.size * 0.5
	var tw := tr.create_tween()
	tw.tween_property(tr, "scale", Vector2(1.08, 1.08), duration + 0.5)


func _input(event: InputEvent) -> void:
	if not _can_skip:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		get_viewport().set_input_as_handled()
		_finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_finish()


func _finish() -> void:
	if _done or not is_inside_tree():
		return
	_done = true
	Game.next_step()
