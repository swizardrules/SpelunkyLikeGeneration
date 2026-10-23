extends RefCounted
## Pure gameplay state. No UI nodes, animations or engine scene dependencies.

const WIDTH: int = 7
const HEIGHT: int = 6
const MAX_WAVES: int = 12
const HAND_SIZE: int = 4

var content
var board: Array = []
var hand: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 20261023
var wave: int = 1
var turn: int = 1
var hp: int = 40
var max_hp: int = 40
var shield: int = 0
var essence: int = 16
var gold: int = 4
var placements_left: int = 2
var enemy: Dictionary = {}
var statuses: Dictionary = {}
var game_over: bool = false
var victory: bool = false
var log: Array[String] = []

func new_run(db, seed: int = 20261023) -> void:
	content = db
	seed_value = seed
	rng.seed = seed_value
	board.clear()
	board.resize(WIDTH * HEIGHT)
	board.fill("")
	hand.clear()
	wave = 1
	turn = 1
	hp = 40
	max_hp = 40
	shield = 0
	essence = 16
	gold = 4
	placements_left = 2
	enemy.clear()
	statuses.clear()
	game_over = false
	victory = false
	log.clear()
	_spawn_enemy()
	for i in range(HAND_SIZE):
		_draw_card()
	add_log("New run. Seed: %s. Select a card, then click an empty cell." % str(seed_value))

func _spawn_enemy() -> void:
	var template: Dictionary = content.enemies[(wave - 1) % content.enemies.size()]
	var multiplier: float = 1.0 + 0.25 * float(wave - 1)
	var hp_value: int = int(round(float(template.get("hp", 18)) * multiplier))
	if wave == MAX_WAVES:
		hp_value *= 3
	var damage_value: int = int(template.get("damage", 3)) + int(floor(float(wave - 1) / 3.0))
	enemy = {
		"name": ("BOSS: " if wave == MAX_WAVES else "") + str(template.get("name", "Wanderer")),
		"hp": hp_value,
		"max_hp": hp_value,
		"damage": damage_value,
		"resistances": template.get("resistances", {}).duplicate(true)
	}
	statuses.clear()
	add_log("Wave %d/%d: %s (%d HP)" % [wave, MAX_WAVES, enemy["name"], hp_value])

func _draw_card() -> void:
	var ids: Array = content.tiles.keys()
	if ids.is_empty():
		return
	ids.sort()
	var total_weight: int = 0
	for id in ids:
		total_weight += maxi(1, int(content.tiles[id].get("weight", 1)))
	var roll: int = rng.randi_range(1, total_weight)
	for id in ids:
		roll -= maxi(1, int(content.tiles[id].get("weight", 1)))
		if roll <= 0:
			hand.append(str(id))
			return

func place_tile(hand_index: int, cell_index: int) -> bool:
	if game_over:
		return false
	if placements_left <= 0:
		add_log("No placements remaining this turn.")
		return false
	if hand_index < 0 or hand_index >= hand.size():
		add_log("Select a card first.")
		return false
	if cell_index < 0 or cell_index >= board.size() or str(board[cell_index]) != "":
		add_log("That cell is occupied.")
		return false
	var tile_id: String = str(hand[hand_index])
	var tile: Dictionary = content.tiles.get(tile_id, {})
	var cost: int = int(tile.get("cost", 2))
	if essence < cost:
		add_log("Not enough essence for %s (need %d)." % [tile.get("name", tile_id), cost])
		return false
	board[cell_index] = tile_id
	hand.remove_at(hand_index)
	_draw_card()
	essence -= cost
	placements_left -= 1
	add_log("Placed %s at (%d, %d) for %d essence." % [
		tile.get("name", tile_id), cell_index % WIDTH, cell_index / WIDTH, cost
	])
	return true

func reroll_hand() -> bool:
	if game_over or gold < 2:
		add_log("Need 2 gold to reroll.")
		return false
	gold -= 2
	hand.clear()
	for i in range(HAND_SIZE):
		_draw_card()
	add_log("Rerolled hand for 2 gold.")
	return true

func adjacent(index: int) -> Array[int]:
	var result: Array[int] = []
	var x: int = index % WIDTH
	var y: int = index / WIDTH
	if x > 0:
		result.append(index - 1)
	if x < WIDTH - 1:
		result.append(index + 1)
	if y > 0:
		result.append(index - WIDTH)
	if y < HEIGHT - 1:
		result.append(index + WIDTH)
	return result

func defeat_enemy() -> void:
	if enemy.is_empty():
		return
	add_log("%s defeated! +4 essence, +2 gold." % str(enemy.get("name", "Enemy")))
	enemy.clear()
	statuses.clear()
	essence = mini(40, essence + 4)
	gold += 2
	if wave >= MAX_WAVES:
		game_over = true
		victory = true
		add_log("VICTORY! You cleared all 12 waves.")

func advance_after_combat() -> void:
	if game_over:
		return
	turn += 1
	placements_left = 2
	essence = mini(40, essence + 5)
	if enemy.is_empty():
		wave += 1
		_spawn_enemy()

func add_log(message: String) -> void:
	log.append(message)
	if log.size() > 120:
		log.remove_at(0)

func snapshot() -> Dictionary:
	return {
		"version": 1,
		"seed": seed_value,
		"rng_state": str(rng.state),
		"board": board.duplicate(),
		"hand": hand.duplicate(),
		"wave": wave,
		"turn": turn,
		"hp": hp,
		"max_hp": max_hp,
		"shield": shield,
		"essence": essence,
		"gold": gold,
		"placements_left": placements_left,
		"enemy": enemy.duplicate(true),
		"statuses": statuses.duplicate(true),
		"game_over": game_over,
		"victory": victory,
		"log": log.duplicate()
	}

func restore(db, data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1:
		return false
	var saved_board = data.get("board", [])
	var saved_hand = data.get("hand", [])
	if not saved_board is Array or saved_board.size() != WIDTH * HEIGHT or not saved_hand is Array:
		return false
	for id in saved_board:
		if str(id) != "" and not db.tiles.has(str(id)):
			return false
	for id in saved_hand:
		if not db.tiles.has(str(id)):
			return false
	content = db
	seed_value = int(data.get("seed", 20261023))
	rng.seed = seed_value
	rng.state = int(str(data.get("rng_state", str(rng.state))))
	board = saved_board.duplicate()
	hand = saved_hand.duplicate()
	wave = int(data.get("wave", 1))
	turn = int(data.get("turn", 1))
	hp = int(data.get("hp", 40))
	max_hp = int(data.get("max_hp", 40))
	shield = int(data.get("shield", 0))
	essence = int(data.get("essence", 16))
	gold = int(data.get("gold", 4))
	placements_left = int(data.get("placements_left", 2))
	enemy = data.get("enemy", {}).duplicate(true)
	statuses = data.get("statuses", {}).duplicate(true)
	game_over = bool(data.get("game_over", false))
	victory = bool(data.get("victory", false))
	log.clear()
	for entry in data.get("log", []):
		log.append(str(entry))
	add_log("Loaded save.")
	return true
