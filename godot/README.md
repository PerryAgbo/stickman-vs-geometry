# Stickman vs Geometry — Godot rebuild

Open this folder in Godot 4.7 (Project > Import > `project.godot`) and press Play.

- `main.gd` — menu, level building, game flow
- `hero.gd` — player controller (run, jump, double jump, flight, dash-strike, sword combo)
- `skin.gd` — skeletal animation using the Blender-rendered body parts
- `foe.gd` — enemies (tri, dia, rival swordsman, hex champion)
- `hud.gd` — HUD, menus, phone thumb-stick and buttons
- `fx.gd` — sparks and the thrown φ
- `art/` — rendered in Blender by the scripts in `../art/`

Automated checks (no window):

    Godot --headless --path . --fixed-fps 60 --quit-after 9000   # with SVG_BOT=1 SVG_LEVEL=arena|line

Two chapters are playable so far: The Line and The Arena.
