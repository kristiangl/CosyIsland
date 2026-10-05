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
  `--npcs[=id,id]` (`--angles=0,35`), `--close`, `--poses` (`--only=chop,sit,...`)),
  `model_gallery.tscn` (`--drops`, `--keys`, `--only=id,id`, `--series=id`, `--variant=id`), `effects_gallery.tscn`
  (`--night`, every particle effect), `calibrate.tscn`
  (`-- --shadows`, checks the cel lighting maths).
- Game screenshot options are listed at the top of `scripts/main.gd` (`--demo`,
  `--demo=decor|sit|home|door|shop|site|tailors|museum|dock|tour|orchard|neighbours|flowers|fishing|bugs` (`--house` builds the house first, `--series=id` furnishes
  the home from one series; `--built` turns the museum tent into the museum, `--visit`
  goes inside the museum or a neighbour's home),
  `--ui=pockets|pause|map|creator|crafting|customise|placing|intro|ask|lucy|sleep|asleep|shop|sell|tailors` (`--place=id` picks what to place),
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
- `Critters` (a child of the island `World`, `data/creatures.json`): fish shadows and bugs
  spawned near the player by time of day; fishing (`cast`/`reel`) and `net`.
- Animal kinds are `CharacterModel.SPECIES` (cat, dog, rabbit, ferret, mouse, bird): meshes in
  `AnimalParts`, face markings in `face.gdshader` by the same index.
- Neighbours (`data/neighbours.json`, read through `NpcData`): Poppy gives three plots at
  the start; a plot only becomes a house when someone invited on a tour moves in overnight
  (`Story.invited()`, `Story.move_in`; placed objects with a "resident"); their rooms are visitor
  `World`s (`visitor = true`: nothing can be moved). The museum's hall is a visitor room
  rebuilt from `Journal.donated` on every visit (`main.gd` `fill_museum`), never saved.
- Island tours: `main.gd` swaps to a tour `World` (`tour = true`, `Game.tour`; nothing
  can be placed) built from `IslandGenerator.generate_tour`, and frees it on the way home.
  `Game.island` stays the home island; `Game.outdoors()` is whichever one you're on (the
  map uses it). Marlow's dock is `World.add_dock` (`dock_spots` for where he stands).
- Building kits (`placeable.builds`, category "kit"): placed like furniture, stamped with
  `plot_day`, and turned into their building the next night by `Story.build_kit`.
- `Story` (autoload) holds conversation progress and every character's lines;
  `DialogueBox` shows them. Await its `finished`/`picked` signals, not coroutines.
- `assets/kaykit/`: KayKit models (CC0) converted by `tools/kaykit_import.gd` from the list
  in `tools/kaykit.json` (needs the unpacked KayKit folder: `-- --src=DIR`). They load as
  `Models.get_mesh("kaykit:<name>")`; island trees, fruit trees, bushes and rocks use them.
  Series pieces with "kaykit" (comfy, kitchen, festive) are KayKit models repainted per
  variant by colour family (`Palette`, the variant's "paint"); they and the KayKit
  decorations in `data/items.json` come from `tools/kaykit_catalogue.py`.
- Generated base bodies (`assets/characters/<kind>.res`, converted from rigged glTFs in
  `assets/characters/src/` by `tools/character_import.gd -- --name=<kind>`; Mixamo bone
  names, T-pose, facing +Z; prompts in `docs/CHARACTER_PROMPTS.md`) replace the procedural
  body where one exists (the human so far): `SkinnedBody` copies the pivots' rotations
  onto its bones each frame, `skinned_body.gdshader` paints clothes from each vertex's
  rest position (UV, UV2.x), and the face shader draws on its head (`rest_space`).
  `--procedural` brings back the old bodies; `tools/skinned_preview.tscn --file=x.glb`
  shows a source model as it came.
- Characters animate two ways: the hand-made walk and run in `character_model.gd`, and
  KayKit's Rig_Medium clips (`assets/kaykit/rig_medium.res`, the clips listed under
  "animations" in `tools/kaykit.json`) for idling, actions (`CharacterModel.ACTIONS`),
  sitting, lying and fishing. `RigPose` copies a clip's bone rotations onto our pivots.
  `tools/kaykit_preview.tscn` shows KayKit characters and clips (`--src=DIR`).
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
