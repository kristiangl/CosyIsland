extends Node
## The island's story so far and everything its characters say.
##
## `flags` remembers which conversations have happened and what's been handed over,
## and is saved with the game. Lines can use {player}, {island}, {fruit} and {flower},
## and button names like {pockets} (see Prompts).

var flags: Dictionary = {}
## What a proper house costs, paid to Poppy, who has it built overnight.
const HOUSE_COST := 10000
## What Lucy needs to build her shop.
const SHOP_MATERIALS := {"wood": 30, "stone": 20, "clay": 10}
## How many different fish and bugs bring Bramble to the island.
const MUSEUM_SPECIMENS := 5
## What Poppy charges for a neighbour's plot.
const PLOT_COST := 2000
var talking := false
## How many times each character has been chatted to today, to cycle their small talk.
var _chats: Dictionary = {}


func reset() -> void:
	flags.clear()
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
		_:
			if NpcData.is_neighbour(who.id):
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
	if flags.get("house_done", false) and not flags.get("house_thanks", false):
		flags["house_thanks"] = true
		poppy.hop()
		await say("poppy", ["A real house! With a chimney and everything!",
			"There's much more room inside, so you can really spread out. Happy decorating, {player}!"])
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
		var house_offer := can_offer_house()
		if house_offer:
			options.insert(2, "About a proper house...")
		var plot_offer := can_offer_plot()
		if plot_offer:
			options.insert(2, "About new neighbours...")
		var museum_offer := museum_project_open()
		if museum_offer:
			options.insert(2, "About fish and bugs..." if not flags.has("museum_gifts") else "I've brought specimens")
		var pick := await ask("poppy", "Anything you'd like to know?", options)
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
			await _house_talk()
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


func _npc_cheer(id: String) -> void:
	var who := npc(id)
	if who:
		who.cheer()


## Builds the house once the night has passed: the tent becomes a house in the same
## spot, keeping everything inside. Returns true if it happened just now.
func finish_house(island: World) -> bool:
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
	if flags.get("shop_done", false) or flags.has("shop_day") or not _has_home():
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
	if gave.is_empty():
		await say("lucy", ["I still need %s. No rush! Well, a little rush. I'm very excited." % _list_needs(needs)])
		return
	if needs.is_empty():
		flags.erase("shop_needs")
		flags["shop_day"] = GameClock.day_key()
		lucy_cheer()
		await say("lucy", ["That's everything! I'll build it tonight. Poppy's lending me her hammer!",
			"Come and see it tomorrow. It's going to be the best shop. The only shop, but the best!"])
		return
	await say("lucy", ["Thank you! That's %s. Still need %s." % [_list_needs(gave), _list_needs(needs)]])


func lucy_cheer() -> void:
	_npc_cheer("lucy")


static func _list_needs(needs: Dictionary) -> String:
	var parts: Array = []
	for mat: String in needs:
		parts.append("%d %s" % [int(needs[mat]), ItemDB.display_name(mat).to_lower()])
	if parts.size() > 1:
		return ", ".join(parts.slice(0, -1)) + " and " + parts[-1]
	return parts[0] if not parts.is_empty() else "nothing"


## Builds Lucy's shop once the night has passed. Returns true if it happened just now.
func finish_shop(island: World) -> bool:
	if not flags.has("shop_day") or flags.get("shop_done", false):
		return false
	if GameClock.day_key() <= int(flags["shop_day"]):
		return false
	if island.add_shop().is_empty():
		return false
	flags["shop_done"] = true
	return true


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
	var given: Array = []
	for i in Inventory.slots.size():
		var slot := Inventory.slots[i]
		var id: String = slot.get("id", "")
		if gifts.size() < MUSEUM_SPECIMENS and ItemDB.is_creature(id) and not id in gifts:
			gifts.append(id)
			given.append(ItemDB.display_name(id).to_lower())
			Inventory.remove_from_slot(i)
	if given.is_empty():
		await say("poppy", ["I've got %d so far. I need %d different ones, so bring me ones I haven't got!" % [gifts.size(), MUSEUM_SPECIMENS]])
		return
	if gifts.size() < MUSEUM_SPECIMENS:
		await say("poppy", ["Ooh, %s! That's %d of %d." % [_and_list(given), gifts.size(), MUSEUM_SPECIMENS]])
		return
	flags["museum_day"] = GameClock.day_key()
	_npc_cheer("poppy")
	await say("poppy", ["That's all %d! I'll pack them up carefully and post them to Bramble tonight." % MUSEUM_SPECIMENS,
		"I wouldn't be surprised if he turned up tomorrow with a tent and a magnifying glass."])


static func _and_list(names: Array) -> String:
	if names.size() > 1:
		return ", ".join(names.slice(0, -1)) + " and " + names[-1]
	return names[0] if not names.is_empty() else ""


## Bramble arrives with his museum tent the day after the specimens were sent, and the
## first specimens go on display. Returns true if it happened just now.
func finish_museum(island: World) -> bool:
	if not flags.has("museum_day") or flags.get("museum_done", false):
		return false
	if GameClock.day_key() <= int(flags["museum_day"]):
		return false
	if island.add_building("museum_tent").is_empty():
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
	var options := ["I'd like to donate", "Tell me about something", "Bye!"]
	match await ask("bramble", _small_talk("bramble_hello", [
		"Welcome, welcome! What have you found today?",
		"Ah, {player}. Come in, mind the jars.",
		"Hello again! The collection grows, little by little.",
	]), options):
		0:
			await _donate()
		1:
			await say("bramble", [_creature_fact()])
		_:
			await say("bramble", ["Do come back. Nature never stops surprising."])


func _donate() -> void:
	var lines: Array = []
	for i in Inventory.slots.size():
		var id: String = Inventory.slots[i].get("id", "")
		if ItemDB.is_creature(id) and not id in Journal.donated:
			Journal.donate(id)
			Inventory.remove_from_slot(i)
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


# --- Neighbours ----------------------------------------------------------------------

## Poppy sells neighbour plots once your house is built, one at a time, until everyone
## who might move in has.
func can_offer_plot() -> bool:
	if not flags.get("house_done", false) or Game.island == null:
		return false
	var residents := 0
	for obj in Game.island.objects():
		if obj["kind"] == "placed" and (obj.has("resident") or obj["item"] == "plot_kit"):
			residents += 1
	return Inventory.count_of("plot_kit") == 0 and residents < NpcData.neighbours().size()


func _plot_talk() -> void:
	await say("poppy", ["New neighbours! I get letters every week from folk who'd love to live here.",
		"I can sell you a plot for %d acorns. Stake it out wherever you like," % PLOT_COST,
		"and someone will move in the very next day."])
	if Inventory.currency < PLOT_COST:
		await say("poppy", ["Come back when you've saved up. Selling to Lucy helps!"])
		return
	if await ask("poppy", "Would you like a plot?", ["Yes please!", "Not yet"]) != 0:
		return
	Inventory.add_currency(-PLOT_COST)
	_give("plot_kit")
	await say("poppy", ["Here you go! Choose it from your pockets and find a nice flat spot.",
		"Leave room in front for the door, and somewhere to sit wouldn't hurt."])


## Plots staked out on an earlier day get a neighbour: someone not already on the
## island, picked by the island and the day. Returns who moved in.
func move_in(island: World) -> Array[String]:
	var here: Array = []
	for obj in island.objects():
		if obj.has("resident"):
			here.append(obj["resident"])
	var arrived: Array[String] = []
	for obj in island.objects():
		if obj["kind"] != "placed" or obj["item"] != "plot_kit" or int(obj.get("plot_day", island.day_key)) >= island.day_key:
			continue
		var free: Array = NpcData.neighbours().keys().filter(func(id): return not id in here)
		if free.is_empty():
			break
		free.sort()
		var who: String = free[(island.data.seed_value + island.day_key + here.size()) % free.size()]
		obj["item"] = "neighbour_house"
		obj["resident"] = who
		obj.erase("plot_day")
		island.refresh_node(obj)
		here.append(who)
		arrived.append(who)
	return arrived


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


func _neighbour(who: Npc) -> void:
	var data := NpcData.get_character(who.id)
	var catch: String = data.get("catchphrase", "")
	var met: Array = flags.get("met_neighbours", [])
	if not who.id in met:
		met.append(who.id)
		flags["met_neighbours"] = met
		who.hop()
		await say(who.id, [("Oh, hello! I'm %s. I've just moved in, isn't it exciting? %s!" % [data["name"], catch.capitalize()]),
			"Poppy told me all about you, {player}. I think we're going to be great friends.",
			"Come and visit me in the evening. I'll be home after six!"])
		return
	var lines: Array = NEIGHBOUR_TALK.get(data.get("personality", "cheerful"), NEIGHBOUR_TALK["cheerful"])
	var line := String(_small_talk(who.id, lines)).replace("{catch}", catch)
	await say(who.id, [line])
	# Now and then, a little present (once a day at most).
	var gifts: Dictionary = flags.get("neighbour_gifts", {})
	if int(gifts.get(who.id, -1)) != GameClock.day_key() and (GameClock.day_key() + who.id.length()) % 3 == 0:
		gifts[who.id] = GameClock.day_key()
		flags["neighbour_gifts"] = gifts
		var inside: Dictionary = data.get("inside", {})
		var pieces: Array = ItemDB.items.keys().filter(func(id): return ItemDB.get_item(id).get("series", "") == inside.get("series", "") \
			and ItemDB.get_item(id).has("placeable") and ItemDB.get_item(id)["placeable"].get("small", false) == false \
			and ItemDB.get_item(id).get("variant", "") == inside.get("variant", ""))
		if not pieces.is_empty():
			pieces.sort()
			var gift: String = pieces[GameClock.day_key() % pieces.size()]
			await say(who.id, ["Oh! I made one of these and I've no room for it. Would you like it? %s!" % catch.capitalize()])
			_give(gift)


func _shop(mode: String) -> void:
	if Game.shop == null:
		return
	Game.shop.open(mode)
	await Game.shop.closed
	Game.mode = Game.Mode.MENU
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
		if obj["kind"] == "placed" and ItemDB.placeable(obj["item"]).has("room") and not obj.has("resident"):
			return true
	return false
