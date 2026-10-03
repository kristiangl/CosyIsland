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

| Character creator | Island Phone | DIY workbench |
| --- | --- | --- |
| ![](docs/screenshots/creator.png) | ![](docs/screenshots/phone.png) | ![](docs/screenshots/crafting.png) |

![Characters](docs/screenshots/characters.png)

![Poppy and Lucy](docs/screenshots/npcs.png)

## Playing

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
  including clothes.
- 66 designed clothes (20 pieces in colourways, four themes: Cosy Knits, Rainy Day,
  Seaside, Garden and Work). Wear them from your pockets and they stay in your
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
- Chop wood, shake trees for fruit and branches (and the odd piece of furniture), hit
  rocks for stone, clay and iron (one rock a day gives acorns).
- DIY workbench with 61 recipes: tools and furniture. Message bottles wash up each day
  with new recipes.
- 148 pieces of furniture to place anywhere on the grid with a preview, rotate and pick
  back up. Three furniture series (Meadow Cottage, Driftwood, Woodland Lodge), each 10
  pieces in four colourways with printed cushions, quilts and shades. Change a piece's
  (or a garment's) colourway at the workbench with a customisation kit from Lucy. Sit on chairs and benches; put teapots, candles and plants on tables.
  Lanterns and campfires glow at night.
- An animated player with knees and elbows: walking, running, chopping, sitting.
- Minimap and a full island map.
- Pockets with item icons, stacking and tools that wear out.
- Real-time clock. The Island Phone has the map, wardrobe, controls, saving and (for
  now) a time travel app. Autosave.

See [docs/DESIGN.md](docs/DESIGN.md) for the full plan.
