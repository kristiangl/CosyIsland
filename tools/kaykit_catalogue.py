"""Generates the KayKit furniture series and decorations for Cosy Island.

    python3 tools/kaykit_catalogue.py /path/to/KayKit

Writes the model entries into tools/kaykit.json, the series into data/furniture/
(comfy, kitchen, festive) and the decorations into data/items.json, with footprints
and table heights measured from the models. Safe to run again (it replaces what it
made before, and won't overwrite any other item); then run tools/kaykit_import.gd to
convert the models.
"""
import json, math, os, sys

SRC = sys.argv[1].rstrip("/") + "/"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
PACKS = {
    "furniture": ("KayKit_Furniture_Bits_1.0_FREE/Assets/gltf/", 0.66),
    "restaurant": ("KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/", 0.5),
    "holiday": ("KayKit_Holiday_Bits_1.0_FREE/Assets/gltf/", 0.5),
    "mixed": ("KayKit_Mixed_Bag_1_FREE/Assets/gltf/", 0.5),
    "halloween": ("KayKit_HalloweenBits_1.0_FREE/Assets/gltf/", 0.5),
    "hexagon": ("KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/buildings/", 2.2),
    "hexdeco": ("KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/decoration/", 2.2),
    "forest": ("KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/", 0.55),
    "city": ("KayKit_City_Builder_Bits_1.0_FREE/Assets/gltf/", 2.6),
    "platformer": ("KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/", 0.5),
    "resource": ("KayKit_ResourceBits_1.0_FREE/Assets/gltf/", 0.5),
}

def _matrix(node):
    """A glTF node's local transform as a 3x4 matrix (rows)."""
    if "matrix" in node:
        m = node["matrix"]
        return [[m[0], m[4], m[8], m[12]], [m[1], m[5], m[9], m[13]], [m[2], m[6], m[10], m[14]]]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    tx, ty, tz = node.get("translation", [0, 0, 0])
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[i][0] * sx, r[i][1] * sy, r[i][2] * sz, t] for i, t in enumerate((tx, ty, tz))]


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) + (a[i][3] if j == 3 else 0) for j in range(4)] for i in range(3)]


def bounds(pack, model):
    """The model's size in game units at the pack's scale, with its node transforms."""
    path = SRC + PACKS[pack][0] + model + ".gltf"
    g = json.load(open(path))
    parent = {}
    for i, n in enumerate(g.get("nodes", [])):
        for c in n.get("children", []):
            parent[c] = i
    mn = [1e9] * 3; mx = [-1e9] * 3
    for i, n in enumerate(g.get("nodes", [])):
        if "mesh" not in n:
            continue
        m = _matrix(n)
        at = parent.get(i)
        while at is not None:
            m = _mul(_matrix(g["nodes"][at]), m)
            at = parent.get(at)
        for p in g["meshes"][n["mesh"]]["primitives"]:
            a = g["accessors"][p["attributes"]["POSITION"]]
            for cx in (a["min"][0], a["max"][0]):
                for cy in (a["min"][1], a["max"][1]):
                    for cz in (a["min"][2], a["max"][2]):
                        v = [m[r][0] * cx + m[r][1] * cy + m[r][2] * cz + m[r][3] for r in range(3)]
                        mn = [min(q, w) for q, w in zip(mn, v)]
                        mx = [max(q, w) for q, w in zip(mx, v)]
    s = PACKS[pack][1]
    return [(mx[i] - mn[i]) * s for i in range(3)]

models = {}

def model(pack, name, scale=None, look=None):
    key = "%s_%s" % (pack, os.path.basename(name).lower())
    models[key] = {"src": PACKS[pack][0] + name + ".gltf", "scale": scale or PACKS[pack][1]}
    if look and "fit" in look:
        # Nature pieces fit a size instead, and take the island's own greens and greys.
        del models[key]["scale"]
    models[key].update(look or {})
    return key


def raw_size(pack, name):
    return [x / PACKS[pack][1] for x in bounds(pack, name)]


def fitted(pack, name, scale=None, fit=None, turn=0):
    """The size a model ends up in game units (scaled, or fitted inside [width, height])."""
    raw = raw_size(pack, name)
    if fit:
        k = min(fit[0] / max(raw[0], raw[2]), fit[1] / raw[1])
    else:
        k = scale or PACKS[pack][1]
    if abs(int(turn)) % 180 == 90:
        raw = [raw[2], raw[1], raw[0]]
    return [x * k for x in raw]

def footprint(size):
    return [max(1, math.ceil(size[0] - 0.3)), max(1, math.ceil(size[2] - 0.3))]

# What each piece is, for laying out rooms (main.gd _series_layout).
KINDS = {"comfy_armchair": "armchair", "comfy_sofa": "sofa", "comfy_bed": "bed", "comfy_single_bed": "single_bed", "comfy_chair": "chair", "comfy_stool": "stool", "comfy_table": "table", "comfy_long_table": "long_table", "comfy_coffee_table": "coffee_table", "comfy_side_table": "side_table", "comfy_cabinet": "dresser", "comfy_bookshelf": "bookcase", "comfy_floor_lamp": "floor_lamp", "comfy_table_lamp": "table_lamp", "comfy_rug": "rug", "comfy_oval_rug": "oval_rug", "kitchen_fridge": "fridge", "kitchen_stove": "stove", "kitchen_oven": "oven", "kitchen_counter": "counter", "kitchen_sink": "sink", "kitchen_cupboard": "cupboard", "kitchen_table": "table", "kitchen_round_table": "round_table", "kitchen_shelf": "shelf", "festive_wingback": "armchair", "festive_footstool": "stool", "festive_tree": "tree", "festive_rug": "rug", "festive_lamp_post": "lamp_post"}


def piece(id, name, pack, src, price, desc, **extra):
    scale = extra.pop("scale", None)
    key = model(pack, src, scale)
    size = bounds(pack, src)
    if scale:
        size = [x * scale / PACKS[pack][1] for x in size]
    p = {"id": id, "name": name, "kind": KINDS[id], "kaykit": key, "footprint": extra.pop("footprint", footprint(size)),
         "price": price, "desc": desc}
    if extra.pop("table", False):
        p["surface"] = round(size[1], 2)
    p.update(extra)
    return p

# --- Series ----------------------------------------------------------------------------

def ramp(*hexes):
    return list(hexes)

COMFY = {
    "id": "comfy", "name": "Comfy Home",
    "desc": "Squashy sofas, chunky wood and big soft cushions.",
    "variants": [
        {"id": "sunny", "name": "Sunny", "wood": "c4946a", "trim": "a8754f", "fabric": ["f6c46f", "9cc0e4", "plain"],
         "paint": {"wood": ramp("a8754f", "c4946a", "dcb48a"), "orange": ramp("eea85a", "f6c46f", "fbdc96"),
                   "blue": ramp("7fa9d6", "9cc0e4", "bcd6ef")}},
        {"id": "rose", "name": "Rose", "wood": "ebddcf", "trim": "d9c6b4", "fabric": ["eeaab3", "d6a9c6", "plain"],
         "paint": {"wood": ramp("d9c6b4", "ebddcf", "f8f1ea"), "orange": ramp("e2909b", "eeaab3", "f7cbd0"),
                   "blue": ramp("c48fb3", "d6a9c6", "e8c8dc")}},
        {"id": "sage", "name": "Sage", "wood": "a8835f", "trim": "8c6a4e", "fabric": ["b6d19c", "99c4b0", "plain"],
         "paint": {"wood": ramp("8c6a4e", "a8835f", "c29d76"), "orange": ramp("9fbe86", "b6d19c", "cfe3ba"),
                   "blue": ramp("7fae9a", "99c4b0", "b8dccb")}},
        {"id": "midnight", "name": "Midnight", "wood": "735448", "trim": "5a4038", "fabric": ["7787bf", "e8c878", "plain"],
         "paint": {"wood": ramp("5a4038", "735448", "8c6a5a"), "orange": ramp("5f6fa8", "7787bf", "93a2d4"),
                   "blue": ramp("d8b25c", "e8c878", "f4dc9a")}},
    ],
    "pieces": [
        piece("comfy_armchair", "Comfy Armchair", "furniture", "armchair_pillows", 1100, "Deep, squashy and very hard to leave.", seat=0.36),
        piece("comfy_sofa", "Comfy Sofa", "furniture", "couch_pillows", 1800, "Big enough for a nap and a half.", seat=0.36),
        piece("comfy_bed", "Comfy Bed", "furniture", "bed_double_A", 1800, "A double bed with fat pillows.", seat=0.4, bed=True),
        piece("comfy_single_bed", "Comfy Single Bed", "furniture", "bed_single_A", 1200, "Snug, with a chunky wooden frame.", seat=0.4, bed=True),
        piece("comfy_chair", "Comfy Chair", "furniture", "chair_A", 480, "A wooden chair with a padded seat.", seat=0.4),
        piece("comfy_stool", "Comfy Stool", "furniture", "chair_stool", 300, "A sturdy little stool.", seat=0.36),
        piece("comfy_table", "Comfy Table", "furniture", "table_medium", 760, "A square table for meals and jigsaws.", table=True),
        piece("comfy_long_table", "Comfy Long Table", "furniture", "table_medium_long", 980, "Room for the whole family.", table=True),
        piece("comfy_coffee_table", "Comfy Coffee Table", "furniture", "table_low", 560, "Low and wide, for mugs and magazines.", table=True),
        piece("comfy_side_table", "Comfy Side Table", "furniture", "table_small", 380, "A little table with a drawer.", table=True),
        piece("comfy_cabinet", "Comfy Cabinet", "furniture", "cabinet_medium", 900, "Drawers and cupboards, and a top for treasures.", table=True),
        piece("comfy_bookshelf", "Comfy Bookshelf", "furniture", "shelf_B_large_decorated", 980, "Books, a plant and a photo or two."),
        piece("comfy_floor_lamp", "Comfy Floor Lamp", "furniture", "lamp_standing", 720, "A tall lamp with a soft shade.", light=True),
        piece("comfy_table_lamp", "Comfy Table Lamp", "furniture", "lamp_table", 420, "A little lamp for a table top.", light=True, small=True),
        piece("comfy_rug", "Comfy Striped Rug", "furniture", "rug_rectangle_stripes_A", 640, "A big striped rug.", rug=True),
        piece("comfy_oval_rug", "Comfy Oval Rug", "furniture", "rug_oval_A", 560, "Soft underfoot.", rug=True),
    ],
}

KITCHEN = {
    "id": "kitchen", "name": "Cosy Kitchen",
    "desc": "Retro appliances and tiled counters for a kitchen that's always baking.",
    "variants": [
        {"id": "mint", "name": "Mint", "wood": "7fd3b5", "trim": "5fbf9f", "fabric": ["e8a273", "7fd3b5", "plain"],
         "paint": {"green": ramp("5fbf9f", "7fd3b5", "a6e4cd"), "orange": ramp("d98a5a", "e8a273", "f2bd92"),
                   "red": ramp("e0605a", "ec7d76", "f4a19b"), "wood": ramp("a8754f", "c4946a", "dcb48a")}},
        {"id": "butter", "name": "Butter", "wood": "f2d47e", "trim": "e8c45f", "fabric": ["c8936b", "f2d47e", "plain"],
         "paint": {"green": ramp("e8c45f", "f2d47e", "f8e3a5"), "orange": ramp("b07a55", "c8936b", "dcad85"),
                   "red": ramp("e0905a", "eca878", "f4c49a"), "wood": ramp("a8754f", "c4946a", "dcb48a")}},
        {"id": "rose", "name": "Rose", "wood": "efa9b6", "trim": "e68fa0", "fabric": ["dbb795", "efa9b6", "plain"],
         "paint": {"green": ramp("e68fa0", "efa9b6", "f6c6cf"), "orange": ramp("c9a07c", "dbb795", "ebcfb1"),
                   "red": ramp("d86a7a", "e68896", "f0aab4"), "wood": ramp("d9c6b4", "ebddcf", "f8f1ea")}},
        {"id": "sky", "name": "Sky", "wood": "98bde4", "trim": "7aa7d8", "fabric": ["eeebe4", "98bde4", "plain"],
         "paint": {"green": ramp("7aa7d8", "98bde4", "bcd5ef"), "orange": ramp("e3e0d8", "eeebe4", "f7f5f0"),
                   "red": ramp("6f86c9", "8aa0d6", "a9bbe4"), "wood": ramp("8c6a4e", "a8835f", "c29d76")}},
    ],
    "pieces": [
        piece("kitchen_fridge", "Kitchen Fridge", "restaurant", "fridge_A", 1600, "A big round-shouldered fridge.", footprint=[1, 1], scale=0.42),
        piece("kitchen_stove", "Kitchen Stove", "restaurant", "stove_single", 1400, "Four rings and an oven underneath.", table=True),
        piece("kitchen_oven", "Kitchen Oven", "restaurant", "oven", 1200, "For bread, pies and the odd cake.", table=True),
        piece("kitchen_counter", "Kitchen Counter", "restaurant", "kitchencounter_straight_A", 700, "A tiled worktop with cupboards below.", table=True),
        piece("kitchen_sink", "Kitchen Sink", "restaurant", "kitchencounter_sink", 900, "A deep sink and a shiny tap."),
        piece("kitchen_cupboard", "Kitchen Cupboard", "restaurant", "kitchencabinet_half", 640, "Plates in here, biscuits up top.", table=True),
        piece("kitchen_round_table", "Kitchen Round Table", "restaurant", "table_round_A_small", 600, "A little round table for breakfast.", table=True),
        piece("kitchen_shelf", "Kitchen Shelf", "restaurant", "shelf_papertowel_decorated", 520, "Kitchen roll and spices, ready to hand."),
    ],
}

FESTIVE = {
    "id": "festive", "name": "Festive",
    "desc": "Wingback chairs and twinkling things for the cosiest time of year.",
    "variants": [
        {"id": "berry", "name": "Berry", "wood": "dc6464", "trim": "c94a4a", "fabric": ["dc6464", "fff4e0", "plain"],
         "paint": {"red": ramp("c94a4a", "dc6464", "ec8a86")}},
        {"id": "pine", "name": "Pine", "wood": "57a874", "trim": "3f8f5f", "fabric": ["57a874", "fff4e0", "plain"],
         "paint": {"red": ramp("3f8f5f", "57a874", "7cc391")}},
        {"id": "frost", "name": "Frost", "wood": "7b9fd6", "trim": "5b84c4", "fabric": ["7b9fd6", "fff4e0", "plain"],
         "paint": {"red": ramp("5b84c4", "7b9fd6", "a3bfe6")}},
        {"id": "cocoa", "name": "Cocoa", "wood": "a5755c", "trim": "8a5a44", "fabric": ["a5755c", "fff4e0", "plain"],
         "paint": {"red": ramp("8a5a44", "a5755c", "bf9176")}},
    ],
    "pieces": [
        piece("festive_wingback", "Wingback Chair", "holiday", "chair_large_red", 1400, "A tall, buttoned chair by the fire.", seat=0.34),
        piece("festive_footstool", "Footstool", "holiday", "footstool_red", 360, "For warm feet.", seat=0.18),
        piece("festive_rug", "Festive Round Rug", "holiday", "carpet_round_large", 680, "A round rug, warm as toast.", rug=True),
        piece("festive_lamp_post", "Festive Lamp Post", "holiday", "lantern_decorated", 1100, "A lamp post with a holly wreath.", light=True),
    ],
}

# --- Plain decorations ---------------------------------------------------------------

PLAIN = [
    # (id, name, pack, model, price, desc, extra)
    ("woodstove", "Wood Stove", "mixed", "woodstove", 1500, "A pot-bellied stove that keeps the whole room warm.", {"light": True, "effects": [{"kind": "smoke", "at": [0, 1.4, 0]}]}),
    ("guitar_pink", "Pink Guitar", "mixed", "guitar_A", 1200, "Three chords and the truth.", {}),
    ("guitar_blue", "Blue Guitar", "mixed", "guitar_B", 1200, "Plugged into nothing, still rocks.", {}),
    ("chicken_plushie", "Chicken Plushie", "mixed", "chicken_plushie_A", 420, "A very soft chicken.", {"small": True}),
    ("brown_hen_plushie", "Brown Hen Plushie", "mixed", "chicken_plushie_B", 420, "A very soft hen.", {"small": True}),
    ("instant_camera", "Instant Camera", "mixed", "instantcamera", 560, "Click, whirr, a picture appears.", {"small": True}),
    ("puzzle_cube", "Puzzle Cube", "mixed", "puzzlecube_complete", 260, "Solved! Don't touch it.", {"small": True}),
    ("comic_box", "Box of Comics", "mixed", "comicbox_filled", 380, "Every issue, in order.", {"small": True}),
    ("roller_skates", "Roller Skates", "mixed", "rollerskate_pair", 480, "Wheee.", {"small": True}),
    ("trophy", "Little Trophy", "mixed", "idol_A", 600, "For being a good egg.", {"small": True}),
    ("pumpkin", "Pumpkin", "halloween", "pumpkin_orange", 300, "A fat orange pumpkin.", {}),
    ("yellow_pumpkin", "Yellow Pumpkin", "halloween", "pumpkin_yellow", 300, "A plump yellow pumpkin.", {}),
    ("little_pumpkin", "Little Pumpkin", "halloween", "pumpkin_orange_small", 180, "Small and round.", {"small": True}),
    ("jack_o_lantern", "Jack-o'-Lantern", "halloween", "pumpkin_orange_jackolantern", 600, "A grinning pumpkin with a candle inside.", {"light": True, "effects": [{"kind": "candle", "at": [0, 0.3, 0]}]}),
    ("standing_lantern", "Standing Lantern", "halloween", "lantern_standing", 520, "A little lantern for the garden path.", {"light": True}),
    ("triple_candle", "Candle Cluster", "halloween", "candle_triple", 300, "Three candles in a huddle.", {"small": True, "light": True, "effects": [{"kind": "candle", "at": [0, 0.42, 0]}]}),
    ("garden_bench", "Garden Bench", "halloween", "bench", 680, "A plain wooden bench.", {"seat": 0.24}),
    ("autumn_fir", "Autumn Fir", "halloween", "tree_pine_orange_small", 900, "A little fir in its autumn coat.", {"scale": 0.42}),
    ("golden_fir", "Golden Fir", "halloween", "tree_pine_yellow_small", 900, "A little fir gone gold.", {"scale": 0.42}),
    ("snowman", "Snowman", "holiday", "snowman_A", 900, "He'll be fine as long as it stays chilly.", {}),
    ("present_red", "Present (Red)", "holiday", "present_A_red", 300, "What could it be?", {"small": True}),
    ("present_blue", "Present (Blue)", "holiday", "present_A_blue", 300, "What could it be?", {"small": True}),
    ("present_stack", "Stack of Presents", "holiday", "present_D_green", 500, "So many presents.", {}),
    ("hot_chocolate", "Hot Chocolate", "holiday", "hot_chocolate_decorated", 240, "With marshmallows, obviously.", {"small": True}),
    ("cookie_plate", "Plate of Cookies", "holiday", "plate_decorated_A", 280, "Fresh from the oven.", {"small": True}),
    ("festive_bell", "Festive Bell", "holiday", "bell_decorated", 320, "Ding!", {"small": True}),
    ("snowball_pile", "Snowball Pile", "holiday", "snowball_pile", 200, "Ready for a snowball fight.", {}),
    ("stew_pot", "Stew Pot", "restaurant", "pot_A_stew", 360, "Something delicious bubbling away.", {"small": True}),
    ("frying_pan", "Frying Pan", "restaurant", "pan_A", 260, "For pancakes on Sundays.", {"small": True}),
    ("dish_rack", "Dish Rack", "restaurant", "dishrack_plates", 300, "Plates drying in a row.", {"small": True}),
    ("jam_jar", "Jam Jar", "restaurant", "jar_A_large", 180, "Homemade, with a gingham lid.", {"small": True}),
    ("cutting_board", "Cutting Board", "restaurant", "cuttingboard", 200, "Well used and well loved.", {"small": True}),
    ("dinner_plate", "Dinner for One", "restaurant", "food_dinner", 320, "A hearty dinner on a plate.", {"small": True}),
    ("burger_plate", "Burger", "restaurant", "food_burger", 280, "Stacked high.", {"small": True}),
    ("carrot_crate", "Crate of Carrots", "restaurant", "crate_carrots", 360, "Fresh from someone's garden.", {}),
    ("tomato_crate", "Crate of Tomatoes", "restaurant", "crate_tomatoes", 360, "Red and ripe.", {}),
    ("lettuce_crate", "Crate of Lettuce", "restaurant", "crate_lettuce", 360, "Crunchy.", {}),
    ("potato_crate", "Crate of Potatoes", "restaurant", "crate_potatoes", 360, "Mash, chips or roasties?", {}),
    ("village_well", "Village Well", "hexagon", "blue/building_well_blue", 2400, "A little roofed well. Make a wish.", {}),
    ("windmill", "Windmill", "hexagon", "red/building_windmill_red", 9800, "Its sails turn lazily in the breeze.", {"scale": 2.6}),
    ("potted_cactus", "Potted Cactus", "furniture", "cactus_medium_A", 280, "Prickly but friendly.", {"small": True}),
    ("book_pile", "Pile of Books", "furniture", "book_set", 220, "Bookmarks in every one.", {"small": True}),
    ("photo_frame", "Photo Frame", "furniture", "pictureframe_standing_A", 260, "A favourite memory.", {"small": True}),
]

# --- Outdoor decorations -------------------------------------------------------------
# Placed like furniture but only outside ("outdoor"), and stocked by Lucy apart from the
# indoor things. (Fences and gates are in data/items.json by hand: they join up, built
# by FenceModels.) Extra keys: scale or fit (with the "nature" palette for rocks and
# plants), footprint, recipe (materials; learned from bottles), and anything for the
# placeable (light, seat, effects, walk_through).

NATURE = {"palette": "nature", "sway": "none"}
LEAFY = {"palette": "nature", "sway": "foliage", "smooth": True}

OUTDOOR = [
    # Big rocks.
    ("big_boulder", "Big Boulder", "forest", "Rock_1_K_Color1", 1800, "A great round boulder. Nobody knows how it got here.", {"fit": [1.9, 1.9], "look": NATURE, "recipe": {"stone": 20}}),
    ("boulder", "Boulder", "forest", "Rock_1_G_Color1", 600, "A nice round rock to lean on.", {"fit": [0.95, 1.0], "look": NATURE, "recipe": {"stone": 8}}),
    ("standing_stone", "Standing Stone", "forest", "Rock_1_N_Color1", 1400, "Tall, old and a little mysterious.", {"fit": [1.0, 2.1], "look": NATURE, "recipe": {"stone": 12}}),
    ("rocky_outcrop", "Rocky Outcrop", "forest", "Rock_3_M_Color1", 2200, "Layers of rock stacked like a cake.", {"fit": [1.9, 2.0], "look": NATURE, "recipe": {"stone": 18}}),
    ("great_crag", "Great Crag", "forest", "Rock_3_Q_Color1", 3600, "A whole cliff's worth of rock, in one lump.", {"fit": [2.9, 2.4], "look": NATURE, "recipe": {"stone": 30}}),
    ("rock_cluster", "Rock Cluster", "forest", "Rock_3_K_Color1", 1200, "A huddle of rocks.", {"fit": [1.8, 1.4], "look": NATURE, "recipe": {"stone": 10}}),
    ("boulder_pile", "Boulder Pile", "forest", "Rock_2_E_Color1", 1600, "Round rocks piled up high.", {"fit": [1.9, 1.7], "look": NATURE, "recipe": {"stone": 14}}),
    ("tumbled_rocks", "Tumbled Rocks", "forest", "Rock_2_H_Color1", 1600, "Rocks that rolled down a hill and stopped here.", {"fit": [1.9, 1.4], "look": NATURE}),
    ("pebbles", "Pebbles", "forest", "Rock_1_C_Color1", 120, "A few smooth pebbles.", {"fit": [0.55, 0.45], "look": NATURE, "recipe": {"stone": 2}}),
    # Plants.
    ("bare_tree", "Bare Tree", "forest", "Tree_Bare_1_A_Color1", 900, "No leaves, all character.", {"fit": [1.0, 2.6], "look": NATURE}),
    ("twisted_tree", "Twisted Tree", "forest", "Tree_Bare_2_A_Color1", 900, "It grew this way on purpose.", {"fit": [1.0, 2.8], "look": NATURE}),
    ("round_shrub", "Round Shrub", "forest", "Bush_1_E_Color1", 300, "A neat, round little shrub.", {"fit": [0.95, 0.6], "look": LEAFY}),
    ("spreading_shrub", "Spreading Shrub", "forest", "Bush_3_C_Color1", 400, "Low and leafy.", {"fit": [1.4, 0.65], "look": LEAFY}),
    # Rustic odds and ends.
    ("rain_barrel", "Rain Barrel", "hexdeco", "props/barrel", 300, "Good for keeping rain water. Or apples.", {"recipe": {"wood": 4}}),
    ("canvas_canopy", "Canvas Canopy", "hexdeco", "props/tent", 1500, "A canvas roof on four poles, for shade or a market day.", {"scale": 3.0}),
    ("log_pile", "Log Pile", "hexdeco", "props/resource_lumber", 500, "Neatly stacked, ready for winter.", {"recipe": {"wood": 6}}),
    ("stone_pile", "Stone Pile", "hexdeco", "props/resource_stone", 400, "Rocks, sorted.", {"recipe": {"stone": 6}}),
    ("archery_target", "Archery Target", "hexdeco", "props/target", 600, "Bullseye!", {"scale": 3.0, "recipe": {"wood": 4, "clay": 2}}),
    ("wooden_crate", "Wooden Crate", "hexdeco", "props/crate_A_big", 250, "A crate for whatever needs crating.", {"recipe": {"wood": 3}}),
    ("open_crate", "Open Crate", "hexdeco", "props/crate_open", 250, "Something's rustling about in there.", {}),
    ("water_bucket", "Bucket of Water", "hexdeco", "props/bucket_water", 180, "Full to the brim.", {"small": True}),
    ("flour_sack", "Sack of Flour", "hexdeco", "props/sack", 150, "For bread, cakes and the odd mess.", {"scale": 3.0, "small": True}),
    ("wooden_stage", "Wooden Stage", "hexagon", "neutral/building_stage_A", 3000, "For concerts, speeches and dancing.", {"recipe": {"wood": 15}}),
    ("plank_stack", "Plank Stack", "resource", "Wood_Planks_Stack_Large", 500, "Planks for the next big project.", {"recipe": {"wood": 6}}),
    ("brick_stack", "Brick Stack", "resource", "Stone_Bricks_Stack_Large", 500, "Bricks, stacked and strapped.", {"recipe": {"stone": 4, "clay": 4}}),
    ("rubble", "Rubble", "resource", "Stone_Chunks_Large", 300, "Broken stone, piled up.", {}),
    ("fabric_bolts", "Bolts of Fabric", "resource", "Textiles_Stack_Large_Colored", 600, "Rolls of colourful cloth.", {}),
    # Town things.
    ("park_bench", "Park Bench", "city", "bench", 700, "A bench for watching the world go by.", {"seat": 0.3}),
    ("street_lamp", "Street Lamp", "city", "streetlight", 1200, "Lights the way home.", {"light": True}),
    ("fire_hydrant", "Fire Hydrant", "city", "firehydrant", 400, "Bright red, just in case.", {}),
    ("cardboard_box", "Cardboard Box", "city", "box_A", 120, "Empty. Or is it?", {}),
    ("planter_shrub", "Planter Shrub", "city", "bush", 350, "A neat shrub in a box.", {}),
    ("water_tower", "Water Tower", "city", "watertower", 2500, "Holds enough water for everyone.", {}),
    # Bright and playful.
    ("garden_arch_blue", "Garden Arch (Blue)", "platformer", "blue/arch_blue", 900, "An arch to walk under.", {"walk_through": True}),
    ("garden_arch_red", "Garden Arch (Red)", "platformer", "red/arch_red", 900, "An arch to walk under.", {"walk_through": True}),
    ("garden_arch_green", "Garden Arch (Green)", "platformer", "green/arch_green", 900, "An arch to walk under.", {"walk_through": True}),
    ("garden_arch_yellow", "Garden Arch (Yellow)", "platformer", "yellow/arch_yellow", 900, "An arch to walk under.", {"walk_through": True}),
    ("pennant_red", "Pennant (Red)", "hexdeco", "props/flag_red", 300, "Flutters in the breeze.", {"scale": 4.0}),
    ("pennant_blue", "Pennant (Blue)", "hexdeco", "props/flag_blue", 300, "Flutters in the breeze.", {"scale": 4.0}),
    ("pennant_green", "Pennant (Green)", "hexdeco", "props/flag_green", 300, "Flutters in the breeze.", {"scale": 4.0}),
    ("pennant_yellow", "Pennant (Yellow)", "hexdeco", "props/flag_yellow", 300, "Flutters in the breeze.", {"scale": 4.0}),
    ("arrow_sign", "Arrow Sign", "platformer", "yellow/signage_arrow_stand_yellow", 350, "This way!", {}),
    ("beach_ball", "Beach Ball", "platformer", "red/ball_red", 300, "Red and white and bouncy.", {"scale": 0.3}),
    ("star_ornament", "Star Ornament", "platformer", "yellow/star_yellow", 500, "A big golden star for the garden.", {}),
    ("heart_ornament", "Heart Ornament", "platformer", "red/heart_red", 500, "A big red heart.", {}),
    ("gem_ornament", "Gem Ornament", "platformer", "blue/diamond_blue", 500, "A big blue gem, polished to a shine.", {}),
    # Spooky and festive.
    ("fence_post", "Fence Post", "halloween", "fence_pillar", 250, "A stone post with a cap.", {}),
    ("lantern_post", "Lantern Post", "halloween", "post_lantern", 1400, "A crooked post with a lantern hanging off it.", {"light": True}),
    ("gravestone", "Gravestone", "halloween", "gravestone", 600, "Here lies... someone's old sock?", {}),
    ("spooky_tree", "Spooky Tree", "halloween", "tree_dead_large", 1200, "Its branches look like fingers.", {}),
    ("little_shrine", "Little Shrine", "halloween", "shrine_candles", 1600, "A quiet little shrine with candles.", {"light": True}),
    ("iron_archway", "Iron Archway", "halloween", "arch_gate", 1800, "A grand gateway to walk through.", {"walk_through": True}),
    ("gingerbread_house", "Gingerbread House", "holiday", "gingerbread_house_decorated", 1200, "Don't eat the roof.", {"scale": 1.1}),
    ("candy_cane", "Candy Cane", "holiday", "candycane_small", 250, "A giant stripy candy cane.", {"scale": 1.5}),
    # Seaside.
    ("circus_tent", "Circus Tent", "mixed", "circus_tent", 6000, "Roll up, roll up!", {"scale": 0.9}),
]


def colour_of(pack, name):
    # A representative colour for icons and menus: the model's commonest texture colour.
    import struct
    from PIL import Image
    path = SRC + PACKS[pack][0] + name + ".gltf"
    g = json.load(open(path)); base = os.path.dirname(path)
    img = Image.open(base + "/" + g["images"][0]["uri"]).convert("RGB"); W, H = img.size
    data = open(base + "/" + g["buffers"][0]["uri"], "rb").read()
    counts = {}
    for m in g["meshes"]:
        for p in m["primitives"]:
            a = g["accessors"][p["attributes"]["TEXCOORD_0"]]; bv = g["bufferViews"][a["bufferView"]]
            off = bv.get("byteOffset", 0) + a.get("byteOffset", 0); stride = bv.get("byteStride", 8)
            for i in range(a["count"]):
                u, v = struct.unpack_from("<ff", data, off + i * stride)
                c = img.getpixel((min(W - 1, int((u % 1) * W)), min(H - 1, int((v % 1) * H))))
                counts[c] = counts.get(c, 0) + 1
    c = max(counts, key=counts.get)
    return "#%02x%02x%02x" % c


def main():
    for s in (COMFY, KITCHEN, FESTIVE):
        path = REPO + "data/furniture/%s.json" % s["id"]
        with open(path, "w") as f:
            f.write("{\n")
            f.write('\t"id": %s,\n\t"name": %s,\n\t"desc": %s,\n' % (json.dumps(s["id"]), json.dumps(s["name"]), json.dumps(s["desc"])))
            f.write('\t"_note": "KayKit pieces (CC0): each is a KayKit model (tools/kaykit.json) repainted by the variant\'s paint, colour family by colour family (Palette).",\n')
            f.write('\t"variants": [\n' + ",\n".join("\t\t" + json.dumps(v) for v in s["variants"]) + "\n\t],\n")
            f.write('\t"pieces": [\n' + ",\n".join("\t\t" + json.dumps(p) for p in s["pieces"]) + "\n\t]\n}\n")
    items_path = REPO + "data/items.json"
    data = json.load(open(items_path))
    # Start again from anything this script made last time.
    ours = [p[0] for p in PLAIN] + ["festive_tree"]
    for id in ours:
        made = data["items"].get(id, {}).get("placeable", {}).get("model", "")
        if made.startswith("kaykit:") or made == "festive_tree":
            del data["items"][id]
    for id, name, pack, src, price, desc, extra in PLAIN:
        if id in data["items"]:
            sys.exit("%s is already an item" % id)
        extra = dict(extra)
        key = model(pack, src, extra.pop("scale", None))
        size = bounds(pack, src)
        if key in models and models[key]["scale"] != PACKS[pack][1]:
            f = models[key]["scale"] / PACKS[pack][1]
            size = [x * f for x in size]
        placeable = {"footprint": footprint(size), "model": "kaykit:" + key, "rotatable": True}
        placeable.update(extra)
        data["items"][id] = {"name": name, "category": "furniture", "stack": 1, "price": price,
                             "color": colour_of(pack, src), "desc": desc, "placeable": placeable}
    recipes_path = REPO + "data/recipes.json"
    recipes = json.load(open(recipes_path))
    for id, name, pack, src, price, desc, extra in OUTDOOR:
        if data["items"].get(id, {}).get("placeable", {}).get("outdoor", False):
            del data["items"][id]
        recipes["recipes"].pop(id, None)
    for id, name, pack, src, price, desc, extra in OUTDOOR:
        if id in data["items"]:
            sys.exit("%s is already an item" % id)
        extra = dict(extra)
        scale, fit, look = extra.pop("scale", None), extra.pop("fit", None), dict(extra.pop("look", {}))
        recipe = extra.pop("recipe", None)
        if fit:
            look["fit"] = fit
        key = model(pack, src, scale, look)
        size = fitted(pack, src, scale, fit, look.get("turn", 0))
        placeable = {"footprint": extra.pop("footprint", footprint(size)), "model": "kaykit:" + key, "rotatable": True, "outdoor": True}
        placeable.update(extra)
        data["items"][id] = {"name": name, "category": "furniture", "stack": 1, "price": price,
                             "color": colour_of(pack, src), "desc": desc, "placeable": placeable}
        if recipe:
            recipes["recipes"][id] = {"materials": recipe}
    with open(recipes_path, "w") as f:
        f.write(json.dumps(recipes, indent="\t", ensure_ascii=False) + "\n")
    data["items"]["festive_tree"] = {"name": "Festive Tree", "category": "furniture", "stack": 1, "price": 2400,
        "color": "#57a874", "desc": "Baubles, a star, and a twinkle at night.",
        "placeable": {"footprint": [1, 1], "model": "festive_tree", "rotatable": True, "light": True}}
    with open(items_path, "w") as f:
        f.write(json.dumps(data, indent="\t", ensure_ascii=False) + "\n")
    kk = json.load(open(REPO + "tools/kaykit.json"))
    kk["models"].update(models)
    with open(REPO + "tools/kaykit.json", "w") as f:
        json.dump(kk, f, indent="\t")
    print(len(models), "models;", sum(len(s["pieces"]) for s in (COMFY, KITCHEN, FESTIVE)), "series pieces;", len(PLAIN), "decorations;", len(OUTDOOR), "outdoor")

main()
