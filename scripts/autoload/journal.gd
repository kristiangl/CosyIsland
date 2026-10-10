extends Node
## Poppy's Island Journal (data/journal.json): counts what you do, and pays stamps for
## milestones (lifetime goals in tiers, some teaching a recipe) and five daily tasks.
## Stamps buy things from the exchange: bigger pockets, recipes, kits and surprises.
##
## Systems report what happened with `Journal.add(stat)`; the journal does the rest.

signal stamps_changed(stamps: int)
## A milestone tier or daily task was just completed: its text and the stamps it paid.
signal completed(text: String, stamps: int)

const DATA_PATH := "res://data/journal.json"
const DAILY_COUNT := 5

var milestones: Array = []
var daily_pool: Array = []
var exchange: Array = []
var stamps := 0
## Lifetime counters by stat.
var stats: Dictionary = {}
## Milestone id -> tiers already paid.
var tiers: Dictionary = {}
## Today's counters, today's task ids and the ones done.
var today := -1
var today_stats: Dictionary = {}
var today_tasks: Array = []
var today_done: Array = []
## Fish and bugs ever caught, and those given to the museum.
var caught: Array = []
var donated: Array = []


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	milestones = data["milestones"]
	daily_pool = data["daily"]
	exchange = data["exchange"]
	Events.day_changed.connect(func(_key): _roll_day())


func reset() -> void:
	stamps = 0
	stats.clear()
	tiers.clear()
	today = -1
	today_stats.clear()
	today_tasks.clear()
	today_done.clear()
	caught.clear()
	donated.clear()


## A fish or bug was caught: counts it, and notes it in the critter log if it's new.
func catch(id: String) -> void:
	add("fish" if ItemDB.fish.has(id) else "bugs")
	if not id in caught:
		caught.append(id)


## Gives a creature to the museum. Returns false if it already has one.
func donate(id: String) -> bool:
	if id in donated or not ItemDB.is_creature(id):
		return false
	donated.append(id)
	Sfx.play("jingle_ding", 0.0, 1.0, 0.0)
	if not id in caught:
		caught.append(id)
	add("donated")
	return true


## Records something done: wood chopped, things sold, flowers picked... Pays any
## milestone tiers and daily tasks it completes.
func add(stat: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	_roll_day()
	stats[stat] = int(stats.get(stat, 0)) + amount
	today_stats[stat] = int(today_stats.get(stat, 0)) + amount
	for m: Dictionary in milestones:
		if m["stat"] != stat:
			continue
		var paid: int = tiers.get(m["id"], 0)
		var goals: Array = m["goals"]
		while paid < goals.size() and int(stats[stat]) >= int(goals[paid]):
			var reward := int(m["stamps"][paid])
			var text := "%s: %s" % [m["name"], String(m["text"]).replace("{n}", str(int(goals[paid])))]
			var recipe: String = m.get("recipes", {}).get(str(paid), "")
			paid += 1
			tiers[m["id"]] = paid
			_pay(text, reward)
			if recipe != "" and Recipes.recipes.has(recipe) and not Recipes.is_known(recipe):
				Recipes.known.append(recipe)
				Recipes.learned.emit(recipe)
				Events.toast.emit("Poppy wrote you a recipe in the journal: %s!" % ItemDB.display_name(recipe))
	for task: Dictionary in tasks_today():
		if task["stat"] == stat and not task["id"] in today_done and int(today_stats[stat]) >= int(task["n"]):
			today_done.append(task["id"])
			_pay("Today: " + String(task["text"]), int(task["stamps"]))


func _pay(text: String, reward: int) -> void:
	stamps += reward
	Sfx.play("jingle_reward", 0.0, 1.0, 0.0)
	stamps_changed.emit(stamps)
	completed.emit(text, reward)
	Events.toast.emit("Journal: %s. +%d stamps" % [text, reward])


## Today's five tasks (rolled fresh each day, the same for everyone on the island).
func tasks_today() -> Array:
	_roll_day()
	var out: Array = []
	for task: Dictionary in daily_pool:
		if task["id"] in today_tasks:
			out.append(task)
	return out


func _roll_day() -> void:
	var key := GameClock.day_key()
	if key == today:
		return
	today = key
	today_stats.clear()
	today_done.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = (Game.island.data.seed_value if Game.island else 0) * 31 + key
	var ids: Array = daily_pool.map(func(t): return t["id"])
	today_tasks.clear()
	for i in mini(DAILY_COUNT, ids.size()):
		today_tasks.append(ids.pop_at(rng.randi() % ids.size()))


## How far into a milestone you are: {tier, goal, count, done}.
func progress(m: Dictionary) -> Dictionary:
	var paid: int = tiers.get(m["id"], 0)
	var goals: Array = m["goals"]
	return {"tier": paid, "goal": int(goals[mini(paid, goals.size() - 1)]),
		"count": int(stats.get(m["stat"], 0)), "done": paid >= goals.size()}


# --- The exchange --------------------------------------------------------------------

## Whether an offer can be bought now. Returns "" if so, else why not.
func can_buy(offer: Dictionary) -> String:
	if offer.has("pockets"):
		var want: int = offer["pockets"]
		if Inventory.slots.size() >= want:
			return "Your pockets are already that big."
		if Inventory.slots.size() < want - 10:
			return "One size at a time!"
	if offer.get("recipe", false) and Recipes.known.size() >= Recipes.recipes.size():
		return "You know every recipe there is!"
	if offer.has("learn") and Recipes.is_known(offer["learn"]):
		return "You know that one already."
	if stamps < int(offer["cost"]):
		return "You need %d stamps for that." % int(offer["cost"])
	if offer.has("item") and not Inventory.can_fit(offer["item"], int(offer.get("count", 1))):
		return "Your pockets are full!"
	if offer.has("random") and not Inventory.can_fit("wooden_box"):
		return "Your pockets are full!"
	return ""


## Buys an offer with stamps. Returns what you got, or "" if it couldn't be bought.
func buy(offer: Dictionary, rng: RandomNumberGenerator) -> String:
	if can_buy(offer) != "":
		return ""
	var got := ""
	if offer.has("pockets"):
		Inventory.expand(int(offer["pockets"]))
		Story.gossip("upgrade", "pockets")
		got = "%d pocket spaces" % int(offer["pockets"])
	elif offer.get("recipe", false):
		got = "the %s recipe" % ItemDB.display_name(Recipes.learn_random(rng))
	elif offer.has("learn"):
		Recipes.learn(offer["learn"])
		got = "the %s recipe" % ItemDB.display_name(offer["learn"])
	elif offer.has("item"):
		Inventory.add_item(offer["item"], int(offer.get("count", 1)))
		got = offer["name"]
	elif offer.has("random"):
		var pool: Array = ItemDB.items.keys().filter(func(id): return _surprise(id, offer["random"]))
		var id: String = pool[rng.randi() % pool.size()]
		Inventory.add_item(id)
		got = ItemDB.display_name(id)
	stamps -= int(offer["cost"])
	stamps_changed.emit(stamps)
	return got


static func _surprise(id: String, category: String) -> bool:
	var def := ItemDB.get_item(id)
	if def.get("category", "") != category or id == "workbench":
		return false
	return not def.get("placeable", {}).get("structure", false) and not def.get("placeable", {}).has("room")


func to_save() -> Dictionary:
	return {"stamps": stamps, "stats": stats, "tiers": tiers, "today": today,
		"today_stats": today_stats, "today_done": today_done, "caught": caught, "donated": donated}


func from_save(saved: Dictionary) -> void:
	reset()
	stamps = int(saved.get("stamps", 0))
	for k in saved.get("stats", {}):
		stats[k] = int(saved["stats"][k])
	for k in saved.get("tiers", {}):
		tiers[k] = int(saved["tiers"][k])
	for id in saved.get("caught", []):
		if ItemDB.is_creature(id):
			caught.append(id)
	for id in saved.get("donated", []):
		if ItemDB.is_creature(id):
			donated.append(id)
	var day := int(saved.get("today", -1))
	if day == GameClock.day_key():
		_roll_day()
		for k in saved.get("today_stats", {}):
			today_stats[k] = int(saved["today_stats"][k])
		today_done.assign(saved.get("today_done", []))
	stamps_changed.emit(stamps)
