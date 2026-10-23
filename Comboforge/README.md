# Comboforge — Godot 4 prototype

Original 2D turn-based roguelike combo builder, exploring spatial tile synergies and complex RPG-style buildcrafting. **Prototype v0.1**, not a finished commercial game.

## Play

Open this directory in Godot **4.4.1** and press F6/F5, or download the Windows build artifact from the GitHub Actions workflow (once CI has passed).

1. Click one of four cards in your hand.
2. Click an empty grid cell to place it (up to two placements per turn).
3. Place support tiles orthogonally next to attack tiles to amplify their effects.
4. Click **END TURN** to resolve all board effects and the enemy attack.
5. Earn essence and gold, reroll your hand, survive twelve enemy waves.

## Current mechanics

- 7 x 6 board; 20 original tiles, 6 enemy templates, 12-wave run and boss.
- Damage types: physical, fire, cold, lightning, chaos; enemy resistances.
- Ignite, stacking poison, chill, critical hits, shield, healing, leech.
- Adjacency supports: additive flat damage, more damage, critical chance, extra chain hit, echo, life leech.
- On-hit, on-crit, on-kill and on-turn event triggers with once-per-turn guards and bounded event queue.
- Deterministic seeded RNG, save/load in user://savegame.json, turn-by-turn combat log.
- Data-driven tiles in data/tiles.json; enemies in data/enemies.json.
- External mods from a mods/ directory next to the executable or user://mods.

## Modify or add tiles

Edit data/tiles.json. Each tile defines id, name, cost, weight, symbol, color, description, effects and optional bonuses. See existing tiles for the supported effect schema.

External mod example in mods/my_tiles.json:

    {
      "tiles": [
        {
          "id": "my_meteor",
          "name": "Meteor",
          "symbol": "M",
          "cost": 4,
          "weight": 1,
          "color": "#f58254",
          "description": "An original fire skill.",
          "effects": [
            {"trigger": "on_turn", "type": "damage", "amount": 10, "element": "fire"}
          ]
        }
      ]
    }

Currently recognized effect triggers: on_turn, on_hit, on_crit, on_kill.
Currently recognized effect types: damage, shield, heal, essence, gold, apply_status.
Support bonus types: damage_flat, damage_more, crit_chance, chain, leech, echo.
Non-turn triggers can use condition: adjacent_source.

## Technical

- scripts/game_state.gd: authoritative gameplay state, seeded draws, placement, persistence.
- scripts/effect_engine.gd: deterministic combat event queue and adjacency modifiers.
- scripts/content_db.gd: JSON loading and mod overlays.
- scripts/main.gd: Godot Control UI; no art or external assets required.
- scripts/tests/test_core.gd: deterministic core smoke tests.
- export_presets.cfg: Windows Desktop x64, embedded PCK.
- .github/workflows/comboforge-windows.yml: test and export CI.

To run tests:

    godot --headless --path Comboforge --import
    godot --headless --path Comboforge --script res://scripts/tests/test_core.gd

To export:

    mkdir -p Comboforge/build
    godot --headless --path Comboforge --export-release "Windows Desktop" build/Comboforge.exe

## Status and next work

The source is an initial implementation. Verify CI and the executable before calling the build playable. Next: reward choice screen, multiple simultaneous enemies, richer targeting, tooltip damage breakdown, content validation and expanded build archetypes.

This prototype uses original game logic and content names, not proprietary assets or source from other games.
