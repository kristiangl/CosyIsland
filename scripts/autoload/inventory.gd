extends Node
## The player's pockets, currency and equipped tool.
##
## Each slot is either {} (empty) or {"id": String, "count": int} with an optional
## "durability" for tools.

const START_SLOTS := 20

var slots: Array[Dictionary] = []
var currency: int = 0
var equipped_slot: int = -1
## Clothes you own (item ids), worn from the wardrobe any time.
var closet: Array[String] = []


func _ready() -> void:
	reset()


func reset() -> void:
	slots.clear()
	for i in START_SLOTS:
		slots.append({})
	currency = 0
	equipped_slot = -1
	closet.clear()


## Adds items, filling existing stacks first. Returns how many didn't fit.
func add_item(id: String, count: int = 1) -> int:
	var stack := ItemDB.max_stack(id)
	var remaining := count
	for slot in slots:
		if remaining <= 0:
			break
		if slot.get("id", "") == id and slot["count"] < stack:
			var moved: int = min(stack - slot["count"], remaining)
			slot["count"] += moved
			remaining -= moved
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var moved: int = min(stack, remaining)
			slots[i] = {"id": id, "count": moved}
			var durability: int = ItemDB.get_item(id).get("durability", 0)
			if durability > 0:
				slots[i]["durability"] = durability
			remaining -= moved
	if remaining != count:
		Events.inventory_changed.emit()
	return remaining


func can_fit(id: String, count: int = 1) -> bool:
	var stack := ItemDB.max_stack(id)
	var space := 0
	for slot in slots:
		if slot.is_empty():
			space += stack
		elif slot["id"] == id:
			space += stack - slot["count"]
	return space >= count


func count_of(id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.get("id", "") == id:
			total += slot["count"]
	return total


## Removes items by id from wherever they are, last slots first. Returns how many
## couldn't be found.
func remove_item(id: String, count: int) -> int:
	var remaining := count
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		if slots[i].get("id", "") == id:
			var take: int = mini(slots[i]["count"], remaining)
			remaining -= take
			remove_from_slot(i, take)
	return remaining


func remove_from_slot(index: int, count: int = 1) -> void:
	var slot := slots[index]
	if slot.is_empty():
		return
	slot["count"] -= count
	if slot["count"] <= 0:
		slots[index] = {}
		if index == equipped_slot:
			equip(-1)
	Events.inventory_changed.emit()


func equipped_id() -> String:
	if equipped_slot < 0 or equipped_slot >= slots.size():
		return ""
	return slots[equipped_slot].get("id", "")


func equip(index: int) -> void:
	equipped_slot = index
	Events.equipped_changed.emit(equipped_id())


## Cycles through the tools in the pockets (plus empty hands).
func cycle_tool(direction: int) -> void:
	var tool_slots: Array[int] = [-1]
	for i in slots.size():
		if ItemDB.is_tool(slots[i].get("id", "")):
			tool_slots.append(i)
	var pos := tool_slots.find(equipped_slot)
	equip(tool_slots[posmod(pos + direction, tool_slots.size())])


## Uses up one point of durability on the equipped tool. Returns false if it broke.
func wear_equipped() -> bool:
	if equipped_slot < 0:
		return true
	var slot := slots[equipped_slot]
	if not slot.has("durability"):
		return true
	slot["durability"] -= 1
	if slot["durability"] <= 0:
		var name := ItemDB.display_name(slot["id"])
		remove_from_slot(equipped_slot)
		Events.toast.emit("Oh no! Your %s broke!" % name.to_lower())
		return false
	return true


## Puts on a piece of clothing from the pockets: it joins the closet for good.
func wear_from_slot(index: int, look: Dictionary) -> Dictionary:
	var id: String = slots[index].get("id", "")
	if not ItemDB.is_clothing(id):
		return look
	remove_from_slot(index)
	if not id in closet:
		closet.append(id)
	var worn := look.duplicate()
	worn.merge(ItemDB.get_item(id)["wear"], true)
	return worn


## Grows the pockets to `size` slots (they never shrink).
func expand(size: int) -> void:
	while slots.size() < size:
		slots.append({})
	Events.inventory_changed.emit()
	Events.pockets_resized.emit()


func add_currency(amount: int) -> void:
	currency += amount
	Events.currency_changed.emit(currency)


func to_save() -> Dictionary:
	return {"slots": slots.duplicate(true), "currency": currency, "equipped_slot": equipped_slot, "closet": closet.duplicate()}


func from_save(data: Dictionary) -> void:
	reset()
	var saved: Array = data.get("slots", [])
	while slots.size() < saved.size():
		slots.append({})
	for i in min(saved.size(), slots.size()):
		var s: Dictionary = saved[i]
		if not s.is_empty() and ItemDB.has_item(s["id"]):
			s["count"] = int(s["count"])
			if s.has("durability"):
				s["durability"] = int(s["durability"])
			slots[i] = s
	currency = int(data.get("currency", 0))
	for id in data.get("closet", []):
		if ItemDB.is_clothing(id) and not id in closet:
			closet.append(id)
	equipped_slot = int(data.get("equipped_slot", -1))
	Events.inventory_changed.emit()
	Events.currency_changed.emit(currency)
	Events.equipped_changed.emit(equipped_id())
