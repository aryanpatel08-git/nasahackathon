# Lunar Life — Gameplay, map and UI update

## Changelog

- Added a marked south transit hatch in the outpost and return travel through the academy's northeast hatch. Completed checks, certification and the simulation state carry across both directions. Travel is available during routine checks and from the debrief. The transit interlock keeps the crew inside during the radiation emergency.
- Expanded the academy from 480 × 270 to 768 × 432 and the outpost from 480 × 272 to 720 × 408. Kept the original 32-pixel astronaut and mentor sprites so the characters occupy less space relative to the rooms. Added a crew lounge, readable landmarks, interactive mission board and plant bench, floor panels, structural highlights and animated indicators. Outpost rooms remain connected by the original west/east/north layout.
- Added acceleration and braking, physics interpolation, a bounded follow camera and a distance-driven walking motion. Adjusted the foot collision and interaction reach for the larger layout. Diagonal movement uses Godot's normalized input vector.
- Added a dropdown pause menu with Resume, Help / Controls, Tasks and confirmation before quitting. It freezes player movement, training and mission clocks. Escape backs out of a menu page, or closes an active dialogue or station panel. Use the menu icon or P to pause over a panel.
- Added a task log with stage-based visibility and completion from existing game state and mission events. Removed permanent objective lists from the world view. Battery telemetry and urgent radiation guidance remain visible during the outpost mission.
- Preserved the existing training, radiation replay, shelter decisions, debrief, source notes and mission retry. The cache and NASA record were carried forward from the supplied source project.

## Files

| Status | Path | Change |
|---|---|---|
| Modified | `project.godot` | Autoload registration and physics interpolation |
| Modified | `scripts/academy/academy_hub.gd` | Larger hub, points of interest, progress tracking and hatch routing |
| Modified | `scripts/autoload/controls.gd` | Pause shortcut |
| Modified | `scripts/autoload/mission_director.gd` | Pause-aware shelter timers |
| Modified | `scripts/autoload/scene_router.gd` | Reports when a scene transition is active |
| Modified | `scripts/outpost/outpost.gd` | Expanded map, HUD, return travel and pause-aware alert delay |
| Modified | `scripts/player/player.gd` | Acceleration, braking, walking motion and interaction prompt |
| Modified | `scripts/ui/create_astronaut.gd` | Records profile creation for the task log |
| Modified | `tools/playtest_driver.gd` | Updated route and navigation, pause, task and quit checks |
| New | `scripts/autoload/pause_menu.gd` | Shared pause UI |
| New | `scripts/autoload/task_log.gd` | Stage-aware objective list |
| New | `scripts/world/habitat_camera.gd` | Shared bounded camera |
| New | `docs/DEVELOPMENT-BATCH.md` | Changelog and test guide |

Godot generates script UID metadata. The rendered playthrough also updates the reference captures in `tools/shots/`.

## How to test

1. Extract the archive, import `nasahackathon/project.godot` in Godot 4.7.2 and press F5.
2. Create an astronaut. Finish the briefing, then walk with WASD or arrows. Try diagonal movement, wall edges and walking around the lounge. Inspect the mission board and plant bench. Talk to the three mentors with E, Space or Enter. The Tasks page should reflect visits and conversations.
3. With Rivera's Power Console open, leave every load on and run Fast to see the failure state. Retry, disable rover charging, run Fast again and confirm that the certificate unlocks the exit.
4. Take the northeast hatch to the outpost. Choose a power policy in the west room, then return through the south hatch before completing the greenhouse check. Take the academy hatch back and verify that the power task stays complete.
5. Visit the east greenhouse and wait for the alert. Press Escape, check that movement and the storm clock stop, and use Down/Enter or the mouse to open Tasks. Check Help, return with Escape and resume. Try the menu icon over a station panel and verify that closing the menu restores focus.
6. Follow the amber route north, choose a shelter policy and read the debrief. Review Source Notes. Test both Retry and Return to the academy. For Quit Game, first cancel, then confirm that Quit to desktop closes the window.
7. To run the automated route from the project directory, use `godot --headless --path . res://tools/playtest.tscn -- speed=3`. Remove `--headless` for screenshot capture. Add `quit=1` to exercise confirmed quit at the end, or `rover=1 choice=0 late=5` for a more demanding power strategy.

## Remaining limitations

- The original front-facing astronaut sprite is animated with motion and mirroring. Directional walk frames are future art work.
- The upgraded rooms use the project's existing procedural drawing approach. A dedicated tile and prop art pass could bring them closer to the earlier concept references.
- Progress persists across room changes for the current session. Quitting ends that run.
- The alert still uses the supplied archived NASA record. The live feed, full Science Library and sound remain outside this batch.
- The automated route verifies state and movement over the main paths. An unaided first-time player session is still needed to assess onboarding and movement feel.

