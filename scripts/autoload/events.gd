extends Node
## Global signal bus. Systems emit here so they don't need references to each other.

signal toast(text: String)
signal inventory_changed
signal currency_changed(amount: int)
signal equipped_changed(item_id: String)
signal day_changed(day_key: int)
signal mode_changed(mode: int)
signal workbench_opened
## Furniture or a building was placed or packed away.
signal placed_changed
## The player walked into a home's door (uid of the home), or out of a room.
signal home_entered(uid: int)
signal home_left
