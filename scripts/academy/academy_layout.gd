class_name AcademyLayout
extends RefCounted
## The Astronaut Academy floor plan, in world pixels (SCALE is 1).
##
## The game builds collision and stations from these numbers, and
## tools/art/paint_academy.py reads this same file to paint
## assets/art/world/academy_bg.png. After changing a number, run the painter again.

const SCALE := 1.0
const MAP := Vector2i(768, 432)
## The hall's floor. Everything outside it is wall.
const FLOOR := Rect2(12, 84, 744, 334)

# --- Furniture that blocks the floor ---
const WEATHER_DESK := Rect2(56, 84, 124, 20)
const SERVER_RACK := Rect2(196, 84, 36, 18)
const PLANTER_WEST := Rect2(246, 84, 18, 12)
const PLANTER_EAST := Rect2(426, 84, 18, 12)
const BATTERY_RACK := Rect2(462, 84, 56, 18)
const TRAINING_CONSOLE := Rect2(560, 84, 84, 20)
const HOLO_TABLE := Rect2(352, 198, 64, 34)
const PLANT_BENCH := Rect2(40, 340, 112, 24)
const SOFA_WEST := Rect2(296, 346, 26, 52)
const SOFA_EAST := Rect2(446, 346, 26, 52)
const LOUNGE_TABLE := Rect2(362, 360, 44, 24)
const LOCKERS := Rect2(590, 326, 96, 24)

# --- Things on the back wall (no footprint) ---
const BOARD := Rect2(268, 18, 74, 52)
const WINDOW_CENTER := Vector2(384, 42)
const HATCH_DOOR := Rect2(668, 22, 56, 62)

# --- Places (feet positions) ---
const SPAWN := Vector2(384, 322)
const HATCH_ARRIVAL := Vector2(696, 112)
const HATCH_SPOT := Vector2(696, 94)
const BOARD_SPOT := Vector2(304, 94)
const DESK_SPOT := Vector2(118, 114)
const PLANT_SPOT := Vector2(96, 330)
const COMMANDER_SPOT := Vector2(336, 150)
const ENGINEER_SPOT := Vector2(540, 122)
const BOTANIST_SPOT := Vector2(176, 350)


static func blockers() -> Array[Rect2]:
	return [WEATHER_DESK, SERVER_RACK, PLANTER_WEST, PLANTER_EAST, BATTERY_RACK, TRAINING_CONSOLE,
		HOLO_TABLE, PLANT_BENCH, SOFA_WEST, SOFA_EAST, LOUNGE_TABLE, LOCKERS]
