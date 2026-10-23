extends SceneTree
## Run: godot --headless --path Comboforge --script res://scripts/tests/test_core.gd

const ContentDB = preload("res://scripts/content_db.gd")
const GameState = preload("res://scripts/game_state.gd")
const EffectEngine = preload("res://scripts/effect_engine.gd")
var failures: int = 0

func _initialize() -> void:
	var db = ContentDB.new()
	db.load_all()
	_check(db.tiles.size() >= 20, "Expected at least 20 content tiles")
	_check(db.enemies.size() >= 5, "Expected at least 5 enemy templates")

	var a = GameState.new()
	var b = GameState.new()
	a.new_run(db, 424242)
	b.new_run(db, 424242)
	_check(a.hand == b.hand, "Seeded draws must be deterministic")
	_check(a.enemy == b.enemy, "Seeded enemy generation must be deterministic")
	_check(a.board.size() == 42, "Board must have 42 cells")
	_check(a.adjacent(0) == [1, 7], "Corner adjacency must be orthogonal")
	_check(a.adjacent(8).size() == 4, "Interior adjacency must have four neighbors")

	var first_id: String = str(a.hand[0])
	_check(a.place_tile(0, 0), "Should be able to place first tile")
	_check(str(a.board[0]) == first_id, "Placed tile must occupy chosen cell")
	_check(not a.place_tile(0, 0), "Cannot overwrite occupied cell")
	_check(a.placements_left == 1, "Placing a tile must consume one placement")

	var engine = EffectEngine.new()
	engine.resolve_turn(a)
	_check(a.turn == 2 or a.game_over, "End turn should advance turn counter")
	_check(a.hp >= 0, "Health should never be negative")
	_check(engine._processed <= engine.MAX_EVENTS, "Event queue must be bounded")

	var encoded: String = JSON.stringify(a.snapshot())
	var decoded = JSON.parse_string(encoded)
	var restored = GameState.new()
	_check(decoded is Dictionary and restored.restore(db, decoded), "Save must roundtrip through JSON")
	_check(restored.board == a.board, "Board must survive save/load")
	_check(restored.hand == a.hand, "Hand must survive save/load")
	_check(restored.rng.state == a.rng.state, "RNG state must survive save/load")

	# Stress test: cyclic on-hit triggers cannot grow without limit.
	var stress = GameState.new()
	stress.new_run(db, 123)
	for i in range(42):
		stress.board[i] = "spark_relay" if i % 2 == 0 else "arc_coil"
	engine.resolve_turn(stress)
	_check(engine._processed <= engine.MAX_EVENTS, "Stress test exceeded event budget")

	if failures > 0:
		printerr("%d Comboforge tests FAILED" % failures)
		quit(1)
	else:
		print("Comboforge core tests PASSED")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
