extends Node
## Global signal bus. Systems emit here so they don't need references to each other.

signal toast(text: String)
signal inventory_changed
## The pockets gained more slots.
signal pockets_resized
signal currency_changed(amount: int)
signal equipped_changed(item_id: String)
signal day_changed(day_key: int)
signal mode_changed(mode: int)
## Home storage was asked for (the pockets at home, or a cupboard there).
signal storage_opened
## A landscaping tool was taken out of the phone's app, swapped, or put away ("").
signal landscaping_changed(tool: String)
## The landscaping Move tool has lifted something (an island object) to carry elsewhere.
signal lift_requested(obj: Dictionary)
signal workbench_opened
## Furniture or a building was placed or packed away.
signal placed_changed
## The player walked into a home's door (uid of the home), or out of a room.
signal home_entered(uid: int)
signal home_left
## Walked through a door inside a home to another of its rooms (0 is the main room).
signal room_door(index: int)
## The player chose to sleep until this hour.
signal sleep_requested(hour: float)
## Marlow is setting sail for a tour island, or back home from one.
signal tour_requested
signal tour_ended
