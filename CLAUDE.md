# Cosy Island

Godot 4.7 game (GDScript, Compatibility renderer). Design and roadmap: `docs/DESIGN.md`.

## Getting Godot in a cloud session

Official download hosts are blocked by the network policy here, so `tools/setup_godot.sh`
tries the official binary first and falls back to building from source (about 50 minutes
on 4 cores). It installs to `/opt/godot/godot`.

## Commands

- Tests: `/opt/godot/godot --headless --path . res://tests/test_runner.tscn`
- Screenshot: `tools/screenshot.sh out.png [extra args]`, e.g.
  `tools/screenshot.sh shots/day.png --seed=7 --hour=10` or `--view=overview`
  (runs under xvfb with Mesa software GL; first run imports the project).
- Run the game with a window: `/opt/godot/godot --path .` (add `-- --new` for a new island).

## Layout

- `scripts/autoload/`: global singletons (Events bus, Game state, ItemDB, GameClock,
  Inventory, SaveGame). Registered in `project.godot`.
- `scripts/world/`: island generation (`island_generator.gd`, pure data), meshes
  (`terrain_builder.gd`, `grass_field.gd`), the live `world.gd` (objects, walkability,
  island rules), `day_night.gd`, `placement.gd`.
- `scripts/player/`, `scripts/ui/`, `scripts/art/` (procedural models and `MeshKit`).
- `shaders/`: every world shader includes `include/world.gdshaderinc` and runs vertices
  through `curve_world()`; lit ones include `include/toon_light.gdshaderinc`.
- `data/items.json`: item definitions. Fruit and flower items are generated in `ItemDB`.

## Conventions

- Scenes are built in code; `scenes/main.tscn` is just the root. Keep it that way unless
  an editor-made scene clearly helps.
- One tile = one world unit. Tile (x, z) spans x..x+1, z..z+1; north is -z.
- Island objects are plain dictionaries in `IslandData.objects` (saved as JSON). Visuals
  are rebuilt from them, so never keep state only on nodes.
- Colours in `Models`/`MeshKit` are sRGB and converted with `MeshKit.lin()`; vertex alpha
  is the wind sway weight.
- Controller first: every action must be reachable with a gamepad.
- Keep it cheap enough for Switch 1 and phones: few draw calls, no per-frame allocations
  in hot paths, Compatibility-renderer features only.
- Run the tests and take a screenshot to check visual changes before committing.
