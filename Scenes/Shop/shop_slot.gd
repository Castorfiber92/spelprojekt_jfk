extends Control
class_name ShopSlot

# This can hold HeroData OR ItemData seamlessly!
var slot_item: PurchaseableData = null
var is_frozen: bool = false

var slot_is_empty: bool:
	get: return slot_item == null

func display_item(new_item: PurchaseableData) -> void:
	slot_item = new_item
	if slot_item:
		$UI.visible = true
		$UI/CostLabel.text = str(slot_item.current_cost)
		$UI/Icon.texture = slot_item.texture
	else:
		clear_slot()

func clear_slot() -> void:
	slot_item = null
	$UI.visible = false
	is_frozen = false

func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_is_empty or is_frozen:
		return null
		
	# Create a tiny visual preview sprite so the user sees what they are dragging
	var preview = TextureRect.new()
	preview.texture = slot_item.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	set_drag_preview(preview)
	
	return self # Return the slot instance as the transfer payload
