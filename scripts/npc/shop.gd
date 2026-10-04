class_name Shop
extends RefCounted
## The island's shops. Lucy's ("lucy"): a few things for sale each day (furniture,
## wallpaper and flooring, and clothes, chosen by the island and the day), and buying
## back anything with a price. Daisy and Morris's ("tailors"): clothes only, more of
## them, and they don't buy.
## Things sell to Lucy for their listed price and cost four times that to buy. Once her
## shop is built (Story "shop_done") she stocks twice as much, plus flower plants from
## other islands.

const BUY_MARKUP := 4
## Always in stock, however many you buy.
const STAPLES := ["flimsy_axe", "flimsy_shovel", "customisation_kit"]
const FURNITURE_PER_DAY := 4
const INTERIORS_PER_DAY := 2
const CLOTHES_PER_DAY := 3
const PLANTS_PER_DAY := 2
## What the tailors put out each day.
const TAILOR_CLOTHES_PER_DAY := 12


static func buy_price(id: String) -> int:
	return maxi(40, int(ItemDB.get_item(id).get("price", 0)) * BUY_MARKUP)


static func sell_price(id: String) -> int:
	return int(ItemDB.get_item(id).get("price", 0))


static func can_sell(id: String) -> bool:
	return sell_price(id) > 0


## Today's stock: staples first, then the day's furniture, wallpaper or flooring, and clothes.
## 0 at the counter, 1 once the shop is built.
static func level() -> int:
	return 1 if Story.flags.get("shop_done", false) else 0


static func stock(island_seed: int, day: int, native_flower: String = "", keeper: String = "lucy") -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = island_seed * 7919 + day + (104729 if keeper == "tailors" else 0)
	var furniture: Array[String] = []
	var interiors: Array[String] = []
	var clothes: Array[String] = []
	var plants: Array[String] = []
	for id in ItemDB.items:
		var def := ItemDB.get_item(id)
		match def.get("category", ""):
			"furniture":
				if id != "workbench" and not def.get("placeable", {}).get("structure", false):
					furniture.append(id)
			"interior":
				interiors.append(id)
			"clothing":
				clothes.append(id)
			"flower_plant":
				if def.get("species", "") != native_flower:
					plants.append(id)
	furniture.sort()
	interiors.sort()
	clothes.sort()
	plants.sort()
	if keeper == "tailors":
		return _pick(rng, clothes, TAILOR_CLOTHES_PER_DAY)
	var more := 1 + level()
	var out: Array[String] = []
	out.append_array(STAPLES)
	out.append_array(_pick(rng, furniture, FURNITURE_PER_DAY * more))
	out.append_array(_pick(rng, interiors, INTERIORS_PER_DAY * more))
	out.append_array(_pick(rng, clothes, CLOTHES_PER_DAY * more))
	if level() > 0:
		out.append_array(_pick(rng, plants, PLANTS_PER_DAY))
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


## Buys one of an item. Returns "" on success, or why not.
static func buy(id: String, day: int, keeper: String = "lucy") -> String:
	if is_sold_out(id, day, keeper):
		return "That's sold out today, sorry!"
	var cost := buy_price(id)
	if Inventory.currency < cost:
		return "You need %d %s for that." % [cost, Game.CURRENCY_NAME.to_lower()]
	if not Inventory.can_fit(id):
		return "Your pockets are full!"
	Inventory.add_item(id)
	Inventory.add_currency(-cost)
	Journal.add("bought")
	if not id in STAPLES:
		var ids := sold_today(day, keeper).duplicate()
		ids.append(id)
		Story.flags["shop_sold" if keeper == "lucy" else keeper + "_sold"] = {"day": day, "ids": ids}
	return ""


## Sells `count` of the item in a pocket slot. Returns the acorns earned.
static func sell(slot: int, count: int) -> int:
	var entry := Inventory.slots[slot]
	if entry.is_empty() or not can_sell(entry["id"]):
		return 0
	var n := mini(count, int(entry.get("count", 1)))
	var earned := sell_price(entry["id"]) * n
	if slot == Inventory.equipped_slot and n >= int(entry.get("count", 1)):
		Inventory.equip(-1)
	Inventory.remove_from_slot(slot, n)
	Inventory.add_currency(earned)
	Journal.add("sold", n)
	Journal.add("acorns_earned", earned)
	return earned
