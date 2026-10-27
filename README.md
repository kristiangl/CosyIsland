# Cosy Island

A cosy island life game about crafting and decorating, made with Godot 4.

![Island overview](docs/screenshots/overview.png)

| Meeting Poppy | Inside the tent | Island map |
| --- | --- | --- |
| ![](docs/screenshots/intro.png) | ![](docs/screenshots/home.png) | ![](docs/screenshots/map.png) |

| Decorating | Dusk | Riverside |
| --- | --- | --- |
| ![](docs/screenshots/furniture.png) | ![](docs/screenshots/dusk.png) | ![](docs/screenshots/river.png) |

| Meadow Cottage | Woodland Lodge | Driftwood |
| --- | --- | --- |
| ![](docs/screenshots/series_meadow.png) | ![](docs/screenshots/series_lodge.png) | ![](docs/screenshots/series_driftwood.png) |

| Comfy Home (KayKit) | Decorations (KayKit) |
| --- | --- |
| ![](docs/screenshots/series_comfy.png) | ![](docs/screenshots/decorations.png) |

| Mushroom Grove | Starlight (at night) |
| --- | --- |
| ![](docs/screenshots/series_mushroom.png) | ![](docs/screenshots/series_starlight.png) |

| Fishing | Lucy's shop | Island Journal |
| --- | --- | --- |
| ![](docs/screenshots/fishing.png) | ![](docs/screenshots/lucy_shop.png) | ![](docs/screenshots/journal.png) |

| Daisy & Morris Tailoring | A shop kit, staked out |
| --- | --- |
| ![](docs/screenshots/tailors.png) | ![](docs/screenshots/building_site.png) |

| Marlow's ferry | A tour island | Planted apple trees growing |
| --- | --- | --- |
| ![](docs/screenshots/dock.png) | ![](docs/screenshots/tour.png) | ![](docs/screenshots/orchard.png) |

| Neighbours | Visiting a neighbour | The museum |
| --- | --- | --- |
| ![](docs/screenshots/neighbours.png) | ![](docs/screenshots/neighbour_home.png) | ![](docs/screenshots/museum.png) |

| The museum building | Inside the museum |
| --- | --- |
| ![](docs/screenshots/museum_building.png) | ![](docs/screenshots/museum_hall.png) |

| Rabbits, ferrets, mice and birds |
| --- |
| ![](docs/screenshots/new_neighbours.png) |

| Character creator | Island Phone | DIY workbench |
| --- | --- | --- |
| ![](docs/screenshots/creator.png) | ![](docs/screenshots/phone.png) | ![](docs/screenshots/crafting.png) |

![Characters](docs/screenshots/characters.png)

![Poppy and Lucy](docs/screenshots/npcs.png)

## Playing

In a browser: **https://kristiangl.github.io/CosyIsland/** (rebuilt from this branch on
every push by `.github/workflows/web.yml`; saves are kept in that browser, and a file's
options can download a copy to carry on elsewhere). A computer with a keyboard or a
controller works best.

On a computer:

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open this folder in Godot and press Play, or run `godot --path .` from here.

Add `-- --new` to start a fresh island, or `-- --seed=123` for a specific one.

### Controls

| Action | Controller (Switch layout) | Keyboard |
| --- | --- | --- |
| Move | Left stick | WASD / arrows |
| Use tool, shake tree, talk, sit, go inside, place | A | E / Space |
| Run, cancel | B | Shift / Esc |
| Pick up (including furniture) | Y | F |
| Pockets | X | Tab / I |
| Switch tool | D-pad left/right | Z / C |
| Rotate while placing | R | R |
| Map | - | M |
| Island Phone (map, wardrobe, time travel, save) | + | Esc / P |
| Switch tabs in menus | L / R | Q / E |

On-screen hints follow whatever you last touched, keyboard or controller.

## What's in so far

- A random island from a seed: beach, cliffs, rivers with a bridge, ponds, ramps,
  a native fruit and flower. Coastlines, cliffs and riverbanks are rounded off.
- Pastel cel-shaded look with ink outlines and a day/night cycle.
- Character creator and wardrobe with icon tabs and pictures of every option: 14
  hairstyles, 16 hair colours, 8 eye styles, brows, noses, mouths, cheeks, 8 skin
  tones, 9 tops with 9 patterns, bottoms, shoes, hats, bows and glasses. Face
  features can be moved, spaced, sized and tilted, Mii-style, and some hats can be
  worn different ways (bows on either side or the back, caps backwards).
- Poppy (a long-haired cat who runs the Island Office) welcomes you and hands over
  your tent; Lucy (a Jack Russell who does odd jobs) explains the workbench. Both
  have things to say every day.
- A paved plaza with the office marquee and the DIY workbench.
- Lucy's shop: sell her anything with a price, and buy from a new stock each day,
  including clothes. Bring her wood, stone and clay and she hands you the kit for a real
  shop, with twice the stock and flower plants from other islands.
- Building kits: Lucy's shop, the tailors, the museum tent and neighbours' plots come
  as kits. Choose the spot (a see-through preview shows the building), stake it out
  and it goes up overnight; until then you can pick the site up and move it.
- Daisy & Morris Tailoring: a day after Lucy's shop opens, her friends the tailors (two
  British Shorthair cats) send their clothes shop ahead in a kit; twelve new things on the rails a day.
- 107 designed clothes (30 pieces in colourways, six themes: Cosy Knits, Rainy Day,
  Seaside, Garden and Work, Sleepy Time, Folk Festival). Wear them from your pockets and they stay in your
  wardrobe. The plan for scaling to thousands of items is in
  [docs/CATALOGUE.md](docs/CATALOGUE.md).
- Particle effects: campfires, candles, chimney smoke, wood chips, sparks, falling
  leaves, crafting confetti, eating crumbs and hearts, fireflies and glowing forest
  at night, drifting petals by day.
- Save up 10,000 acorns and Poppy builds you a house overnight where your tent was,
  with a bigger room inside.
- Go inside your tent and decorate it: furniture, seats and table tops work indoors,
  plus wallpaper and flooring. Sleep in a bed or sleeping bag until morning, noon,
  evening or midnight.
- Pick flowers (the plant blooms again the next day) to wear in your hair or stand in
  a vase, or dig the whole plant up with a shovel and replant it.
- Fishing and bug catching: 21 fish (sea, rivers, ponds) and 17 bugs that come and go
  by time of day. Cast near a fish's shadow and press when it bites; creep up on bugs
  with a net (running scares them off). Give Poppy five different ones and she hands you
  the kit for her friend Bramble's museum tent; the journal keeps a critter log.
  After 15 donations, bring him materials and the tent becomes a real museum, with a
  tank or case for every creature that fills as you donate.
- Island tours: Marlow, a seagull with a ferry, ties up at the beach on your second
  day. A tour ticket (1,000 acorns, or stamps from the journal) takes you to a little
  wild island, new every trip, with fruit and flowers that don't grow at home. Gather,
  dig up flowers, fish and catch bugs, then sail home. Sometimes a neighbour is camping
  there; invite them and they'll move into one of your plots. Your first ticket is free.
- Neighbours: Poppy gives you three plots on your first day (and sells more later).
  Stake them out, then find someone to live there on an island tour: one of sixteen
  animal neighbours (cats, dogs, rabbits, ferrets, mice and birds) is camping on each
  tour island, and if you invite them they move into a plot the next day. They wander near home by day, chat in their own way and
  sometimes give you furniture, and you can visit their furnished homes after six.
  Chat daily, give presents they like and do their favours to fill five hearts of
  friendship (the journal's Neighbours page shows who likes what).
- Chop wood with an axe, shake trees for fruit and branches (and the odd piece of
  furniture), break rocks with a pickaxe for stone, clay and iron (one rock a day gives
  acorns), and dig up flowers with a shovel to replant them.
- Plant fruit on open grass and it grows into a fruit tree over four nights. Fruit
  that isn't native to your island sells to Lucy for three times as much.
- DIY workbench with 61 recipes: tools and furniture. Message bottles wash up each day
  with new recipes.
- 302 pieces of furniture to place anywhere on the grid with a preview, rotate and pick
  back up. Five furniture series (Meadow Cottage, Driftwood, Woodland Lodge, Mushroom
  Grove, Starlight) in four colourways each, with printed cushions, quilts and shades.
  Mushroom Grove's toadstools and Starlight's moons and stars glow at night. The
  original wooden pieces come painted white, pink, mint or walnut too. Change a piece's
  (or a garment's) colourway at the workbench with a customisation kit from Lucy.
- Rugs (round, large and runners, in ten prints plus one per series) lie under your
  furniture, and curtains dress your home's windows. Sit on chairs and benches; put teapots, candles and plants on tables.
  Lanterns and campfires glow at night.
- An animated player with knees and elbows: a hand-made walk and run, and KayKit's
  animations for idling, chopping, digging, fishing, sitting, eating, crafting and cheering.
- Minimap and a full island map.
- Pockets with item icons, stacking and tools that wear out.
- Poppy's Island Journal (a phone app): milestones and five daily tasks earn stamps,
  spent on bigger pockets, recipe cards, customisation kits and surprises.
- Real-time clock. The Island Phone has the map, wardrobe, controls, saving and (for
  now) a time travel app. Autosave.

See [docs/DESIGN.md](docs/DESIGN.md) for the full plan.

## Credits

Trees, bushes and rocks are from the KayKit Forest Nature Pack; the Comfy Home, Cosy
Kitchen and Festive sets and many decorations from KayKit's Furniture, Restaurant,
Holiday, Halloween and Mixed Bag packs; neighbours' cottages, Lucy's market stall, the
well, the windmill and building sites from the Medieval Hexagon Pack; and the characters'
actions (chopping, digging, fishing, sitting, lying down, cheering...) from KayKit
Character Animations, both by Kay Lousberg ([www.kaylousberg.com](https://www.kaylousberg.com),
CC0). The fairground snack stands and gate, the mini golf holes and the skate ramp and rail
are from Kenney's Coaster Kit, Minigolf Kit and Mini Skate ([www.kenney.nl](https://www.kenney.nl),
CC0). Both are converted for the game by `tools/kaykit_import.gd`. Everything else is built
in code.
