class_name Shop
extends RefCounted
## The island's shops. Lucy's ("lucy"): a few things for sale each day (furniture,
## wallpaper and flooring, and everyday clothes, chosen by the island and the day), and
## buying back anything with a price. Daisy and Morris's ("tailors"): designed clothes
## only, more of them, and they don't buy.
## Things sell to Lucy for their listed price and cost four times that to buy. Once her
## shop is built (Story "shop_done") she stocks twice as much, plus flower plants from
## other islands.
## Daily visitors keep stalls too (KEEPERS): Fennel's fabrics and Tansy's seeds to buy,
## and Basil and Marina, who only buy bugs or fish, for half as much again.

const BUY_MARKUP := 4
## Always in stock, however many you buy.
const STAPLES := ["flimsy_axe", "flimsy_pickaxe", "flimsy_shovel", "customisation_kit"]
const FURNITURE_PER_DAY := 4
const INTERIORS_PER_DAY := 2
const CLOTHES_PER_DAY := 3
const PLANTS_PER_DAY := 2
## What the tailors put out each day.
const TAILOR_CLOTHES_PER_DAY := 12
## Every counter: its title, whether you can buy or sell there (the first is where it
## opens), who pays you, and what a buyer-only stall wants and how well it pays.
const KEEPERS := {
	"lucy": {"title": "Lucy's Odds & Ends", "modes": ["buy", "sell"], "who": "Lucy"},
	"tailors": {"title": "Daisy & Morris Tailoring", "modes": ["buy"], "who": "Daisy"},
	"fennel": {"title": "Fennel's Fabric Cart", "modes": ["buy"], "who": "Fennel"},
	"tansy": {"title": "Tansy's Seed Barrow", "modes": ["buy"], "who": "Tansy"},
	"basil": {"title": "Basil's Bug Swap", "modes": ["sell"], "who": "Basil", "buys": "bug", "rate": 1.5},
	"marina": {"title": "Marina's Fish Stall", "modes": ["sell"], "who": "Marina", "buys": "fish", "rate": 1.5},
}
## How many things Fennel and Tansy bring.
const FENNEL_PER_DAY := 8
const TANSY_PER_DAY := 5


static func buy_price(id: String) -> int:
	return maxi(40, int(ItemDB.get_item(id).get("price", 0)) * BUY_MARKUP)


## Fruit that doesn't grow on your island sells for this many times as much.
const FOREIGN_FRUIT := 3


static func sell_price(id: String, keeper: String = "lucy") -> int:
	var def := ItemDB.get_item(id)
	var price := int(def.get("price", 0))
	if def.get("category", "") == "fruit" and Game.island and id != Game.island.data.native_fruit:
		price *= FOREIGN_FRUIT
	var buys: String = KEEPERS.get(keeper, {}).get("buys", "")
	if buys != "":
		if def.get("category", "") != buys:
			return 0
		price = roundi(price * float(KEEPERS[keeper]["rate"]))
	return price


static func can_sell(id: String, keeper: String = "lucy") -> bool:
	return sell_price(id, keeper) > 0


## Today's stock: staples first, then the day's furniture, wallpaper or flooring, and clothes.
## 0 at the counter, 1 once the shop is built.
static func level() -> int:
	return 1 if Story.flags.get("shop_done", false) else 0


static func stock(island_seed: int, day: int, native_flower: String = "", keeper: String = "lucy") -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = island_seed * 7919 + day + ({"lucy": 0, "tailors": 104729}.get(keeper, absi(hash(keeper)) % 1000003) as int)
	var furniture: Array[String] = []
	var interiors: Array[String] = []
	var clothes: Array[String] = []
	var plants: Array[String] = []
	var umbrellas: Array[String] = []
	for id in ItemDB.items:
		var def := ItemDB.get_item(id)
		match def.get("category", ""):
			"furniture":
				if id != "workbench" and not def.get("placeable", {}).get("structure", false):
					furniture.append(id)
			"interior":
				interiors.append(id)
			"clothing":
				# Designed pieces; everyday ones are made up for Lucy's rail below.
				if not def.get("basic", false):
					clothes.append(id)
			"tool":
				if def.get("tool", "") == "umbrella":
					umbrellas.append(id)
			"flower_plant":
				if def.get("species", "") != native_flower and not ItemDB.is_rare_flower(def["species"], def["flower_color"]):
					plants.append(id)
	furniture.sort()
	interiors.sort()
	clothes.sort()
	plants.sort()
	if keeper == "tailors":
		return _pick(rng, clothes, TAILOR_CLOTHES_PER_DAY)
	if keeper == "fennel":
		# Wallpaper, flooring, curtains and rugs.
		var fabrics := interiors.duplicate()
		for id: String in furniture:
			if ItemDB.placeable(id).get("rug", false):
				fabrics.append(id)
		return _pick(rng, fabrics, FENNEL_PER_DAY)
	if keeper == "tansy":
		return tansy_stock(rng, native_flower)
	var more := 1 + level()
	var out: Array[String] = []
	out.append_array(STAPLES)
	umbrellas.sort()
	out.append_array(_pick(rng, umbrellas, 1))
	out.append_array(_pick(rng, furniture, FURNITURE_PER_DAY * more))
	out.append_array(_pick(rng, interiors, INTERIORS_PER_DAY * more))
	var everyday: Array[String] = []
	for i in CLOTHES_PER_DAY * more * 4:
		var id := ItemDB.random_basic(rng)
		if id != "" and not id in everyday:
			everyday.append(id)
		if everyday.size() == CLOTHES_PER_DAY * more:
			break
	out.append_array(everyday)
	if level() > 0:
		out.append_array(_pick(rng, plants, PLANTS_PER_DAY))
	return out


## Tansy's barrow: flower plants in colours you'd otherwise only find on far-off
## islands (one of them really rare), and fruit for planting from elsewhere.
static func tansy_stock(rng: RandomNumberGenerator, native_flower: String) -> Array[String]:
	var plants: Array[String] = []
	var rare: Array[String] = []
	for id: String in ItemDB.items:
		var def := ItemDB.get_item(id)
		if def.get("category", "") == "flower_plant" and def.get("species", "") != native_flower:
			if ItemDB.is_rare_flower(def["species"], def["flower_color"]):
				rare.append(id)
			else:
				plants.append(id)
	plants.sort()
	rare.sort()
	var out := _pick(rng, rare, 1)
	out.append_array(_pick(rng, plants, TANSY_PER_DAY - 3))
	var fruit: Array[String] = []
	for f: String in IslandGenerator.FRUITS:
		if not Game.island or f != Game.island.data.native_fruit:
			fruit.append(f)
	out.append_array(_pick(rng, fruit, 2))
	return out


static func _pick(rng: RandomNumberGenerator, from: Array[String], count: int) -> Array[String]:
	var pool := from.duplicate()
	var out: Array[String] = []
	for i in mini(count, pool.size()):
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## Things from today's stock already bought (staples never sell out).
static func sold_today(day: int, keeper: String = "lucy") -> Array:
	var sold: Dictionary = Story.flags.get("shop_sold" if keeper == "lucy" else keeper + "_sold", {})
	return sold.get("ids", []) if int(sold.get("day", -1)) == day else []


static func is_sold_out(id: String, day: int, keeper: String = "lucy") -> bool:
	return not id in STAPLES and id in sold_today(day, keeper)


## Buys one of an item. Returns "" on success, or why not. Clothes bought in the fitting
## room (`wearing`) go straight into the wardrobe.
static func buy(id: String, day: int, keeper: String = "lucy", wearing := false) -> String:
	if is_sold_out(id, day, keeper):
		return "That's sold out today, sorry!"
	var cost := buy_price(id)
	if Inventory.currency < cost:
		return "You need %d %s for that." % [cost, Game.CURRENCY_NAME.to_lower()]
	if wearing:
		if not id in Inventory.closet:
			Inventory.closet.append(id)
	elif not Inventory.can_fit(id):
		return "Your pockets are full!"
	else:
		Inventory.add_item(id)
	Inventory.add_currency(-cost)
	Journal.add("bought")
	if not id in STAPLES:
		var ids := sold_today(day, keeper).duplicate()
		ids.append(id)
		Story.flags["shop_sold" if keeper == "lucy" else keeper + "_sold"] = {"day": day, "ids": ids}
	return ""


## Sells `count` of the item in a pocket slot. Returns the acorns earned.
static func sell(slot: int, count: int, keeper: String = "lucy") -> int:
	var entry := Inventory.slots[slot]
	if entry.is_empty() or not can_sell(entry["id"], keeper):
		return 0
	var n := mini(count, int(entry.get("count", 1)))
	var earned := sell_price(entry["id"], keeper) * n
	if slot == Inventory.equipped_slot and n >= int(entry.get("count", 1)):
		Inventory.equip(-1)
	Inventory.remove_from_slot(slot, n)
	Inventory.add_currency(earned)
	Journal.add("sold", n)
	Journal.add("acorns_earned", earned)
	return earned
