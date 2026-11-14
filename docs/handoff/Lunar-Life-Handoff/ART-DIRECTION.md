# Lunar Life art direction

Use these concepts to build clear playable rooms. Match the chunky top-down pixel style and indigo/steel base. Teal marks powered equipment, amber marks briefing and caution, green marks crops. Pair every color cue with a symbol, shape or short label. At 480×270 with 32×32 sprites, walls and furnishings can be detailed, but floors should be low contrast and interactions readable. Use consistent angles, wall thickness and doorway scale. Keep passages comfortably wider than the character collision footprint.

| Reference | Match this | Implement independently |
|---|---|---|
| 01-academy | Warm map board, large lunar window, three mentor landmarks | Replace placeholder rectangles in the existing hub; keep mentors separate and add unobstructed routes. |
| 02-outpost | West power, east plants, north shelter, central circulation | Treat layout intent as authoritative; adjust paths and doorways to fit the camera and collision. |
| 03-power | Battery bank, teal readouts, amber switch panel | Battery/console visuals reflect actual ResourceSim state. |
| 04-greenhouse | Crop beds, clear aisle, grow lights | Make the reachable irrigation/control point stand out. Let lamps dim when a load is paused. |
| 05-shelter | Thick recognizable hatch, beacon, benches | Set an explicit sheltered zone and a clear confirmation prompt. |
| 06-exterior | Low sun, long shadows, modular base and solar panels | Use as backdrop or transition art; no outside traversal required. |
| 07-props | Equipment silhouettes and material language | Redraw or cut and clean props individually; this is not a ready-to-import tileset. |

Keep one or two strong landmarks per room. Draw gameplay markers and text in Godot. Keep floor/background, collision geometry, props with Y-sort as needed, and UI separate. Do not copy characters rendered in the concepts into the game; those are size/context examples. The PNGs are generated visual references and can differ slightly in camera angle and proportions. Design actual layout in Godot to support interaction. Credit the generated references and any derivative assets used.

Exterior concept note: keep food production inside a sealed habitat; omit the exposed planters shown in the reference.
