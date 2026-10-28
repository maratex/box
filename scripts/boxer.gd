class_name Boxer
extends Node2D
## Боксёр: состояние, выносливость, удары и рисовка (вид сбоку).
## Пока рисуется кодом. Позже здесь можно поставить спрайты.

signal punch_active(boxer: Boxer, punch: StringName)
signal knocked_out(boxer: Boxer)

enum State { IDLE, WINDUP, ACTIVE, RECOVER, BLOCK, DODGE, HIT, KO }

## Параметры ударов. windup — замах, active — момент попадания, recover — возврат.
const PUNCHES := {
	&"jab": {"damage": 4.0, "stamina": 6.0, "windup": 0.10, "active": 0.08, "recover": 0.16, "range": 200.0, "stun": 0.22},
	&"cross": {"damage": 8.0, "stamina": 12.0, "windup": 0.18, "active": 0.08, "recover": 0.24, "range": 205.0, "stun": 0.30},
	&"hook": {"damage": 13.0, "stamina": 18.0, "windup": 0.28, "active": 0.10, "recover": 0.34, "range": 175.0, "stun": 0.45},
}

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const STAMINA_REGEN := 14.0
const MOVE_SPEED := 230.0
const DODGE_TIME := 0.38
const DODGE_COST := 10.0
const DODGE_COOLDOWN := 0.6

@export var display_name := "Боксёр"
@export var facing := 1  ## 1 — смотрит вправо, -1 — влево
@export var body_scale := 1.35  ## размер фигуры на экране
@export var trunks_color := Color(0.75, 0.1, 0.12)
@export var glove_color := Color(0.85, 0.12, 0.12)
@export var skin_color := Color(0.87, 0.67, 0.54)
@export var hair_color := Color(0.15, 0.1, 0.08)

var health := MAX_HEALTH
var stamina := MAX_STAMINA
var state: State = State.IDLE
var punch: StringName = &""
var punch_power := 1.0

var _timer := 0.0
var _state_time := 0.0
var _dodge_cd := 0.0
var _move := 0.0
var _block_held := false
var _flash := 0.0
var _anim_t := 0.0
var _ko_tween: Tween


func _ready() -> void:
	scale = Vector2(facing * body_scale, body_scale)


# ---------- Команды (от игрока или ИИ) ----------

func set_move(dir: float) -> void:
	_move = clampf(dir, -1.0, 1.0)


func set_block(on: bool) -> void:
	_block_held = on


func can_act() -> bool:
	return state == State.IDLE or state == State.BLOCK


func try_punch(type: StringName) -> bool:
	if not can_act() or not PUNCHES.has(type):
		return false
	var p: Dictionary = PUNCHES[type]
	if stamina < p["stamina"]:
		return false
	# Уставший бьёт слабее: от 60 % до 100 % силы.
	punch_power = lerpf(0.6, 1.0, stamina / MAX_STAMINA)
	stamina -= p["stamina"]
	punch = type
	_enter(State.WINDUP, p["windup"])
	return true


func try_dodge() -> bool:
	if not can_act() or _dodge_cd > 0.0 or stamina < DODGE_COST:
		return false
	stamina -= DODGE_COST
	_dodge_cd = DODGE_COOLDOWN
	_enter(State.DODGE, DODGE_TIME)
	return true


# ---------- Проверки для боя ----------

func is_dodging_now() -> bool:
	# Неуязвимость почти на всё время уклона, кроме самого начала и конца.
	return state == State.DODGE and _state_time > 0.03 and _state_time < DODGE_TIME - 0.05


func is_blocking() -> bool:
	return state == State.BLOCK


func is_winding_up() -> bool:
	return state == State.WINDUP


func is_ko() -> bool:
	return state == State.KO


# ---------- Получение ударов ----------

func take_hit(damage: float, stun: float) -> void:
	health = maxf(0.0, health - damage)
	_flash = 0.18
	punch = &""
	if health <= 0.0:
		_knock_out()
		return
	_enter(State.HIT, stun)


func block_hit(stamina_loss: float, chip_damage: float) -> bool:
	## Возвращает true, если блок пробит (кончилась выносливость).
	stamina = maxf(0.0, stamina - stamina_loss)
	health = maxf(1.0, health - chip_damage)
	_flash = 0.06
	if stamina <= 0.0:
		_enter(State.HIT, 0.4)
		return true
	return false


func reset_for_round(heal_fraction: float) -> void:
	if _ko_tween:
		_ko_tween.kill()
	health = minf(MAX_HEALTH, health + MAX_HEALTH * heal_fraction)
	stamina = MAX_STAMINA
	punch = &""
	_move = 0.0
	_block_held = false
	rotation = 0.0
	_enter(State.IDLE, 0.0)


func _knock_out() -> void:
	_enter(State.KO, 0.0)
	_ko_tween = create_tween()
	_ko_tween.tween_property(self, "rotation", -PI * 0.47 * facing, 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	knocked_out.emit(self)


# ---------- Логика по кадрам ----------

func _enter(new_state: State, duration: float) -> void:
	state = new_state
	_timer = duration
	_state_time = 0.0


func _physics_process(delta: float) -> void:
	_anim_t += delta
	_state_time += delta
	_flash = maxf(0.0, _flash - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	self_modulate = Color(1.0, 0.55, 0.55) if _flash > 0.0 else Color.WHITE

	if state == State.KO:
		queue_redraw()
		return

	match state:
		State.IDLE, State.BLOCK:
			state = State.BLOCK if _block_held else State.IDLE
			var regen := STAMINA_REGEN * (0.4 if state == State.BLOCK else 1.0)
			stamina = minf(MAX_STAMINA, stamina + regen * delta)
			var speed := MOVE_SPEED * (0.45 if state == State.BLOCK else 1.0)
			position.x += _move * speed * delta
		_:
			_timer -= delta
			if _timer <= 0.0:
				_advance()
	queue_redraw()


func _advance() -> void:
	match state:
		State.WINDUP:
			_enter(State.ACTIVE, PUNCHES[punch]["active"])
			punch_active.emit(self, punch)
		State.ACTIVE:
			_enter(State.RECOVER, PUNCHES[punch]["recover"])
		State.RECOVER:
			punch = &""
			_enter(State.IDLE, 0.0)
		State.DODGE, State.HIT:
			_enter(State.IDLE, 0.0)


# ---------- Рисовка ----------
## Координаты локальные: (0, 0) — между ступнями, боксёр смотрит вправо.
## Отражение влево делает scale.x = -1.

func _phase_progress() -> float:
	var total := _state_time + _timer
	if total <= 0.0:
		return 1.0
	return clampf(_state_time / total, 0.0, 1.0)


func _extension() -> float:
	# Насколько вытянута бьющая рука: 0 — в защите, 1 — в точке удара.
	match state:
		State.WINDUP:
			return -0.15 * _phase_progress()
		State.ACTIVE:
			return 1.0
		State.RECOVER:
			return 1.0 - _phase_progress()
	return 0.0


func _draw() -> void:
	var t := _phase_progress()
	var ext := _extension()

	# Наклон корпуса
	var lean := Vector2(0.0, sin(_anim_t * 6.0) * 2.0)
	match state:
		State.DODGE:
			lean += Vector2(-32.0, 24.0) * sin(t * PI)
		State.HIT:
			lean += Vector2(-20.0, 4.0) * (1.0 - t)
		State.BLOCK:
			lean += Vector2(-4.0, 6.0)
	if punch != &"":
		lean.x += 10.0 * maxf(ext, 0.0)

	# Перчатки: lead — передняя рука, rear — задняя
	var lead_guard := Vector2(40, -160)
	var rear_guard := Vector2(20, -172)
	var lead := lead_guard
	var rear := rear_guard
	if state == State.BLOCK:
		lead = Vector2(34, -194)
		rear = Vector2(26, -178)
	elif punch == &"jab":
		lead = lead_guard.lerp(Vector2(122, -174), ext)
	elif punch == &"cross":
		rear = rear_guard.lerp(Vector2(126, -174), ext)
		lean.x += 6.0 * maxf(ext, 0.0)
	elif punch == &"hook":
		var e := maxf(ext, 0.0)
		lead = lead_guard.lerp(Vector2(100, -182), e) + Vector2(0, -22) * sin(e * PI)
	lead += lean
	rear += lean

	var hip := Vector2(0, -92)
	var shoulder_lead := Vector2(10, -162) + lean
	var shoulder_rear := Vector2(-4, -166) + lean
	var head := Vector2(8, -194) + lean
	var skin_dark := skin_color.darkened(0.25)
	var glove_dark := glove_color.darkened(0.35)

	# Тень
	var shadow := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		shadow.append(Vector2(cos(a) * 55.0, sin(a) * 9.0 + 2.0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))

	# Задняя рука (за корпусом)
	_draw_arm(shoulder_rear, rear, skin_dark, glove_dark, glove_color.darkened(0.15))

	# Ноги
	var knee_f := Vector2(20, -46)
	var knee_b := Vector2(-16, -48)
	draw_polyline(PackedVector2Array([hip + Vector2(-8, 0), knee_b, Vector2(-28, -4)]), skin_dark, 16.0)
	draw_polyline(PackedVector2Array([hip + Vector2(8, 0), knee_f, Vector2(30, -4)]), skin_color, 16.0)
	draw_rect(Rect2(-44, -10, 30, 12), Color(0.12, 0.12, 0.14))
	draw_rect(Rect2(18, -10, 32, 12), Color(0.16, 0.16, 0.18))

	# Корпус
	var torso := PackedVector2Array([
		hip + Vector2(-18, 0), hip + Vector2(18, 0),
		Vector2(24, -158) + lean, Vector2(14, -170) + lean,
		Vector2(-14, -172) + lean, Vector2(-20, -158) + lean,
	])
	draw_colored_polygon(torso, skin_color)

	# Трусы с поясом
	var trunks := PackedVector2Array([
		Vector2(-22, -66), Vector2(24, -66), Vector2(22, -104), Vector2(-20, -104),
	])
	draw_colored_polygon(trunks, trunks_color)
	draw_rect(Rect2(-21, -108, 44, 8), Color(0.95, 0.95, 0.95))

	# Голова
	draw_circle(head + Vector2(0, 20), 9.0, skin_dark)  # шея
	draw_circle(head, 23.0, skin_color)
	draw_arc(head, 23.0, PI * 1.05, PI * 1.95, 16, hair_color, 9.0)
	draw_circle(head + Vector2(14, -3), 3.0, Color(0.1, 0.1, 0.1))  # глаз
	if state == State.HIT or state == State.KO:
		draw_line(head + Vector2(10, -7), head + Vector2(18, 1), Color(0.1, 0.1, 0.1), 2.0)

	# Передняя рука
	_draw_arm(shoulder_lead, lead, skin_color, glove_dark, glove_color)


func _draw_arm(shoulder: Vector2, glove: Vector2, arm_col: Color, outline: Color, glove_col: Color) -> void:
	var mid := (shoulder + glove) * 0.5
	var reach := shoulder.distance_to(glove)
	var elbow := mid + Vector2(-6, 22) * clampf(1.0 - reach / 120.0, 0.0, 1.0)
	draw_polyline(PackedVector2Array([shoulder, elbow, glove]), arm_col, 12.0)
	draw_circle(glove, 17.0, outline)
	draw_circle(glove, 15.0, glove_col)
	draw_circle(glove + Vector2(4, -5), 4.0, glove_col.lightened(0.35))
