extends Node2D
## Бой: раунды, удары, попадания, нокаут, решение судей.

const ROUNDS := 3
const ROUND_TIME := 60.0
const FLOOR_Y := 600.0
const MIN_GAP := 125.0          ## ближе боксёры не сходятся
const ROPE_MARGIN := 120.0     ## отступ от края ринга
const HEAL_BETWEEN_ROUNDS := 0.2

enum Phase { INTRO, FIGHT, BREAK, OVER }

var phase: Phase = Phase.INTRO
var round_num := 1
var time_left := ROUND_TIME
var stats := {"player_landed": 0, "enemy_landed": 0}

var _view := Vector2(1280, 720)
var world: Node2D
var ring: Node2D
var player: Boxer
var enemy: Boxer
var ai: EnemyAI
var hud: Control
var banner: Label
var pads: Array[TouchPad] = []
var _shake := 0.0


func _ready() -> void:
	process_physics_priority = 10  # после боксёров
	_view = get_viewport().get_visible_rect().size

	world = Node2D.new()
	add_child(world)

	ring = preload("res://scripts/ring.gd").new()
	world.add_child(ring)

	player = _make_boxer(Game.player_name, 1, Color(0.12, 0.25, 0.75), Color(0.15, 0.3, 0.85), Color(0.87, 0.67, 0.54))
	enemy = _make_boxer(Game.enemy_name, -1, Color(0.7, 0.08, 0.1), Color(0.85, 0.12, 0.12), Color(0.72, 0.52, 0.4))

	ai = EnemyAI.new()
	ai.me = enemy
	ai.foe = player
	add_child(ai)

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
	banner.add_theme_font_size_override("font_size", 84)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 14)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(banner)

	var pad_layer := CanvasLayer.new()
	pad_layer.layer = 2
	add_child(pad_layer)
	_make_pads(pad_layer)

	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	_start_round()


func _make_boxer(n: String, face: int, trunks: Color, gloves: Color, skin: Color) -> Boxer:
	var b := Boxer.new()
	b.display_name = n
	b.facing = face
	b.trunks_color = trunks
	b.glove_color = gloves
	b.skin_color = skin
	b.punch_active.connect(_on_punch_active)
	b.knocked_out.connect(_on_knocked_out)
	world.add_child(b)
	return b


func _make_pads(layer: CanvasLayer) -> void:
	var white := Color(1, 1, 1, 0.16)
	var red := Color(0.9, 0.2, 0.2, 0.35)
	var blue := Color(0.2, 0.45, 0.95, 0.35)
	pads = [
		TouchPad.new().setup("", "move_left", 62, white, TouchPad.Icon.LEFT),
		TouchPad.new().setup("", "move_right", 62, white, TouchPad.Icon.RIGHT),
		TouchPad.new().setup("УКЛОН", "dodge", 50, white),
		TouchPad.new().setup("БЛОК", "block", 60, blue),
		TouchPad.new().setup("ДЖЕБ", "jab", 56, red),
		TouchPad.new().setup("КРОСС", "cross", 56, red),
		TouchPad.new().setup("ХУК", "hook", 50, red),
	]
	for p in pads:
		layer.add_child(p)


func _on_resize() -> void:
	_view = get_viewport().get_visible_rect().size
	ring.set_view(_view, FLOOR_Y)
	var w := _view.x
	var h := _view.y
	var spots := [
		Vector2(100, h - 100), Vector2(240, h - 100), Vector2(380, h - 95),      # влево, вправо, уклон
		Vector2(w - 100, h - 100),                                               # блок
		Vector2(w - 240, h - 95), Vector2(w - 115, h - 238), Vector2(w - 255, h - 235),  # джеб, кросс, хук
	]
	for i in pads.size():
		pads[i].position = spots[i]


# ---------- Раунды ----------

func _start_round() -> void:
	phase = Phase.INTRO
	ai.enabled = false
	time_left = ROUND_TIME
	hud.round_num = round_num
	hud.time_left = time_left
	player.position = Vector2(_view.x * 0.5 - 180, FLOOR_Y)
	enemy.position = Vector2(_view.x * 0.5 + 180, FLOOR_Y)
	await _show_banner("РАУНД %d" % round_num, 1.2)
	if not is_inside_tree():
		return
	await _show_banner("БОКС!", 0.6)
	if not is_inside_tree() or phase != Phase.INTRO:
		return
	phase = Phase.FIGHT
	ai.enabled = true


func _end_round() -> void:
	phase = Phase.BREAK
	ai.enabled = false
	player.set_move(0)
	player.set_block(false)
	if round_num < ROUNDS:
		await _show_banner("Конец раунда", 1.6)
		if not is_inside_tree():
			return
		round_num += 1
		player.reset_for_round(HEAL_BETWEEN_ROUNDS)
		enemy.reset_for_round(HEAL_BETWEEN_ROUNDS)
		_start_round()
	else:
		_decision()


func _decision() -> void:
	phase = Phase.OVER
	# Судьи: здоровье плюс количество точных ударов
	var p_score: float = player.health + stats["player_landed"] * 0.5
	var e_score: float = enemy.health + stats["enemy_landed"] * 0.5
	var won: bool = p_score >= e_score
	await _show_banner("Решение судей", 1.8)
	if not is_inside_tree():
		return
	_finish(won, "Победа решением судей" if won else "Поражение решением судей")


func _on_knocked_out(b: Boxer) -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	ai.enabled = false
	_shake = 0.5
	var won := b == enemy
	await _show_banner("НОКАУТ!", 2.4)
	if not is_inside_tree():
		return
	var reason := "Нокаут в %d-м раунде" % round_num
	_finish(won, reason)


func _finish(won: bool, reason: String) -> void:
	Game.finish_fight("win" if won else "lose", reason)


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
	var out := create_tween()
	out.tween_property(banner, "modulate:a", 0.0, 0.15)


# ---------- Каждый кадр ----------

func _physics_process(delta: float) -> void:
	# Управление игрока
	if phase == Phase.FIGHT and not player.is_ko():
		player.set_move(Input.get_axis("move_left", "move_right"))
		player.set_block(Input.is_action_pressed("block"))
		if Input.is_action_just_pressed("jab"):
			player.try_punch(&"jab")
		elif Input.is_action_just_pressed("cross"):
			player.try_punch(&"cross")
		elif Input.is_action_just_pressed("hook"):
			player.try_punch(&"hook")
		if Input.is_action_just_pressed("dodge"):
			player.try_dodge()
	else:
		player.set_move(0)
		player.set_block(false)

	_keep_apart()

	if phase == Phase.FIGHT:
		time_left = maxf(0.0, time_left - delta)
		hud.time_left = time_left
		if time_left <= 0.0:
			_end_round()

	# Тряска экрана
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * _shake / 0.3
	else:
		world.position = Vector2.ZERO


func _keep_apart() -> void:
	var left := ROPE_MARGIN
	var right := _view.x - ROPE_MARGIN
	player.position.x = clampf(player.position.x, left, right - MIN_GAP)
	enemy.position.x = clampf(enemy.position.x, left + MIN_GAP, right)
	var gap := enemy.position.x - player.position.x
	if gap < MIN_GAP:
		var push := (MIN_GAP - gap) * 0.5
		player.position.x -= push
		enemy.position.x += push


# ---------- Попадания ----------

func _on_punch_active(attacker: Boxer, type: StringName) -> void:
	if phase != Phase.FIGHT:
		return
	var defender := enemy if attacker == player else player
	if defender.is_ko():
		return
	var p: Dictionary = Boxer.PUNCHES[type]
	var dist := absf(attacker.position.x - defender.position.x)
	if dist > p["range"]:
		return  # не достал

	var hit_point := defender.position + Vector2(0, -290)

	if defender.is_dodging_now():
		_popup("Уклон!", hit_point, Color(0.5, 0.85, 1.0))
		return

	if defender.is_blocking():
		var broken := defender.block_hit(p["stamina"] * 0.7, p["damage"] * 0.15)
		_popup("Блок пробит!" if broken else "Блок", hit_point, Color(0.7, 0.8, 1.0))
		defender.position.x += attacker.facing * 6.0
		return

	var dmg: float = p["damage"] * attacker.punch_power
	var counter := defender.is_winding_up()
	if counter:
		dmg *= 1.5
	defender.take_hit(dmg, p["stun"])
	defender.position.x += attacker.facing * 14.0
	stats["player_landed" if attacker == player else "enemy_landed"] += 1

	if counter:
		_popup("КОНТРА! %d" % roundi(dmg), hit_point, Color(1.0, 0.85, 0.2))
	else:
		_popup(str(roundi(dmg)), hit_point, Color.WHITE)
	if type == &"hook" or counter:
		_shake = maxf(_shake, 0.25)


func _popup(text: String, pos: Vector2, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	world.add_child(l)
	l.position = pos - Vector2(60, 0)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", pos.y - 70, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


# ---------- Кнопка «Назад» на Android ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.go_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Game.go_to_menu()
