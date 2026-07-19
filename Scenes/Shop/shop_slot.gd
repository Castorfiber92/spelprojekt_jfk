extends Control
class_name ShopSlot

@export var UI : Control
@export var hp_label : Label
@export var lvl_label : Label
@export var dmg_label : Label
@export var cost_label : Label
@export var sprite : TextureRect

var slot_item: Variant = null
var slot_number : int
var shop_manager: Node = null 

var slot_is_empty: bool:
	get: return slot_item == null

func _gui_input(event: InputEvent) -> void:
	# Check if the player left-clicked the card
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# If a manager was successfully injected, pass the execution to the command center
		if shop_manager and shop_manager.has_method("handle_slot_clicked"):
			shop_manager.handle_slot_clicked(self)

func display_item(new_item: Variant) -> void:
	slot_item = new_item
	
	if slot_item:
		UI.visible = true
		
		# --- CASE A: This slot is acting as a Shop Shelf (Resource) ---
		if slot_item is PurchaseableData:
			cost_label.text = str(slot_item.cost)
			
			# HeroData is a sub-class of PurchaseableData, but uses SpriteFrames instead of a flat texture
			if slot_item is HeroData:
				dmg_label.text = str(slot_item.base_damage)
				hp_label.text = str(slot_item.base_HP)
				# Pull the default idle frame from your generated SpriteFrames asset
				if slot_item.sprites and slot_item.sprites.has_animation("idle"):
					sprite.texture = slot_item.sprites.get_frame_texture("idle", 0)
			else:
				# Standard non-hero purchaseables use the default flat texture property
				sprite.texture = slot_item.texture
				
		# --- CASE B: This slot is acting as a Player Bench (Live Node) ---
		elif slot_item is Hero:
			# Pull static visual data from the nested resource blueprint
			cost_label.text = str(slot_item.hero_data.cost)
			
			if slot_item.hero_data and slot_item.hero_data.sprites:
				sprite.texture = slot_item.hero_data.sprites.get_frame_texture("idle", 0)
			
			# Pull live combat stats straight from the active Node!
			dmg_label.text = str(slot_item.current_damage)
			hp_label.text = str(slot_item.current_HP) 
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
	
	# FIXED: Safely grab whatever texture is currently visible on the slot UI card 
	# to completely bypass missing property reference crashes!
	preview.texture = sprite.texture
	
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	set_drag_preview(preview)
	
	return self # Return the slot instance as the transfer payload
	
# 1. Determines if this specific slot can accept the dragged item
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is ShopSlot:
		return false
		
	var source_slot = data as ShopSlot
	
	if shop_manager == null or source_slot.shop_manager == null:
		return false
		
	if shop_manager.shop_slots.has(source_slot):
		return shop_manager.party_slots.has(self)
		
	if shop_manager.party_slots.has(source_slot):
		return shop_manager.party_slots.has(self)
		
	return false

# 2. Triggers when the player drops the dragged item onto this slot
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_slot = data as ShopSlot
	
	if shop_manager and shop_manager.has_method("execute_transaction"):
		shop_manager.execute_transaction(source_slot, self)
