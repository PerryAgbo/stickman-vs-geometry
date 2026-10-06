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

## Phone build

    ./build_apk.sh            # writes ../build/StickmanVsGeometry.apk

Release-signed with `~/.android/stickman-release.keystore` (alias `stickman`). Keep that file: an installed
copy only updates when the new APK carries the same signature. If it is missing the script falls back to a
debug-signed build. Godot's editor settings must point at the Android SDK and Android Studio's JDK (done on this Mac).
It is a self-signed sideload key; make a fresh one before any store release.

Install: copy the APK to the phone and open it (allow "install unknown apps"), or `adb install -r build/StickmanVsGeometry.apk`.

- `juice.gd` — game feel and phone glue: haptics, hit sparks, shards, flash, slow motion, banners, save file, back button
- `save.gd` — progress and settings in `user://svg.cfg`
- `fx.gd` — sparks, shards, dust, rings, floating text, dash ghosts, the thrown φ
- `hud.gd` — HUD, chapter screen, pause and result menus, thumb-stick and buttons (safe-area aware)
- Headless checks: `SVG_SIM="200:pause" SVG_SHOT2=/tmp/p.png@230 Godot --path .` (actions: pause back hurt kill win lose combo:n hp:n tap:x:y press:a release:a shot:path quit)
