extends Node2D
class_name ShopManager

@export var party_slots: Array[ShopSlot] = [] # Changed to ShopSlot array

enum ShopPhase { IDLE, TRANSACTION, ROLLING, ROUIECE_CLEANUP }
var current_phase: ShopPhase = ShopPhase.IDLE


func execute_transaction(source_slot: ShopSlot, target_slot: ShopSlot) -> void: # Fixed type here
	# Rule validation phase
	if current_phase != ShopPhase.IDLE: return
	
	var incoming_data = source_slot.slot_item
	if incoming_data == null: return
	
	if not PlayerData.canPay(incoming_data.cost): # Fixed property name to .cost
		print("Cannot afford: ", incoming_data.spiritName)
		return

	current_phase = ShopPhase.TRANSACTION
	
	# Execute the placement logic branching
	if incoming_data is HeroData:
		await _handle_hero_placement(incoming_data, source_slot, target_slot)
	#elif incoming_data is ItemData:
		#await _handle_item_placement(incoming_data, source_slot, target_slot)
		
	current_phase = ShopPhase.IDLE
	update_shop_UI()


func _handle_hero_placement(hero: HeroData, shop: ShopSlot, target: ShopSlot) -> void:
	var target_index = target.slot_number - 1
	
	# Ensure backend data array is large enough to prevent index out of bounds
	if PlayerData.playerParty.size() < party_slots.size():
		PlayerData.playerParty.resize(party_slots.size())
	
	# 1. Merge EXP rules check
	if not target.slot_is_empty and target.slot_item.spiritName == hero.spiritName:
		PlayerData.deductCost(hero.cost)
		PlayerData.playerParty[target_index].add_exp(hero.exp_value)
		shop.clear_slot()
		update_shop_UI() 
		return
		
	# 2. Open Slot rules check
	if target.slot_is_empty:
		PlayerData.deductCost(hero.cost)
		PlayerData.playerParty[target_index] = hero
		shop.clear_slot()
		update_shop_UI()
		return
		
	# 3. Shifting row rules check
	var empty_index = find_nearest_empty_slot(target_index)
	if empty_index != -1:
		PlayerData.deductCost(hero.cost)
		shop.clear_slot()
		
		# Move the data array first, then update the screen
		shift_party_slots(target_index, empty_index)
		PlayerData.playerParty[target_index] = hero
		update_shop_UI()
	else:
		print("Placement failed: Lineup is entirely full.")


func shift_party_slots(target_idx: int, empty_idx: int) -> void:
	# Step 1: Shift the RAW DATA array (No UI code here, keep it pure)
	if target_idx < empty_idx:
		for i in range(empty_idx, target_idx, -1):
			PlayerData.playerParty[i] = PlayerData.playerParty[i-1]
	else:
		for i in range(empty_idx, target_idx):
			PlayerData.playerParty[i] = PlayerData.playerParty[i+1]
			
	PlayerData.playerParty[target_idx] = null


func find_nearest_empty_slot(start_idx: int) -> int:
	for i in range(start_idx, party_slots.size()):
		if party_slots[i].slot_is_empty: return i
	for i in range(start_idx, -1, -1):
		if party_slots[i].slot_is_empty: return i
	return -1


func update_shop_UI() -> void:
	# Loops through slots and cleanly matches them to the state of the backend array
	for i in range(party_slots.size()):
		if i < PlayerData.playerParty.size() and PlayerData.playerParty[i] != null:
			party_slots[i].display_item(PlayerData.playerParty[i])
		else:
			party_slots[i].clear_slot()
