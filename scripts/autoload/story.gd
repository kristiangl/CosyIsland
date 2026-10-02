extends Node
## The island's story so far and everything its characters say.
##
## `flags` remembers which conversations have happened and what's been handed over,
## and is saved with the game. Lines can use {player}, {island}, {fruit} and {flower},
## and button names like {pockets} (see Prompts).

var flags: Dictionary = {}
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
	match who.id:
		"poppy":
			await _poppy(who)
		"lucy":
			await _lucy(who)
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
		var pick := await ask("poppy", "Anything you'd like to know?", ["How do I make things?", "What is there to do?", "I'm all set!"])
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


func _lucy(lucy: Npc) -> void:
	if not flags.get("met_lucy", false):
		flags["met_lucy"] = true
		lucy.hop()
		await say("lucy", [
			"Hi hi hi! You're new! I'm Lucy! I do odd jobs, fix things and dig holes. Mostly dig holes.",
			"This is the workbench! Bring wood, stone and clay and you can make all sorts.",
			"Walk up to it and press {use} to see what you know how to make.",
			"Oh! And if you find a bottle on the beach, open it! Sometimes there's a recipe inside!",
			"One day I'm going to open a shop here. A real one. With a bell on the door!",
		])
		lucy.cheer()
		return
	await say("lucy", [_small_talk("lucy", [
		"I found a stick today. It's a really good stick.",
		"You can sit on chairs, you know. I sit on everything. Benches, stumps, Poppy's paperwork...",
		"Small things like teapots and candles can go on tables. Very fancy!",
		"If you shake a tree and furniture falls out, don't ask me how it got up there.",
		"My shop will sell everything. Probably. Maybe just sticks at first.",
		"Rocks give more if you hit them fast. Bonk bonk bonk!",
	])])


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
		if obj["kind"] == "placed" and ItemDB.placeable(obj["item"]).has("room"):
			return true
	return false
