# Astronaut animations

All sprites are 32x32 pixel art with the feet at the bottom centre. The PNGs are in `assets/astronaut/`.
The player scene is `player/player.tscn` (script: `player/player.gd`).
`scenes/astronaut_demo.tscn` is a test scene. Open it and press F6.

| Key | Animation |
|-----|-----------|
| none | `idle_front` |
| S | `walk_front` (toward the camera) |
| W | `turn_away` (front, 3/4, side, then 3/4 back), then `walk_back` |
| D | `turn_right` (3/4 view), then `walk_right` |
| A | `turn_left` (3/4 view), then `walk_left` |

Releasing a key plays the turn backwards, then `idle_front`.

To use it in an existing player: add an `AnimatedSprite2D` child, put `player.gd` on the `CharacterBody2D`, and
turn off `allow_vertical` for a side-scroller. The script builds its own SpriteFrames, so nothing needs setting up
in the editor. Keep **Texture Filter = Nearest** so the pixels stay sharp (the script sets this on the sprite itself).
