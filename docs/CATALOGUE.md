# Catalogue plan: clothes and furniture

The finished game should have well over a thousand things to collect. This is the plan
for making that many without the art turning into a jumble or the data into a mess.

## The idea: bases, variants and series

Every item is a **base** (a shape: "Puffer Jacket", "Ladder-back Chair") in one of a few
**variants** (colourways or materials: "Mint", "Walnut"). Bases belong to a **series**
(furniture) or **theme** (clothes) that sets the palette, motifs and materials, so a room
or outfit made from one series looks like it belongs together, and mixing series still
works because every palette is drawn from the same pastel range.

Typical sizes:

| | Bases | Variants each | Items |
| --- | --- | --- | --- |
| Furniture | 160 | 3 to 6 | ~650 |
| Wallpaper, flooring, rugs | 70 | 3 | ~210 |
| Clothes | 150 | 4 to 8 | ~900 |
| Tools, materials, fish, bugs, misc | | | ~250 |
| **Total** | | | **~2000** |

## Data

Items are written as bases with variants, and the game expands them into one item each
at load (`ItemDB`). One file per theme or series keeps files small and diffs readable:

```
data/clothing/<theme>.json        clothes, one theme per file (data/clothing.json for now)
data/furniture/<series>.json      furniture, one series per file
```

A furniture series file has the series' variants (wood, trim, fabric colours and print,
an accent) and its pieces. Each piece names a `kind` (the builder in
`scripts/art/series_models.gd`) and `params` choosing parts, plus its placeable settings
(`seat`, `surface`, `bed`, `light`, `small`) and an optional DIY `recipe`, which makes
the first variant. Pieces become items `<piece>_<variant>`:

```json
{"id": "meadow_chair", "name": "Meadow Chair", "kind": "chair", "footprint": [1, 1],
 "price": 520, "recipe": {"wood": 5}, "params": {"back": "ladder", "legs": "turned",
 "cushion": true}, "seat": 0.48}
```

Fabric parts are a second mesh surface drawn with the cloth shader, so cushions, quilts
and lampshades share the clothes' prints. `tools/model_gallery.tscn --series=meadow
[--variant=sage]` shows a series; `--demo=home --house --series=lodge` furnishes a room
with one.

A base:

```json
{
	"id": "raincoat",
	"name": "Raincoat",
	"slot": "top",
	"style": "raincoat",
	"theme": "rainy_day",
	"price": 640,
	"sources": ["shop"],
	"tags": ["outdoor", "cute"],
	"variants": [
		{"id": "yellow", "name": "Sunny", "colors": ["yellow", "navy"]},
		{"id": "red", "name": "Postbox", "colors": ["red", "cream"], "pattern": "dots"}
	]
}
```

- `style` names the builder that makes the shape (a function in code). Many bases can
  share one builder with different parameters, which is how a small amount of code makes
  a lot of shapes.
- Colours come from the shared palette (`data/appearance.json` "colors"), so every
  variant stays on-palette. Prints come from the fabric pattern library.
- `sources`: where it comes from: `shop` (Lucy's daily stock), `diy` (a recipe),
  `gift` (trees, neighbours, visitors), `event` (seasonal), `tour` (island tours).
- `tags` feed future features: room scoring, neighbour tastes, catalogue filters.
- Item ids are `base_variant` (`raincoat_yellow`); names read "Raincoat (Sunny)".

Imported models (if we add packs later) slot into the same scheme: `style` becomes
`"glb:res://assets/models/…"` with recolour masks for the variant colours.

## Making the shapes

- **Part library.** Furniture builders are assembled from shared parts: legs (tapered,
  turned, log, hairpin, cabriole), backs (slat, ladder, spindle, round, upholstered),
  tops, cushions, trims, knobs, frames. A new chair is mostly a choice of parts.
- **Garment builders.** Clothes are built from body-hugging shells plus details: collars
  (round, shirt, sailor, hood), plackets and buttons, pockets, cuffs and hems, belts,
  bibs and straps, frills, quilting, knit ribbing.
- **Fabric prints** in the cloth shader: stripes, wide stripes, dots, checks, hearts,
  stars, flowers so far; planned gingham, tartan, waves, leaves, fruit, argyle, polka
  hearts, rainbow, cloud, paisley-like swirl (gingham, tartan, waves, leaves, argyle,
  cherries and clouds are in). Prints are shared by clothes, cushions,
  curtains and rugs.

## Budgets (Switch 1 and phones)

- Furniture: under 1,500 triangles a base. Clothes: under 800 a piece.
- One shared material per kind of thing; colour by vertex colour or a two-colour shader.
- Item icons: rendered at runtime for now; for 1000+ items, bake them into icon atlases
  at build time.

## Furniture series

Each series: palette, materials, signature motif, and the kinds of pieces it covers.

| Series | Feel | Palette and materials | Signature |
| --- | --- | --- | --- |
| Meadow Cottage | painted country | cream wood, sage, butter yellow, gingham | heart cut-outs |
| Driftwood | beachy, bleached | pale grey wood, rope, sea glass | knotted rope |
| Woodland Lodge | logs and plaid | honey logs, red-green plaid, wool | pinecones |
| Mushroom Grove | fairytale forest | caps in coral, cream spots, moss | glowing caps at night |
| Starlight | dreamy night sky | navy, lilac, gold | moons and stars, soft glow |
| Seaside | fishing village | white-blue stripes, nets, buoys | shells |
| Teacup Café | pastel bakery | mint, pink, cream, glazed tiles | cake stands, scallops |
| Lantern Garden | quiet stone garden | grey stone, dark wood, paper | paper lanterns, moss |
| Tinker's Workshop | handmade, practical | iron, oak, copper | gears and rivets |
| Toybox | children's room | primary pastels, felt | building blocks, plushies |
| Scholar | cosy library | walnut, green leather, brass | books, globes |
| Orchard | fruit-themed | per native fruit | apple chairs, pear lamps |
| Blossom, Summer Fair, Harvest, Frost | seasonal | season palettes | events and weather |

Kinds of piece across series: seating, tables, storage, beds, lighting, small decor
(table-top), wall-mounted, rugs, wallpaper, flooring, garden and outdoor, fences and
paths, kitchen, bath, plants, music, toys, hobby and crafting.

## Clothing themes

| Theme | Pieces |
| --- | --- |
| Everyday basics | tees, long tees, tanks, shirts, shorts, trousers, skirts (free in the creator) |
| Cosy Knits | jumpers with motifs, cardigans, turtlenecks, beanies, scarves, mittens |
| Rainy Day | raincoats, wellies, bucket hats, umbrellas (held) |
| Seaside | sailor tops, striped tees, swimsuits, sandals, sun hats |
| Garden and Work | dungarees, aprons, work shirts, gloves, straw hats |
| Woodland Ranger | flannel shirts, vests, cargo shorts, hiking boots, caps |
| Folk Festival | embroidered blouses, pinafores, flower crowns, waistcoats |
| Sleepy Time | pyjamas, nightcaps, slippers, sleep masks |
| Sporty | track jackets, joggers, trainers, headbands |
| Party | dresses, suits, bow ties, shiny shoes |
| Seasonal | puffer jackets, winter coats, fairy and pumpkin outfits, festive jumpers |
| Make-believe | wizard robes, chef whites, explorer, astronaut-ish, animal hoods |
| Accessories | bags, backpacks, bows, glasses, masks, earrings |

Slots: top, bottom, dress (top and bottom in one), shoes, hat, glasses, and later
bag/back and held items. Outerwear stays in the top slot (no layering), like Animal
Crossing, to keep characters cheap to draw.

## Where things come from

- **Lucy's shop:** a daily rotation of furniture, interior items and clothes (more racks
  as her shop grows: a stall, then a shop with a fitting room).
- **DIY recipes:** mostly furniture and some practical clothes, learned from bottles,
  neighbours and seasonal events.
- **Gifts:** trees, neighbours, visitors, the mail.
- **Seasonal events** and **island tours** for rarer series and themes.

## Rollout

1. Now: the variant data model, garment builders, about 20 clothing bases in four
   themes (Cosy Knits, Rainy Day, Seaside, Garden and Work), sold by Lucy.
2. Done: furniture series files and a part library; Meadow Cottage, Driftwood and
   Woodland Lodge (10 bases each, 4 variants).
3. Done: more prints in the cloth shader. Next: rugs and curtains share them, and the
   workbench can change a piece's variant.
4. Mushroom Grove and Starlight with glowing pieces (uses the particle and glow work).
5. Seasonal series alongside the seasons and weather milestone.
6. Icon atlas baking once the item count passes a few hundred.
