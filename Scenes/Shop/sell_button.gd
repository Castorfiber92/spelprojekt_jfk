extends Button
class_name SellButton

var manager: ShopManager

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Checks if the manager is valid, idle, and the dragged item is a party slot
	return manager != null and manager.current_phase == manager.ShopPhase.IDLE and data is ShopSlot and not data.slot_is_empty and manager.party_slots.has(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	manager.selected_slot = data
	manager.sell_selected_slot()
