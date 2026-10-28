extends Node
## Глобальное состояние игры (автозагрузка «Game»):
## порядок экранов, загрузка фото и видео, управление с клавиатуры.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const CUTSCENE_SCENE := "res://scenes/cutscene.tscn"
const FIGHT_SCENE := "res://scenes/fight.tscn"

const PHOTOS_DIR := "res://assets/media/photos/"
const VIDEO_DIR := "res://assets/media/video/"

## Кат-сцены. Если видео нет, показывается картинка с медленным наездом камеры,
## если нет и картинки — тёмный фон с текстом. Так игра работает без медиа.
const CUTSCENES := {
	"intro": {
		"video": "intro.ogv",
		"image": "locker_bg.png",
		"title": "Путь к рингу",
		"subtitle": "Сегодня всё решится",
		"duration": 4.0,
	},
	"faceoff": {
		"video": "faceoff.ogv",
		"image": ["faceoff.png", "opponent_base.jpg"],
		"title": "{player}  против  {enemy}",
		"subtitle": "3 раунда по 60 секунд",
		"duration": 4.0,
	},
	"win": {
		"video": "win.ogv",
		"image": "win.png",
		"title": "ПОБЕДА",
		"subtitle": "{reason}",
		"duration": 4.0,
	},
	"lose": {
		"video": "lose.ogv",
		"image": "lose.png",
		"title": "ПОРАЖЕНИЕ",
		"subtitle": "{reason}",
		"duration": 4.0,
	},
}

## Ролики соперника (вид от первого лица). Лежат в assets/media/video/.
## Если файла нет, ролик просто не используется — игра работает с тем, что есть.
##   length — длина ролика, сек.;  impact — момент удара в ролике, сек.;
##   damage — урон игроку;  dodge — в какую сторону надо уклониться
##   (left / right / any);  block_mult — какая доля урона проходит через блок.
const CLIPS := {
	"idle": {"file": "idle.ogv", "kind": "idle"},
	"jab": {"file": "jab.ogv", "kind": "attack", "length": 1.62, "impact": 0.72,
		"damage": 8.0, "dodge": "any", "block_mult": 0.0},
	"cross": {"file": "cross.ogv", "kind": "attack", "length": 1.6, "impact": 0.8,
		"damage": 11.0, "dodge": "any", "block_mult": 0.25},
	"hook": {"file": "hook.ogv", "kind": "attack", "length": 2.33, "impact": 1.2,
		"damage": 14.0, "dodge": "right", "block_mult": 0.35,
		"hint": "Хук летит слева — уклон ВПРАВО или блок"},
	"block": {"file": "block.ogv", "kind": "block", "length": 1.5},
	"hit_head": {"file": "hit_head.ogv", "kind": "hit", "length": 1.5},
	"hit_hook": {"file": "hit_hook.ogv", "kind": "hit", "length": 1.5},
	"hit_body": {"file": "hit_body.ogv", "kind": "hit", "length": 1.5},
	"knockdown": {"file": "knockdown.ogv", "kind": "ko", "length": 3.0},
}

var player_name := "Игрок"
var enemy_name := "Громов"

var current_cutscene := ""
var last_result := ""          # "win" или "lose"
var last_reason := ""          # «Нокаут во 2-м раунде» и т. п.

var _flow: Array = []


func _ready() -> void:
	_setup_input()


# ---------- Порядок экранов ----------

func start_match() -> void:
	_flow = [
		{"cutscene": "intro"},
		{"cutscene": "faceoff"},
		{"scene": FIGHT_SCENE},
	]
	next_step()


func finish_fight(result: String, reason: String) -> void:
	last_result = result
	last_reason = reason
	_flow = [{"cutscene": result}]
	next_step()


func next_step() -> void:
	if _flow.is_empty():
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	var step: Dictionary = _flow.pop_front()
	if step.has("cutscene"):
		current_cutscene = step["cutscene"]
		get_tree().change_scene_to_file(CUTSCENE_SCENE)
	else:
		get_tree().change_scene_to_file(step["scene"])


func go_to_menu() -> void:
	_flow.clear()
	get_tree().change_scene_to_file(MENU_SCENE)


# ---------- Медиа ----------

## Принимает имя файла или список имён — берётся первый найденный.
func load_texture(file_names: Variant) -> Texture2D:
	var names: Array = file_names if file_names is Array else [file_names]
	for file_name in names:
		if str(file_name).is_empty():
			continue
		var path: String = PHOTOS_DIR + str(file_name)
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func load_video(file_name: String) -> VideoStream:
	if file_name.is_empty():
		return null
	var path := VIDEO_DIR + file_name
	if ResourceLoader.exists(path):
		return load(path) as VideoStream
	return null


func format_text(text: String) -> String:
	return text.format({
		"player": player_name,
		"enemy": enemy_name,
		"reason": last_reason,
	})


# ---------- Клавиатура (для проверки на компьютере) ----------
## На телефоне те же действия нажимают экранные кнопки.

func _setup_input() -> void:
	var keys := {
		"dodge_left": [KEY_A, KEY_LEFT],
		"dodge_right": [KEY_D, KEY_RIGHT],
		"punch_left": [KEY_J],
		"punch_right": [KEY_K],
		"block": [KEY_SPACE, KEY_S, KEY_DOWN],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
