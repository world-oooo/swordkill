extends Area2D
## 상점 좌판. 플레이어가 닿으면 재화가 충분할 때 구매하고, 구매 완료 상태로 저장된다.
## kind: weapon / hp / shield / energy. currency: coin / gem.

var kind: String = "hp"
var currency: String = "coin"
var cost: int = 10
var weapon_key: String = ""
var label_text: String = ""
var _sold: bool = false

@onready var _sprite: ColorRect = $Sprite
@onready var _name_label: Label = $NameLabel
@onready var _price_label: Label = $PriceLabel

func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	_refresh()

func configure(d: Dictionary) -> void:
	kind = d.get("kind", kind)
	currency = d.get("currency", currency)
	cost = d.get("cost", cost)
	weapon_key = d.get("weapon_key", "")
	label_text = d.get("label", "")
	_refresh()

func _refresh() -> void:
	if _name_label == null:
		return
	_name_label.text = label_text
	_price_label.text = ("보석 %d" % cost) if currency == "gem" else ("코인 %d" % cost)

func _on_body_entered(body: Node) -> void:
	if _sold or not body.is_in_group("player"):
		return
	var paid: bool = GameManager.spend_gems(cost) if currency == "gem" else GameManager.spend_coins(cost)
	if not paid:
		_flash_deny()
		return
	if kind == "weapon" and body.has_method("set_weapon"):
		body.set_weapon(weapon_key)
	elif body.has_method("apply_upgrade"):
		body.apply_upgrade(kind)
	_sold = true
	_sprite.color = Color(0.3, 0.3, 0.32)
	_name_label.text = "판매 완료"
	_price_label.text = ""

func save_data() -> Dictionary:
	if _sold:
		return {}
	return {
		"kind": "shop",
		"pos": position,
		"item": {"kind": kind, "currency": currency, "cost": cost, "weapon_key": weapon_key, "label": label_text},
	}

func _flash_deny() -> void:
	var t: Tween = create_tween()
	t.tween_property(_price_label, "modulate", Color(1, 0.3, 0.3), 0.1)
	t.tween_property(_price_label, "modulate", Color(1, 1, 1), 0.3)
