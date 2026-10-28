class_name Fighter
extends RefCounted
## Здоровье и выносливость бойца (для игрока и соперника).

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0

var display_name := "Боец"
var glove_color := Color(0.8, 0.1, 0.1)
var health := MAX_HEALTH
var stamina := MAX_STAMINA


func _init(n: String = "Боец", col: Color = Color(0.8, 0.1, 0.1)) -> void:
	display_name = n
	glove_color = col


func damage(amount: float) -> void:
	health = maxf(0.0, health - amount)


func spend(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true


func regen(amount: float) -> void:
	stamina = minf(MAX_STAMINA, stamina + amount)


## Уставший бьёт слабее: от 60 % до 100 % силы.
func power() -> float:
	return lerpf(0.6, 1.0, stamina / MAX_STAMINA)


func is_out() -> bool:
	return health <= 0.0


func rest(heal_fraction: float) -> void:
	health = minf(MAX_HEALTH, health + MAX_HEALTH * heal_fraction)
	stamina = MAX_STAMINA
