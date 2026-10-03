class_name Shop
extends RefCounted
## Lucy's shop: a few things for sale each day (furniture, wallpaper and flooring, and
## clothes; one of each, chosen by the island and the day), and buying back anything
## with a price. Things sell to Lucy for their
## listed price and cost four times that to buy.

const BUY_MARKUP := 4
## Always in stock, however many you buy.
const STAPLES := ["flimsy_axe", "flimsy_shovel"]
const FURNITURE_PER_DAY := 4
const INTERIORS_PER_DAY := 2
const CLOTHES_PER_DAY := 3


static func buy_price(id: String) -> int:
	return maxi(40, int(ItemDB.get_item(id).get("price", 0)) * BUY_MARKUP)


static func sell_price(id: String) -> int:
	return int(ItemDB.get_item(id).get("price", 0))


static func can_sell(id: String) -> bool:
	return sell_price(id) > 0


## Today's stock: staples first, then the day's furniture, wallpaper or flooring, and clothes.
static func stock(island_seed: int, day: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = island_seed * 7919 + day
	var furniture: Array[String] = []
	var interiors: Array[String] = []
	var clothes: Array[String] = []
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
	furniture.sort()
	interiors.sort()
	clothes.sort()
	var out: Array[String] = []
	out.append_array(STAPLES)
	out.append_array(_pick(rng, furniture, FURNITURE_PER_DAY))
	out.append_array(_pick(rng, interiors, INTERIORS_PER_DAY))
	out.append_array(_pick(rng, clothes, CLOTHES_PER_DAY))
	return out


static func _pick(rng: RandomNumberGenerator, from: Array[String], count: int) -> Array[String]:
	var pool := from.duplicate()
	var out: Array[String] = []
	for i in mini(count, pool.size()):
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## Things from today's stock already bought (staples never sell out).
static func sold_today(day: int) -> Array:
	var sold: Dictionary = Story.flags.get("shop_sold", {})
	return sold.get("ids", []) if int(sold.get("day", -1)) == day else []


static func is_sold_out(id: String, day: int) -> bool:
	return not id in STAPLES and id in sold_today(day)


## Buys one of an item. Returns "" on success, or why not.
static func buy(id: String, day: int) -> String:
	if is_sold_out(id, day):
		return "That's sold out today, sorry!"
	var cost := buy_price(id)
	if Inventory.currency < cost:
		return "You need %d %s for that." % [cost, Game.CURRENCY_NAME.to_lower()]
	if not Inventory.can_fit(id):
		return "Your pockets are full!"
	Inventory.add_item(id)
	Inventory.add_currency(-cost)
	if not id in STAPLES:
		var ids := sold_today(day).duplicate()
		ids.append(id)
		Story.flags["shop_sold"] = {"day": day, "ids": ids}
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
	return earned
