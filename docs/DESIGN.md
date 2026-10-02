# Cosy Island: design notes

Working title. An island life game in the Animal Crossing mould, built around crafting and
decorating instead of farming.

## Pillars

1. **Decorating first.** Hundreds of furniture and outdoor items, a grid you can place them
   on freely, and tools that let you reshape the island itself (paths, cliffs, rivers,
   moving rocks).
2. **Slow, real-time progression.** The island runs on the real clock. Things unlock over
   days, not minutes. Time travel is built in and never punished.
3. **A place that feels alive.** Animal neighbours, daily visitors, weather, seasons,
   fishing and bug catching, a museum.
4. **Painterly and cosy.** Soft, hand-painted Ghibli feel: warm light, cool shadows,
   puffy trees, wind in the grass.

## Platforms

PC first (Windows/macOS/Linux), then Nintendo Switch 1, iOS and Android.

- Engine: Godot 4 with the **Compatibility** renderer (OpenGL ES 3 / WebGL 2 class
  hardware). It runs on Switch 1 and low-end phones, and keeps one look everywhere.
- Controller is the primary input, laid out like the Switch (A use, B run/back,
  Y pick up, X pockets, + menu). Keyboard works too. Touch comes with the mobile ports.
- Switch release will need Nintendo developer approval and a console porting service for
  Godot (for example W4 Games). Nothing in the code should depend on desktop-only APIs.

## Art direction

Everything is made in code: models are built from simple shapes (`scripts/art/models.gd`)
and coloured with vertex colours, and the look comes from shaders:

- Soft two-band toon lighting with cool, sky-tinted shadows and a warm rim.
- Painted noise patches on grass, sand strata on cliffs, foam bands on the shore.
- A "rolling log" world curve so the horizon bends away like Animal Crossing.
- Day/night colour grading keyed to the clock (dawn pinks, golden hour, blue nights).

Detailed textures (fabric, wood grain, wallpapers) may come later from free sources or
ChatGPT-generated images. Keep everything working with plain vertex colours first.

Fixed camera, angled down over the player, looking north.

## The island

- 96 x 80 tiles. One tile = one world unit = one grid cell for placement.
- Generated from a seed: rounded coastline, beach ring, two or three cliff tiers (higher
  to the north), a river (sometimes forked) with a starter bridge, one or two ponds, ramps
  up each plateau, a plaza near the middle, forests, six rocks, native flowers, palms on
  the beach.
- Each island gets one **native fruit** (apple, orange, pear, cherry, peach, plum) and one
  **native flower** species. Other fruit and flowers come from visiting other islands.
- Only one kind of wood.

## Progression (planned)

Stages unlock with real days and with milestones (things crafted, neighbours moved in,
items donated). Rough order:

1. **Tent.** Flimsy tools, basic DIY workbench recipes, wood/stone/clay/iron gathering.
2. **First visitors.** Daily visiting NPCs start appearing. Island tickets to visit random
   islands for new fruit, flowers and neighbours.
3. **House.** Tent upgrades to a small house; interior decorating unlocks. Stronger tools.
4. **Shop and museum.** Fishing rod and net, bug and fish collections, museum donations.
5. **Bigger house.** More rooms, more storage. Outdoor furniture recipes multiply.
6. **Island makeover.** Path tool, then terraforming (cliffs), waterscaping (rivers and
   ponds), and the rock-moving tool. Bridges and ramps become buildable anywhere.

Time travel: the pause menu ("Island Phone") moves the clock forwards or back by hours or
days. Daily resets (wood, rocks, fruit regrowth) happen at 5am island time.

## Systems roadmap

Milestone 1 (this branch):
- [x] Seeded island generation with tiers, river, bridge, ponds, ramps
- [x] Terrain, sea, river and grass rendering with stylised shaders
- [x] Player movement, fixed follow camera
- [x] Axe on trees for wood (3 per tree per day), shaking trees for fruit and branches
- [x] Hitting rocks for stone/clay/iron/gold, and the daily money rock
- [x] Pockets, picking up, dropping, tools with durability
- [x] Grid placement with ghost preview; pitching the tent
- [x] Real-time clock, day/night lighting, time travel menu
- [x] Save and load

Next milestones (suggested order):
2. DIY workbench and recipes; first furniture set; item icons rendered from the models.
3. Tent interior and indoor decorating grid; house upgrade path.
4. Daily visitors and the first animal neighbours (dialogue, homes, schedules).
5. Fishing, bug catching, the museum.
6. Island tours to random islands (reusing the generator with different seeds).
7. Path tool, terraforming, waterscaping, rock moving.
8. Weather and seasons; audio.
9. Platform work: touch controls, performance passes, Switch porting.

## Naming

Currency is "Acorns" (placeholder). Everything else in-game should have original names.
Animal species can match Animal Crossing's (cats, dogs, rabbits, bears...) but every
character and their name is original.
