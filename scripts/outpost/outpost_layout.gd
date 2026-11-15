class_name OutpostLayout
extends RefCounted
## The outpost floor plan: one place for every rectangle and spot.
##
## Units are MAP UNITS. Multiply by SCALE for world pixels (keep the numbers even so
## they land on whole pixels). The game builds collision and stations from these, and
## tools/art/paint_world.py reads this same file to paint assets/art/world/outpost_bg.png,
## so the picture and the walls can never drift apart. After changing a number here,
## run the painter again.

const SCALE := 1.5
const MAP := Vector2i(480, 304)
## Sky above this line (map units); regolith below it.
const HORIZON := 26

# --- Walkable floor ---
const CORRIDOR := Rect2(204, 132, 72, 150)
const POWER_ROOM := Rect2(28, 156, 148, 112)
const POWER_DOOR := Rect2(176, 194, 28, 36)
const GREEN_ROOM := Rect2(304, 156, 148, 112)
const GREEN_DOOR := Rect2(276, 194, 28, 36)
const SHELTER_ROOM := Rect2(160, 54, 160, 60)
const SHELTER_DOOR := Rect2(222, 114, 36, 18)

# --- Things that block the floor ---
const BATTERY_BANK := Rect2(40, 156, 64, 10)
const POWER_CONSOLE := Rect2(116, 156, 44, 10)
const CRATES := Rect2(32, 240, 26, 24)
const WORKBENCH := Rect2(30, 198, 12, 30)
const BED_A := Rect2(316, 166, 44, 28)
const BED_B := Rect2(396, 166, 44, 28)
const BED_C := Rect2(316, 226, 44, 28)
const BED_D := Rect2(396, 226, 44, 28)
const WATER_TANK := Rect2(366, 156, 24, 12)
const BENCH_WEST := Rect2(168, 54, 44, 10)
const BENCH_EAST := Rect2(268, 54, 44, 10)

# --- Places (feet positions) ---
const POWER_SPOT := Vector2(138, 180)
const GREEN_SPOT := Vector2(378, 182)
const HATCH_SPOT := Vector2(240, 124)
const SPAWN := Vector2(240, 248)
const RETURN_SPOT := Vector2(240, 272)
const ROVER_SPOT := Vector2(96, 290)

# --- Crew: where they work, where they wait at the hatch, where they sit out the storm ---
const TANAKA_HOME := Vector2(424, 210)
const TANAKA_WAIT := Vector2(256, 142)
const TANAKA_SEAT := Vector2(290, 78)
const RIVERA_HOME := Vector2(62, 214)
const RIVERA_WAIT := Vector2(224, 142)
const RIVERA_SEAT := Vector2(190, 78)
const HALL_JUNCTION := Vector2(240, 212)


static func floors() -> Array[Rect2]:
	return [CORRIDOR, POWER_ROOM, POWER_DOOR, GREEN_ROOM, GREEN_DOOR, SHELTER_ROOM, SHELTER_DOOR]


static func rooms() -> Array[Rect2]:
	return [CORRIDOR, POWER_ROOM, GREEN_ROOM, SHELTER_ROOM]


static func beds() -> Array[Rect2]:
	return [BED_A, BED_B, BED_C, BED_D]


static func blockers() -> Array[Rect2]:
	return [BATTERY_BANK, POWER_CONSOLE, CRATES, WORKBENCH, BED_A, BED_B, BED_C, BED_D, WATER_TANK, BENCH_WEST, BENCH_EAST]


## Map units -> world pixels.
static func px(point: Vector2) -> Vector2:
	return (point * SCALE).round()


static func px_rect(rect: Rect2) -> Rect2:
	return Rect2((rect.position * SCALE).round(), (rect.size * SCALE).round())
