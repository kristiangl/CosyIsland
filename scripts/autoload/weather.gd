extends Node
## The island's weather and seasons.
##
## Every day has a plan, picked from the island's seed and the date, so it's the same
## however often you look: clear, cloudy, showers (a few hours of rain), rain (most of
## the day) or a storm, maybe with a misty morning, a windy day or a rainbow after the
## showers. Seasons follow the real calendar for the island's hemisphere (Story.flags
## "hemisphere", "south" unless set): autumn leaves, spring blossom, and snow on the
## ground (and snow instead of rain) in the depths of winter.
##
## The state right now is kept in plain numbers, worked out a few times a second, for
## DayNight, AmbientEffects and the shaders to read.

const KINDS := ["clear", "cloudy", "showers", "rain", "storm"]
const SEASONS := ["spring", "summer", "autumn", "winter"]
## How likely each kind of day is in each season.
const WEIGHTS := {
	"spring": {"clear": 40, "cloudy": 25, "showers": 22, "rain": 9, "storm": 4},
	"summer": {"clear": 55, "cloudy": 14, "showers": 15, "rain": 5, "storm": 11},
	"autumn": {"clear": 35, "cloudy": 30, "showers": 18, "rain": 12, "storm": 5},
	"winter": {"clear": 30, "cloudy": 35, "showers": 15, "rain": 15, "storm": 5},
}
## What the weather can be forced to (screenshots, the phone's time travel page).
const FORCES := ["", "clear", "cloudy", "showers", "rain", "storm", "snow", "mist", "rainbow", "windy", "meteors"]

## Forces the weather all day ("" for the real forecast), and the season.
var force := ""
var force_season := ""

# The state right now (see _update).
## Cloud cover: 0 clear blue sky, 1 overcast.
var clouds := 0.25
## Rain and snow falling, 0 to 1.
var rain := 0.0
var snow := 0.0
## 0 to 1 while a storm is on (lightning).
var storm := 0.0
var mist := 0.0
var rainbow := 0.0
## How often shooting stars cross the sky tonight (0 to 1): now and then on clear nights,
## lots on a meteor shower night.
var meteors := 0.0
## How wet the ground is: wet while it rains and drying for a while after.
var wetness := 0.0
var wind := 1.0
## Snow lying on the ground (deep winter).
var snow_cover := 0.0
## How far through their turn the trees are: autumn colours, spring blossom.
var autumn := 0.0
var blossom := 0.0
var season := "spring"

var _plans: Dictionary = {}
var _check := 0.0


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.25
		update(GameClock.hour_float())


func hemisphere() -> String:
	return Story.flags.get("hemisphere", "south")


func _seed() -> int:
	return Game.island.data.seed_value if Game.island and Game.island.data else 0


## The date (a GameClock datetime dictionary) at midday on an island day.
static func date_of(key: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(key * 86400 + 12 * 3600)


## The season on a date, and how far through it (0 to 1).
func season_on(date: Dictionary) -> Array:
	if force_season != "":
		return [force_season, 0.5]
	var month: int = date["month"]
	if hemisphere() == "south":
		month = (month + 5) % 12 + 1
	# Spring is March to May in the north; each season is three months.
	var index := posmod(month - 3, 12) / 3
	var into := posmod(month - 3, 12) % 3
	return [SEASONS[index], (into + (date["day"] - 1) / 31.0) / 3.0]


## True on days in the depths of winter, when snow lies and falls instead of rain.
func snowy(key: int) -> bool:
	if force == "snow":
		return true
	var s := season_on(date_of(key))
	return s[0] == "winter" and s[1] > 0.12 and s[1] < 0.9


## The day's weather: {"kind", "from", "to" (hours of rain or snow, counting on past
## midnight to 29), "mist", "windy", "rainbow", "snow"}.
func plan(key: int) -> Dictionary:
	if force != "":
		return _forced(key)
	if _plans.has(key):
		return _plans[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed(), key, "weather"])
	var s: String = season_on(date_of(key))[0]
	var weights: Dictionary = WEIGHTS[s]
	var total := 0
	for k: String in weights:
		total += weights[k]
	var roll := rng.randi_range(0, total - 1)
	var kind := "clear"
	for k: String in KINDS:
		roll -= weights[k]
		if roll < 0:
			kind = k
			break
	var p := {"kind": kind, "from": -1.0, "to": -1.0, "mist": false, "windy": false, "rainbow": false, "snow": snowy(key)}
	match kind:
		"showers":
			p["from"] = rng.randf_range(8.0, 17.0)
			p["to"] = p["from"] + rng.randf_range(1.5, 3.5)
		"rain":
			p["from"] = rng.randf_range(4.0, 9.0)
			p["to"] = rng.randf_range(19.0, 29.5)
		"storm":
			p["from"] = rng.randf_range(12.0, 19.0)
			p["to"] = p["from"] + rng.randf_range(3.0, 5.5)
	p["mist"] = kind in ["clear", "cloudy"] and s != "summer" and rng.randf() < 0.3
	p["windy"] = kind == "storm" or rng.randf() < 0.12
	p["rainbow"] = kind == "showers" and not p["snow"] and p["to"] > 9.0 and p["to"] < 17.5 and rng.randf() < 0.65
	p["meteors"] = kind == "clear" and rng.randf() < 0.15
	if _plans.size() > 16:
		_plans.clear()
	_plans[key] = p
	return p


func _forced(key: int) -> Dictionary:
	var p := {"kind": "clear", "from": -1.0, "to": -1.0, "mist": false, "windy": false, "rainbow": false, "snow": snowy(key),
		"meteors": force == "meteors"}
	match force:
		"cloudy":
			p["kind"] = "cloudy"
		"rain", "snow", "storm":
			p["kind"] = "storm" if force == "storm" else "rain"
			p["from"] = 0.0
			p["to"] = 30.0
		"showers":
			p["kind"] = "showers"
			p["from"] = 0.0
			p["to"] = 30.0
		"mist":
			p["mist"] = true
		"rainbow":
			p["kind"] = "showers"
			p["rainbow"] = true
		"windy":
			p["windy"] = true
	return p


## Works out the state at `hour` today.
func update(hour: float) -> void:
	var key := GameClock.day_key()
	var p := plan(key)
	var h := hour if hour >= GameClock.DAY_START_HOUR else hour + 24.0
	var s := season_on(date_of(key))
	season = s[0]
	var t: float = s[1]
	autumn = (smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.9, 1.0, t) * 0.4)) if season == "autumn" else 0.0
	blossom = (smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.4, 0.55, t))) if season == "spring" else 0.0
	snow_cover = 1.0 if p["snow"] and (season == "winter" or force == "snow") else 0.0
	var falling := 0.0
	var near := 0.0
	if p["from"] >= 0.0:
		falling = smoothstep(p["from"] - 0.3, p["from"] + 0.3, h) * (1.0 - smoothstep(p["to"] - 0.3, p["to"] + 0.3, h))
		near = smoothstep(p["from"] - 1.5, p["from"], h) * (1.0 - smoothstep(p["to"], p["to"] + 1.5, h))
	var strength: float = {"showers": 0.6, "rain": 0.8, "storm": 1.0}.get(p["kind"], 0.0)
	rain = 0.0 if p["snow"] else falling * strength
	snow = falling * strength if p["snow"] else 0.0
	storm = falling if p["kind"] == "storm" else 0.0
	match p["kind"]:
		"clear":
			clouds = 0.3
		"cloudy":
			clouds = 0.8
		"showers":
			clouds = lerpf(0.45, 1.0, near)
		"rain":
			clouds = lerpf(0.75, 1.0, near)
		"storm":
			clouds = lerpf(0.55, 1.0, near)
	mist = (1.0 - smoothstep(8.0, 9.5, h)) if p["mist"] else 0.0
	rainbow = 0.0
	if p["rainbow"]:
		rainbow = 1.0 if force == "rainbow" else smoothstep(p["to"] + 0.1, p["to"] + 0.4, h) * (1.0 - smoothstep(p["to"] + 1.3, p["to"] + 1.8, h))
	wetness = 0.0
	if not p["snow"] and p["from"] >= 0.0:
		wetness = maxf(falling, (1.0 - clampf((h - p["to"]) / 2.0, 0.0, 1.0)) * float(h >= p["to"]))
		if force == "rainbow":
			wetness = 0.5
	wind = 1.0 + (1.2 if p["windy"] else 0.0) + storm * 0.8
	meteors = 0.0
	if p["kind"] == "clear":
		meteors = 0.85 if p.get("meteors", false) else 0.05


## A line for the phone: what today's weather is doing.
func forecast(key: int = GameClock.day_key()) -> String:
	var p := plan(key)
	var what := "snow" if p["snow"] else "rain"
	var text := ""
	match p["kind"]:
		"clear":
			text = "Sunny"
		"cloudy":
			text = "Cloudy"
		"showers":
			text = "%s showers around %s" % [what.capitalize(), _hour_name(p["from"])]
		"rain":
			text = "%s most of the day" % ("Snowing" if p["snow"] else "Rain")
		"storm":
			text = ("Snowstorm" if p["snow"] else "Storms") + " from about " + _hour_name(p["from"])
	if p["mist"]:
		text += ", misty morning"
	if p["windy"] and p["kind"] != "storm":
		text += ", breezy"
	if p.get("meteors", false):
		text += ". Shooting stars tonight!"
	return text


static func _hour_name(h: float) -> String:
	var hour := int(h) % 24
	var shown := hour % 12
	return "%d%s" % [12 if shown == 0 else shown, "am" if hour < 12 else "pm"]
