extends Node
## Real-time game clock in the player's local time, plus a time travel offset.
##
## The island runs on the system clock. Time travel just shifts `offset_seconds`, which
## is saved. `time_scale` speeds the clock up for testing and is not saved.

## A new island day starts at this hour, so late-night play still counts as "today".
const DAY_START_HOUR := 5

const WEEKDAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var offset_seconds: int = 0
var time_scale: float = 1.0
var _scaled_extra: float = 0.0
var _last_day_key: int = -1


func _ready() -> void:
	_last_day_key = day_key()


func _process(delta: float) -> void:
	if time_scale != 1.0:
		_scaled_extra += delta * (time_scale - 1.0)
	var key := day_key()
	if key != _last_day_key:
		_last_day_key = key
		Events.day_changed.emit(key)


## Seconds since the Unix epoch, in local time, including time travel.
func local_unix() -> int:
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	return int(Time.get_unix_time_from_system()) + bias_minutes * 60 + offset_seconds + int(_scaled_extra)


func datetime() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(local_unix())


## Hour of the day as a float, e.g. 13.5 for half past one.
func hour_float() -> float:
	var t := local_unix() % 86400
	return t / 3600.0


## Island day number. Changes at DAY_START_HOUR rather than midnight.
func day_key() -> int:
	return floori((local_unix() - DAY_START_HOUR * 3600) / 86400.0)


func time_string() -> String:
	var d := datetime()
	var h: int = d["hour"] % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, d["minute"], "AM" if d["hour"] < 12 else "PM"]


func date_string() -> String:
	var d := datetime()
	return "%s %d %s" % [WEEKDAYS[d["weekday"]], d["day"], MONTHS[d["month"] - 1]]


## Time travel: move the clock by a number of seconds (negative goes back).
func travel(seconds: int) -> void:
	offset_seconds += seconds


## Time travel to a given hour today, keeping the date.
func set_hour(hour: float) -> void:
	var current := local_unix()
	var start_of_day := current - current % 86400
	offset_seconds += int(start_of_day + hour * 3600.0) - current


func reset_travel() -> void:
	offset_seconds = 0
	_scaled_extra = 0.0
