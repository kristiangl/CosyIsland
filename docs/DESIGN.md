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

Pastel and cel-shaded with ink lines (reference: Organized Inside), with Animal Crossing
proportions and camera.

Everything is made in code: models are built from simple shapes (`scripts/art/`) and
coloured with vertex colours or material colours, and the look comes from shaders:

- Cel lighting with one crisp step. Two global tints set by the time of day decide the
  lit and shadow colours exactly (`shaders/include/toon_light.gdshaderinc`), so palette
  colours show as designed and shadows are soft lavender.
- A full-screen outline pass from the depth buffer draws silhouettes and creases.
- Gentle noise in grass and sand, strata on cliffs, foam on the waterline.
- A "rolling log" world curve so the horizon bends away like Animal Crossing.

Characters are modular chibi models (`scripts/character/`): parts on pivots, faces
drawn in a shader, fabrics with procedural patterns. Free character packs were checked
(Quaternius Universal Base Characters and outfits, CC0) but are realistic-proportioned
with fantasy outfits, so the chibi system is our own.

Detailed textures (fabric prints, wood grain, wallpapers) may come later from free
sources or ChatGPT-generated images.

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

### The progression spine

- **Poppy's Island Journal** (`data/journal.json`, the `Journal` autoload): lifetime
  milestones in tiers (wood chopped, things made, flowers planted...) and five daily
  tasks, all paying **stamps**. Some milestone tiers teach recipes (the stone axe after
  50 wood, the sturdy shovel after 50 rock finds). Systems report with `Journal.add()`.
- **The stamp exchange** (the journal's third page): bigger pockets (20, 30, 40),
  recipe cards, customisation kits, surprise furniture and clothes.
- **Projects**: things the islanders build when you bring materials. Lucy's shop first
  (30 wood, 20 stone, 10 clay, delivered bit by bit, built overnight): twice the stock,
  plus flower plants from other islands. Then the museum and neighbours' plots.
- Acorns are for buying and building; stamps reward playing and buy conveniences.

Time travel: sleeping in a bed moves the clock on to morning, noon, evening or midnight.
For testing, the Island Phone's time travel app moves it forwards or back by hours or days. Daily resets (wood, rocks, fruit regrowth) happen at 5am island time.

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

Milestone 2:
- [x] Pastel cel shading, ink outlines, rounded UI font (Fredoka, OFL)
- [x] Rounded coastlines, cliff corners and riverbanks
- [x] Modular characters, character creator and wardrobe
- [x] DIY workbench, 27 recipes, 23 furniture pieces, daily message bottles
- [x] Item icons rendered from the 3D models
- [x] Picking furniture back up; lanterns that glow at night

Milestone 3:
- [x] Rigged, animated player (hips, waist, knees, elbows; idle, walk, run, sit, actions)
- [x] Sitting on seats, small things on table tops, placement preview
- [x] Keyboard/controller prompt detection
- [x] Layered trees, textured grass, water ripples, bank foam, stone cliffs
- [x] Minimap and full map
- [x] Tent interior with floor, walls and indoor decorating; rooms saved per home
- [x] Paved plaza with the Island Office; Poppy and Lucy with dialogue and an intro

Milestone 3b:
- [x] Rivers no longer run along beaches (generator version 2; old islands keep theirs)
- [x] Character creator with tabs, option pictures, Mii-style face adjustments, noses,
      hat positions
- [x] Island Phone with apps; sleeping in beds moves time on
- [x] Wallpaper and flooring items

- [x] Lucy's shop: selling for acorns, a daily stock of furniture and wallpaper
- [x] Tent to house through Poppy (10,000 acorns, built overnight, 8x7 room)

- [x] Particle effects (fire, smoke, chips, sparks, leaves, confetti, fireflies, glow)
- [x] Pockets at the top; eating and crafting animations
- [x] Catalogue plan (docs/CATALOGUE.md); designed clothes as items with a wardrobe
- [x] Seven more fabric prints; furniture series Meadow Cottage, Driftwood and Woodland
  Lodge (120 items from a shared part library, sold by Lucy, 19 new recipes)
- [x] Customising at the workbench: any colourway of a piece or garment, one kit each
- [x] Rugs on a floor layer under furniture; windows in every room, and curtains
- [x] Mushroom Grove and Starlight series, with parts that glow at night
- [x] Sleepy Time and Folk Festival clothes (pyjamas, nightgown, nightcap, bunny
  slippers; folk blouse, waistcoat, folk skirt, clogs, festival crown)
- [x] Painted colourways for the original wooden furniture
- [x] Island Journal: milestones and daily tasks earning stamps; stamp exchange with
  pocket upgrades
- [x] Lucy's shop project: bring materials and she builds a real shop beside the plaza
- [x] Fishing and bug catching (data/creatures.json): fish shadows by water type, bites
  to time, bugs by habitat and hour that flee from runners
- [x] The museum: five specimens for Poppy bring Bramble and his museum tent; donations,
  a critter log in the journal
- [x] The museum building: after 15 donations Bramble asks for wood, stone and iron, and
  the tent becomes a stone museum overnight; inside, a tank for every fish round the walls
  and a case for every bug, filled as they're donated
- [x] Neighbours (data/neighbours.json): plots from Poppy, move-ins overnight, houses in
  their colours, wandering by day, personality chat and gifts, furnished homes to visit
- [x] KayKit furniture: Comfy Home, Cosy Kitchen and Festive series in four colourways
  each, and 40 decorations (wood stove, guitars, plushies, pumpkins, snowman, crates of
  veg, kitchen bits, a festive fir...)
- [x] Daisy & Morris Tailoring: a day after Lucy's shop opens she says her tailor friends
  are coming, and their shop goes up overnight; twelve new clothes on the rails each day
- [x] KayKit buildings: neighbours live in timbered cottages painted in their own roof
  and wall colours, Lucy's shop is a market stall, and a well and windmill can be placed
  (the player's house stays our own, to be customised)
- [x] Lie down in bed to sleep
- [x] KayKit nature: cube-cluster trees and pines, boulders, and bushes along the edges
  of the woods (island generation version 3), recoloured to the island palette
- [x] More species: rabbits (upright or lop ears), ferrets, mice and birds alongside the
  cats and dogs, sixteen neighbours in all
- [x] Friendship: daily chats, presents (each personality loves some kinds of thing) and
  favours fill five hearts; closer friends chat warmly and give presents more often
- [x] Flowers: picked blooms regrow overnight, worn in hair or put in vases; plants dug
  up with a shovel and replanted (breeding later)
- [x] Building kits: Lucy's shop, the tailors, the museum tent and neighbour plots are
  placed by the player from kits (`placeable.builds`), previewed as the building, asked
  about first, shown as a KayKit building site and built overnight; a staked kit can be
  picked up and moved until then, and a lost kit is replaced by whoever gave it
- [x] Island tours: Marlow's ferry dock (placed on the beach, north shore first) and
  tour tickets; tour islands are small generated islands (`IslandGenerator.generate_tour`)
  with other natives, never saved; a neighbour sometimes camps there and can be invited
  to move into the next plot
- [x] Fruit planting: plant a fruit on open grass at home and it grows into a fruit
  tree over `World.GROW_DAYS` nights (saplings scale up); fruit from other islands sells
  for three times as much
- [x] Neighbours only come from tours: Poppy hands out three plots on the first day (more
  for sale later), plots stay empty until someone you invited on a tour moves in, and a
  neighbour camps on every tour island; Marlow gives the first ticket free
- [x] Tools with one job each: axe for trees, pickaxe for rocks, shovel for flowers
- [x] Generated heads: animals keep the procedural body (clothes and animation work
  best there) and wear a generated head; nine are in, the shorthair cat to follow
- [x] Asking first: materials for building projects, Poppy's specimens, donations to
  the museum (all at once or one at a time) and favours ask "Give them X?" first
- [x] Rare tour islands (`data/tour_islands.json`, `TourKinds`): after the first trip,
  about one tour in three lands somewhere special: an orchard of every fruit, a flower
  meadow with rare colours (pink, orange, purple, blue; never sold), a rocky island with
  iron and gold, and bug and fishing islands with creatures found nowhere else
- [x] Vaulting pole: hop over rivers and ponds (made at the workbench, never wears out);
  tour islands always have a way across their rivers, and a sandy border round the
  screen while you're on one
- [x] SOS on the phone: fetches you back to open ground by the plaza (by Marlow's boat on
  a tour, the doormat indoors) if you ever get stuck
- [x] Title screen: a splash, then Continue and three save files (play, or start over and
  delete under File options, asking twice); the phone's Title screen app saves and goes
  back to it
- [x] Visitors from tours: someone you met camping on a tour sometimes spends a day by
  your plaza, brings a souvenir (fruit or a flower you don't grow) and can be asked to
  stay if a plot is free

- [x] The big house: after the house, Poppy offers an extension (25,000 acorns, built
  overnight): an upstairs outside, and inside a bigger living room with doors through to
  three more rooms
- [x] House paint: Poppy has Lucy repaint the roof, walls and door (500 acorns), picked
  from swatches with a preview
- [x] Everyday clothes are items too (`basic.<slot>.<style>.<colour>...`): the wardrobe
  shows only clothes you own, the outfit you start in included; Lucy sells a few
  everyday pieces each day and the tailors the designed ones
- [x] Options on the phone (music on or off, time travel, controls); neighbours' faces in
  the journal and over their houses on the map

- [x] Daily visitors: Fennel (fabrics), Tansy (seeds, a rare flower, fruit from away),
  Basil and Marina (buy bugs and fish for half as much again as Lucy pays) take turns by
  the plaza most days
- [x] Neighbours moving out: now and then a settled neighbour has a "..." bubble and
  wonders about moving on; asked to stay they stay, told to follow their heart they leave
  a keepsake and pack up overnight, freeing their plot
- [x] DIY Recipes on the phone: the recipes you know and what they need

- [x] Inside the tailors: walk in to find Daisy at the counter and Morris by the rails;
  the fitting mirror (or "Try things on" with Daisy) opens the wardrobe with today's
  rail, and what you keep on is bought straight into the wardrobe
- [x] Poppy's office and Bramble's museum tent have insides (a striped marquee and a
  rugged canvas tent, with poles) where they work; Bramble stands in the museum too.
  Marlow's dock is on the south shore; neighbours stay off cliffs; the KayKit buildings
  are a size up
- [x] Five more furniture series (Garden Party, Seaside, Scholar's Study, Hearth & Home,
  Playroom; 240 items) from 27 new kinds of piece: planters, pots, vases, clocks,
  wardrobes, desks, fireplaces, pianos, screens, floor cushions, coat stands, parasols,
  deckchairs, hammocks, swings, rose arches, bird baths, picnic blankets, globes,
  gramophones, rocking horses, fish tanks, fountains, lamp posts, bunting, telescopes and
  toy boxes; some neighbours furnish with them. 27 more wallpapers and floors
- [x] Bridges: Poppy sells a bridge kit (spans one to four tiles of river or pond between
  banks of the same height), used from the pockets where you stand and built on the spot.
- [x] Landscaping: once the house is built, Poppy sells a permit that adds a Landscaping
  app to the phone. Pick a tool there (cliffs, water, slopes, or one of six paths: stone,
  brick, wood, terracotta, sand, dirt), swap with the D-pad, and put them away from the
  app. Cliffs only ever step one level at a time, water sits level with its banks, and
  nothing changes against the beach, slopes, bridges or the plaza. Slopes laid side by side
  make a wider one, and any slope (the island's own too) can be taken away; a stone, brick, wooden or terracotta path on a slope turns it into
  stairs, while sand and dirt stay slopes. Paths round off their outer corners.
- [x] Trees and rocks in the Landscaping app: the Trees tool chops a tree down in three
  chops (it topples away from you, leaving a stump you can sit on, its wood, and any fruit
  or furniture it held) and digs up stumps, bushes and young trees (their fruit comes back);
  the Move tool digs up a tree, bush, rock or stump and carries it to a new spot (open grass,
  or sand for palms and rocks, with room round trees). A grassy border goes round the screen
  while a landscaping tool is out. B while carrying puts it in your pockets instead, looking
  just as it did, to plant again anywhere outside.
- [x] Outdoor decorations: 60 garden pieces from the KayKit packs (big boulders, standing
  stones and crags, bare trees and shrubs, fences, walls and gates, arches to walk under,
  lamp posts, benches, pennants, log and stone piles, a stage, a circus tent, spooky and
  festive bits). Lucy has two a day (four once her shop's built), and the rustic ones can
  be made at the workbench once the recipe turns up in a bottle.
- [x] Home storage: put things away from the pockets while at home (or at a dresser,
  wardrobe or toy box there), sorted by kind, 400 stacks.
- [x] Weather and seasons: a forecast for every day (sunny, cloudy, showers, rain, storms with
  lightning, misty mornings, breezy days), on the phone. Rain darkens the light and wets the
  ground, rings the water and brings out snails, a rare fish or two and raindrop beetles
  while butterflies hide; neighbours put up umbrellas (Lucy sells them, and Poppy gives you
  one the first rainy day). Seasons follow the real calendar for your hemisphere: blossom in
  spring, fireflies in summer, turning leaves in autumn, snow in deep winter. Hold the look-up
  button to see the sky: drifting clouds, a rainbow after the showers, stars and shooting
  stars.
- [x] Tour islands keep their own time of day, weather and season (an evening in the snow,
  a misty spring morning...), and a piece or two of furniture lies about to take home. Fish
  shadows are pointed ovals that wiggle as they swim.
- [x] Sound effects: footsteps on grass, sand, snow, stone and wood; chopping, mining,
  digging, rustling trees, fishing plops and splashes, nets, doors, coins, pages, menus;
  steel-drum and pizzicato jingles for catches, rewards, recipes and building; characters
  babble as they talk, each at their own pitch. The island sounds alive round you: birds by
  day (a dawn chorus), crickets on dry nights, waves by the sea, a stream by the river, rain
  and wind with the weather, thunder after the lightning, and the rain on the roof indoors.

Next milestones (suggested order):
4. More to find on tours: other kinds of tree on rare islands, flower breeding for the
   rare colours.
5. Path tool, rock moving (bridges, slopes, cliffs and water are in).
6. More sound: per-room ambience (a ticking clock, a crackling fire), music boxes and
   record players that play.
7. Platform work: touch controls, performance passes, Switch porting.

## Characters

- **Poppy**: a domestic long-haired cat, a golden-brown tabby with dark stripes, a white
  blaze, muzzle and bib, and green-gold eyes. Runs the
  Island Office in the plaza, welcomes new arrivals, hands over the tent and will
  look after house upgrades and new neighbours.
- **Lucy**: a Jack Russell terrier. Does odd jobs, knows all about DIY, and wants to
  open the island's first shop.
- **Bramble**: an elderly spaniel-ish naturalist in a waistcoat and glasses, Poppy's
  old friend. Comes to run the museum.
- **Daisy and Morris**: British Shorthair cats, sister and brother, Daisy dark brown and
  chatty, Morris grey, quiet and particular. They run the island's clothes shop.

Characters are defined in `data/characters.json` (species, fur colours, outfit) and
their lines live in `scripts/autoload/story.gd`, with progress flags saved in the game.

## Naming

Currency is "Acorns" (placeholder). Everything else in-game should have original names.
Animal species can match Animal Crossing's (cats, dogs, rabbits, bears...) but every
character and their name is original.
