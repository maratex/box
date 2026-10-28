extends Control
## Бой от первого лица. Соперник — видеоролики (opponent.gd),
## игрок — камера: уклоны качают «голову», удары и попадания трясут картинку.

const ROUNDS := 3
const ROUND_TIME := 60.0
const HEAL_BETWEEN_ROUNDS := 0.2

const PUNCH_TIME := 0.3          ## длительность своего удара
const PUNCH_CONTACT := 0.1       ## через сколько после нажатия удар «доходит»
const PUNCH_COST := 7.0
const DODGE_TIME := 0.5
const DODGE_SAFE_FROM := 0.03    ## окно неуязвимости уклона
const DODGE_SAFE_TO := 0.42
const DODGE_COST := 6.0
const HURT_TIME := 0.45
const STAMINA_REGEN := 12.0
const VIEW_ZOOM := 1.06          ## запас по краям, чтобы при уклоне не было пустоты

enum Phase { INTRO, FIGHT, BREAK, OVER }
enum P { IDLE, PUNCH, DODGE, BLOCK, HURT, KO }

var phase: Phase = Phase.INTRO
var round_num := 1
var time_left := ROUND_TIME

var player := Fighter.new(Game.player_name, Color(0.15, 0.3, 0.85))
var enemy := Fighter.new(Game.enemy_name, Color(0.85, 0.12, 0.12))
var stats := {"player_landed": 0, "enemy_landed": 0}

var pstate: P = P.IDLE
var _p_time := 0.0               ## сколько длится текущее состояние игрока
var _punch_side := ""
var _punch_resolved := false
var _dodge_dir := ""
var _ai_timer := 2.0
var _shown_hints := {}

var view: Control
var opp: Opponent
var gloves: TextureRect
var _glove_tex := {}
var flash: ColorRect
var hurt_overlay: TextureRect
var dim: ColorRect
var hud: Control
var banner: Label
var hint: Label
var pads: Array[TouchPad] = []
var _view_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# «Камера» — всё, что качается при уклонах и ударах
	view = Control.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)

	opp = Opponent.new()
	view.add_child(opp)
	opp.impact.connect(_on_enemy_impact)
	opp.clip_finished.connect(_on_clip_finished)

	if not opp.has_video():
		var warn := Label.new()
		warn.text = "Нет роликов соперника.\nПоложи idle.ogv, jab.ogv, hook.ogv в assets/media/video/"
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		view.add_child(warn)

	flash = _overlay(Color(1, 1, 1, 0))
	hurt_overlay = _vignette(Color(0.8, 0.0, 0.0))
	dim = _overlay(Color(0, 0, 0, 0))

	# Свои перчатки (картинки с прозрачным фоном), если есть
	for key in ["guard", "jab", "cross", "block"]:
		var t := Game.load_texture(["gloves_%s.png" % key])
		if t:
			_glove_tex[key] = t
	gloves = TextureRect.new()
	gloves.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gloves.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	gloves.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gloves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gloves)
	_set_gloves("guard")

	# Интерфейс
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	hud = preload("res://scripts/hud.gd").new()
	hud.player = player
	hud.enemy = enemy
	hud.rounds_total = ROUNDS
	hud_layer.add_child(hud)

	banner = Label.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 92)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 16)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(banner)

	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 0.66
	hint.anchor_bottom = 0.66
	hint.add_theme_font_size_override("font_size", 30)
	hint.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 10)
	hint.modulate.a = 0.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hint)

	var pad_layer := CanvasLayer.new()
	pad_layer.layer = 2
	add_child(pad_layer)
	_make_pads(pad_layer)

	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	_start_round()


func _overlay(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _vignette(col: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.85))
	g.set_offset(0, 0.45)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	add_child(tr)
	return tr


func _make_pads(layer: CanvasLayer) -> void:
	var dark := Color(0, 0, 0, 0.28)
	var red := Color(0.75, 0.1, 0.1, 0.32)
	pads = [
		TouchPad.new().setup("", "dodge_left", 58, dark, TouchPad.Icon.LEFT),
		TouchPad.new().setup("", "dodge_right", 58, dark, TouchPad.Icon.RIGHT),
		TouchPad.new().setup("БЛОК", "block", 54, Color(0.15, 0.3, 0.8, 0.3)),
		TouchPad.new().setup("ЛЕВЫЙ", "punch_left", 64, red),
		TouchPad.new().setup("ПРАВЫЙ", "punch_right", 64, red),
	]
	for p in pads:
		layer.add_child(p)


func _on_resize() -> void:
	var sz := get_viewport().get_visible_rect().size
	# Центр «камеры» — на уровне лица соперника (верхняя треть кадра)
	view.pivot_offset = Vector2(sz.x * 0.5, sz.y * 0.3)
	view.scale = Vector2.ONE * VIEW_ZOOM
	opp.pivot_offset = Vector2(sz.x * 0.5, sz.y * 0.35)
	var spots := [
		Vector2(95, sz.y - 95), Vector2(235, sz.y - 95), Vector2(165, sz.y - 225),
		Vector2(sz.x - 240, sz.y - 95), Vector2(sz.x - 100, sz.y - 200),
	]
	for i in pads.size():
		pads[i].position = spots[i]


# ---------- Раунды ----------

func _start_round() -> void:
	phase = Phase.INTRO
	time_left = ROUND_TIME
	hud.round_num = round_num
	hud.time_left = time_left
	_ai_timer = 1.5
	await _show_banner("РАУНД %d" % round_num, 1.2)
	if not is_inside_tree():
		return
	await _show_banner("БОКС!", 0.6)
	if not is_inside_tree() or phase != Phase.INTRO:
		return
	phase = Phase.FIGHT


func _end_round() -> void:
	phase = Phase.BREAK
	if round_num < ROUNDS:
		await _show_banner("Конец раунда", 1.6)
		if not is_inside_tree():
			return
		round_num += 1
		player.rest(HEAL_BETWEEN_ROUNDS)
		enemy.rest(HEAL_BETWEEN_ROUNDS)
		pstate = P.IDLE
		_start_round()
	else:
		_decision()


func _decision() -> void:
	phase = Phase.OVER
	var p_score: float = player.health + stats["player_landed"] * 0.5
	var e_score: float = enemy.health + stats["enemy_landed"] * 0.5
	var won: bool = p_score >= e_score
	await _show_banner("Решение судей", 1.8)
	if not is_inside_tree():
		return
	Game.finish_fight("win" if won else "lose", "Победа решением судей" if won else "Поражение решением судей")


func _knockout(player_won: bool) -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	if player_won:
		if not opp.play("knockdown"):
			opp.interrupt()
			var tw := create_tween()
			tw.tween_property(dim, "color:a", 0.75, 1.2)
	else:
		pstate = P.KO
		# Падаем: камера заваливается и темнеет
		_kill_view_tween()
		var tw := create_tween().set_parallel()
		tw.tween_property(view, "rotation", 0.5, 0.9).set_ease(Tween.EASE_IN)
		tw.tween_property(view, "position:y", 260.0, 0.9).set_ease(Tween.EASE_IN)
		tw.tween_property(dim, "color:a", 0.85, 1.2)
	await _show_banner("НОКАУТ!", 2.6)
	if not is_inside_tree():
		return
	Game.finish_fight("win" if player_won else "lose", "Нокаут в %d-м раунде" % round_num)


func _show_banner(text: String, seconds: float) -> void:
	banner.text = text
	banner.modulate = Color(1, 1, 1, 0)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(1.4, 1.4)
	var tw := create_tween().set_parallel()
	tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		return
	create_tween().tween_property(banner, "modulate:a", 0.0, 0.15)


# ---------- Каждый кадр ----------

func _process(delta: float) -> void:
	_p_time += delta
	_update_player(delta)
	_update_ai(delta)

	if phase == Phase.FIGHT:
		time_left = maxf(0.0, time_left - delta)
		hud.time_left = time_left
		if time_left <= 0.0:
			_end_round()


func _update_player(delta: float) -> void:
	if pstate == P.KO:
		return
	var can_input := phase == Phase.FIGHT

	match pstate:
		P.IDLE, P.BLOCK:
			player.regen(STAMINA_REGEN * delta * (0.5 if pstate == P.BLOCK else 1.0))
			var want_block := can_input and Input.is_action_pressed("block")
			if want_block != (pstate == P.BLOCK):
				_set_pstate(P.BLOCK if want_block else P.IDLE)
				_set_gloves("block" if want_block else "guard")
				create_tween().tween_property(dim, "color:a", 0.18 if want_block else 0.0, 0.1)
			if not can_input:
				return
			if Input.is_action_just_pressed("punch_left"):
				_start_punch("left")
			elif Input.is_action_just_pressed("punch_right"):
				_start_punch("right")
			elif Input.is_action_just_pressed("dodge_left"):
				_start_dodge("left")
			elif Input.is_action_just_pressed("dodge_right"):
				_start_dodge("right")
		P.PUNCH:
			if not _punch_resolved and _p_time >= PUNCH_CONTACT:
				_punch_resolved = true
				_resolve_player_punch()
			if _p_time >= PUNCH_TIME:
				_set_pstate(P.IDLE)
				_set_gloves("guard")
		P.DODGE:
			if _p_time >= DODGE_TIME:
				_set_pstate(P.IDLE)
		P.HURT:
			if _p_time >= HURT_TIME:
				_set_pstate(P.IDLE)
				_set_gloves("guard")


func _set_pstate(s: P) -> void:
	pstate = s
	_p_time = 0.0


func _start_punch(side: String) -> void:
	if not player.spend(PUNCH_COST):
		_popup("Нет сил", Color(0.7, 0.7, 0.8))
		return
	_set_pstate(P.PUNCH)
	_punch_side = side
	_punch_resolved = false
	_set_gloves("jab" if side == "left" else "cross")
	# Рывок камеры вперёд
	_kill_view_tween()
	_view_tween = create_tween()
	_view_tween.tween_property(view, "scale", Vector2.ONE * VIEW_ZOOM * 1.035, 0.07)
	_view_tween.tween_property(view, "scale", Vector2.ONE * VIEW_ZOOM, 0.18)


func _start_dodge(dir: String) -> void:
	if not player.spend(DODGE_COST):
		return
	_set_pstate(P.DODGE)
	_dodge_dir = dir
	var sgn := -1.0 if dir == "left" else 1.0
	# Голова уходит в сторону — картинка смещается в обратную
	_kill_view_tween()
	view.scale = Vector2.ONE * VIEW_ZOOM
	_view_tween = create_tween()
	_view_tween.set_parallel()
	# Небольшой наезд, чтобы при сдвиге по краям не появлялась пустота
	_view_tween.tween_property(view, "position:x", -sgn * 80.0, 0.11).set_ease(Tween.EASE_OUT)
	_view_tween.tween_property(view, "position:y", 22.0, 0.11)
	_view_tween.tween_property(view, "rotation", sgn * 0.03, 0.11)
	_view_tween.tween_property(view, "scale", Vector2.ONE * VIEW_ZOOM * 1.08, 0.11)
	_view_tween.chain().tween_interval(0.2)
	_view_tween.chain().set_parallel()
	_view_tween.tween_property(view, "position", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN_OUT)
	_view_tween.tween_property(view, "rotation", 0.0, 0.2)
	_view_tween.tween_property(view, "scale", Vector2.ONE * VIEW_ZOOM, 0.2)


func _kill_view_tween() -> void:
	if _view_tween:
		_view_tween.kill()
	view.position = Vector2.ZERO
	view.rotation = 0.0


func _set_gloves(key: String) -> void:
	gloves.texture = _glove_tex.get(key, _glove_tex.get("guard", null))


# ---------- Удар игрока ----------

func _resolve_player_punch() -> void:
	if phase != Phase.FIGHT:
		return
	var power := player.power()
	var kind := opp.current_kind()
	var dmg := 0.0
	var label := ""

	if kind == "attack" and not opp.impact_passed:
		# Попал на замахе соперника — контратака, его удар сорван
		dmg = 12.0 * power
		label = "КОНТРА!"
		opp.interrupt()
	elif kind == "attack":
		# Соперник промахнулся и открыт
		dmg = 9.0 * power
	elif kind == "hit":
		dmg = 6.0 * power
	elif kind == "ko":
		return
	else:
		# Соперник в стойке — может закрыться
		var block_chance := 0.45 + 0.08 * (round_num - 1)
		if randf() < block_chance:
			enemy.damage(1.0)
			_popup("Блок", Color(0.7, 0.8, 1.0))
			if not opp.play("block"):
				_enemy_recoil(0.4)
			_ai_timer = minf(_ai_timer, 0.5)  # после блока часто отвечает
			return
		dmg = 7.0 * power

	enemy.damage(dmg)
	stats["player_landed"] += 1
	_popup("%s %d" % [label, roundi(dmg)] if label != "" else str(roundi(dmg)),
		Color(1.0, 0.85, 0.2) if label != "" else Color.WHITE)
	_flash(0.22)

	if enemy.is_out():
		_knockout(true)
		return

	var react := "hit_hook" if _punch_side == "right" and opp.has_clip("hit_hook") else "hit_head"
	if not opp.play(react):
		_enemy_recoil(1.0)
		_ai_timer = maxf(_ai_timer, 0.7)


## Заглушка реакции, пока нет роликов «пропустил удар»: соперника отбрасывает назад.
func _enemy_recoil(strength: float) -> void:
	var tw := create_tween()
	tw.tween_property(opp, "scale", Vector2.ONE * (1.0 - 0.05 * strength), 0.06)
	tw.parallel().tween_property(opp, "position:y", -14.0 * strength, 0.06)
	tw.parallel().tween_property(opp, "rotation", randf_range(-0.03, 0.03) * strength, 0.06)
	tw.tween_property(opp, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(opp, "position:y", 0.0, 0.25)
	tw.parallel().tween_property(opp, "rotation", 0.0, 0.25)


# ---------- Удар соперника ----------

func _update_ai(delta: float) -> void:
	if phase != Phase.FIGHT or opp.is_busy():
		return
	enemy.regen(STAMINA_REGEN * delta)
	_ai_timer -= delta
	if _ai_timer > 0.0:
		return
	var attacks := opp.clips_of_kind("attack")
	if attacks.is_empty():
		return
	var choice: String = attacks.pick_random()
	if enemy.spend(10.0) and opp.play(choice):
		var tip: String = Game.CLIPS[choice].get("hint", "")
		if tip != "" and not _shown_hints.has(choice):
			_shown_hints[choice] = true
			_show_hint(tip)
	_ai_timer = randf_range(0.9, 2.2) - 0.2 * (round_num - 1)


func _on_enemy_impact(clip: String) -> void:
	if phase != Phase.FIGHT or pstate == P.KO:
		return
	var info: Dictionary = Game.CLIPS[clip]
	var dodge_ok: bool = pstate == P.DODGE and _p_time >= DODGE_SAFE_FROM and _p_time <= DODGE_SAFE_TO \
		and (info["dodge"] == "any" or info["dodge"] == _dodge_dir)
	if dodge_ok:
		_popup("Уклон!", Color(0.55, 0.85, 1.0))
		return

	var dmg: float = info["damage"] * enemy.power()
	if pstate == P.BLOCK:
		dmg *= info.get("block_mult", 0.3)
		player.stamina = maxf(0.0, player.stamina - 10.0)
		_shake(6.0, 0.15)
		if dmg < 0.5:
			_popup("Блок", Color(0.7, 0.8, 1.0))
			return
	else:
		_set_pstate(P.HURT)
		_set_gloves("guard")
		_shake(22.0, 0.3)
		_hurt_flash()

	player.damage(dmg)
	stats["enemy_landed"] += 1
	if player.is_out():
		_knockout(false)


func _on_clip_finished(_clip: String) -> void:
	pass


# ---------- Эффекты ----------

func _shake(amount: float, duration: float) -> void:
	_kill_view_tween()
	_view_tween = create_tween()
	var steps := int(duration / 0.03)
	for i in steps:
		var k := 1.0 - float(i) / steps
		_view_tween.tween_property(view, "position", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * k, 0.03)
	_view_tween.tween_property(view, "position", Vector2.ZERO, 0.05)


func _flash(alpha: float) -> void:
	flash.color.a = alpha
	create_tween().tween_property(flash, "color:a", 0.0, 0.18)


func _hurt_flash() -> void:
	hurt_overlay.modulate.a = 1.0
	create_tween().tween_property(hurt_overlay, "modulate:a", 0.0, 0.6)


func _popup(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 46)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(l)
	var sz := get_viewport().get_visible_rect().size
	l.size = Vector2(400, 60)
	l.position = Vector2(sz.x * 0.5 - 200 + randf_range(-60, 60), sz.y * 0.32)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 70, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _show_hint(text: String) -> void:
	hint.text = text
	var tw := create_tween()
	tw.tween_property(hint, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.2)
	tw.tween_property(hint, "modulate:a", 0.0, 0.4)


# ---------- Кнопка «Назад» ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.go_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Game.go_to_menu()
