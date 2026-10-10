extends Node
## The island's story so far and everything its characters say.
##
## `flags` remembers which conversations have happened and what's been handed over,
## and is saved with the game. Lines can use {player}, {island}, {fruit} and {flower},
## and button names like {pockets} (see Prompts).

var flags: Dictionary = {}
## What a proper house costs, paid to Poppy, who has it built overnight.
const HOUSE_COST := 10000
## What the extension costs: an upstairs and three more rooms.
const EXTENSION_COST := 25000
## What Lucy charges to repaint the house.
const PAINT_COST := 500
## What Lucy needs to build her shop.
const SHOP_MATERIALS := {"wood": 30, "stone": 20, "clay": 10}
## How many different fish and bugs bring Bramble to the island.
const MUSEUM_SPECIMENS := 5
## What Poppy charges for a neighbour's plot.
const PLOT_COST := 2000
## Donations before Bramble wants a proper building, and what it takes.
const MUSEUM_DONATIONS := 15
const MUSEUM_MATERIALS := {"wood": 40, "stone": 30, "iron_nugget": 10}
## What Marlow charges for a tour ticket.
const TICKET_COST := 1000
## What Poppy charges for a bridge kit.
const BRIDGE_COST := 4000
const BUILD_OPTION := "About bridges..."
## What Poppy charges for the landscaping permit (the cliff pick and water spade).
const LANDSCAPING_COST := 8000
const LANDSCAPE_OPTION := "About landscaping..."
var talking := false
## How many times each character has been chatted to today, to cycle their small talk.
var _chats: Dictionary = {}


func reset() -> void:
	flags.clear()
	force_visitor = ""
	force_daily = ""
	_chats.clear()


func to_save() -> Dictionary:
	return flags


func from_save(saved: Dictionary) -> void:
	flags = saved.duplicate()


## Fills in names and button prompts.
func fill(text: String) -> String:
	var island: World = Game.island
	text = text.replace("{player}", Game.player_name if Game.player_name != "" else "friend")
	text = text.replace("{island}", Game.island_name if Game.island_name != "" else "this")
	if island:
		text = text.replace("{fruit}", island.data.native_fruit).replace("{flower}", island.data.native_flower)
	return Prompts.fill(text)


func _ready() -> void:
	# A rare catch gets talked about.
	Events.caught.connect(func(id: String):
		var c: Dictionary = ItemDB.fish.get(id, ItemDB.bugs.get(id, {}))
		if int(c.get("weight", 9)) <= 2:
			gossip("catch", id))


func npc(id: String) -> Npc:
	for n: Npc in Game.npcs:
		if n.id == id:
			return n
	return null


# --- Conversations -------------------------------------------------------------------

## Talk to a character. The player turns to them, the camera leans in, and the world
## waits until the conversation is over.
func talk_to(who: Npc) -> void:
	if talking or Game.dialogue == null:
		return
	await _begin(who)
	Journal.add("chats")
	match who.id:
		"poppy":
			await _poppy(who)
		"lucy":
			await _lucy(who)
		"bramble":
			await _bramble(who)
		"daisy", "morris":
			await _tailors(who)
		"marlow":
			await _marlow(who)
		"fennel", "tansy", "basil", "marina":
			await _daily(who)
		_:
			if NpcData.is_neighbour(who.id) and who.world and who.world.tour:
				await _tour_visitor(who)
			elif NpcData.is_neighbour(who.id) and who.visiting:
				await _visitor(who)
			elif NpcData.is_neighbour(who.id):
				await _neighbour(who)
	_end()


## Poppy meets a new arrival in the plaza and hands over the tent.
func intro() -> void:
	var poppy := npc("poppy")
	if poppy == null or talking or Game.dialogue == null:
		return
	await _begin(poppy)
	poppy.hop()
	await say("poppy", [
		"Oh! Hello, hello! You must be {player}. Welcome to {island} Island!",
		"I'm Poppy. I look after the Island Office, which is a very grand name for a tent.",
		"It's just us for now: you, me, and Lucy. She's around here somewhere. Probably digging.",
		"This island is yours to make cosy. Gather things, make things, and put them wherever feels right.",
		"Our native fruit is the {fruit}, and {flower}s grow wild all over. Lovely, aren't they?",
		"Now, first things first. You'll need somewhere to sleep! Here you go...",
	])
	if not flags.get("got_tent", false):
		flags["got_tent"] = true
		_give("tent_kit")
	await say("poppy", [
		"Your very own tent kit! Open your pockets with {pockets}, choose the tent, and find a nice flat spot.",
		"Somewhere with a view, I'd say.",
	])
	await _starting_plots()
	flags["met_poppy"] = true
	flags["intro_done"] = true
	await _poppy_questions()
	_end()


func _poppy(poppy: Npc) -> void:
	if not flags.get("met_poppy", false):
		# Islands from before Poppy arrived.
		flags["met_poppy"] = true
		poppy.hop()
		await say("poppy", [
			"Oh! Hello! We haven't met properly. I'm Poppy, and I've just set up the Island Office.",
			"You've been busy, {player}! The place is already looking lived in.",
			"If you ever need a hand, I'm usually right here in the plaza.",
		])
		return
	if not _has_home():
		await say("poppy", ["Found a spot for your tent yet? Open your pockets with {pockets} and choose the tent kit.",
			"Anywhere flat will do. Just leave a bit of room in front of the door!"])
		return
	if not flags.get("tent_gift", false):
		flags["tent_gift"] = true
		poppy.hop()
		await say("poppy", ["Your tent looks wonderful! The island feels more like home already.",
			"Here, a little something for inside."])
		_give("potted_plant")
		await say("poppy", ["A potted plant! Pop it on a table, or on the floor. Plants aren't fussy."])
		return
	if flags.has("house_day") and not flags.get("house_done", false):
		await say("poppy", ["Your house is coming along nicely! Lucy's been hammering since breakfast.",
			"It'll be ready tomorrow. Sleep well tonight, it's your last night under canvas!"])
		return
	if not flags.get("plots_given", false):
		poppy.hop()
		await _starting_plots()
		return
	if await _spare_kit("poppy", "museum_kit", flags.get("museum_kit", false) and not flags.get("museum_done", false)):
		return
	if flags.has("extension_day") and not flags.get("extension_done", false):
		await say("poppy", ["Lucy's up a ladder on your roof as we speak. Well, she was. She's having a sandwich.",
			"Your extension will be ready in the morning!"])
		return
	if flags.get("extension_done", false) and not flags.get("extension_thanks", false):
		flags["extension_thanks"] = true
		poppy.hop()
		await say("poppy", ["Look at your house now! An upstairs and everything!",
			"The new rooms are through the doors in your living room. Back, left and right. So many walls to decorate!"])
		return
	if flags.get("house_done", false) and not flags.get("house_thanks", false):
		flags["house_thanks"] = true
		poppy.hop()
		await say("poppy", ["A real house! With a chimney and everything!",
			"There's much more room inside, so you can really spread out. Happy decorating, {player}!"])
		return
	if (Weather.rain > 0.1 or Weather.snow > 0.1) and not flags.get("umbrella_gift", false):
		flags["umbrella_gift"] = true
		poppy.hop()
		await say("poppy", ["Oh, {player}, you're soaked! Here, have this. I keep a spare for exactly this sort of day."])
		_give("umbrella_yellow")
		await say("poppy", ["Hold it like a tool: choose it from your pockets, or switch to it with {tools}.",
			"Lucy sells other colours, if yellow isn't your thing."])
		return
	var remark := weather_line()
	if remark != "":
		await say("poppy", [remark])
		await _poppy_questions()
		return
	await say("poppy", [_small_talk("poppy", [
		"The office is always open. Well, the flap is.",
		"I keep a diary of everything that happens on the island. Today's entry: {player} said hello. Lovely.",
		"Have you tried shaking the trees? Things fall out of them. Things!",
		"Bottles wash up on the beach now and then. Lucy reads every single one. Twice.",
		"If you're ever tired, a sit down does wonders. Any chair will do.",
		"When the island gets a bit busier, I'd love to welcome some new neighbours.",
	])])
	await _poppy_questions()


func _poppy_questions() -> void:
	while true:
		var options := ["How do I make things?", "What is there to do?", "I'm all set!"]
		var house_offer := can_offer_house() or can_offer_extension()
		if house_offer:
			options.insert(2, "About a proper house..." if can_offer_house() else "About a bigger house...")
		var plot_offer := can_offer_plot()
		if plot_offer:
			options.insert(2, "About new neighbours...")
		var museum_offer := museum_project_open()
		if museum_offer:
			options.insert(2, "About fish and bugs..." if not flags.has("museum_gifts") else "I've brought specimens")
		if flags.get("plots_given", false):
			options.insert(options.size() - 1, BUILD_OPTION)
		if flags.get("house_done", false):
			options.insert(options.size() - 1, LANDSCAPE_OPTION)
		var home := player_house()
		if not home.is_empty():
			options.insert(options.size() - 1, "About my house's paint...")
		var pick := await ask("poppy", "Anything you'd like to know?", options)
		if options[pick] == BUILD_OPTION:
			await _kit_talk()
			continue
		if options[pick] == LANDSCAPE_OPTION:
			await _landscaping_talk()
			continue
		if not home.is_empty() and pick == options.size() - 2:
			await _paint_talk(home)
			continue
		if museum_offer and pick == 2:
			await _museum_project()
			continue
		if museum_offer and pick > 2:
			pick -= 1
		if plot_offer and pick == 2:
			await _plot_talk()
			continue
		if plot_offer and pick > 2:
			pick -= 1
		if house_offer and pick == 2:
			if can_offer_house():
				await _house_talk()
			else:
				await _extension_talk()
			continue
		if house_offer and pick > 2:
			pick -= 1
		match pick:
			0:
				await say("poppy", ["The workbench here in the plaza is for DIY. Walk up to it and press {use}.",
					"Lucy knows all about it. Ask her! She loves being asked."])
			1:
				await say("poppy", ["Chop trees with your axe for wood, hit rocks for stone and clay, and shake trees for branches.",
					"Then make yourself at home. There's no rush here. Ever."])
			_:
				await say("poppy", ["Off you go, then! Come and see me any time."])
				return


## The tent can become a house once it's up, until one is under way.
func can_offer_house() -> bool:
	return _has_home() and flags.get("tent_gift", false) and not flags.has("house_day")


func _house_talk() -> void:
	await say("poppy", ["A proper house! With walls that don't flap in the wind, and a lot more room inside.",
		"Lucy and I can build one where your tent is, overnight. It costs %d acorns, all in one go." % HOUSE_COST])
	if Inventory.currency < HOUSE_COST:
		await say("poppy", ["You've got %d so far. Selling things to Lucy is a good way to save up!" % Inventory.currency,
			"Fruit, furniture you don't need, that sort of thing. Come and see me when you're ready."])
		return
	if await ask("poppy", "Shall we start building?", ["Yes please!", "Not just yet"]) != 0:
		await say("poppy", ["No rush at all. The offer stands!"])
		return
	Inventory.add_currency(-HOUSE_COST)
	flags["house_day"] = GameClock.day_key()
	_npc_cheer("poppy")
	await say("poppy", ["Wonderful! We'll start tonight. Have one last sleep in your tent,",
		"and in the morning you'll have a house!"])


## Once the house has been lived in a while (the day after it went up), it can grow.
func can_offer_extension() -> bool:
	return flags.get("house_done", false) and flags.get("house_thanks", false) and not flags.has("extension_day")


func _extension_talk() -> void:
	await say("poppy", ["A bigger house? Ooh, yes! We can put an upstairs on, and three more rooms through doors off your living room.",
		"The living room gets bigger too. It's %d acorns, and it'll be done overnight." % EXTENSION_COST])
	if Inventory.currency < EXTENSION_COST:
		await say("poppy", ["You've got %d at the moment. Keep selling to Lucy and you'll be there in no time!" % Inventory.currency])
		return
	if await ask("poppy", "Shall we build it?", ["Yes please!", "Not just yet"]) != 0:
		await say("poppy", ["Whenever you're ready!"])
		return
	Inventory.add_currency(-EXTENSION_COST)
	flags["extension_day"] = GameClock.day_key()
	_npc_cheer("poppy")
	await say("poppy", ["Hooray! Lucy will start tonight. Mind the scaffolding!"])


## The player's house (once the tent has become one), or {}.
func player_house() -> Dictionary:
	if Game.island == null:
		return {}
	for obj in Game.island.objects():
		if obj["kind"] == "placed" and obj["item"] in ["house", "big_house"]:
			return obj
	return {}


func _paint_talk(home: Dictionary) -> void:
	await say("poppy", ["A new coat of paint? Lucy loves painting. Mostly she loves the ladder.",
		"Choose your colours and she'll do it straight away. It's %d acorns." % PAINT_COST])
	if Inventory.currency < PAINT_COST:
		await say("poppy", ["Oh, you're a little short. Come back when you've got %d!" % PAINT_COST])
		return
	if Game.house_paint == null:
		return
	Game.house_paint.open(home.get("paint", {}), home["item"] == "big_house")
	var paint: Dictionary = await Game.house_paint.closed
	Game.mode = Game.Mode.MENU
	if paint.is_empty():
		await say("poppy", ["Keeping it as it is? It does look lovely already."])
		return
	Inventory.add_currency(-PAINT_COST)
	home["paint"] = paint
	Game.island.refresh_node(home)
	_npc_cheer("poppy")
	await say("poppy", ["Lucy's on it! ...And she's done. That was quick. She must have been waiting with the brush."])


## Poppy sells the kits for bridges over rivers and slopes up cliffs.
func _kit_talk() -> void:
	await say("poppy", ["Getting about can be tricky with all these rivers, can't it?",
		"A bridge kit spans a river up to four tiles wide: stand on the bank facing the water and use it from your pockets.",
		"Slopes are part of landscaping now, so ask me about that for those. Bridges are %d acorns." % BRIDGE_COST])
	if await ask("poppy", "Would you like a bridge kit?", ["Yes please!", "Not just now"]) != 0:
		await say("poppy", ["Just say the word if you change your mind!"])
		return
	if Inventory.currency < BRIDGE_COST:
		await say("poppy", ["Oh, you're a little short. It's %d acorns, and you've got %d." % [BRIDGE_COST, Inventory.currency]])
		return
	Inventory.add_currency(-BRIDGE_COST)
	_give("bridge_kit")
	_npc_cheer("poppy")
	await say("poppy", ["Here you are! Lucy and I will do the heavy lifting, you just choose the spot."])


## Poppy's landscaping permit: it adds the Landscaping app to the phone, for reshaping
## the island.
func _landscaping_talk() -> void:
	if flags.get("landscaping", false):
		await say("poppy", ["Open the Landscaping app on your phone and pick a tool: cliffs, water, slopes or paths.",
			"{tools} swaps between them, and the app puts them away again when you're done. Have fun!"])
		return
	await say("poppy", ["Fancy reshaping the island? Ooh, I've always wanted a waterfall. Well, a pond.",
		"With a landscaping permit you can raise cliffs and cut them back, dig ponds and rivers, lay slopes and paths.",
		"It's %d acorns, and it all goes on your phone. No tools to carry about!" % LANDSCAPING_COST])
	if Inventory.currency < LANDSCAPING_COST:
		await say("poppy", ["You've got %d so far. Come back when you've saved up!" % Inventory.currency])
		return
	if await ask("poppy", "Shall I sign you up?", ["Yes please!", "Not just yet"]) != 0:
		await say("poppy", ["No rush. The island's lovely as it is!"])
		return
	Inventory.add_currency(-LANDSCAPING_COST)
	flags["landscaping"] = true
	_npc_cheer("poppy")
	await say("poppy", ["There! Open the Landscaping app on your phone, pick a tool, face the spot next to you and press {use}.",
		"Don't worry about getting it wrong. Everything can be put back the way it was."])


func _npc_cheer(id: String) -> void:
	var who := npc(id)
	if who:
		who.cheer()


## Builds the house once the night has passed: the tent becomes a house in the same
## spot, keeping everything inside (and later the house becomes the big house). Returns true if it happened just now.
func finish_house(island: World) -> bool:
	if flags.has("extension_day") and not flags.get("extension_done", false) \
			and GameClock.day_key() > int(flags["extension_day"]):
		for obj in island.objects():
			if obj["kind"] == "placed" and obj["item"] == "house":
				obj["item"] = "big_house"
				island.refresh_node(obj)
				flags["extension_done"] = true
				return true
	if not flags.has("house_day") or flags.get("house_done", false):
		return false
	if GameClock.day_key() <= int(flags["house_day"]):
		return false
	for obj in island.objects():
		if obj["kind"] == "placed" and obj["item"] == "tent_kit":
			obj["item"] = "house"
			island.refresh_node(obj)
			flags["house_done"] = true
			return true
	return false


func _lucy(lucy: Npc) -> void:
	if not flags.get("met_lucy", false):
		flags["met_lucy"] = true
		flags["lucy_met_day"] = GameClock.day_key()
		lucy.hop()
		await say("lucy", [
			"Hi hi hi! You're new! I'm Lucy! I do odd jobs, fix things and dig holes. Mostly dig holes.",
			"This is the workbench! Bring wood, stone and clay and you can make all sorts.",
			"Walk up to it and press {use} to see what you know how to make.",
			"Oh! And if you find a bottle on the beach, open it! Sometimes there's a recipe inside!",
			"And guess what? I've opened a shop! Well, a counter. Well, me, standing here.",
			"I'll buy anything you don't need, and I've got a few bits for sale. New things every day!",
		])
		lucy.cheer()
		return
	if tailors_coming():
		flags["tailors_day"] = GameClock.day_key()
		flags["tailors_kit"] = true
		lucy.hop()
		await say("lucy", ["{player}! Big news! Huge news! My friends Daisy and Morris want to come too!",
			"They're tailors. Cats. Very fluffy, very fancy. They make the best clothes in the whole sea.",
			"They posted their shop ahead in a kit! Clothes! Hats! Little shoes! Well, the shop for them."])
		_give("tailor_kit")
		await say("lucy", ["Stake it out wherever you think they'd like, and they'll put it up that night!"])
		lucy.cheer()
		return
	if await _spare_kit("lucy", "shop_kit", flags.get("shop_kit", false) and not flags.get("shop_done", false)):
		return
	if await _spare_kit("lucy", "tailor_kit", flags.get("tailors_kit", false) and not flags.get("tailors_done", false)):
		return
	if flags.get("shop_done", false) and not flags.get("shop_thanks", false):
		flags["shop_thanks"] = true
		lucy.hop()
		await say("lucy", ["Look! LOOK! A real shop! With shelves! And an awning! And a bell!",
			"Thank you thank you thank you, {player}. I'll have twice as much to sell now, every day.",
			"And flowers! Plants from other islands, for your garden. Come and see!"])
		lucy.cheer()
		return
	var greeting := _small_talk("lucy_hello", [
		"Welcome to Lucy's Odds & Ends! What'll it be?",
		"Hi hi! Buying, selling, or just saying hello?",
		"Customer! A real customer! What can I do for you?",
	])
	var options := ["I'd like to sell", "Let's see what's for sale", "Just chatting", "Bye!"]
	var project := shop_project_open()
	if project:
		options.insert(2, "About your shop..." if flags.has("shop_needs") else "One day this will be a real shop?")
	var pick := await ask("lucy", greeting, options)
	if project and pick == 2:
		await _shop_project()
		return
	if project and pick > 2:
		pick -= 1
	match pick:
		0:
			await _shop("sell")
		1:
			await _shop("buy")
		2:
			await say("lucy", [_small_talk("lucy", [
				"I found a stick today. It's a really good stick.",
				"You can sit on chairs, you know. I sit on everything. Benches, stumps, Poppy's paperwork...",
				"Small things like teapots and candles can go on tables. Very fancy!",
				"If you shake a tree and furniture falls out, don't ask me how it got up there.",
				"Fruit sells for a nice bit. Not that I'd know. I definitely didn't eat any.",
				"Rocks give more if you hit them fast. Bonk bonk bonk!",
				"One day this counter will be a real shop. With a bell on the door!",
			])])
		_:
			await say("lucy", ["Bye bye! Come back soon!"])


## Lucy's shop project: open once you've a home and have done a bit of trading (or a
## day has passed), until the materials are in.
func shop_project_open() -> bool:
	if flags.get("shop_done", false) or flags.has("shop_day") or flags.has("shop_kit") or not _has_home():
		return false
	return flags.has("shop_needs") or int(Journal.stats.get("sold", 0)) >= 5 \
		or GameClock.day_key() > int(flags.get("lucy_met_day", GameClock.day_key()))


func _shop_project() -> void:
	if not flags.has("shop_needs"):
		await say("lucy", ["A real shop! With walls and shelves and a little bell that goes ding!",
			"I've drawn the plans. I just need the materials. Lots of materials.",
			"Could you help? I need %s." % _list_needs(SHOP_MATERIALS)])
		if await ask("lucy", "Will you help me build it?", ["Of course!", "Maybe later"]) != 0:
			await say("lucy", ["Okay! The plans will be right here. In my head. Next to the stick."])
			return
		flags["shop_needs"] = SHOP_MATERIALS.duplicate()
		lucy_cheer()
		await say("lucy", ["Yay! Bring them whenever you can, a bit at a time is fine!"])
		return
	var needs: Dictionary = flags["shop_needs"]
	if _offer(needs).is_empty():
		await say("lucy", ["I still need %s. No rush! Well, a little rush. I'm very excited." % _list_needs(needs)])
		return
	if not await _confirm_giving("lucy", _offer(needs)):
		await say("lucy", ["Okay! Whenever you're ready."])
		return
	var gave := _take_materials(needs)
	if needs.is_empty():
		flags.erase("shop_needs")
		flags["shop_kit"] = true
		lucy_cheer()
		await say("lucy", ["That's everything! I've packed it all into a kit. It's the whole shop, folded up!"])
		_give("shop_kit")
		await say("lucy", ["Stake it out wherever you like and I'll build it that very night. Poppy's lending me her hammer!",
			"Near the plaza would be nice. Or the beach! Or... you choose!"])
		return
	await say("lucy", ["Thank you! That's %s. Still need %s." % [_list_needs(gave), _list_needs(needs)]])


func lucy_cheer() -> void:
	_npc_cheer("lucy")


## Puts up the building a staked-out kit is for, once a night has passed since it was
## staked. Returns the building, or {} if no kit is ready.
static func build_kit(island: World, kit: String) -> Dictionary:
	for obj in island.objects():
		if obj["kind"] == "placed" and obj["item"] == kit and int(obj.get("plot_day", island.day_key)) < island.day_key:
			obj["item"] = ItemDB.placeable(kit)["builds"]
			obj["fixed"] = true
			obj.erase("plot_day")
			island.refresh_node(obj)
			return obj
	return {}


## Whether a kit someone gave you has gone missing: not in your pockets, not staked out
## and not lying on the ground (sold, perhaps). They always have a spare.
static func kit_missing(island: World, kit: String) -> bool:
	if island == null or Inventory.count_of(kit) > 0:
		return false
	for obj in island.objects():
		if obj["kind"] in ["placed", "drop"] and obj["item"] == kit:
			return false
	return true


func _spare_kit(speaker: String, kit: String, waiting: bool) -> bool:
	if not waiting or not kit_missing(Game.island, kit):
		return false
	await say(speaker, ["Lost the %s? Don't worry, I've got a spare. Here!" % ItemDB.display_name(kit).to_lower()])
	_give(kit)
	return true


static func _list_needs(needs: Dictionary) -> String:
	var parts: Array = []
	for mat: String in needs:
		parts.append("%d %s" % [int(needs[mat]), ItemDB.display_name(mat).to_lower()])
	if parts.size() > 1:
		return ", ".join(parts.slice(0, -1)) + " and " + parts[-1]
	return parts[0] if not parts.is_empty() else "nothing"


## Builds Lucy's shop once the night has passed. Returns true if it happened just now.
func finish_shop(island: World) -> bool:
	if flags.get("shop_done", false):
		return false
	if flags.get("shop_kit", false):
		if build_kit(island, "shop_kit").is_empty():
			return false
	elif not flags.has("shop_day") or GameClock.day_key() <= int(flags["shop_day"]) or island.add_shop().is_empty():
		# (Saves from before kits, where Lucy picked the spot herself.)
		return false
	flags["shop_done"] = true
	flags["shop_open_day"] = GameClock.day_key()
	return true


# --- The tailors ---------------------------------------------------------------------

## A day after Lucy's shop opens, she has news: her friends the tailors want to come.
func tailors_coming() -> bool:
	return flags.get("shop_thanks", false) and not flags.has("tailors_day") and not flags.get("tailors_done", false) \
		and GameClock.day_key() > int(flags.get("shop_open_day", -1))


## The tailors' shop goes up the night after Lucy tells you they're coming.
func finish_tailors(island: World) -> bool:
	if not flags.has("tailors_day") or flags.get("tailors_done", false):
		return false
	if flags.get("tailors_kit", false):
		if build_kit(island, "tailor_kit").is_empty():
			return false
	elif GameClock.day_key() <= int(flags["tailors_day"]) or island.add_building("tailor_shop").is_empty():
		return false
	flags["tailors_done"] = true
	return true


func _tailors(who: Npc) -> void:
	if not flags.get("met_tailors", false):
		flags["met_tailors"] = true
		who.hop()
		await say("daisy", ["Oh, you must be {player}! Lucy hasn't stopped talking about you.",
			"I'm Daisy, and this is my brother Morris. We make clothes. Well, I make them. Morris makes them perfect."])
		await say("morris", ["...Hello. Nice to meet you. Your collar's a bit wonky."])
		await say("daisy", ["Morris! Sorry. He means well.",
			"We'll have new things on the rails every day. Do come and have a look whenever you like!"])
		return
	var speaker := who.id
	var greeting := _small_talk(speaker + "_hello", [
		"Welcome to Daisy & Morris! Looking for something new?",
		"Hello again! The rails are full today.",
		"Oh, I love what you're wearing. Shall we find something to go with it?",
	] if speaker == "daisy" else [
		"...Welcome. Have a look.",
		"Mm. You'd suit something in green.",
		"Daisy chose today's things. I hemmed them.",
	])
	var pick := await ask(speaker, greeting, ["Let's see the clothes", "Try things on", "Just chatting", "Bye!"])
	match pick:
		0:
			await _shop("buy", "tailors", speaker)
		1:
			await _fitting(speaker)
		2:
			await say(speaker, [_small_talk(speaker, [
				"Lucy sold us our very first thimble, you know. She was six.",
				"Morris can tell a fabric just by touching it. Blindfolded. Don't ask how I know.",
				"A good outfit is like a good cup of tea. Warm, and exactly right.",
				"Customise your clothes at the workbench with a kit! Morris approves. Mostly.",
			] if speaker == "daisy" else [
				"...I like buttons. Small ones.",
				"Daisy talks. I sew. It works.",
				"The light's good on this island. Good for choosing colours.",
				"Stripes go with everything. Don't tell Daisy I said that.",
			])])
		_:
			await say(speaker, ["Come back soon!" if speaker == "daisy" else "...Bye."])


## The mirror by the tailors' door: straight into the fitting room, Daisy minding it.
func use_mirror() -> void:
	if talking or Game.dialogue == null:
		return
	var daisy := npc("daisy")
	if daisy:
		await _begin(daisy)
	else:
		talking = true
		Game.mode = Game.Mode.MENU
	await _fitting("daisy")
	_end()


## The fitting room: try on anything from today's rail with your own clothes, in front
## of the mirror. Whatever new you've still got on at the end can be bought, straight
## into the wardrobe; otherwise it all goes back on the rail.
func _fitting(speaker: String) -> void:
	var day := GameClock.day_key()
	var rail: Array[String] = []
	for id in Shop.stock(Game.island.data.seed_value if Game.island else 0, day, "", "tailors"):
		if not Shop.is_sold_out(id, day, "tailors") and not id in Inventory.closet:
			rail.append(id)
	if rail.is_empty() or Game.creator == null or Game.player == null:
		await say(speaker, ["Oh! We've nothing left to try today. New things tomorrow!" if speaker == "daisy" else "...Sold out. Tomorrow."])
		return
	await say(speaker, ["The fitting room's just here. Try on whatever you like!" if speaker == "daisy" else "...Mirror's there. Take your time."])
	var before: Dictionary = Game.player.model.look.duplicate()
	Game.creator.open_fitting(before, rail)
	var look: Dictionary = await Game.creator.fitted
	Game.mode = Game.Mode.MENU
	var wanted: Array[String] = []
	var cost := 0
	for slot: String in ItemDB.SLOT_KEYS:
		var id := ItemDB.worn_item(slot, look)
		if id in rail:
			wanted.append(id)
			cost += Shop.buy_price(id)
	if wanted.is_empty():
		Game.player.model.set_look(look)
		await say(speaker, ["Lovely! Come back and try more whenever you like." if speaker == "daisy" else "...Suits you."])
		return
	var names := " and ".join(wanted.map(func(id): return ItemDB.display_name(id)))
	if await ask(speaker, "The %s: that's %d acorns. Would you like to keep them on?" % [names, cost],
			["Yes please!", "Just trying"]) != 0:
		Game.player.model.set_look(before)
		await say(speaker, ["No trouble! I'll pop them back on the rail." if speaker == "daisy" else "...Back on the rail."])
		return
	if Inventory.currency < cost:
		Game.player.model.set_look(before)
		await say(speaker, ["Oh dear, that's a bit more than you've got. They'll keep for today!" if speaker == "daisy" \
			else "...Not enough acorns. Another day."])
		return
	for id in wanted:
		Shop.buy(id, day, "tailors", true)
	Game.player.model.set_look(look)
	gossip("look", ItemDB.worn_item("top", look) if ItemDB.worn_item("top", look) in wanted else "")
	_npc_cheer(speaker)
	await say(speaker, ["They're yours! You look wonderful. Wear them well!" if speaker == "daisy" else "...Good choice. Very good."])


# --- The museum ----------------------------------------------------------------------

## Poppy's museum project: once you've a home and have caught a fish or bug, until
## Bramble's on his way.
func museum_project_open() -> bool:
	if flags.has("museum_day") or flags.get("museum_done", false) or not _has_home():
		return false
	return flags.has("museum_gifts") or int(Journal.stats.get("fish", 0)) + int(Journal.stats.get("bugs", 0)) > 0


func _museum_project() -> void:
	if not flags.has("museum_gifts"):
		await say("poppy", ["You've been catching things! I knew you would.",
			"My old friend Bramble is a naturalist. He's always wanted to start a museum somewhere.",
			"If you bring me %d different fish or bugs, I'll send them to him with a letter." % MUSEUM_SPECIMENS,
			"Something tells me he won't be able to resist coming to see them."])
		flags["museum_gifts"] = []
		return
	var gifts: Array = flags["museum_gifts"]
	var giving: Array[String] = []
	for slot in Inventory.slots:
		var id: String = slot.get("id", "")
		if gifts.size() + giving.size() < MUSEUM_SPECIMENS and ItemDB.is_creature(id) and not id in gifts and not id in giving:
			giving.append(id)
	if giving.is_empty():
		await say("poppy", ["I've got %d so far. I need %d different ones, so bring me ones I haven't got!" % [gifts.size(), MUSEUM_SPECIMENS]])
		return
	var names: Array = giving.map(func(id): return "the " + ItemDB.display_name(id).to_lower())
	if await ask("", "Give Poppy %s for Bramble?" % _and_list(names), ["Yes", "Not now"]) != 0:
		await say("poppy", ["That's all right. Bring them by whenever you like!"])
		return
	var given: Array = []
	for id in giving:
		Inventory.remove_item(id, 1)
		gifts.append(id)
		given.append(ItemDB.display_name(id).to_lower())
	if gifts.size() < MUSEUM_SPECIMENS:
		await say("poppy", ["Ooh, %s! That's %d of %d." % [_and_list(given), gifts.size(), MUSEUM_SPECIMENS]])
		return
	flags["museum_day"] = GameClock.day_key()
	flags["museum_kit"] = true
	_npc_cheer("poppy")
	await say("poppy", ["That's all %d! I'll pack them up carefully and post them to Bramble tonight." % MUSEUM_SPECIMENS,
		"And between you and me, he sent me this ages ago, just in case. His museum tent, in a kit!"])
	_give("museum_kit")
	await say("poppy", ["Find it a nice spot. Once it's staked out, I'm sure he'll come and put it up that night."])


static func _and_list(names: Array) -> String:
	if names.size() > 1:
		return ", ".join(names.slice(0, -1)) + " and " + names[-1]
	return names[0] if not names.is_empty() else ""


## Bramble arrives with his museum tent the day after the specimens were sent, and the
## first specimens go on display. Returns true if it happened just now.
func finish_museum(island: World) -> bool:
	if not flags.has("museum_day") or flags.get("museum_done", false):
		return false
	if flags.get("museum_kit", false):
		if build_kit(island, "museum_kit").is_empty():
			return false
	elif GameClock.day_key() <= int(flags["museum_day"]) or island.add_building("museum_tent").is_empty():
		return false
	for id: String in flags.get("museum_gifts", []):
		Journal.donate(id)
	flags["museum_done"] = true
	return true


func _bramble(bramble: Npc) -> void:
	if not flags.get("met_bramble", false):
		flags["met_bramble"] = true
		bramble.hop()
		await say("bramble", [
			"Ah! You must be {player}. Bramble, naturalist, at your service. Poppy's letter was ever so persuasive.",
			"And the specimens! Marvellous. I simply had to come and see where they were found.",
			"This tent will do for a museum to begin with. Bring me any fish or bug I haven't got, and I'll look after it.",
			"Every creature tells you something about the island. I intend to listen to all of them.",
		])
		return
	if flags.get("museum_built", false) and not flags.get("museum_thanks", false):
		flags["museum_thanks"] = true
		bramble.hop()
		await say("bramble", ["Isn't it splendid? A proper museum, with tanks and cases for everything!",
			"Do go in and have a look. Every fish and bug you've brought me is on show."])
		return
	var options := ["I'd like to donate", "Tell me about something", "Bye!"]
	var building := museum_building_open()
	if building:
		options.insert(2, "About a bigger museum..." if not flags.has("museum_needs") else "I've brought materials")
	var pick := await ask("bramble", _small_talk("bramble_hello", [
		"Welcome, welcome! What have you found today?",
		"Ah, {player}. Come in, mind the jars.",
		"Hello again! The collection grows, little by little.",
	]), options)
	if building and pick == 2:
		await _museum_building()
		return
	if building and pick > 2:
		pick -= 1
	match pick:
		0:
			await _donate()
		1:
			await say("bramble", [_creature_fact()])
		_:
			await say("bramble", ["Do come back. Nature never stops surprising."])


## With enough donations, Bramble wants to build a real museum.
func museum_building_open() -> bool:
	return flags.get("museum_done", false) and not flags.get("museum_built", false) and not flags.has("museum_build_day") \
		and (flags.has("museum_needs") or Journal.donated.size() >= MUSEUM_DONATIONS)


func _museum_building() -> void:
	if not flags.has("museum_needs"):
		await say("bramble", ["The tent is bursting, {player}! Tanks under the table, beetles in my hat...",
			"What we need is a proper museum, with room for every creature on the island.",
			"I've drawn up plans. I'd need %s." % _list_needs(MUSEUM_MATERIALS)])
		if await ask("bramble", "Would you help me gather them?", ["Of course!", "Maybe later"]) != 0:
			await say("bramble", ["Whenever you're ready. The beetles and I will manage."])
			return
		flags["museum_needs"] = MUSEUM_MATERIALS.duplicate()
		await say("bramble", ["Marvellous! Bring them a little at a time if you like."])
		return
	var needs: Dictionary = flags["museum_needs"]
	if _offer(needs).is_empty():
		await say("bramble", ["We still need %s." % _list_needs(needs)])
		return
	if not await _confirm_giving("bramble", _offer(needs)):
		await say("bramble", ["Of course. Whenever suits."])
		return
	var gave := _take_materials(needs)
	if needs.is_empty():
		flags.erase("museum_needs")
		flags["museum_build_day"] = GameClock.day_key()
		_npc_cheer("bramble")
		await say("bramble", ["That's everything! Lucy and I will build it tonight.",
			"Come and see tomorrow. Do wear sensible shoes, it's a very big museum."])
		return
	await say("bramble", ["Thank you! That's %s. Still need %s." % [_list_needs(gave), _list_needs(needs)]])


## What the pockets could give towards `needs`: {material: count}.
static func _offer(needs: Dictionary) -> Dictionary:
	var out := {}
	for mat: String in needs:
		var n := mini(int(needs[mat]), Inventory.count_of(mat))
		if n > 0:
			out[mat] = n
	return out


## Asks before handing things over: "Give them 10 wood and 5 stone?"
func _confirm_giving(to: String, things: Dictionary) -> bool:
	return await ask("", "Give %s %s?" % [NpcData.display_name(to), _list_needs(things)], ["Yes", "Not now"]) == 0


## Takes whatever's needed from the pockets, crossing it off. Returns what was taken.
func _take_materials(needs: Dictionary) -> Dictionary:
	var gave := {}
	for mat: String in needs:
		var n := mini(int(needs[mat]), Inventory.count_of(mat))
		if n > 0:
			Inventory.remove_item(mat, n)
			needs[mat] = int(needs[mat]) - n
			gave[mat] = n
	for mat: String in needs.keys():
		if int(needs[mat]) <= 0:
			needs.erase(mat)
	return gave


## The tent becomes the museum the night after the materials are in.
func finish_museum_building(island: World) -> bool:
	if not flags.has("museum_build_day") or flags.get("museum_built", false):
		return false
	if GameClock.day_key() <= int(flags["museum_build_day"]):
		return false
	var tent := island.building("museum_tent")
	if tent.is_empty():
		return false
	tent["item"] = "museum"
	island.refresh_node(tent)
	flags["museum_built"] = true
	return true


func _donate() -> void:
	var new: Array[String] = []
	for slot in Inventory.slots:
		var id: String = slot.get("id", "")
		if ItemDB.is_creature(id) and not id in Journal.donated and not id in new:
			new.append(id)
	# Ask first: you might want to keep one to sell.
	var giving: Array[String] = []
	if not new.is_empty():
		var names: Array = new.map(func(id): return "the " + ItemDB.display_name(id).to_lower())
		var options := ["Yes", "Not now"] if new.size() == 1 else ["All of them", "One at a time", "Not now"]
		var pick := await ask("", "Donate %s to the museum?" % _and_list(names), options)
		if new.size() == 1:
			if pick == 0:
				giving = new
		elif pick == 0:
			giving = new
		elif pick == 1:
			for id in new:
				if await ask("", "Donate the %s?" % ItemDB.display_name(id).to_lower(), ["Yes", "Keep it"]) == 0:
					giving.append(id)
		if giving.is_empty():
			await say("bramble", ["Quite all right. The collection will wait."])
			return
	var lines: Array = []
	for id in giving:
		Journal.donate(id)
		Inventory.remove_item(id, 1)
		gossip("museum", id)
		lines.append("A %s! %s" % [ItemDB.display_name(id).to_lower(), _thanks(id)])
	if lines.is_empty():
		await say("bramble", ["Hmm, nothing new for the collection there, I'm afraid.",
			"We have %d of %d so far. Keep looking!" % [Journal.donated.size(), ItemDB.fish.size() + ItemDB.bugs.size()]])
		return
	_npc_cheer("bramble")
	lines.append("That's %d of %d in the collection now. Thank you, {player}." % [Journal.donated.size(), ItemDB.fish.size() + ItemDB.bugs.size()])
	await say("bramble", lines)


func _thanks(id: String) -> String:
	var c: Dictionary = ItemDB.fish.get(id, ItemDB.bugs.get(id, {}))
	return _small_talk("bramble_thanks", [
		"What a splendid specimen.",
		"I'll find it the perfect spot.",
		"Oh, look at the colour of it!",
		"The collection wasn't complete without one.",
	]) if c.is_empty() else "%s %s" % [_small_talk("bramble_thanks", ["Splendid.", "Marvellous.", "Oh, lovely.", "How wonderful."]),
		ItemDB.WHERE_TEXT.get(c["where"], "")]


## Something Bramble knows about one of the creatures in the collection.
func _creature_fact() -> String:
	if Journal.donated.is_empty():
		return "Once you've brought me a few things, I'll have plenty to tell you!"
	var id: String = Journal.donated[(_chats.get("bramble_fact", 0) + GameClock.day_key()) % Journal.donated.size()]
	_chats["bramble_fact"] = _chats.get("bramble_fact", 0) + 1
	var c: Dictionary = ItemDB.fish.get(id, ItemDB.bugs.get(id, {}))
	var hours: Array = c["hours"]
	var when := "at any hour" if hours[0] == 0 and hours[1] == 24 else ("by day" if hours[0] < hours[1] and hours[1] <= 20 else "after dark")
	return "The %s! %s You'll find them %s. Lucy would pay %d acorns for one, but I'd rather you brought them here." % [
		ItemDB.display_name(id).to_lower(), ItemDB.WHERE_TEXT.get(c["where"], ""), when, int(c["price"])]


# --- Island tours --------------------------------------------------------------------

## Marlow ties up his ferry at the beach the day after you arrive.
func finish_dock(island: World) -> bool:
	if flags.get("dock_done", false) or not flags.get("intro_done", false):
		return false
	if not flags.has("dock_from"):
		flags["dock_from"] = GameClock.day_key()
	if GameClock.day_key() <= int(flags["dock_from"]):
		return false
	if island.add_dock(island.data.spawn).is_empty():
		return false
	flags["dock_done"] = true
	return true


func _marlow(who: Npc) -> void:
	if who.world and who.world.tour:
		if await ask("marlow", _small_talk("marlow_away", ["Ready to head home, {player}?",
				"Found anything good? Ready to sail back?", "The tide's turning. Home?"]), ["Take me home", "Not yet"]) == 0:
			await say("marlow", ["Righto! Hold on to your hat."])
			Events.tour_ended.emit()
		else:
			await say("marlow", ["Take your time. I'll be right here, watching the gulls. The other gulls."])
		return
	if not flags.get("met_marlow", false):
		flags["met_marlow"] = true
		who.hop()
		await say("marlow", ["Ahoy! Marlow's the name, ferrying's the game. Poppy said you might like to see a bit of the sea.",
			"There are little islands all over these waters. Nobody lives on most of them, so everything there's up for grabs.",
			"Fruit you've never tasted, flowers you've never seen, and now and then someone looking for a new home.",
			"A trip costs a tour ticket. I sell them for %d acorns, and Poppy's journal has them for stamps." % TICKET_COST,
			"Here, your first one's on me. Come and see me when you're ready!"])
		_give("tour_ticket")
		return
	var greeting := _small_talk("marlow_hello", [
		"Ahoy, {player}! Fancy a trip?",
		"Lovely day for a sail. Where to? Oh, I choose. Somewhere nice!",
		"The boat's ready when you are.",
	])
	match await ask("marlow", greeting, ["Let's go!", "Buy a ticket (%d acorns)" % TICKET_COST, "Not today"]):
		0:
			if Inventory.count_of("tour_ticket") == 0:
				await say("marlow", ["You'll need a ticket first, I'm afraid. Rules of the sea. Well, my rules."])
				return
			if await ask("", "Use a tour ticket?", ["Yes", "Not now"]) != 0:
				return
			Inventory.remove_item("tour_ticket", 1)
			Journal.add("tours")
			await say("marlow", ["All aboard! Mind the step, it's mostly sea."])
			Events.tour_requested.emit()
		1:
			if Inventory.currency < TICKET_COST:
				await say("marlow", ["That's %d acorns, and you've %d. Lucy pays well for fruit, I hear." % [TICKET_COST, Inventory.currency]])
				return
			if await ask("", "Buy a tour ticket for %d acorns?" % TICKET_COST, ["Yes", "No thanks"]) != 0:
				return
			Inventory.add_currency(-TICKET_COST)
			_give("tour_ticket")
		_:
			await say("marlow", [_small_talk("marlow", [
				"Every island's different. Some have cherries, some have pears. One had nothing but a very cross crab.",
				"Bring a shovel. Flowers dig up lovely, and they'll grow at home.",
				"Fruit you plant at home grows into a tree, given time. So I'm told. I mostly eat it.",
				"Sometimes there's someone camping out there who'd love a proper home. Worth a chat!",
				"Every so often we land somewhere special. An island of nothing but flowers, once. Another one, all bugs.",
				"There's fish out on the far islands you'll never catch at home. Golden ones, if you believe the stories.",
			])])


## Someone camping on a tour island, who might move to yours.
func _tour_visitor(who: Npc) -> void:
	var data := NpcData.get_character(who.id)
	var catch: String = data.get("catchphrase", "")
	if who.id in invited():
		await say(who.id, ["I'm packing already! See you on {island} Island. %s!" % catch.capitalize()])
		return
	# Remembered, so they might drop in on your island one day.
	var met: Dictionary = flags.get("met", {})
	if not met.has(who.id):
		met[who.id] = GameClock.day_key()
		flags["met"] = met
	who.hop()
	await say(who.id, ["Oh! A visitor! I'm %s. I've been camping here a while. It's lovely, but awfully quiet, %s." % [data["name"], catch]])
	if open_plots() <= invited().size():
		await say(who.id, ["Is your island nice? I'd love to move somewhere friendlier one day.",
			"Oh, but you've no plot free? Never mind. Maybe I'll come and visit you instead!"])
		return
	if await ask(who.id, "Is your island nice? I've been thinking of moving somewhere friendlier.",
			["Come and live on mine!", "Just visiting"]) != 0:
		await say(who.id, ["Fair enough! Enjoy the island. Mind the crabs."])
		return
	await _invite(who)


## They're coming to live on your island: into the next plot staked out.
func _invite(who: Npc) -> void:
	var catch: String = NpcData.get_character(who.id).get("catchphrase", "")
	var list := invited()
	list.append(who.id)
	flags["invited"] = list
	who.cheer()
	var staked := false
	if Game.island:
		for obj in Game.island.objects():
			staked = staked or (obj["kind"] == "placed" and obj["item"] == "plot_kit")
	await say(who.id, ["Really? Oh, %s! Yes please!" % catch,
		"I'll move into one of your plots first thing tomorrow!" if staked
			else "Stake out one of your plots and I'll move in the next day!"])


# --- Visitors ------------------------------------------------------------------------

## How likely it is that someone you met on a tour drops in on a given day.
const VISIT_CHANCE := 0.4
## Who visits regardless of the day's luck (for demos and tests).
var force_visitor := ""


## Who's visiting your island today: now and then, someone you met camping on a tour
## (on a later day) who hasn't moved in yet. "" for nobody.
func visitor_today() -> String:
	var met: Dictionary = flags.get("met", {})
	var day := GameClock.day_key()
	var here: Array = []
	if Game.island:
		for obj in Game.island.objects():
			if obj.has("resident"):
				here.append(obj["resident"])
	var free: Array = met.keys().filter(func(id): return not id in here and day > int(met[id]))
	if free.is_empty():
		return ""
	if force_visitor in free:
		return force_visitor
	free.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["visitor", day, Game.island.data.seed_value if Game.island else 0])
	if rng.randf() >= VISIT_CHANCE:
		return ""
	return free[rng.randi() % free.size()]


## Someone from a tour, visiting for the day: a souvenir, and a chance to ask them to stay.
func _visitor(who: Npc) -> void:
	var catch: String = NpcData.get_character(who.id).get("catchphrase", "")
	var day := GameClock.day_key()
	if who.id in invited():
		await say(who.id, ["Just having a look round before I move in. I can't wait, %s!" % catch])
		return
	if flags.get("visit_greeted", -1) != day:
		flags["visit_greeted"] = day
		who.hop()
		await say(who.id, ["{player}! Remember me? We met on my island. I've come to see what {island} Island's like!"])
		if flags.get("visit_gift", -1) != day:
			flags["visit_gift"] = day
			var gift := souvenir(who.id, day)
			await say(who.id, ["I brought you a little something from home, %s." % catch])
			_give(gift)
	if open_plots() > invited().size():
		if await ask(who.id, "It's lovely here. I don't suppose... is there room for me?",
				["Come and live here!", "Just visiting today"]) == 0:
			await _invite(who)
			return
		await say(who.id, ["That's all right! I'll enjoy my day out. %s!" % catch.capitalize()])
		return
	await say(who.id, [_small_talk(who.id, [
		"I'm catching the evening boat home. It's been a lovely day out!",
		"Your island's so much busier than mine. In a good way!",
		"If you ever have a plot free, I'd love to live here. Just saying, %s." % catch,
	])])


# --- Daily visitors ----------------------------------------------------------------

## Travelling folk who set up by the plaza for a day: Fennel's fabrics, Tansy's seeds,
## Basil who buys bugs and Marina who buys fish (both for more than Lucy pays).
const DAILY_VISITORS := ["fennel", "tansy", "basil", "marina"]
## How likely it is that one of them is about on a given day.
const DAILY_CHANCE := 0.75
## Who's about regardless of the day's luck (for demos and tests).
var force_daily := ""


## Which travelling visitor is by the plaza today ("" for none). They start coming the
## day after you meet Lucy, and never two days running.
func daily_visitor_today(day: int = GameClock.day_key()) -> String:
	if force_daily != "":
		return force_daily
	if not flags.get("met_lucy", false) or day <= int(flags.get("lucy_met_day", day)):
		return ""
	return _daily_pick(day) if _daily_pick(day) != _daily_pick(day - 1) else ""


func _daily_pick(day: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["daily", day, Game.island.data.seed_value if Game.island else 0])
	if rng.randf() >= DAILY_CHANCE:
		return ""
	return DAILY_VISITORS[rng.randi() % DAILY_VISITORS.size()]


func _daily(who: Npc) -> void:
	var met: Array = flags.get("met_visitors", [])
	var first := not who.id in met
	if first:
		met.append(who.id)
		flags["met_visitors"] = met
		who.hop()
	var hello: Dictionary = {
		"fennel": ["Ooh, hello! I'm Fennel. I wheel my fabric cart from island to island.",
			"Wallpaper, flooring, curtains, rugs... all the soft and pretty things. Have a rummage!"],
		"tansy": ["Hello there! Tansy. I grow things. Well, I mostly grow things.",
			"I've seeds and plants from all over, and some colours you won't find round here!"],
		"basil": ["Oh! Hello! Basil. I collect bugs. Well, I love bugs. Same thing really.",
			"Bring me any bugs you catch and I'll pay half as much again as Lucy does. Honest!"],
		"marina": ["Afternoon. Marina. I fish. Mostly I talk about fishing.",
			"I'm after fish for my collection. I'll pay half as much again as Lucy. Got any?"],
	}
	var again: Dictionary = {
		"fennel": ["Fennel's back! Fresh fabrics today. Shall we have a look?"],
		"tansy": ["Back again! The barrow's full. Something for your garden?"],
		"basil": ["Hello again! Caught anything crawly?"],
		"marina": ["Ah, you again. Anything biting?"],
	}
	await say(who.id, hello[who.id] if first else again[who.id])
	var buying: bool = who.id in ["fennel", "tansy"]
	var pick := await ask(who.id, "Have a look?" if buying else "Sell me something?",
		["Let's see!" if buying else "Let's trade!", "Just saying hello"])
	if pick != 0:
		await say(who.id, [{"fennel": "Come back before I pack up tonight!", "tansy": "I'm here till sundown!",
			"basil": "Keep your net handy!", "marina": "Tight lines."}[who.id]])
		return
	if Game.shop == null:
		return
	Game.shop.open("buy" if buying else "sell", who.id)
	await Game.shop.closed
	Game.mode = Game.Mode.MENU
	await say(who.id, [{"fennel": "Lovely! Enjoy, enjoy!", "tansy": "Water them well!",
		"basil": "What a collection! Thank you!", "marina": "Pleasure doing business."}[who.id]])


## What a visitor brings: fruit from their island, or a flower plant you don't grow.
func souvenir(id: String, day: int) -> String:
	var pool: Array = []
	var native_fruit: String = Game.island.data.native_fruit if Game.island else ""
	var native_flower: String = Game.island.data.native_flower if Game.island else ""
	for f: String in IslandGenerator.FRUITS:
		if f != native_fruit:
			pool.append(f)
	for fl: String in IslandGenerator.FLOWERS:
		if fl != native_flower:
			pool.append("%s_%s_plant" % [fl, IslandGenerator.FLOWER_COLOURS[absi(hash([id, fl])) % IslandGenerator.FLOWER_COLOURS.size()]])
	return pool[absi(hash([id, day])) % pool.size()]


# --- Neighbours ----------------------------------------------------------------------

## Poppy sells neighbour plots once your house is built, one at a time, until everyone
## who might move in has.
## How many plots Poppy hands out to begin with.
const STARTING_PLOTS := 3


## Poppy's first job for you: stake out three plots for neighbours, who'll come from
## the islands you visit on Marlow's tours.
func _starting_plots() -> void:
	flags["plots_given"] = true
	var have := Inventory.count_of("plot_kit")
	if Game.island:
		for obj in Game.island.objects():
			if obj["kind"] == "placed" and (obj.has("resident") or obj["item"] == "plot_kit"):
				have += 1
	var giving := maxi(0, STARTING_PLOTS - have)
	await say("poppy", ["And one more thing! This island's ready for a few neighbours.",
		"Here are %s for their homes. Stake them out wherever you'd like someone to live," % ("three plots" if giving == 3 else "some plots"),
		"just like the tent: choose one from your pockets with {pockets}."] if giving > 0 else
		["About neighbours! Folk don't just turn up here, you know. You'll find them on your travels."])
	for i in giving:
		_give("plot_kit")
	await say("poppy", ["A friend of mine, Marlow, runs a little ferry. He'll be tying up at the beach tomorrow.",
		"He sails to islands nobody lives on, and there's often someone camping there who'd love a home.",
		"Invite them, and they'll move into one of your plots the very next day."])


## Plots that are staked out or still in the pockets, with nobody living in them yet.
func open_plots() -> int:
	var n := Inventory.count_of("plot_kit")
	if Game.island:
		for obj in Game.island.objects():
			n += 1 if obj["kind"] == "placed" and obj["item"] == "plot_kit" else 0
	return n


## Who's been invited on a tour and is waiting for a plot, first invited first.
func invited() -> Array:
	var list: Variant = flags.get("invited", [])
	if list is String:
		list = [] if list == "" else [list]
	return list


## Once the first plots are out, Poppy sells more, one at a time, until everyone who
## might move in has a plot.
func can_offer_plot() -> bool:
	if not flags.get("plots_given", false) or Game.island == null:
		return false
	var residents := 0
	for obj in Game.island.objects():
		if obj["kind"] == "placed" and (obj.has("resident") or obj["item"] == "plot_kit"):
			residents += 1
	return Inventory.count_of("plot_kit") == 0 and residents < NpcData.neighbours().size()


func _plot_talk() -> void:
	await say("poppy", ["More neighbours! The more the merrier.",
		"I can sell you another plot for %d acorns. Stake it out, then find someone on a tour to live there." % PLOT_COST])
	if Inventory.currency < PLOT_COST:
		await say("poppy", ["Come back when you've saved up. Selling to Lucy helps!"])
		return
	if await ask("poppy", "Would you like a plot?", ["Yes please!", "Not yet"]) != 0:
		return
	Inventory.add_currency(-PLOT_COST)
	_give("plot_kit")
	await say("poppy", ["Here you go! Choose it from your pockets and find a nice flat spot.",
		"Leave room in front for the door, and somewhere to sit wouldn't hurt."])


## Plots staked out on an earlier day get a neighbour: someone you invited on a tour,
## first invited first. Plots stay empty until then. Returns who moved in.
func move_in(island: World) -> Array[String]:
	var here: Array = []
	for obj in island.objects():
		if obj.has("resident"):
			here.append(obj["resident"])
	var waiting: Array = invited().filter(func(id): return not id in here)
	var arrived: Array[String] = []
	for obj in island.objects():
		if waiting.is_empty():
			break
		if obj["kind"] != "placed" or obj["item"] != "plot_kit" or int(obj.get("plot_day", island.day_key)) >= island.day_key:
			continue
		var who: String = waiting.pop_front()
		obj["item"] = "neighbour_house"
		obj["resident"] = who
		obj.erase("plot_day")
		island.refresh_node(obj)
		here.append(who)
		arrived.append(who)
		gossip("moved_in", "", who)
		var moved: Dictionary = flags.get("moved_in", {})
		moved[who] = island.day_key
		flags["moved_in"] = moved
	flags["invited"] = waiting
	return arrived


# --- Moving out ----------------------------------------------------------------------

## Now and then someone who's lived here a while wonders about moving on: they've a
## thought bubble that day, and tell you when you talk to them. They only go if you
## tell them to follow their heart; then they pack overnight and their plot is free
## for someone new. Nobody else wonders for a while after.
const SETTLE_DAYS := 10
const MOVE_GAP_DAYS := 14
const MOVE_CHANCE := 0.15
## It takes a few neighbours before anyone thinks of leaving.
const MOVE_MIN_RESIDENTS := 3


## Who's thinking of moving today ("" for nobody).
func thinking_of_moving() -> String:
	var m: Dictionary = flags.get("moving", {})
	if m.get("state", "") == "thinking" and int(m.get("day", -1)) == GameClock.day_key():
		return m["id"]
	return ""


## Who's packed and leaving tomorrow ("" for nobody).
func leaving() -> String:
	var m: Dictionary = flags.get("moving", {})
	return m["id"] if m.get("state", "") == "leaving" else ""


## Each morning: whoever agreed to go yesterday leaves, their house going back to an
## empty plot (returns {"who", "uid"}); someone who wasn't asked has decided to stay;
## and now and then a settled neighbour starts wondering.
func check_moving(island: World) -> Dictionary:
	var day := GameClock.day_key()
	var m: Dictionary = flags.get("moving", {})
	if m.get("state", "") == "leaving" and day > int(m["day"]):
		flags.erase("moving")
		flags["last_move"] = day
		var who: String = m["id"]
		var house := island.building_of(who)
		if house.is_empty():
			return {}
		house["item"] = "plot_kit"
		house.erase("resident")
		house["plot_day"] = day
		island.refresh_node(house)
		return {"who": who, "uid": house["uid"]}
	if m.get("state", "") == "thinking" and day > int(m["day"]):
		flags.erase("moving")
	if flags.has("moving") or day - int(flags.get("last_move", -999)) < MOVE_GAP_DAYS:
		return {}
	var residents: Array = []
	var moved: Dictionary = flags.get("moved_in", {})
	for obj in island.objects():
		if obj.has("resident"):
			residents.append(obj["resident"])
	var settled := residents.filter(func(id): return day - int(moved.get(id, 0)) >= SETTLE_DAYS)
	if residents.size() < MOVE_MIN_RESIDENTS or settled.is_empty():
		return {}
	settled.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["moving", day, island.data.seed_value])
	if rng.randf() >= MOVE_CHANCE:
		return {}
	flags["moving"] = {"id": settled[rng.randi() % settled.size()], "day": day, "state": "thinking"}
	return {}


func _moving_talk(who: Npc, data: Dictionary) -> void:
	var catch: String = data.get("catchphrase", "")
	await say(who.id, ["Oh, {player}. Can I tell you something? I've been thinking...",
		"I love it here, I really do. But I wonder if it's time I saw somewhere new."])
	var pick := await ask(who.id, "What do you think I should do?", ["Please don't go!", "Follow your heart"])
	if pick == 0:
		flags.erase("moving")
		flags["last_move"] = GameClock.day_key()
		befriend(who.id, 2)
		who.hop()
		await say(who.id, ["You really want me to stay? ...Then I'm staying! What was I thinking? %s!" % catch.capitalize()])
		return
	flags["moving"]["state"] = "leaving"
	await say(who.id, ["You're right. You always know what to say, {player}.",
		"I'll pack up tonight and catch Marlow's boat in the morning."])
	var piece := _their_piece(data)
	if piece != "":
		await say(who.id, ["Here. I'd like you to have this, to remember me by."])
		_give(piece)
	await say(who.id, ["I'll write! And maybe we'll meet again on one of your trips. %s." % catch.capitalize()])


const NEIGHBOUR_TALK := {
	"cheerful": [
		"Isn't today just the best? I think it's the best. {catch}!",
		"I waved at a butterfly and it waved back. Well, it flapped. Same thing!",
		"You look lovely today, {player}! Have I said that already? {catch}!",
		"I'm going to plant flowers all round my house. All of them. Every flower.",
	],
	"bookish": [
		"I'm reading about the tides. Fascinating, {catch}.",
		"Did you know Bramble has notes on every bug? I've asked to borrow them. Twice.",
		"A quiet afternoon and a good book. What more could one want? {catch}.",
		"I've been cataloguing the shells on the beach. There are eleven kinds, {catch}.",
	],
	"sporty": [
		"I ran round the whole island this morning! Twice! {catch}!",
		"Want to race to the beach? No? Next time then, {catch}!",
		"Chopping wood is great exercise. Lucy says I'm her best customer.",
		"Stretch before you shake trees, {player}. Trust me, {catch}.",
	],
	"sleepy": [
		"I had a lovely nap. Then another one. {catch}.",
		"The sun's so warm here. Perfect for... dozing... {catch}.",
		"Have you seen the fireflies at night? I watch them from my window.",
		"I'm not lazy, I'm resting up for later. Later's important, {catch}.",
	],
}


## What each personality loves to be given (item categories).
const LIKES := {
	"cheerful": ["flower", "clothing"], "bookish": ["furniture", "bug"],
	"sporty": ["fruit", "fish"], "sleepy": ["clothing", "furniture"],
}
## Friendship points for each heart (five hearts in all).
const HEART_POINTS := [3, 8, 15, 24, 35]
## Friendship gained from gifts each day, at most, per neighbour.
const GIFT_POINTS_PER_DAY := 6


func friendship(id: String) -> int:
	return int(flags.get("friendship", {}).get(id, 0))


func befriend(id: String, points: int) -> void:
	var f: Dictionary = flags.get("friendship", {})
	f[id] = int(f.get(id, 0)) + points
	flags["friendship"] = f


## 0 to 5 hearts.
func hearts(id: String) -> int:
	var n := 0
	for p: int in HEART_POINTS:
		if friendship(id) >= p:
			n += 1
	return n


## Today's favour a neighbour would like (an item id), or "" if they don't need anything
## today. About half of them ask for something each day.
func request_for(id: String) -> String:
	var day := GameClock.day_key()
	var reqs: Dictionary = flags.get("requests", {})
	var r: Dictionary = reqs.get(id, {})
	if int(r.get("day", -1)) == day:
		return "" if r.get("done", false) else String(r.get("item", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + day * 7
	var item := ""
	if rng.randf() < 0.5:
		var pool: Array = ["wood", "stone", "clay", "tree_branch"]
		if Game.island:
			var d := Game.island.data
			pool.append(d.native_fruit)
			for colour: String in ItemDB.flowers.get(d.native_flower, {}).get("colors", {}):
				if not ItemDB.is_rare_flower(d.native_flower, colour):
					pool.append("%s_%s" % [d.native_flower, colour])
		for c: Dictionary in ItemDB.fish.values() + ItemDB.bugs.values():
			if int(c.get("weight", 1)) >= 8:
				pool.append(c["id"])
		pool.sort()
		item = pool[rng.randi() % pool.size()]
	reqs[id] = {"day": day, "item": item, "done": false}
	flags["requests"] = reqs
	return item


func _neighbour(who: Npc) -> void:
	var data := NpcData.get_character(who.id)
	var catch: String = data.get("catchphrase", "")
	var met: Array = flags.get("met_neighbours", [])
	if not who.id in met:
		met.append(who.id)
		flags["met_neighbours"] = met
		befriend(who.id, 1)
		who.hop()
		await say(who.id, [("Oh, hello! I'm %s. I've just moved in, isn't it exciting? %s!" % [data["name"], catch.capitalize()]),
			"Poppy told me all about you, {player}. I think we're going to be great friends.",
			"Come and visit me in the evening. I'll be home after six!"])
		return
	if thinking_of_moving() == who.id:
		await _moving_talk(who, data)
		return
	if leaving() == who.id:
		await say(who.id, ["Nearly all packed! It's funny, the boxes take up more room than I did. %s." % catch.capitalize()])
		return
	# Caught out in the rain without an umbrella? Someone always has a spare.
	if (Weather.rain > 0.1 or Weather.snow > 0.1) and not flags.get("spare_umbrella", false) and _no_umbrella() \
			and who.world and not who.world.interior:
		flags["spare_umbrella"] = true
		await say(who.id, ["{player}, you're soaked through! Here, take my spare umbrella. I've another at home, %s." % catch])
		_give(Npc.umbrella_item(who.id))
		await say(who.id, ["Hold it like any tool and up it goes. There, much better!"])
		return
	# A game: one they'd like to play, one being played, or how one went.
	var hood := Game.neighbourhood
	if hood:
		if not hood.result_for(who.id).is_empty():
			await _game_result(who, data)
			return
		if not hood.offer_for(who.id).is_empty():
			await _game_offer(who, data)
			return
		if who.pastime == "stretch" and Game.player and not Game.player.stretching:
			await _stretch_offer(who, data)
			return
		if hood.game.get("by", "") == who.id and hood.game.get("kind", "") == "catch":
			await say(who.id, ["Any luck with the %s yet? Go on, you can do it, %s!" % [ItemDB.display_name(hood.game["what"]).to_lower(), catch]])
			return
	# The first chat each day counts towards being friends.
	var chatted: Dictionary = flags.get("chatted", {})
	if int(chatted.get(who.id, -1)) != GameClock.day_key():
		chatted[who.id] = GameClock.day_key()
		flags["chatted"] = chatted
		befriend(who.id, 1)
	var lines: Array = NEIGHBOUR_TALK.get(data.get("personality", "cheerful"), NEIGHBOUR_TALK["cheerful"])
	var greeting := String(_small_talk(who.id, lines)).replace("{catch}", catch)
	var remark := weather_line(catch)
	if remark != "":
		greeting = remark
	var news := gossip_line(who.id) if randf() < 0.45 else ""
	if news != "":
		greeting = news
	var doing := _pastime_line(who, catch)
	if doing != "":
		greeting = doing
	var wanted := request_for(who.id)
	var options := ["Let's chat!", "I've got something for you", "Need anything?", "Bye!"]
	if wanted != "" and Inventory.count_of(wanted) > 0:
		options[2] = "Here's your %s!" % ItemDB.display_name(wanted).to_lower()
	match await ask(who.id, greeting, options):
		0:
			await say(who.id, [_chat_line(who.id, data)])
		1:
			await _gift_to(who, data)
		2:
			await _favour(who, data, wanted)
		_:
			await say(who.id, ["See you around, {player}! %s!" % catch.capitalize()])
			return
	await _share_catch(who, data)
	await _maybe_present(who, data)


# --- Gossip --------------------------------------------------------------------------

## What the island's been saying about you: the latest things you've done, oldest
## first, each {"day", "kind", "what", "who", "worth"}. Neighbours bring them up when you
## talk to them (`gossip_line`) and talk them over with each other (`gossip_topic`).
## Kinds: "gift" (what, to who), "museum" (what), "catch" (a rare what), "game" (what:
## "race_won", "hide_lost"..., with who), "landscape" (what: the tool), "bought" (the
## priciest thing that day), "upgrade" (what: "house", "big_house", "pockets", "bridge",
## or a building), "tour" (what: the island's kind), "look" (what: the top you put on),
## "moved_in" (who).
const GOSSIP_KEEP := 30
## How many days old news stays news.
const GOSSIP_DAYS := 4
## Who's been told what, so they don't say the same thing every time.
var _gossiped := {}


## Something for the island to talk about. One of each kind (and person) a day: the
## latest, or for "bought" the priciest (`worth`).
func gossip(kind: String, what: String = "", who: String = "", worth: int = 0) -> void:
	var news: Array = flags.get("gossip", [])
	var day := GameClock.day_key()
	for i in range(news.size() - 1, -1, -1):
		var g: Dictionary = news[i]
		if int(g["day"]) == day and g["kind"] == kind and g.get("who", "") == who:
			if int(g.get("worth", 0)) > worth:
				return
			news.remove_at(i)
	news.append({"day": day, "kind": kind, "what": what, "who": who, "worth": worth})
	while news.size() > GOSSIP_KEEP:
		news.remove_at(0)
	flags["gossip"] = news


## The news from the last few days that `listener` could talk about (not their own
## moving in), newest last.
func recent_gossip(listener: String = "") -> Array:
	var out: Array = []
	for g: Dictionary in flags.get("gossip", []):
		if GameClock.day_key() - int(g["day"]) <= GOSSIP_DAYS and not (g["kind"] == "moved_in" and g["who"] == listener):
			out.append(g)
	return out


## Something `listener` has heard about you lately ("I heard you gave Maple a teacup!"),
## a different bit of news each time; "" if there's nothing new.
func gossip_line(listener: String) -> String:
	var news := recent_gossip(listener)
	if news.is_empty():
		return ""
	var n: int = _gossiped.get(listener, 0)
	_gossiped[listener] = n + 1
	return _gossip_said(news[news.size() - 1 - n % mini(news.size(), 4)], listener)


func _gossip_said(g: Dictionary, listener: String) -> String:
	var what: String = g.get("what", "")
	var who: String = g.get("who", "")
	var them := NpcData.display_name(who) if who != "" else ""
	var thing := ItemDB.display_name(what).to_lower() if what != "" else ""
	match g["kind"]:
		"gift":
			if who == listener:
				return "I keep looking at the %s you gave me. It's just right!" % thing
			return "I heard you gave %s a %s! They haven't stopped talking about it." % [them, thing]
		"museum":
			return "Bramble says you gave the museum a %s! I must go and see it." % thing
		"catch":
			return "Is it true you caught a %s? Everyone's talking about it!" % thing
		"game":
			var lines := {
				"race_won": ["You beat me fair and square in that race. I want a rematch!", "%s says you beat them in a race! I'd like to see that."],
				"race_lost": ["I still can't believe I beat you in that race. Hee hee!", "%s says they beat you in a race. Want me to train you?"],
				"hide_won": ["You found me so fast in hide and seek! How?", "I heard you found everyone in hide and seek! Sharp eyes."],
				"hide_lost": ["Nobody found my hiding spot. I'm a legend!", "%s says you never found them in hide and seek!"],
				"catch_won": ["You really did catch it in time! I was so sure you wouldn't.", "%s set you a catching challenge and you did it! Show-off."],
				"catch_lost": ["Never mind about that challenge. They're tricky to catch!", "%s says you didn't quite manage their catching challenge."],
			}
			var pair: Array = lines.get(what, lines["race_won"])
			return pair[0] if who == listener else (pair[1] % them if "%s" in pair[1] else pair[1])
		"landscape":
			return {"cliff": "You've been moving cliffs about! I nearly walked off a new one.",
				"water": "Was the new water your doing? The fish must be thrilled.",
				"slope": "The new slope's ever so handy. My knees thank you!",
				"path": "I love the new paths. My shoes have never been so clean!",
				"trees": "Did you chop down a tree? I'm sure there was one there yesterday.",
				"move": "Has a tree moved? I'm sure it was somewhere else yesterday!"}.get(what, "You've been busy changing the island!")
		"bought":
			return "Lucy says you bought a %s! Ooh, fancy." % thing
		"upgrade":
			return {"house": "Your new house looks lovely! Will you have me round?",
				"big_house": "All those rooms! You'll have to give me a tour.",
				"pockets": "Bigger pockets! What are you going to fill them with?",
				"bridge": "Thank you for the new bridge! It saves an awful lot of swimming.",
				"lucy_shop": "Lucy's new shop is wonderful, isn't it?",
				"tailor_shop": "Have you seen the tailors'? I want everything on the rails.",
				"museum_tent": "A museum on our island! Bramble's ever so pleased.",
				"museum": "The new museum is so grand! You've done the island proud."}.get(what, "You've been building things, I hear!")
		"tour":
			var place: String = TourKinds.get_kind(what).get("name", "") if what != "" else ""
			if place == "" or what == "plain":
				return "Marlow says you went off on a tour! Did you meet anyone nice?"
			return "Marlow says you went to a %s! What was it like?" % place.to_lower()
		"look":
			return "Ooh, a new look! It really suits you." if thing == "" else "Ooh, new %s? It really suits you!" % thing
		"moved_in":
			return "Have you met %s yet? They've just moved in!" % them
	return ""


## Something neighbours chatting together might be talking about: the latest news about
## you ("the coelacanth you caught"), or "" if there's none.
func gossip_topic() -> String:
	var news := recent_gossip()
	if news.is_empty():
		return ""
	var g: Dictionary = news[news.size() - 1 - randi() % mini(news.size(), 3)]
	var what: String = g.get("what", "")
	var thing := ItemDB.display_name(what).to_lower() if what != "" else ""
	var them := NpcData.display_name(g.get("who", "")) if g.get("who", "") != "" else ""
	match g["kind"]:
		"gift":
			return "the %s you gave %s" % [thing, them]
		"museum":
			return "the %s you gave the museum" % thing
		"catch":
			return "the %s you caught" % thing
		"game":
			return "your race with %s" % them if what.begins_with("race") else ("hide and seek" if what.begins_with("hide") else "%s's catching challenge" % them)
		"landscape":
			return "all your landscaping"
		"bought":
			return "your new %s" % thing
		"upgrade":
			return {"house": "your new house", "big_house": "your big house", "pockets": "your bigger pockets",
				"bridge": "the new bridge"}.get(what, "the new %s" % ItemDB.display_name(what).to_lower())
		"tour":
			return "your trip with Marlow"
		"look":
			return "your new look"
		"moved_in":
			return "%s moving in" % them
	return ""


## Something to say about what a neighbour's up to (fishing, catching bugs, chatting
## with someone, having a sit, the coffee in their hand), or "".
func _pastime_line(who: Npc, catch: String) -> String:
	var lines: Array = []
	match who.pastime:
		"fishing":
			lines = ["Shh! You'll scare the fish. ...Oh, it's you, {player}!",
				"They're biting today, %s! Well. Nibbling." % catch,
				"I could sit here with a rod all day. Some days I do!"]
		"bugs":
			lines = ["I nearly had one! Nearly, %s." % catch, "Bug hunting! Don't tell the bugs.",
				"Did you see where that butterfly went? It was right here!"]
		"chat":
			if who.partner:
				var topics := ["the weather", "Lucy's new stock", "who's the best at hide and seek", "the best fishing spot",
					"what Poppy keeps in that office", "whether bugs have favourite flowers", "dinner"]
				# Most likely, you.
				var topic := gossip_topic() if randf() < 0.7 else ""
				if topic == "":
					topic = topics[(hash(who.id) + GameClock.day_key()) % topics.size()]
				lines = ["Oh, {player}! %s and I were just talking about %s." % [NpcData.display_name(who.partner.id), topic]]
		"sit":
			lines = ["Just having a little sit, %s. My feet were telling me to." % catch,
				"Lovely spot, this. You can see half the island from here! Well, some of it."]
		"visit":
			var host := Game.neighbourhood.host_of(who.id) if Game.neighbourhood else ""
			if host != "":
				lines = ["I'm going round to %s's for the evening. They've promised me cake, %s!" % [NpcData.display_name(host), catch],
					"Shh, I'm surprising %s! I've brought biscuits." % NpcData.display_name(host)]
		"campfire":
			lines = ["Pull up a log, {player}! There's always room by the fire.",
				"I've burnt three marshmallows. This one's going to be perfect, %s." % catch,
				"Listen to it crackle. Best sound there is."]
	if lines.is_empty() and who.prop == "held:coffee_cup":
		lines = ["Mmm. Coffee. Nothing works before coffee, %s." % catch]
	if lines.is_empty() or (who.pastime == "" and randf() < 0.5):
		return ""
	return lines[randi() % lines.size()]


## Morning stretches on the plaza: would you like to join in?
func _stretch_offer(who: Npc, data: Dictionary) -> void:
	var catch := String(data.get("catchphrase", ""))
	if await ask(who.id, "Morning, {player}! It's stretch time. Join in, %s?" % catch, ["Join in!", "Not today"]) != 0:
		await say(who.id, ["Suit yourself! More stretching for me."])
		return
	await say(who.id, ["Find a space and copy everyone. Reach for the sky! Walk off whenever you've had enough."])
	if Game.camera:
		Game.camera.talk_with = null
	Game.neighbourhood.join_stretches()


## A neighbour with a "!" over their head asks to play a game (Neighbourhood.offer).
func _game_offer(who: Npc, data: Dictionary) -> void:
	var hood := Game.neighbourhood
	var offer := hood.offer_for(who.id)
	var catch := String(data.get("catchphrase", ""))
	var question := ""
	match offer["game"]:
		"hide":
			question = "{player}! Let's play hide and seek! We hide, you seek. Want to play?"
		"catch":
			question = "I bet you can't catch a %s in three minutes, %s! Want to try?" % [ItemDB.display_name(offer["what"]).to_lower(), catch]
		"race":
			question = "Race you to %s! First one there wins. Ready?" % offer["name"]
	who.hop()
	if await ask(who.id, question, ["Let's play!", "Not now"]) != 0:
		hood.decline()
		await say(who.id, ["Aww. Another time, then! %s." % catch.capitalize()])
		return
	match offer["game"]:
		"hide":
			await say(who.id, ["Yay! Close your eyes and count to ten. No peeking!",
				"You've got two and a half minutes to find us. Walk right up to us when you do!"])
			if Game.camera:
				Game.camera.talk_with = null
			await hood.start(who)
			if hood.game.is_empty():
				await say(who.id, ["...Hmm. There's nowhere good to hide. Never mind!"])
			else:
				Events.toast.emit("Ready or not! Find %d hiding %s." % [hood.game["hiders"].size(), "neighbour" if hood.game["hiders"].size() == 1 else "neighbours"])
		"catch":
			await say(who.id, ["Go on then! Three minutes, starting... now!"])
			await hood.start(who)
		"race":
			await say(who.id, ["Look for the flag at %s. On your marks..." % offer["name"]])
			await hood.start(who)
			await hood.count_down(who)


## How a game went, with a present if you won.
func _game_result(who: Npc, data: Dictionary) -> void:
	var hood := Game.neighbourhood
	var r := hood.result_for(who.id)
	hood.clear_result()
	var catch := String(data.get("catchphrase", ""))
	if not r["won"]:
		befriend(who.id, 1)
		gossip("game", r["game"] + "_lost", who.id)
		match r["game"]:
			"hide":
				await say(who.id, ["Ha! Couldn't find us all, could you? I'm not telling where I was. %s!" % catch.capitalize()])
			"catch":
				await say(who.id, ["No %s? They're tricky. Thanks for trying, {player}!" % ItemDB.display_name(r["what"]).to_lower()])
			"race":
				await say(who.id, ["I win! I win! Rematch tomorrow, %s?" % catch])
		return
	befriend(who.id, 3)
	Journal.add("games_won")
	gossip("game", r["game"] + "_won", who.id)
	who.hop()
	_npc_cheer(who.id)
	match r["game"]:
		"hide":
			await say(who.id, ["You found us all! You've got sharp eyes, {player}."])
		"catch":
			await say(who.id, ["A %s! You really did it, and in time too! %s!" % [ItemDB.display_name(r["what"]).to_lower(), catch.capitalize()]])
		"race":
			await say(who.id, ["You beat me! You're fast, {player}. I'll get you next time, %s!" % catch])
	var piece := _their_piece(data)
	if piece != "" and randf() < 0.5:
		await say(who.id, ["Here, a prize for the winner!"])
		_give(piece)
	else:
		var acorns := 300 + hearts(who.id) * 100
		Inventory.add_currency(acorns)
		Sfx.play("coins")
		await say(who.id, ["Here's %d acorns for the winner!" % acorns])


## Something to say about the weather or the season today ("" if there's nothing much to
## say, or now and then even if there is). `catch` is the speaker's catchphrase.
func weather_line(catch: String = "") -> String:
	var tail := (", %s!" % catch) if catch != "" else "!"
	var lines: Array[String] = []
	if Weather.storm > 0.3:
		lines.append("What a storm" + tail + " Did you see the lightning? I counted to three and then hid.")
	elif Weather.snow > 0.1:
		lines.append("It's snowing" + tail + " Everything goes so quiet when it snows.")
	elif Weather.rain > 0.1:
		lines.append("Lovely weather for snails" + tail + " They come out on the rocks when it rains.")
		lines.append("Rain, rain" + tail + " Good for the flowers, mind. And for the fish, I hear.")
	elif Weather.rainbow > 0.2:
		lines.append("Have you looked up? There's a rainbow" + tail + " Hold {look_up} to see the sky.")
	elif Weather.mist > 0.3:
		lines.append("Misty this morning" + tail + " It'll burn off by nine, you'll see.")
	elif Weather.snow_cover > 0.5:
		lines.append("The snow makes everything look like a cake" + tail)
	elif Weather.autumn > 0.5:
		lines.append("The leaves are turning" + tail + " Orange is my favourite colour this time of year.")
	elif Weather.blossom > 0.5:
		lines.append("The blossom's out" + tail + " Spring always smells of something sweet.")
	if Weather.meteors > 0.5 or (Weather.plan(GameClock.day_key()).get("meteors", false) and GameClock.hour_float() > 15.0):
		lines.append("Clear skies tonight" + tail + " They say there'll be shooting stars. Hold {look_up} after dark and look up!")
	if lines.is_empty() or randf() < 0.35:
		return ""
	return lines[randi() % lines.size()]


## Chatter that warms up as you become friends.
func _chat_line(id: String, data: Dictionary) -> String:
	var catch: String = data.get("catchphrase", "")
	# Now and then, what everyone's been saying about you.
	if randf() < 0.4:
		var news := gossip_line(id)
		if news != "":
			return news
	var h := hearts(id)
	if h >= 4:
		return String(_small_talk(id + "_close", [
			"You know, {player}, I'm really glad I moved here. You're the best, %s." % catch,
			"I told my old friends all about you. They're very jealous, %s!" % catch,
			"Whenever I'm feeling down I think of our chats. Silly, isn't it? %s." % catch.capitalize(),
		]))
	if h >= 2:
		return String(_small_talk(id + "_friend", [
			"I keep a little list of things I like. You're on it, {player}! %s!" % catch.capitalize(),
			"Have you been to see Bramble's collection? I go every week, %s." % catch,
			"Let's go fishing together one day. You can do the catching, %s." % catch,
		]))
	var lines: Array = NEIGHBOUR_TALK.get(data.get("personality", "cheerful"), NEIGHBOUR_TALK["cheerful"])
	return String(_small_talk(id + "_chat", lines)).replace("{catch}", catch)


## Lets the player pick something from their pockets to give.
func _gift_to(who: Npc, data: Dictionary) -> void:
	var choices: Array[String] = []
	for slot in Inventory.slots:
		var id: String = slot.get("id", "")
		if id != "" and not id in choices and not ItemDB.is_tool(id) and choices.size() < 5:
			choices.append(id)
	if choices.is_empty():
		await say(who.id, ["Your pockets are empty! That's all right, the thought counts."])
		return
	var options: Array = choices.map(func(id): return ItemDB.display_name(id))
	options.append("Never mind")
	var pick := await ask("", "What shall I give %s?" % data["name"], options)
	if pick >= choices.size():
		return
	var gift := choices[pick]
	Inventory.remove_item(gift, 1)
	Journal.add("gifts_given")
	gossip("gift", gift, who.id)
	var liked: bool = ItemDB.get_item(gift).get("category", "") in LIKES.get(data.get("personality", ""), [])
	var given: Dictionary = flags.get("gift_points", {})
	var today: Dictionary = given.get(who.id, {})
	if int(today.get("day", -1)) != GameClock.day_key():
		today = {"day": GameClock.day_key(), "points": 0}
	var points := mini(4 if liked else 2, GIFT_POINTS_PER_DAY - int(today["points"]))
	if points > 0:
		befriend(who.id, points)
		today["points"] = int(today["points"]) + points
	given[who.id] = today
	flags["gift_points"] = given
	var name := ItemDB.display_name(gift).to_lower()
	if liked:
		who.hop()
		_npc_cheer(who.id)
		await say(who.id, ["A %s? For me? Oh, {player}, I love it! %s!" % [name, String(data.get("catchphrase", "")).capitalize()]])
	else:
		await say(who.id, ["A %s! How kind of you. Thank you, {player}." % name])


func _favour(who: Npc, data: Dictionary, wanted: String) -> void:
	var catch: String = data.get("catchphrase", "")
	if wanted == "":
		await say(who.id, ["Not today, thanks! But it's sweet of you to ask, %s." % catch])
		return
	var name := ItemDB.display_name(wanted).to_lower()
	if Inventory.count_of(wanted) == 0:
		await say(who.id, ["Actually, yes! I'd love a %s. Could you bring me one today? %s!" % [name, catch.capitalize()]])
		return
	if await ask("", "Give %s the %s?" % [data["name"], name], ["Yes", "Not now"]) != 0:
		await say(who.id, ["Oh! Okay. Maybe later, %s." % catch])
		return
	Inventory.remove_item(wanted, 1)
	var reqs: Dictionary = flags["requests"]
	reqs[who.id]["done"] = true
	befriend(who.id, 3)
	Journal.add("favours")
	who.hop()
	_npc_cheer(who.id)
	await say(who.id, ["A %s! Just what I needed. You're a star, {player}!" % name])
	# A thank-you: acorns, or something from home.
	var piece := _their_piece(data)
	if piece != "" and (GameClock.day_key() + hearts(who.id)) % 2 == 0:
		await say(who.id, ["Here, have this. I made it myself, %s." % catch])
		_give(piece)
	else:
		var acorns := 300 + hearts(who.id) * 100
		Inventory.add_currency(acorns)
		await say(who.id, ["Here's %d acorns for your trouble. No arguing!" % acorns])


## A piece of furniture from the neighbour's favourite series (not a little one).
func _their_piece(data: Dictionary) -> String:
	var inside: Dictionary = data.get("inside", {})
	var pieces: Array = ItemDB.items.keys().filter(func(id): return ItemDB.get_item(id).get("series", "") == inside.get("series", "") \
		and ItemDB.get_item(id).has("placeable") and not ItemDB.get_item(id)["placeable"].get("small", false) \
		and ItemDB.get_item(id).get("variant", "") == inside.get("variant", ""))
	if pieces.is_empty():
		return ""
	pieces.sort()
	return pieces[(GameClock.day_key() + friendship(String(data.get("name", "")))) % pieces.size()]


## True if you've no umbrella, in your pockets or put away at home.
func _no_umbrella() -> bool:
	for stack: Dictionary in Inventory.slots + Inventory.storage:
		if stack.get("id", "") != "" and ItemDB.tool_type(stack["id"]) == "umbrella":
			return false
	return true


## Something they caught today, offered to you now and then (once a day each): one the
## museum hasn't got yet, if they've one of those.
func _share_catch(who: Npc, data: Dictionary) -> void:
	var caught := who.catches_today()
	var shared: Dictionary = flags.get("shared_catch", {})
	if caught.is_empty() or int(shared.get(who.id, -1)) == GameClock.day_key() or randf() < 0.35:
		return
	var pick: String = caught[0]
	for id in caught:
		if not id in Journal.donated:
			pick = id
			break
	shared[who.id] = GameClock.day_key()
	flags["shared_catch"] = shared
	var name := ItemDB.display_name(pick).to_lower()
	var line := "Oh! I caught a %s earlier and I've nowhere to put it. Would you like it?" % name
	if not pick in Journal.donated:
		line += " The museum hasn't got one yet, you know!"
	if await ask(who.id, line, ["Yes please!", "You keep it"]) == 0:
		_give(pick)
		await say(who.id, ["It's all yours! Look after it, %s." % String(data.get("catchphrase", ""))])
	else:
		await say(who.id, ["Then I'll let it go. Off you go, little %s!" % name])


## Now and then (more often as friends), a little present, once a day at most.
func _maybe_present(who: Npc, data: Dictionary) -> void:
	var gifts: Dictionary = flags.get("neighbour_gifts", {})
	if int(gifts.get(who.id, -1)) == GameClock.day_key():
		return
	var every := maxi(1, 4 - hearts(who.id) / 2)
	if (GameClock.day_key() + who.id.length()) % every != 0:
		return
	var piece := _their_piece(data)
	if piece == "":
		return
	gifts[who.id] = GameClock.day_key()
	flags["neighbour_gifts"] = gifts
	await say(who.id, ["Oh! I made one of these and I've no room for it. Would you like it? %s!" % String(data.get("catchphrase", "")).capitalize()])
	_give(piece)


func _shop(mode: String, keeper: String = "lucy", speaker: String = "lucy") -> void:
	if Game.shop == null:
		return
	Game.shop.open(mode, keeper)
	await Game.shop.closed
	Game.mode = Game.Mode.MENU
	if keeper == "tailors":
		await say(speaker, ["Thank you! Wear it well!" if speaker == "daisy" else "...It'll suit you."])
		return
	await say("lucy", [_small_talk("lucy_bye", ["Thanks! Pleasure doing business!", "Come back tomorrow, I'll have new things!",
		"Ka-ching! That's the sound of a happy shopkeeper."])])


# --- Helpers -------------------------------------------------------------------------

func say(speaker: String, lines: Array) -> void:
	Game.dialogue.say(speaker, lines)
	await Game.dialogue.finished


func ask(speaker: String, question: String, options: Array) -> int:
	Game.dialogue.ask(speaker, question, options)
	return await Game.dialogue.picked


func _begin(who: Npc) -> void:
	talking = true
	Game.mode = Game.Mode.MENU
	var player := Game.player
	if player:
		player.face_towards(who.position)
	if Game.camera:
		Game.camera.talk_with = who
	await get_tree().create_timer(0.2).timeout


func _end() -> void:
	if Game.camera:
		Game.camera.talk_with = null
	Game.mode = Game.Mode.PLAY
	talking = false


## Cycles through a character's small talk, a different line each chat.
func _small_talk(id: String, lines: Array) -> String:
	var n: int = _chats.get(id, 0)
	_chats[id] = n + 1
	return lines[(n + GameClock.day_key()) % lines.size()]


func _give(item: String) -> void:
	var player := Game.player
	if Inventory.add_item(item) > 0 and player:
		player.world.drop_from_pockets(player.tile(), player.target_tile(), item, 1)
		Events.toast.emit("Your pockets are full, so it's on the ground.")
	else:
		Events.toast.emit("You got %s!" % ItemDB.display_name(item))
	if player:
		player.model.play("cheer")


## True once the player has a home of their own on the island.
func _has_home() -> bool:
	if Game.island == null:
		return false
	for obj in Game.island.objects():
		if obj["kind"] == "placed" and ItemDB.placeable(obj["item"]).has("room") and not obj.has("resident") \
				and not ItemDB.placeable(obj["item"]).get("museum", false) and not ItemDB.placeable(obj["item"]).has("inside"):
			return true
	return false
