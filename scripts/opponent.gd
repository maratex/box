class_name Opponent
extends Control
## Соперник из видеороликов. Внизу всегда крутится стойка (idle),
## поверх неё с коротким наплывом показываются ролики действий:
## удары, блок, пропущенные удары, нокдаун.

signal impact(clip: String)          ## момент удара в атакующем ролике
signal clip_finished(clip: String)

const FADE_IN := 0.08
const FADE_OUT := 0.16

var current := ""                    ## что играет сейчас ("" — стойка)
var impact_passed := false           ## удар в текущем ролике уже прошёл

var _frame: AspectRatioContainer
var _idle: VideoStreamPlayer
var _players := {}                   ## имя → VideoStreamPlayer
var _tweens := {}
var _fallback: TextureRect
var _finishing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_frame = AspectRatioContainer.new()
	_frame.ratio = 16.0 / 9.0
	_frame.stretch_mode = AspectRatioContainer.STRETCH_COVER
	# На вытянутых экранах обрезаем низ кадра (шорты), а не голову
	_frame.alignment_vertical = AspectRatioContainer.ALIGNMENT_BEGIN
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	# Неподвижный кадр — виден, пока видео не начало играть
	var base_tex := Game.load_texture(["opponent_base.jpg", "opponent_base.png"])
	if base_tex:
		_fallback = TextureRect.new()
		_fallback.texture = base_tex
		_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(_fallback)

	for clip_name in Game.CLIPS:
		var info: Dictionary = Game.CLIPS[clip_name]
		var stream := Game.load_video(info["file"])
		if stream == null:
			continue
		var vp := VideoStreamPlayer.new()
		vp.stream = stream
		vp.expand = true
		vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if clip_name == "idle":
			vp.loop = true
			_idle = vp
		else:
			vp.visible = false
			vp.finished.connect(_on_video_finished.bind(clip_name))
			_players[clip_name] = vp
		_frame.add_child(vp)

	if _idle:
		_idle.play()


func has_video() -> bool:
	return _idle != null or not _players.is_empty()


func has_clip(clip_name: String) -> bool:
	return _players.has(clip_name)


func clips_of_kind(kind: String) -> Array[String]:
	var out: Array[String] = []
	for n in _players:
		if Game.CLIPS[n]["kind"] == kind:
			out.append(n)
	return out


func is_busy() -> bool:
	return current != ""


func current_kind() -> String:
	return "" if current == "" else Game.CLIPS[current]["kind"]


func play(clip_name: String) -> bool:
	if not _players.has(clip_name):
		return false
	if current != "":
		_hide(current, FADE_IN)
	var vp: VideoStreamPlayer = _players[clip_name]
	_kill_tween(clip_name)
	vp.visible = true
	vp.modulate.a = 0.0
	vp.play()
	var tw := create_tween()
	tw.tween_property(vp, "modulate:a", 1.0, FADE_IN)
	_tweens[clip_name] = tw
	current = clip_name
	impact_passed = false
	_finishing = false
	return true


## Прервать текущий ролик (например, соперника сбили контратакой).
func interrupt() -> void:
	if current != "":
		var n := current
		_hide(n, 0.1)
		current = ""
		clip_finished.emit(n)


func position_in_clip() -> float:
	if current == "":
		return 0.0
	return (_players[current] as VideoStreamPlayer).stream_position


func _process(_delta: float) -> void:
	if current == "":
		return
	var info: Dictionary = Game.CLIPS[current]
	var pos := position_in_clip()
	if not impact_passed and info.has("impact") and pos >= info["impact"]:
		impact_passed = true
		impact.emit(current)
	# Плавно уходим в стойку чуть раньше конца ролика
	var length: float = info.get("length", 0.0)
	if not _finishing and length > 0.0 and pos >= length - FADE_OUT:
		_finish_current()


func _on_video_finished(clip_name: String) -> void:
	if clip_name == current and not _finishing:
		_finish_current()


func _finish_current() -> void:
	_finishing = true
	var n := current
	if Game.CLIPS[n]["kind"] == "ko":
		return  # лежит — остаётся последний кадр
	_hide(n, FADE_OUT)
	current = ""
	clip_finished.emit(n)


func _hide(clip_name: String, fade: float) -> void:
	var vp: VideoStreamPlayer = _players[clip_name]
	_kill_tween(clip_name)
	var tw := create_tween()
	tw.tween_property(vp, "modulate:a", 0.0, fade)
	tw.tween_callback(func():
		vp.stop()
		vp.visible = false)
	_tweens[clip_name] = tw


func _kill_tween(clip_name: String) -> void:
	if _tweens.has(clip_name) and _tweens[clip_name]:
		(_tweens[clip_name] as Tween).kill()
		_tweens.erase(clip_name)
