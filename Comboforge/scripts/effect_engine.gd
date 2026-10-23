extends RefCounted
## Deterministic event queue. Triggers are data-defined, recursion is bounded.
## All modifiers from orthogonally adjacent support tiles are additive within
## their own stat; damage_more then multiplies base damage.

const MAX_EVENTS: int = 512
const MAX_DEPTH: int = 6
var _queue: Array[Dictionary] = []
var _seen: Dictionary = {}
var _processed: int = 0

func resolve_turn(state) -> void:
	if state.game_over:
		return
	_queue.clear()
	_seen.clear()
	_processed = 0
	state.add_log("--- Resolve turn %d ---" % state.turn)
	state.shield = 0
	_tick_statuses(state)
	for cell in range(state.board.size()):
		if str(state.board[cell]) != "":
			_queue.append({"trigger": "on_turn", "source": cell, "depth": 0, "power": 1.0})
	_drain(state)
	if not state.enemy.is_empty() and not state.game_over:
		var attack: int = int(state.enemy.get("damage", 3))
		if state.statuses.has("chill"):
			attack = maxi(1, int(ceil(float(attack) * 0.7)))
		var blocked: int = mini(attack, state.shield)
		state.shield -= blocked
		var taken: int = attack - blocked
		state.hp -= taken
		state.add_log("%s attacks: %d blocked, %d damage taken." % [
			state.enemy.get("name", "Enemy"), blocked, taken
		])
		if state.hp <= 0:
			state.hp = 0
			state.game_over = true
			state.add_log("DEFEAT. Try a different tile synergy.")
	if _processed >= MAX_EVENTS:
		state.add_log("Event budget reached: remaining triggers skipped.")
	state.advance_after_combat()

func _tick_statuses(state) -> void:
	var status_names: Array = state.statuses.keys()
	status_names.sort()
	for status_name in status_names:
		if state.enemy.is_empty():
			break
		var status: Dictionary = state.statuses.get(status_name, {})
		if status_name == "ignite" or status_name == "poison":
			_damage(state, int(status.get("damage", 0)), str(status_name), -1, 0, false, false)
		status["turns"] = int(status.get("turns", 1)) - 1
		if int(status["turns"]) <= 0:
			state.statuses.erase(status_name)
		else:
			state.statuses[status_name] = status

func _drain(state) -> void:
	while not _queue.is_empty() and _processed < MAX_EVENTS:
		var event: Dictionary = _queue.pop_front()
		var depth: int = int(event.get("depth", 0))
		if depth > MAX_DEPTH:
			continue
		_processed += 1
		var trigger: String = str(event.get("trigger", ""))
		if trigger == "on_turn":
			_dispatch_tile(state, int(event.get("source", -1)), event)
		else:
			for cell in range(state.board.size()):
				if str(state.board[cell]) != "":
					_dispatch_tile(state, cell, event)

func _dispatch_tile(state, cell: int, event: Dictionary) -> void:
	if cell < 0 or cell >= state.board.size():
		return
	var tile_id: String = str(state.board[cell])
	if tile_id == "":
		return
	var tile: Dictionary = state.content.tiles.get(tile_id, {})
	var effects: Array = tile.get("effects", [])
	for effect_index in range(effects.size()):
		var effect = effects[effect_index]
		if not effect is Dictionary:
			continue
		var trigger: String = str(event.get("trigger", ""))
		if str(effect.get("trigger", "on_turn")) != trigger:
			continue
		if trigger != "on_turn":
			if str(effect.get("condition", "any")) == "adjacent_source":
				if not state.adjacent(cell).has(int(event.get("source", -1))):
					continue
			# Event-triggered effects proc at most once per tile/effect per turn.
			# This prevents on-hit -> on-hit cycles while allowing distinct tiles.
			var key: String = "%d:%d" % [cell, effect_index]
			if _seen.has(key):
				continue
			_seen[key] = true
		_apply_effect(state, cell, effect, event)

func _apply_effect(state, cell: int, effect: Dictionary, event: Dictionary) -> void:
	var kind: String = str(effect.get("type", ""))
	var amount: int = int(effect.get("amount", 0))
	match kind:
		"damage":
			_apply_attack(state, cell, effect, event)
		"shield":
			state.shield += amount
			state.add_log("%s grants %d shield." % [_tile_name(state, cell), amount])
		"heal":
			var restored: int = mini(amount, state.max_hp - state.hp)
			state.hp += restored
			if restored > 0:
				state.add_log("%s heals %d HP." % [_tile_name(state, cell), restored])
		"essence":
			state.essence = mini(40, state.essence + amount)
			state.add_log("%s generates %d essence." % [_tile_name(state, cell), amount])
		"gold":
			state.gold += amount
			state.add_log("%s generates %d gold." % [_tile_name(state, cell), amount])
		"apply_status":
			if not state.enemy.is_empty():
				_apply_status(state, effect)
		_:
			state.add_log("Unknown effect type: " + kind)

func _apply_attack(state, cell: int, effect: Dictionary, event: Dictionary) -> void:
	if state.enemy.is_empty():
		return
	var flat_bonus: int = 0
	var more_bonus: float = 0.0
	var crit_bonus: float = 0.0
	var chain_bonus: int = 0
	var leech_bonus: float = 0.0
	var echo_bonus: int = 0
	for adjacent_cell in state.adjacent(cell):
		var neighbor_id: String = str(state.board[adjacent_cell])
		if neighbor_id == "":
			continue
		var neighbor: Dictionary = state.content.tiles.get(neighbor_id, {})
		for bonus in neighbor.get("bonuses", []):
			if not bonus is Dictionary:
				continue
			match str(bonus.get("type", "")):
				"damage_flat":
					flat_bonus += int(bonus.get("amount", 0))
				"damage_more":
					more_bonus += float(bonus.get("amount", 0.0))
				"crit_chance":
					crit_bonus += float(bonus.get("amount", 0.0))
				"chain":
					chain_bonus += int(bonus.get("amount", 0))
				"leech":
					leech_bonus += float(bonus.get("amount", 0.0))
				"echo":
					echo_bonus += int(bonus.get("amount", 0))
	var power: float = float(event.get("power", 1.0))
	var base: int = maxi(1, int(effect.get("amount", 1)) + flat_bonus)
	var raw: int = maxi(1, int(round(float(base) * (1.0 + more_bonus) * power)))
	var critical: bool = state.rng.randf() < clampf(0.05 + crit_bonus, 0.0, 0.95)
	if critical:
		raw = int(ceil(float(raw) * 1.5))
	var element: String = str(effect.get("element", "physical"))
	var depth: int = int(event.get("depth", 0))
	var dealt: int = _damage(state, raw, element, cell, depth, true, critical)
	if dealt > 0 and leech_bonus > 0.0:
		state.hp = mini(state.max_hp, state.hp + int(ceil(float(dealt) * leech_bonus)))
	if dealt > 0 and effect.has("status") and not state.enemy.is_empty():
		_apply_status(state, effect)
	for n in range(mini(chain_bonus, 2)):
		if state.enemy.is_empty():
			break
		_damage(state, maxi(1, int(ceil(float(raw) * 0.5))), element, cell, depth + 1, true, false)
	# Echo repeats only on-turn damage effects, at half strength and bounded depth.
	if echo_bonus > 0 and str(event.get("trigger", "")) == "on_turn" and depth < 2:
		for n in range(mini(echo_bonus, 1)):
			_queue.append({"trigger": "on_turn", "source": cell, "depth": depth + 1, "power": power * 0.5})

func _apply_status(state, effect: Dictionary) -> void:
	var name: String = str(effect.get("status", ""))
	if not ["ignite", "poison", "chill"].has(name):
		return
	var duration: int = maxi(1, int(effect.get("duration", 2)))
	var potency: int = maxi(0, int(effect.get("potency", 2)))
	var previous: Dictionary = state.statuses.get(name, {"damage": 0, "turns": 0})
	if name == "poison":
		previous["damage"] = int(previous.get("damage", 0)) + potency
	elif name == "ignite":
		previous["damage"] = maxi(int(previous.get("damage", 0)), potency)
	previous["turns"] = maxi(int(previous.get("turns", 0)), duration)
	state.statuses[name] = previous
	state.add_log("%s applied (%d turns)." % [name.capitalize(), duration])

func _damage(state, raw: int, element: String, source: int, depth: int, is_hit: bool, critical: bool) -> int:
	if state.enemy.is_empty():
		return 0
	var resistance: float = float(state.enemy.get("resistances", {}).get(element, 0.0))
	var dealt: int = maxi(1, int(round(float(raw) * (1.0 - clampf(resistance, -0.5, 0.9)))))
	state.enemy["hp"] = maxi(0, int(state.enemy.get("hp", 0)) - dealt)
	var source_name: String = _tile_name(state, source) if source >= 0 else element.capitalize()
	state.add_log("%s: %d %s damage%s." % [
		source_name, dealt, element, " (CRIT)" if critical else ""
	])
	if is_hit:
		_queue.append({"trigger": "on_hit", "source": source, "depth": depth + 1, "power": 1.0})
		if critical:
			_queue.append({"trigger": "on_crit", "source": source, "depth": depth + 1, "power": 1.0})
	if int(state.enemy["hp"]) <= 0:
		state.defeat_enemy()
		_queue.append({"trigger": "on_kill", "source": source, "depth": depth + 1, "power": 1.0})
	return dealt

func _tile_name(state, cell: int) -> String:
	if cell < 0 or cell >= state.board.size():
		return "Effect"
	var id: String = str(state.board[cell])
	return str(state.content.tiles.get(id, {}).get("name", id))
