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
