# Cosy Island

Godot 4.7 game (GDScript, Compatibility renderer). Design and roadmap: `docs/DESIGN.md`.

## Getting Godot in a cloud session

`tools/setup_godot.sh` installs Godot to `/opt/godot/godot`: the official binary when
the network allows it, otherwise a build from source (about 30 minutes on 4 cores).

## Commands

- Tests: `/opt/godot/godot --headless --path . res://tests/test_runner.tscn`
- Screenshot: `tools/screenshot.sh out.png [extra args]`, e.g.
  `tools/screenshot.sh shots/day.png --seed=7 --hour=10` or `--view=overview`
  (runs under xvfb with Mesa software GL; first run imports the project).
- Run the game with a window: `/opt/godot/godot --path .` (add `-- --new` for a new island).
- Check every script parses: `tools/check_scripts.sh` (run this first; GDScript treats
  inferred-Variant types as errors, so type loop variables over literal arrays).
- Art check scenes (render with `tools/screenshot_scene.sh out.png res://tools/<scene>`):
  `character_lineup.tscn` (`--seed`, `--angle`, `--vary=KEY`, `--base=k:v`, `--poses`,
  `--npcs`, `--close`),
  `model_gallery.tscn` (`--drops`, `--keys`, `--only=id,id`, `--series=id`, `--variant=id`), `effects_gallery.tscn`
  (`--night`, every particle effect), `calibrate.tscn`
  (`-- --shadows`, checks the cel lighting maths).
- Game screenshot options are listed at the top of `scripts/main.gd` (`--demo`,
  `--demo=decor|sit|home|door` (`--house` builds the house first, `--series=id` furnishes
  the home from one series),
  `--ui=pockets|pause|map|creator|crafting|customise|placing|intro|ask|lucy|sleep|shop|sell`,
  `--tab=N` and `--try=key:id` for the creator, `--room=wallpaper,flooring`, `--gen=N`,
  `--at=X,Z`, `--hour`).

## Layout

- `scripts/autoload/`: global singletons (Events bus, Game state, ItemDB, GameClock,
  Inventory, SaveGame). Registered in `project.godot`.
- `scripts/world/`: island generation (`island_generator.gd`, pure data), meshes
  (`terrain_builder.gd`, `grass_field.gd`), the live `world.gd` (objects, walkability,
  island rules), `day_night.gd`, `placement.gd`.
- `scripts/player/`, `scripts/ui/`, `scripts/art/` (procedural models, `MeshKit`,
  `FurnitureModels`, `SeriesModels` for furniture series), `scripts/character/` (appearance, parts, animal parts, the
  character model), `scripts/npc/` (island characters).
- Rooms inside homes are a second `World` with `interior = true` on a small
  `IslandData.room()`; `main.gd` swaps between the island and the room.
- `Journal` (autoload, `data/journal.json`) counts what the player does (`Journal.add(stat)`)
  and pays stamps for milestones and daily tasks; its exchange sells pocket upgrades etc.
- `Story` (autoload) holds conversation progress and every character's lines;
  `DialogueBox` shows them. Await its `finished`/`picked` signals, not coroutines.
- Island generation is versioned (`IslandGenerator.VERSION`, saved as "gen"): bump it
  for changes that would reshape existing islands, and keep the old behaviour behind it.
- Worker-thread tasks must always be collected (`IslandMap.finish()`), or Godot
  crashes on quit.
- `shaders/`: every world shader includes `include/world.gdshaderinc` and runs vertices
  through `curve_world()`; lit ones include `include/toon_light.gdshaderinc`.
- `data/items.json`: item definitions. Fruit and flower items are generated in `ItemDB`,
  and so are clothes, from bases with colourways in `data/clothing.json` (plan:
  `docs/CATALOGUE.md`), and furniture series from `data/furniture/<series>.json`
  (models with fabric have a second surface: show them with `Models.dress`). Rugs
  (`placeable.rug`) sit on their own floor layer in `World`, under furniture. Parts that
  glow at night go in a series model's glow surface (`night_glow` global). Effects: `Effects.burst(kind, pos)` / `Effects.emitter(kind)`.
  `data/recipes.json`: DIY recipes. `data/appearance.json`: character options.

## Conventions

- Scenes are built in code; `scenes/main.tscn` is just the root. Keep it that way unless
  an editor-made scene clearly helps.
- One tile = one world unit. Tile (x, z) spans x..x+1, z..z+1; north is -z.
- Island objects are plain dictionaries in `IslandData.objects` (saved as JSON). Visuals
  are rebuilt from them, so never keep state only on nodes.
- Colours are sRGB everywhere (vertex colours and `source_color` uniforms): the
  Compatibility renderer treats ALBEDO as sRGB. Vertex alpha on props is wind sway.
- Lit shaders end with `EMISSION = cel_ambient(ALBEDO);` and include
  `toon_light.gdshaderinc`. The sun must cast shadows (the maths relies on it).
- Things shown outside the island (icons, menus) set the material's `curved` to false.
- Controller first: every action must be reachable with a gamepad.
- Keep it cheap enough for Switch 1 and phones: few draw calls, no per-frame allocations
  in hot paths, Compatibility-renderer features only.
- Run the tests and take a screenshot to check visual changes before committing.
