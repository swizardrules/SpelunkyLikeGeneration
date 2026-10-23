extends Control
## Self-contained Godot UI for the first playable Comboforge vertical slice.

const ContentDB = preload("res://scripts/content_db.gd")
const GameState = preload("res://scripts/game_state.gd")
const EffectEngine = preload("res://scripts/effect_engine.gd")

var db
var state
var engine
var selected_hand: int = -1
var board_buttons: Array[Button] = []
var hand_buttons: Array[Button] = []
var stats_label: Label
var enemy_label: Label
var selected_label: Label
var log_box: TextEdit
var end_button: Button
var reroll_button: Button

func _ready() -> void:
	db = ContentDB.new()
	db.load_all()
	state = GameState.new()
	state.new_run(db)
	engine = EffectEngine.new()
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#101826")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	layout.add_child(title_row)
	title_row.add_child(_label("COMBOFORGE", 28, Color("#f4d8a4")))
	title_row.add_child(_label(" |  ROGUELIKE COMBO BUILDER  /  ALPHA 0.1", 13, Color("#9db4d0")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	var new_button := _button("New Run")
	new_button.pressed.connect(_new_run)
	title_row.add_child(new_button)
	var save_button := _button("Save")
	save_button.pressed.connect(_save_game)
	title_row.add_child(save_button)
	var load_button := _button("Load")
	load_button.pressed.connect(_load_game)
	title_row.add_child(load_button)

	stats_label = _label("", 16, Color("#c7dfec"))
	layout.add_child(stats_label)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 20)
	layout.add_child(middle)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	middle.add_child(left)
	left.add_child(_label("BUILD BOARD  /  7 x 6", 16, Color("#f1e0b7")))

	var grid := GridContainer.new()
	grid.columns = GameState.WIDTH
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	left.add_child(grid)
	for i in range(GameState.WIDTH * GameState.HEIGHT):
		var cell := _button("")
		cell.custom_minimum_size = Vector2(84, 67)
		cell.pressed.connect(_cell_pressed.bind(i))
		cell.focus_mode = Control.FOCUS_NONE
		grid.add_child(cell)
		board_buttons.append(cell)

	var info := _label("Orthogonal adjacency only. Supports empower neighboring attacks.", 13, Color("#a2b7ce"))
	left.add_child(info)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(345, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	middle.add_child(right)
	right.add_child(_label("ENCOUNTER", 16, Color("#f1e0b7")))
	enemy_label = _label("", 17, Color("#e9d7c3"))
	enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(enemy_label)
	selected_label = _label("", 14, Color("#b7d3f4"))
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(selected_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	right.add_child(action_row)
	end_button = _button("END TURN")
	end_button.custom_minimum_size = Vector2(150, 48)
	end_button.pressed.connect(_end_turn)
	action_row.add_child(end_button)
	reroll_button = _button("Reroll (2 gold)")
	reroll_button.pressed.connect(_reroll)
	action_row.add_child(reroll_button)

	right.add_child(_label("COMBAT / TRIGGER LOG", 16, Color("#f1e0b7")))
	log_box = TextEdit.new()
	log_box.editable = false
	log_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.custom_minimum_size = Vector2(340, 230)
	log_box.add_theme_color_override("font_color", Color("#d1e1ee"))
	right.add_child(log_box)

	layout.add_child(_label("YOUR HAND  /  CLICK A CARD, THEN AN EMPTY BOARD CELL", 16, Color("#f1e0b7")))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 9)
	layout.add_child(cards)
	for i in range(GameState.HAND_SIZE):
		var card := _button("")
		card.custom_minimum_size = Vector2(180, 95)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_card_pressed.bind(i))
		cards.add_child(card)
		hand_buttons.append(card)

	var footer := _label("FIRE / POISON / CRITS / TRIGGERS / AURAS  •  Survive 12 waves.  •  All mechanics are original.", 12, Color("#819bb8"))
	layout.add_child(footer)

func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("#f4f7fb"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	_style_button(button, Color("#25364c"), false)
	return button

func _style_button(button: Button, color: Color, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#f1c46c") if selected else Color("#465b76")
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 5
	style.content_margin_right = 5
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.13)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := style.duplicate()
	disabled.bg_color = Color("#1c293a")
	button.add_theme_stylebox_override("disabled", disabled)

func _refresh() -> void:
	stats_label.text = "TURN %d   |   WAVE %d/%d   |   HP %d/%d   |   SHIELD %d   |   ESSENCE %d   |   GOLD %d   |   PLACEMENTS %d" % [
		state.turn, state.wave, GameState.MAX_WAVES, state.hp, state.max_hp,
		state.shield, state.essence, state.gold, state.placements_left
	]
	if state.game_over:
		enemy_label.text = "VICTORY! All waves cleared." if state.victory else "DEFEAT! Your fortress has fallen."
	elif state.enemy.is_empty():
		enemy_label.text = "Wave complete. The next enemy arrives next turn."
	else:
		var enemy_status: String = ""
		for key in state.statuses.keys():
			var status: Dictionary = state.statuses[key]
			enemy_status += "\n%s: %d turns" % [str(key).capitalize(), int(status.get("turns", 0))]
		enemy_label.text = "%s\nHP: %d / %d\nAttack: %d%s" % [
			state.enemy.get("name", "Enemy"),
			int(state.enemy.get("hp", 0)),
			int(state.enemy.get("max_hp", 0)),
			int(state.enemy.get("damage", 0)),
			enemy_status
		]
	for i in range(board_buttons.size()):
		var button: Button = board_buttons[i]
		var id: String = str(state.board[i])
		if id == "":
			button.text = "+"
			button.tooltip_text = "Empty cell (%d, %d)" % [i % GameState.WIDTH, i / GameState.WIDTH]
			_style_button(button, Color("#203048"), false)
		else:
			var tile: Dictionary = db.tiles.get(id, {})
			button.text = "%s\n%s" % [str(tile.get("symbol", "*")), str(tile.get("name", id))]
			button.tooltip_text = str(tile.get("description", ""))
			_style_button(button, Color.from_string(str(tile.get("color", "#49627b")), Color("#49627b")).darkened(0.30), false)
		button.disabled = state.game_over or (id == "" and state.placements_left <= 0)
	for i in range(hand_buttons.size()):
		var button: Button = hand_buttons[i]
		if i >= state.hand.size():
			button.text = "Empty"
			button.disabled = true
			continue
		var id: String = str(state.hand[i])
		var tile: Dictionary = db.tiles.get(id, {})
		var cost: int = int(tile.get("cost", 2))
		button.text = "%d  |  %s\nCost: %d essence\n%s" % [
			i + 1, str(tile.get("name", id)), cost, str(tile.get("symbol", "*"))
		]
		button.tooltip_text = str(tile.get("description", ""))
		button.disabled = state.game_over or state.placements_left <= 0 or state.essence < cost
		_style_button(button, Color.from_string(str(tile.get("color", "#49627b")), Color("#49627b")).darkened(0.55), selected_hand == i)
	if selected_hand >= 0 and selected_hand < state.hand.size():
		var tile: Dictionary = db.tiles.get(str(state.hand[selected_hand]), {})
		selected_label.text = "SELECTED: %s\n%s" % [str(tile.get("name", "")), str(tile.get("description", ""))]
	else:
		selected_label.text = "Choose a card below, then an empty cell. End turn to trigger your board."
	end_button.disabled = state.game_over
	reroll_button.disabled = state.game_over or state.gold < 2
	var text_value: String = ""
	for entry in state.log:
		text_value += entry + "\n"
	log_box.text = text_value
	log_box.scroll_vertical = log_box.get_line_count()

func _card_pressed(index: int) -> void:
	if state.game_over:
		return
	selected_hand = index
	_refresh()

func _cell_pressed(index: int) -> void:
	if selected_hand < 0:
		state.add_log("Select a card from your hand first.")
	else:
		if state.place_tile(selected_hand, index):
			selected_hand = -1
	_refresh()

func _end_turn() -> void:
	engine.resolve_turn(state)
	selected_hand = -1
	_refresh()

func _reroll() -> void:
	state.reroll_hand()
	selected_hand = -1
	_refresh()

func _new_run() -> void:
	state.new_run(db, int(Time.get_unix_time_from_system()))
	selected_hand = -1
	_refresh()

func _save_game() -> void:
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file == null:
		state.add_log("Could not write savegame.")
	else:
		file.store_string(JSON.stringify(state.snapshot(), "\t"))
		file.close()
		state.add_log("Saved to user://savegame.json")
	_refresh()

func _load_game() -> void:
	if not FileAccess.file_exists("user://savegame.json"):
		state.add_log("No savegame found.")
		_refresh()
		return
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	if file == null:
		state.add_log("Could not open savegame.")
		_refresh()
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary and state.restore(db, data):
		selected_hand = -1
	else:
		state.add_log("Invalid or incompatible savegame.")
	_refresh()
