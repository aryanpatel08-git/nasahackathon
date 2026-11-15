# Lunar Life

**Junior Astronaut Mission Trainer** for the 2026 NASA Space Apps Challenge.
Team: Kareem Dahrouj, Aryan Patel, Jimmy Lam.

You are a new crew member at a research outpost near the Moon's South Pole. Train at the academy,
fly down, run the power and the greenhouse, and get everyone behind the storm shelter when a
solar particle storm arrives. The storm is a replay of a real NASA DONKI record (10 May 2024).

## Run it
1. Open Godot 4.7 (4.7.2 was used), choose **Import**, and pick `project.godot` in this folder.
2. Press **F5**.

## Controls
| Key | Action |
| --- | --- |
| WASD / arrows (or gamepad stick) | Walk. Two keys at once walks diagonally. |
| E / Space / Enter (gamepad A) | Talk, use, next line. Every story screen waits for this key. |
| Hold E | Crank open the storm-shelter hatch. |
| M | Map and waypoints. |
| Esc / P | Pause: field notes, tasks, help, sound. |

## A full run takes about five minutes
1. **Intro** — four slides, each waits for E.
2. **Academy** — Commander's briefing, then Engineer Rivera's power-console training:
   keep Life Support alive through a 10-hour shadow by switching off what can wait.
3. **Outpost** — check the power room and the greenhouse. Each is a real trade-off.
4. **Radiation alert** — run north, hold E on the heavy hatch, step inside. The hatch seals
   behind the crew and you choose what the outpost powers while you wait.
5. **Mission report** — the battery chart for the whole shift, three star ratings
   (crew safety, power, food + science), and why it went the way it did. Try again for 9 stars.

Ten **field notes** unlock as you play. Each gives the real fact, how the game simplifies it,
and the NASA page it comes from.

## What is real and what is simplified
- Real: the DONKI solar-energetic-particle record, the facts in the field notes (sources in `CREDITS.md`).
- Simplified: exposure, battery, power and time are game units. The record is a detection near Earth,
  not a dose at a lunar outpost. The sunlight shadow pattern is invented.
  The game says so on the report's **Sources** page and in the last field note.

## For developers
- Everything is built in code; scenes are one node with a script. Autoloads are listed in `project.godot`.
- Floor plans live in `scripts/outpost/outpost_layout.gd` and `scripts/academy/academy_layout.gd`.
  The room art is painted from those files: `python3 tools/art/paint_world.py` and `tools/art/paint_academy.py`.
- Sound is made by `python3 tools/audio/make_audio.py`.
- Automatic playthrough with about 130 checks:
  `godot --headless --path . res://tools/playtest.tscn -- speed=3`
  (options: `rover=0|1 choice=0|1|2 late=N`). Screenshots from the last run are in `tools/shots/`.
- `tools/dev/strategy_table.tscn` prints the outcome of every strategy; the star thresholds were set from it.
