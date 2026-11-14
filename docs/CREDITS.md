# Lunar Life: credits and data sources

## NASA data
- **Solar energetic particle (SEP) event** used for the radiation alert: NASA CCMC DONKI record
  `2024-05-10T13:35:00-SEP-001` (event time 2024-05-10T13:35Z, instrument GOES-P: SEISS >10 MeV).
  Record page: https://ccmc.gsfc.nasa.gov/DONKI/view/SEP/30677/-1
  Retrieved 2026-11-14 from `https://ccmc.gsfc.nasa.gov/DONKI-API/get/SEP?startDate=2024-05-01&endDate=2024-06-15`
  and stored unchanged in `data/nasa/donki_sep_cached.json` (provenance: ARCHIVED).
- The record is a detection near Earth. It is **not** a radiation dose at a lunar outpost.
  Exposure, battery, power and time in the game are simplified game units set in
  `data/nasa/sep_replay_config.json` and `scripts/autoload/resource_sim.gd`.
- The sunlight/shadow pattern is a fictional stand-in for south-polar terrain shadowing and is unrelated to the SEP event.
- There is no live API call in the game yet.

## Art
- Character sprites (player astronaut, commander, engineer, botanist): generated with SpriteCook
  (Pixel Engine model). Asset IDs are in `spritecook-assets.json`.
- Astronaut walk cycle (`assets/art/characters/player_walk_sheet.png`, 8 frames of 32 x 32): made by Kareem Dahrouj by
  rearranging pixels of the SpriteCook astronaut sprite. Played at 10 frames per second.
- Directional astronaut animations (`assets/art/characters/astronaut/`: idle, 8-frame walk in 4 directions, 3/4 turn frames): made by Kareem Dahrouj by
  redrawing the SpriteCook astronaut in side profile and back view. Played by `scripts/player/player.gd`.
- Rooms, props and UI are drawn in code by the game.
- `docs/handoff/.../references/*.png`: AI-generated concept images supplied by Jimmy as visual targets.
  They are not used as game assets and are excluded from the Godot project by `docs/.gdignore`.

## Tools
- Godot 4.7.2. Code written with Claude.

## To confirm with the team
- Which work done before the event start may be included in the submission.
