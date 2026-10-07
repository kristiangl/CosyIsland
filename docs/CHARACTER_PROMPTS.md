# Animal head prompts

Image prompts for ChatGPT, to make reference images for an image-to-3D service. The 3D
heads replace the procedural animal heads; bodies, clothes and animation stay
procedural.

## How the heads are used

- `tools/head_import.gd` converts a head into `assets/characters/heads/<kind>.res` and the
  game puts it on the head joint in place of the procedural head, for every animal of
  that kind. It's sized and placed from the tip of the muzzle and the head's width, so
  heads from different images line up.
- Faces stay blank in the model: eyes, mouths, noses and fur markings come from the
  face shader, so they keep working with the creator's adjustments and each
  neighbour's colours.
- The ears, muzzle or beak come with the model, so the procedural ones are dropped. Tails
  stay procedural.

```
/opt/godot/godot --headless --path . --script res://tools/head_import.gd -- --name=dog_upright --from-body
```

All the heads so far came from full-body models in T-pose (`--from-body` cuts the head
off at the throat, keeping ears clear of the arms they rest on); a head on its own works
too and gets more of the model's detail. The importer also fixes triangles wound the
wrong way round and smooths the normals. Every head is placed alike: its eye line (part
way up the middle of the head) where the face shader draws eyes, and the face beside the
muzzle or beak at the same depth, so muzzles and beaks stick out in front. A bird's beak
is painted its species' "beak" colour. Per-head settings live at the top of
`tools/head_import.gd`: `SIZES` (how big each head looks), `EYES` (how far up the eyes
go), `HANGING_EARS` (heads whose ears hang below the chin: the floppy dog and the lop
rabbit) and `SMOOTHING` (the mouse's surface came out crumpled).

## The heads (10)

| # | File name | Head | Who uses it |
| --- | --- | --- | --- |
| 1 | `cat` | Cat, pointed ears | Done; every cat (Cacticat is a cactus cat: `"cactus"`) |
| 2 | `cat_short` | Cat, round-faced shorthair | Not made yet: Daisy and Morris (`"short"`) wear `cat` |
| 3 | `dog` | Dog, floppy ears | Done; every dog but Pip and Sunny, Lucy and Bramble included |
| 4 | `dog_upright` | Dog, upright ears | Done; Pip and Sunny (`"head": "dog_upright"`) |
| 5 | `rabbit` | Rabbit, upright ears | Done; Clover |
| 6 | `rabbit_lop` | Rabbit, lop ears | Done; Hazel and Pudding (`"lop"`) |
| 7 | `ferret` | Ferret | Done; Sable, Pepper, Truffle |
| 8 | `mouse` | Mouse | Done; Crumb, Barley, Mochi |
| 9 | `bird` | Songbird | Done; Kiwi, Rosie, Wren |
| 10 | `bird_sea` | Seabird | Done; Marlow (`"head": "bird_sea"`) |

The file name picks who wears it: a character's `"head"` in their species data if set,
else their kind plus `_short` or `_lop` for those variants, else just their kind. Until a
variant's head exists, they wear their kind's. Model heads bring their own ears, muzzle
or beak, so the procedural ones (and long-haired cats' ruff) are left off.

## Tips

- Do them in one ChatGPT conversation, and attach the first head image when asking for
  the others, with "same size, style and angle as the attached image".
- In the 3D service, ask for a low-poly result if it offers one (a head needs 1,000 to
  3,000 triangles).

## Prompts

Each prompt stands on its own. Copy one code block at a time.

### 2. Cat, round-faced shorthair

```
A single cute chibi animal head for a cosy life-sim game, shown as a reference for 3D modelling: the head of a British Shorthair cat, like an Animal Crossing villager's, on its own with no body and no neck.

Shape: a large, very round, chubby-cheeked head, a little wider than it is tall, with a small, broad, softly rounded muzzle at the front. Two small, rounded cat ears set wide apart on the top corners of the head, each about a fifth of the head's height. The underside of the head is smooth and gently rounded where the neck would join.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no surface texture, no seams.

Face: completely blank apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no markings, no inner-ear detail.

View: three-quarter view from the front and slightly to one side, camera a little above, so the face, one side and both ears are visible. The head is centred with space around it.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 3. Dog, upright ears

```
A single cute chibi animal head for a cosy life-sim game, shown as a reference for 3D modelling: the head of a dog, like an Animal Crossing villager's, on its own with no body and no neck.

Shape: a large, slightly wide, rounded head with a short, rounded dog snout at the front, sticking out about a fifth of the head's depth. Two upright, pricked triangular ears with rounded tips, like a Shiba Inu's, each about a third of the head's height, set on the top corners of the head. The underside of the head is smooth and gently rounded where the neck would join.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no surface texture, no seams.

Face: completely blank apart from the snout shape. No eyes, no eyebrows, no nose, no mouth, no markings, no inner-ear detail.

View: three-quarter view from the front and slightly to one side, camera a little above, so the face, one side and both ears are visible. The head is centred with space around it.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 4. Dog, floppy ears

```
A single cute chibi animal head for a cosy life-sim game, shown as a reference for 3D modelling: the head of a dog, like an Animal Crossing villager's, on its own with no body and no neck.

Shape: a large, slightly wide, rounded head with a short, rounded dog snout at the front, sticking out about a fifth of the head's depth. Two soft, floppy ears like a beagle's or a spaniel's, attached high on the sides of the head and hanging down flat against it to about the level of the jaw, slightly flared at the bottom. The underside of the head is smooth and gently rounded where the neck would join.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no surface texture, no seams.

Face: completely blank apart from the snout shape. No eyes, no eyebrows, no nose, no mouth, no markings.

View: three-quarter view from the front and slightly to one side, camera a little above, so the face, one side and both ears are visible. The head is centred with space around it.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 5. Rabbit, upright ears

```
A single cute chibi animal head for a cosy life-sim game, shown as a reference for 3D modelling: the head of a rabbit, like an Animal Crossing villager's, on its own with no body and no neck.

Shape: a large, slightly wide, rounded head with a small, rounded, slightly puffy muzzle at the front. Two long upright rabbit ears on top of the head, each about as tall as the head itself, slim at the base, wider in the middle with rounded tips and a shallow scoop on the front, leaning slightly apart. The underside of the head is smooth and gently rounded where the neck would join.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no surface texture, no seams.

Face: completely blank apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no buck teeth, no markings, no inner-ear detail.

View: three-quarter view from the front and slightly to one side, camera a little above, so the face, one side and both ears are visible. The whole head, ears included, is centred with space around it.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 6. Rabbit, lop ears

```
A single cute chibi animal head for a cosy life-sim game, shown as a reference for 3D modelling: the head of a lop-eared rabbit, like an Animal Crossing villager's, on its own with no body and no neck.

Shape: a large, slightly wide, rounded head with a small, rounded, slightly puffy muzzle at the front. Two long, wide, soft ears that start on the top of the head and droop down the sides, hanging a little below the jaw, slightly flared and rounded at the ends, held a little away from the cheeks. The underside of the head is smooth and gently rounded where the neck would join.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no surface texture, no seams.

Face: completely blank apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no buck teeth, no markings.

View: three-quarter view from the front and slightly to one side, camera a little above, so the face, one side and both ears are visible. The head is centred with space around it.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 7. Ferret

```
A single cute chibi animal head for a cosy life-sim game, shown as a reference for 3D modelling: the head of a ferret, like an Animal Crossing villager's, on its own with no body and no neck.

Shape: a large, smooth head, a little narrower and longer front-to-back than a cat's, with a distinctly long, tapering, rounded muzzle that sticks out about a third of the head's depth, like a ferret's. Two small, round, half-circle ears set low on the sides of the top of the head, each about a sixth of the head's height. The underside of the head is smooth and gently rounded where the neck would join.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no surface texture, no seams.

Face: completely blank apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no mask markings.

View: three-quarter view from the front and slightly to one side, camera a little above, so the face, one side and both ears are visible. The head is centred with space around it.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 8. Mouse

```
A single cute chibi animal head for a cosy life-sim game, shown as a reference for 3D modelling: the head of a mouse, like an Animal Crossing villager's, on its own with no body and no neck.

Shape: a large, smooth, slightly egg-shaped head with a small, pointed but rounded muzzle at the front. Two very large, round, thin, dish-shaped ears on the top corners of the head, each about half the head's width, facing forward. The underside of the head is smooth and gently rounded where the neck would join.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no surface texture, no seams.

Face: completely blank apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no markings, no inner-ear detail.

View: three-quarter view from the front and slightly to one side, camera a little above, so the face, one side and both ears are visible. The head is centred with space around it.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 9. Songbird

```
A single cute chibi animal head for a cosy life-sim game, shown as a reference for 3D modelling: the head of a little songbird, like an Animal Crossing villager's, on its own with no body and no neck.

Shape: a large, round, smooth head with a small, short, cone-shaped beak in the middle of the face, closed, about a sixth of the head's width. A small tuft crest of three soft rounded feathers on top of the head. The underside of the head is smooth and gently rounded where the neck would join.

Surface: completely smooth and soft, like an unpainted matte vinyl toy; the crest feathers are a few large smooth shapes. Uniform light grey all over, beak included. No surface texture, no seams.

Face: completely blank apart from the beak. No eyes, no eyebrows, no nostrils, no markings.

View: three-quarter view from the front and slightly to one side, camera a little above, so the face, one side, the beak and the crest are visible. The head is centred with space around it.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 10. Seabird

```
A single cute chibi animal head for a cosy life-sim game, shown as a reference for 3D modelling: the head of a seagull, like an Animal Crossing villager's, on its own with no body and no neck.

Shape: a large, smooth, slightly oval head with a longer, gently hooked, closed beak in the middle of the face, about a third of the head's width long, flat-sided and rounded at the tip. No crest; the top of the head is smooth. The underside of the head is smooth and gently rounded where the neck would join.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over, beak included. No surface texture, no seams.

Face: completely blank apart from the beak. No eyes, no eyebrows, no nostrils, no markings.

View: three-quarter view from the front and slightly to one side, camera a little above, so the face, one side and the beak are visible. The head is centred with space around it.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```
