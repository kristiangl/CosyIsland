# Character base model prompts

Image prompts for ChatGPT, to make reference images for an image-to-3D service. The
3D models replace the procedural bodies in `scripts/character/`.

## How the models will be used

- **One bare base body per kind of character**, smooth like an unpainted vinyl toy.
  Faces stay blank: eyes, mouths, noses and markings keep coming from the face shader,
  so they can still be moved and changed in the creator.
- **Clothes are painted onto the body as textures**: tops on everyone, and shorts or
  trousers on the human's legs. Animals go without bottoms, as in Animal Crossing.
  Anything that sticks out from the body gets its own small mesh: skirts, dresses,
  hoods, hats, hair and glasses.
- **Fur colours and patterns are textures too**, so one cat model covers every cat
  neighbour.

## The models (12)

| # | Model | Who uses it |
| --- | --- | --- |
| 1 | Human, bald | The player |
| 2 | Cat, pointed ears | Most cat neighbours |
| 3 | Cat, long-haired | Poppy |
| 4 | Cat, round-faced shorthair | Daisy, Morris |
| 5 | Dog, upright ears | Dogs with pricked ears |
| 6 | Dog, floppy ears | Bramble, Lucy, droopy-eared dogs |
| 7 | Rabbit, upright ears | |
| 8 | Rabbit, lop ears | |
| 9 | Ferret | |
| 10 | Mouse | |
| 11 | Bird, songbird | Kiwi, Rosie |
| 12 | Bird, seabird | Marlow |

## Tips

- Make the human first. When you ask for each animal, attach the human image and keep
  "same size, proportions and pose as the attached image" in the prompt.
- Do them all in one ChatGPT conversation so the style stays put. If one drifts, ask
  for it again rather than fixing it with edits.
- If the 3D service takes several views, also ask ChatGPT for a straight front view and
  a straight back view of each one: "the same character, seen from directly in front"
  (or behind), with the rest of the prompt unchanged.
- In the 3D service, ask for a low-poly or quad-remeshed result if it offers one
  (around 5,000 to 10,000 triangles), in T-pose, ideally auto-rigged as a humanoid.

## Prompts

Each prompt stands on its own. Copy one code block at a time.

### 1. Human, bald

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. A small human child-like figure, bald, with no hair.

Proportions (keep these exact): total height is 2.4 head-heights. The head is a large, slightly wide, smooth sphere, about 42% of the total height and about 1.3 times as wide as the shoulders. There is no visible neck: the head sits right on the shoulders. The torso is short and soft, a rounded pear shape slightly wider at the hips, about 30% of the height. The legs are short, round and stubby, about 28% of the height, with a gap of one leg-width between them. The feet are small, rounded and point forward. The hands are rounded mittens with a small separate thumb and no fingers. Small simple rounded ears on the sides of the head.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth. No eyes, no eyebrows, no nose, no mouth, no blush, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front and one side of the body are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 2. Cat, pointed ears

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic cat standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights, not counting the ears. The head is a large, slightly wide, smooth rounded shape, about 42% of the total height and about 1.3 times as wide as the shoulders, with a small, softly rounded muzzle at the front. There is no visible neck: the head sits right on the shoulders. The torso is short and soft, a rounded pear shape slightly wider at the hips, about 30% of the height. The legs are short, round and stubby, about 28% of the height, with a gap of one leg-width between them. The feet are small rounded paws pointing forward. The hands are rounded mitten paws with a small separate thumb and no fingers.

Cat features: two upright, pointed triangular cat ears on top of the head, each about a third of the head's height. A long, thin tail that comes out low on the back, sticks out behind and curves up and to one side so it is clearly visible beside the body.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 3. Cat, long-haired

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic long-haired cat standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights, not counting the ears. The head is a large, slightly wide, smooth rounded shape, about 42% of the total height and about 1.3 times as wide as the shoulders, with a small, softly rounded muzzle at the front. There is no visible neck: the head sits right on the shoulders. The torso is short and soft, a rounded pear shape slightly wider at the hips, about 30% of the height. The legs are short, round and stubby, about 28% of the height, with a gap of one leg-width between them. The feet are small rounded paws pointing forward. The hands are rounded mitten paws with a small separate thumb and no fingers.

Long-haired cat features: two upright pointed cat ears with small soft tufts at the tips. Soft fluffy cheeks that flare out a little at the sides of the face, and a soft rounded ruff of fur around the chest under the chin, all shaped as a few large smooth clumps, not strands. A big, bushy, plume-like tail that comes out low on the back, sticks out behind and curves up and to one side so it is clearly visible beside the body.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 4. Cat, round-faced shorthair

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic British Shorthair cat standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights, not counting the ears. The head is a large, very round, chubby-cheeked shape, a little wider than the other characters', about 42% of the total height and about 1.4 times as wide as the shoulders, with a small, broad, softly rounded muzzle at the front. There is no visible neck: the head sits right on the shoulders. The torso is short, soft and a little stocky, a rounded pear shape slightly wider at the hips, about 30% of the height. The legs are short, round and stubby, about 28% of the height, with a gap of one leg-width between them. The feet are small rounded paws pointing forward. The hands are rounded mitten paws with a small separate thumb and no fingers.

Shorthair cat features: two small, rounded cat ears set wide apart on the top corners of the head, each about a fifth of the head's height. A thick, short-to-medium tail with a rounded tip that comes out low on the back, sticks out behind and curves to one side so it is clearly visible beside the body.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 5. Dog, upright ears

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic dog standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights, not counting the ears. The head is a large, slightly wide, smooth rounded shape, about 42% of the total height and about 1.3 times as wide as the shoulders, with a short, rounded dog snout at the front, sticking out about a fifth of the head's depth. There is no visible neck: the head sits right on the shoulders. The torso is short and soft, a rounded pear shape slightly wider at the hips, about 30% of the height. The legs are short, round and stubby, about 28% of the height, with a gap of one leg-width between them. The feet are small rounded paws pointing forward. The hands are rounded mitten paws with a small separate thumb and no fingers.

Dog features: two upright, pricked triangular ears with rounded tips, like a Shiba Inu's, each about a third of the head's height, set on the top corners of the head. A fluffy tail that comes out low on the back and curls up over itself into a loose ring, turned to one side so it is clearly visible beside the body.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the snout shape. No eyes, no eyebrows, no nose, no mouth, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 6. Dog, floppy ears

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic dog standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights. The head is a large, slightly wide, smooth rounded shape, about 42% of the total height and about 1.3 times as wide as the shoulders, with a short, rounded dog snout at the front, sticking out about a fifth of the head's depth. There is no visible neck: the head sits right on the shoulders. The torso is short and soft, a rounded pear shape slightly wider at the hips, about 30% of the height. The legs are short, round and stubby, about 28% of the height, with a gap of one leg-width between them. The feet are small rounded paws pointing forward. The hands are rounded mitten paws with a small separate thumb and no fingers.

Dog features: two soft, floppy ears like a beagle's or a spaniel's, attached high on the sides of the head and hanging down flat against it to about the level of the jaw, slightly flared at the bottom. A short, straight, tapering tail that comes out low on the back and points up and back at an angle, turned a little to one side so it is clearly visible beside the body.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the snout shape. No eyes, no eyebrows, no nose, no mouth, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body, the ears and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 7. Rabbit, upright ears

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic rabbit standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights, not counting the ears. The head is a large, slightly wide, smooth rounded shape, about 42% of the total height and about 1.3 times as wide as the shoulders, with a small, rounded, slightly puffy muzzle at the front. There is no visible neck: the head sits right on the shoulders. The torso is short and soft, a rounded pear shape slightly wider at the hips, about 30% of the height. The legs are short, round and stubby, about 28% of the height, with a gap of one leg-width between them. The feet are rounded rabbit feet, a little longer than the other characters', pointing forward. The hands are rounded mitten paws with a small separate thumb and no fingers.

Rabbit features: two long upright rabbit ears on top of the head, each about as tall as the head itself, slim at the base, wider in the middle with rounded tips and a shallow scoop on the front, leaning slightly apart. A small, round, fluffy pom-pom tail low on the back, sticking out enough to be visible from the side.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no buck teeth, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body and the tail are visible. The whole figure, ears included, is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 8. Rabbit, lop ears

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic lop-eared rabbit standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights. The head is a large, slightly wide, smooth rounded shape, about 42% of the total height and about 1.3 times as wide as the shoulders, with a small, rounded, slightly puffy muzzle at the front. There is no visible neck: the head sits right on the shoulders. The torso is short and soft, a rounded pear shape slightly wider at the hips, about 30% of the height. The legs are short, round and stubby, about 28% of the height, with a gap of one leg-width between them. The feet are rounded rabbit feet, a little longer than the other characters', pointing forward. The hands are rounded mitten paws with a small separate thumb and no fingers.

Lop rabbit features: two long, wide, soft ears that start on the top of the head and droop down the sides, hanging past the jaw to about shoulder level, slightly flared and rounded at the ends. A small, round, fluffy pom-pom tail low on the back, sticking out enough to be visible from the side.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart. The ears hang clear of the arms.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no buck teeth, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body, the ears and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 9. Ferret

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic ferret standing upright on two legs, like an Animal Crossing villager. Same overall size and pose as the attached image, but noticeably slimmer and longer, as described below.

Proportions (keep these exact): total height is 2.5 head-heights. The head is a large, smooth shape, about 40% of the total height, a little narrower and longer front-to-back than the other characters', about 1.15 times as wide as the shoulders, with a distinctly long, tapering, rounded muzzle that sticks out about a third of the head's depth, like a ferret's. A short, slender neck is visible between the head and the shoulders. The torso is long, slim and tube-like, about 34% of the height, only slightly wider at the hips. The legs are short and stubby, about 24% of the height, with a gap of one leg-width between them. The feet are small rounded paws pointing forward. The hands are rounded mitten paws with a small separate thumb and no fingers.

Ferret features: two small, round, half-circle ears set low on the sides of the top of the head, each about a sixth of the head's height. A long, thick, furry tail about as long as the body is tall, coming out low on the back, sticking out behind and curving to one side so it is clearly visible beside the body.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no mask markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 10. Mouse

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic mouse standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights, not counting the ears. The head is a large, smooth, slightly egg-shaped head, about 42% of the total height and about 1.3 times as wide as the shoulders, with a small, pointed but rounded muzzle at the front. There is no visible neck: the head sits right on the shoulders. The torso is short and soft, a rounded pear shape slightly wider at the hips, about 30% of the height. The legs are short, round and stubby, about 28% of the height, with a gap of one leg-width between them. The feet are small rounded paws pointing forward. The hands are rounded mitten paws with a small separate thumb and no fingers.

Mouse features: two very large, round, thin, dish-shaped ears on the top corners of the head, each about half the head's width, facing forward. A long, thin, smooth tail, about one and a half times the body's height, coming out low on the back and curving out to one side in a gentle S so it is clearly visible beside the body.

Pose: a strict, symmetrical T-pose. Standing straight, arms held straight out to the sides at shoulder height, palms facing down, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy. Uniform light grey all over. No fur strands, no clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the muzzle shape. No eyes, no eyebrows, no nose, no mouth, no whiskers, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body, the ears and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 11. Bird, songbird

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic little songbird standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights, not counting the crest. The head is a large, round, smooth shape, about 42% of the total height and about 1.3 times as wide as the shoulders. There is no visible neck: the head sits right on the shoulders. The torso is short, soft and round-bellied, slightly wider at the hips, about 30% of the height. The legs are short and stubby, about 28% of the height, with a gap of one leg-width between them, ending in small rounded bird feet with three short, thick, rounded toes pointing forward.

Bird features: a small, short, cone-shaped beak in the middle of the face, closed, about a sixth of the head's width. A small tuft crest of three soft rounded feathers on top of the head. The arms are wings: the same length and thickness as the other characters' arms, but each ends in a soft fan of four or five broad, rounded feather tips instead of a hand, with a small thumb-like feather that can grip things, and a short row of rounded feathers along the underside of the arm. A short, fanned tail of five rounded feathers low on the back, angled to one side so it is clearly visible beside the body.

Pose: a strict, symmetrical T-pose. Standing straight, wing-arms held straight out to the sides at shoulder height, feather tips spread flat, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy; feathers are a few large smooth shapes, not detailed. Uniform light grey all over, beak included. No clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the beak. No eyes, no eyebrows, no nostrils, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body, a wing and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```

### 12. Bird, seabird

```
A single cute chibi character for a cosy life-sim game, shown as a reference for 3D modelling. An anthropomorphic seagull standing upright on two legs, like an Animal Crossing villager. Same size, proportions and pose as the attached image.

Proportions (keep these exact): total height is 2.4 head-heights. The head is a large, smooth, slightly oval shape, about 42% of the total height and about 1.3 times as wide as the shoulders. There is no visible neck: the head sits right on the shoulders. The torso is short, soft and round-bellied, slightly wider at the hips, about 30% of the height. The legs are short and stubby, about 28% of the height, with a gap of one leg-width between them, ending in small, flat, webbed feet pointing forward.

Seabird features: a longer, gently hooked, closed beak in the middle of the face, about a third of the head's width long, flat-sided and rounded at the tip. No crest; the top of the head is smooth. The arms are wings: the same length and thickness as the other characters' arms, but each ends in a soft fan of four or five long, rounded feather tips instead of a hand, with a small thumb-like feather that can grip things, and a row of rounded feathers along the underside of the arm. A short, pointed tail of a few rounded feathers low on the back, angled to one side so it is clearly visible beside the body.

Pose: a strict, symmetrical T-pose. Standing straight, wing-arms held straight out to the sides at shoulder height, feather tips spread flat, legs straight with feet slightly apart.

Surface: completely smooth and soft, like an unpainted matte vinyl toy; feathers are a few large smooth shapes, not detailed. Uniform light grey all over, beak included. No clothing, no anatomical detail, no seams, no surface texture.

Face: completely blank and smooth apart from the beak. No eyes, no eyebrows, no nostrils, no markings.

View: isometric three-quarter view from the front and slightly to one side, camera about 30 degrees above, so the front, one side of the body, a wing and the tail are visible. The whole figure is in frame with space around it, centred.

Background: plain flat white. No ground, no shadow, no props, no text. Soft even lighting. Square image.
```
