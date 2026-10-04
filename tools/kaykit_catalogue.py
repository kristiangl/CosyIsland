"""Generates the KayKit furniture series and decorations for Cosy Island.

    python3 tools/kaykit_catalogue.py /path/to/KayKit

Writes the model entries into tools/kaykit.json, the series into data/furniture/
(comfy, kitchen, festive) and the decorations into data/items.json, with footprints
and table heights measured from the models. Run it on a clean data/items.json (it
refuses to overwrite an existing item), then tools/kaykit_import.gd to convert the
models.
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
}

def bounds(pack, model):
    path = SRC + PACKS[pack][0] + model + ".gltf"
    g = json.load(open(path))
    mn = [1e9] * 3; mx = [-1e9] * 3
    for m in g["meshes"]:
        for p in m["primitives"]:
            a = g["accessors"][p["attributes"]["POSITION"]]
            mn = [min(x, y) for x, y in zip(mn, a["min"])]
            mx = [max(x, y) for x, y in zip(mx, a["max"])]
    s = PACKS[pack][1]
    return [(mx[i] - mn[i]) * s for i in range(3)]

models = {}

def model(pack, name, scale=None):
    key = "%s_%s" % (pack, name.lower())
    models[key] = {"src": PACKS[pack][0] + name + ".gltf", "scale": scale or PACKS[pack][1]}
    return key

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
    ("potted_cactus", "Potted Cactus", "furniture", "cactus_medium_A", 280, "Prickly but friendly.", {"small": True}),
    ("book_pile", "Pile of Books", "furniture", "book_set", 220, "Bookmarks in every one.", {"small": True}),
    ("photo_frame", "Photo Frame", "furniture", "pictureframe_standing_A", 260, "A favourite memory.", {"small": True}),
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
    data["items"]["festive_tree"] = {"name": "Festive Tree", "category": "furniture", "stack": 1, "price": 2400,
        "color": "#57a874", "desc": "Baubles, a star, and a twinkle at night.",
        "placeable": {"footprint": [1, 1], "model": "festive_tree", "rotatable": True, "light": True}}
    with open(items_path, "w") as f:
        f.write(json.dumps(data, indent="\t", ensure_ascii=False) + "\n")
    kk = json.load(open(REPO + "tools/kaykit.json"))
    kk["models"].update(models)
    with open(REPO + "tools/kaykit.json", "w") as f:
        json.dump(kk, f, indent="\t")
    print(len(models), "models;", sum(len(s["pieces"]) for s in (COMFY, KITCHEN, FESTIVE)), "series pieces;", len(PLAIN), "decorations")

main()
