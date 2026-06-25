extends Control
class_name ShopSlot

@export var UI : Control
@export var hp_label : Label
@export var lvl_label : Label
@export var dmg_label : Label
@export var cost_label : Label
@export var sprite : TextureRect

var slot_item: PurchaseableData = null
var shop_manager: Node = null 

var slot_is_empty: bool:
	get: return slot_item == null

func _gui_input(event: InputEvent) -> void:
	# Check if the player left-clicked the card
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# If a manager was successfully injected, pass the execution to the command center
		if shop_manager and shop_manager.has_method("handle_slot_clicked"):
			shop_manager.handle_slot_clicked(self)

func display_item(new_item: PurchaseableData) -> void:
	slot_item = new_item
	if slot_item:
		UI.visible = true
		cost_label.text = str(slot_item.cost)
		sprite.texture = slot_item.texture
		if slot_item is HeroData:
			dmg_label.text = str(slot_item.base_damage)
			hp_label.text = str(slot_item.base_HP)
			#lvl_label.text = str(slot_item.level)
	else:
		clear_slot()

func clear_slot() -> void:
	slot_item = null
	UI.visible = false

func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_is_empty:
		return null
		
	# Create a tiny visual preview sprite so the user sees what they are dragging
	var preview = TextureRect.new()
	preview.texture = slot_item.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	set_drag_preview(preview)
	
	return self # Return the slot instance as the transfer payload
