class_name EnemyAI
extends Node
## Простой ИИ соперника: держит дистанцию, бьёт, иногда закрывается или уклоняется.

@export_range(0.0, 1.0) var reaction := 0.45    ## шанс среагировать на замах игрока
@export_range(0.0, 1.0) var aggression := 0.55  ## шанс ударить, когда дистанция подходящая
@export var think_interval := 0.32              ## как часто принимает решения, сек.

var me: Boxer
var foe: Boxer
var enabled := false

var _think := 0.0
var _block_t := 0.0
var _seen_windup := false
var _combo: Array[StringName] = []


func _physics_process(delta: float) -> void:
	if me == null or foe == null:
		return
	if not enabled or me.is_ko() or foe.is_ko():
		me.set_move(0.0)
		me.set_block(false)
		return

	_block_t -= delta
	if _block_t <= 0.0:
		me.set_block(false)

	var dist := absf(me.position.x - foe.position.x)
	var toward := signf(foe.position.x - me.position.x)

	# Реакция на замах игрока (один раз на удар)
	if foe.is_winding_up():
		if not _seen_windup:
			_seen_windup = true
			var reach: float = Boxer.PUNCHES[foe.punch]["range"]
			if dist < reach + 20.0 and randf() < reaction:
				if randf() < 0.65:
					me.set_block(true)
					_block_t = 0.45
				else:
					me.try_dodge()
	else:
		_seen_windup = false

	_think -= delta
	if _think > 0.0:
		return
	_think = think_interval * randf_range(0.7, 1.3)

	# Продолжение серии
	if not _combo.is_empty() and me.can_act():
		me.try_punch(_combo.pop_front())
		return

	# Устал — отходит и закрывается
	if me.stamina < 22.0:
		me.set_move(-toward)
		if randf() < 0.4:
			me.set_block(true)
			_block_t = 0.5
		return

	if dist > 190.0:
		me.set_move(toward)
		return
	elif dist < 140.0:
		me.set_move(-toward * 0.6)
	else:
		me.set_move(0.0)

	if _block_t > 0.0 or randf() > aggression:
		return

	var r := randf()
	if r < 0.45:
		if me.try_punch(&"jab") and randf() < 0.35:
			_combo = [&"cross"]
	elif r < 0.78:
		me.try_punch(&"cross")
	elif dist < 170.0:
		me.try_punch(&"hook")
	else:
		me.try_punch(&"jab")
