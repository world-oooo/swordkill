extends Node
## Data-only sword database for The Last Light.
##
## The run starts with the Wooden Sword equipped, but the prototype inventory
## intentionally grants all six swords so combat feel can be tested quickly.

const ORDER: Array[String] = ["wood", "steel", "light", "rune", "flame", "radiant"]
const ELEMENT_LIGHTNING: String = "lightning"
const ELEMENT_WATER: String = "water"
const ELEMENT_FIRE: String = "fire"
const ELEMENTS: Array[String] = [ELEMENT_LIGHTNING, ELEMENT_WATER, ELEMENT_FIRE]

const WEAPONS: Dictionary = {
	"wood": {
		"name": "허접한 나무검",
		"melee": true,
		"auto": true,
		"damage": 2,
		"attack_rate": 2.65,
		"range": 98.0,
		"arc": 118.0,
		"texture": "res://assets/sword/sword_wood.png",
		"frames": 1,
		"aura": Color(0.78, 0.62, 0.38),
	},
	"steel": {
		"name": "녹슨 철검",
		"melee": true,
		"auto": true,
		"damage": 2,
		"attack_rate": 2.7,
		"range": 96.0,
		"arc": 112.0,
		"texture": "res://assets/sword/sword_steel.png",
		"frames": 1,
		"aura": Color(0.78, 0.88, 1.0),
	},
	"light": {
		"name": "기사단의 강철검",
		"melee": true,
		"auto": true,
		"damage": 2,
		"attack_rate": 3.2,
		"range": 100.0,
		"arc": 116.0,
		"texture": "res://assets/sword/sword_light.png",
		"frames": 1,
		"aura": Color(1.0, 0.96, 0.55),
	},
	"rune": {
		"name": "룬이 깃든 마검",
		"melee": true,
		"auto": true,
		"damage": 3,
		"attack_rate": 2.8,
		"range": 104.0,
		"arc": 116.0,
		"texture": "res://assets/sword/sword_rune.png",
		"frames": 2,
		"anim_fps": 4.0,
		"aura": Color(0.66, 0.9, 1.0),
	},
	"flame": {
		"name": "용살의 화염검",
		"melee": true,
		"auto": true,
		"damage": 3,
		"attack_rate": 2.45,
		"range": 108.0,
		"arc": 122.0,
		"texture": "res://assets/sword/sword_flame.png",
		"frames": 1,
		"aura": Color(1.0, 0.42, 0.16),
	},
	"radiant": {
		"name": "빛의 성검 「에이렌」",
		"melee": true,
		"auto": true,
		"damage": 4,
		"attack_rate": 3.0,
		"range": 116.0,
		"arc": 124.0,
		"texture": "res://assets/sword/sword_radiant.png",
		"frames": 1,
		"aura": Color(1.0, 0.9, 0.38),
	},
}

func get_weapon(key: String) -> Dictionary:
	if WEAPONS.has(key):
		return WEAPONS[key]
	return _evolved_weapon(key)

func display_name(key: String) -> String:
	return get_weapon(key).get("name", "맨손")

func evolved_key(base_or_evolved_key: String, element: String) -> String:
	var base: String = base_key(base_or_evolved_key)
	if not WEAPONS.has(base) or element not in ELEMENTS:
		return ""
	return "%s_%s" % [base, element]

func base_key(key: String) -> String:
	for element in ELEMENTS:
		var suffix: String = "_" + element
		if key.ends_with(suffix):
			return key.trim_suffix(suffix)
	return key

func element_from_key(key: String) -> String:
	for element in ELEMENTS:
		if key.ends_with("_" + element):
			return element
	return ""

func tier_for(key: String) -> int:
	var idx: int = ORDER.find(base_key(key))
	return max(1, idx + 1)

func is_evolved(key: String) -> bool:
	return element_from_key(key) != ""

func _evolved_weapon(key: String) -> Dictionary:
	var element: String = element_from_key(key)
	var base: String = base_key(key)
	if element == "" or not WEAPONS.has(base):
		return WEAPONS["wood"]

	var cfg: Dictionary = WEAPONS[base].duplicate(true)
	var tier: int = tier_for(base)
	cfg["base_weapon"] = base
	cfg["element"] = element
	cfg["evolved"] = true
	if element == ELEMENT_LIGHTNING:
		cfg["aura"] = Color(0.62, 0.92, 1.0)
	elif element == ELEMENT_WATER:
		cfg["aura"] = Color(0.42, 0.82, 1.0)
	else:
		cfg["aura"] = Color(1.0, 0.42, 0.10)
	cfg["frames"] = 1

	if element == ELEMENT_LIGHTNING:
		cfg["name"] = "%s 번개검" % WEAPONS[base].get("name", "검")
		cfg["damage"] = int(cfg.get("damage", 1)) + 1
		cfg["attack_rate"] = float(cfg.get("attack_rate", 2.4)) + 0.25
		cfg["range"] = float(cfg.get("range", 90.0)) + 8.0
		cfg["texture"] = "res://assets/sword/sword_lightning_ai.png"
		cfg["elemental_effect"] = "chain_lightning"
		cfg["chain_damage"] = max(1, int(ceil(float(tier) * 0.75)))
		cfg["chain_range"] = 150.0 + float(tier) * 12.0
		cfg["chain_targets"] = 2 + int(tier / 3)
	elif element == ELEMENT_WATER:
		cfg["name"] = "%s 물의 검" % WEAPONS[base].get("name", "검")
		cfg["damage"] = int(cfg.get("damage", 1))
		cfg["attack_rate"] = float(cfg.get("attack_rate", 2.4)) + 0.10
		cfg["range"] = float(cfg.get("range", 90.0)) + 14.0
		cfg["arc"] = float(cfg.get("arc", 110.0)) + 10.0
		cfg["texture"] = "res://assets/sword/sword_water_ai.png"
		cfg["elemental_effect"] = "water_freeze"
		cfg["aoe_damage"] = max(1, int(ceil(float(tier) * 0.5)))
		cfg["aoe_radius"] = 96.0 + float(tier) * 10.0
		cfg["slow_duration"] = 1.6 + float(tier) * 0.12
	else:
		cfg["name"] = "%s 불의 검" % WEAPONS[base].get("name", "검")
		cfg["damage"] = int(cfg.get("damage", 1)) + 1
		cfg["attack_rate"] = maxf(1.8, float(cfg.get("attack_rate", 2.4)) - 0.05)
		cfg["range"] = float(cfg.get("range", 90.0)) + 6.0
		cfg["arc"] = float(cfg.get("arc", 110.0)) + 6.0
		cfg["texture"] = "res://assets/sword/sword_flame.png"
		cfg["elemental_effect"] = "fire_burst"
		cfg["fire_damage"] = max(1, int(ceil(float(tier) * 0.65)))
		cfg["fire_radius"] = 82.0 + float(tier) * 9.0
	return cfg
