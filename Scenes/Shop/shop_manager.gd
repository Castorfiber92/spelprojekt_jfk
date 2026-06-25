extends Node2D
class_name ShopManager

var party_slots: Array[ShopSlot] = []
var shop_slots: Array[ShopSlot] = []
@export var shop_ui : ShopUi
@export var max_party_size: int = 4
@export var max_shop_size: int = 5

var selected_slot: ShopSlot = null
enum ShopPhase { IDLE, TRANSACTION, ROLLING, CLEANUP }
var current_phase: ShopPhase = ShopPhase.IDLE

func _ready() -> void:
	initialize_slots()
	
	connect_ui_elements()

func connect_ui_elements() -> void:
	shop_ui.roll_button.pressed.connect(execute_shop_roll)
	shop_ui.sell_button.pressed.connect(sell_selected_slot)
	shop_ui.sell_button.manager = self

func initialize_slots():
	for i in range(max_party_size):
		var party_slot: ShopSlot = Preloads.shop_slot.instantiate()
		party_slot.shop_manager = self
		party_slot.slot_number = i + 1 # Assigns 1-based index mapping for transactions
		shop_ui.party_slots.add_child(party_slot)
		party_slots.append(party_slot)
		
	for i in range(max_party_size):
		var shop_slot: ShopSlot = Preloads.shop_slot.instantiate()
		shop_slot.shop_manager = self
		shop_slot.slot_number = i + 1
		shop_ui.shop_slots.add_child(shop_slot)
		shop_slots.append(shop_slot)

	update_shop_UI()

func select_slot(slot: ShopSlot) -> void:
	if current_phase != ShopPhase.IDLE: return
	
	# If the player clicks the already selected slot, deselect it
	if selected_slot == slot:
		selected_slot = null
		print("Deselected slot.")
	else:
		selected_slot = slot
		print("Selected slot: ", slot.slot_number)
	# Visual outline code here

func sell_selected_slot() -> void:
	# Rule validations
	if selected_slot == null or selected_slot.slot_is_empty or current_phase != ShopPhase.IDLE:
		return
		
	# Ensure we are selling from the player's party, not the shop
	var is_party_slot: bool = party_slots.has(selected_slot)
	if not is_party_slot:
		return

	current_phase = ShopPhase.TRANSACTION
	
	var target_index: int = selected_slot.slot_number - 1
	var item_to_sell: PurchaseableData = PlayerData.playerParty[target_index]
	
	# Calculate dynamic refund based on the Tier (Bronze=1, Silver=2, Gold=3, Legendary=4)
	var refund_amount: int = 1 # Base backup cost
	if item_to_sell is HeroData:
		match item_to_sell.current_tier:
			HeroData.HeroTier.BRONZE:
				refund_amount = 1 # Cost to buy: 2
			HeroData.HeroTier.SILVER:
				refund_amount = 2 # Cost to buy: 4
			HeroData.HeroTier.GOLD, HeroData.HeroTier.LEGENDARY:
				refund_amount = 3 # Cost to buy: 6 (Legendary retains Gold value)
	
	# Process transaction data mutation
	PlayerData.essence += refund_amount
	PlayerData.playerParty[target_index] = null
	
	print("Sold %s for %d Essence." % [item_to_sell.name, refund_amount])
	
	# Reset selection state
	selected_slot = null
	
	# Linear UI rebuild
	current_phase = ShopPhase.IDLE
	update_shop_UI()

func execute_shop_roll():
	if current_phase != ShopPhase.IDLE: return
	
	if not PlayerData.can_pay(PlayerData.get_reroll_cost()):
		print("Roll failed: Cannot afford shop refresh.")
		return
		
	PlayerData.deduct_cost(PlayerData.get_reroll_cost())
	
	roll_shop_slots()
	
	# _update_currency_ui() # Direct call to refresh your gold/essence counters

func roll_shop_slots() -> void:
	# 1. Verification gates
	if current_phase != ShopPhase.IDLE: return
	if PlayerData.active_roster.is_empty():
		print("Roll failed: Active run deck is empty! Add heroes to pool first.")
		return
		
	current_phase = ShopPhase.ROLLING
	
	# 2. Populate each shop bench slot
	for slot in shop_slots:
		# Pick a completely random master resource from the player's custom deck
		var random_index: int = randi() % PlayerData.active_roster.size()
		var hero: HeroData = PlayerData.active_roster[random_index]
		
		slot.display_item(hero)
		
	current_phase = ShopPhase.IDLE
	print("Shop refreshed using customized player pool.")

func execute_transaction(source_slot: ShopSlot, target_slot: ShopSlot) -> void:
	if current_phase != ShopPhase.IDLE: return
	
	var incoming_data = source_slot.slot_item
	if incoming_data == null: return
	
	if not PlayerData.can_pay(incoming_data.cost):
		print("Cannot afford: ", incoming_data.spiritName)
		return

	current_phase = ShopPhase.TRANSACTION
	
	if incoming_data is HeroData:
		await _handle_hero_placement(incoming_data, source_slot, target_slot)
		
	current_phase = ShopPhase.IDLE
	update_shop_UI()

func _handle_hero_placement(hero: HeroData, shop: ShopSlot, target: ShopSlot) -> void:
	var target_index = target.slot_number - 1
	
	# Ensure backend data array is large enough to prevent index out of bounds
	if PlayerData.player_party.size() < party_slots.size():
		PlayerData.player_party.resize(party_slots.size())
	
	# 1. Merge Check
	if not target.slot_is_empty and target.slot_item is HeroData:
		var target_hero: HeroData = PlayerData.player_party[target_index]
		
		if target_hero.can_merge_with(hero):
			PlayerData.deduct_cost(hero.cost)
			target_hero.advance_tier() # Upgrades target instance from Bronze -> Silver -> Gold
			shop.clear_slot()
			update_shop_UI() 
			return
		else:
			print("Merge rejected: Maximum tier reached or distinct characters.")
			return
		
	# 2. Open Slot rules check
	if target.slot_is_empty:
		PlayerData.deduct_cost(hero.cost)
		
		# Assign the new instance to the player
		var hero_instance: HeroData = hero.duplicate() 
		PlayerData.player_party[target_index] = hero_instance
		
		shop.clear_slot()
		update_shop_UI()
		return
		
	# 3. Shifting row rules check
	var empty_index = find_nearest_empty_slot(target_index)
	if empty_index != -1:
		PlayerData.deduct_cost(hero.cost)
		shop.clear_slot()
		
		shift_party_slots(target_index, empty_index)
		
		# Assign the new instance to the player
		var hero_instance: HeroData = hero.duplicate() 
		PlayerData.player_party[target_index] = hero_instance
		
		update_shop_UI()
	else:
		print("Placement failed: Lineup is entirely full.")

func shift_party_slots(target_idx: int, empty_idx: int) -> void:
	if target_idx < empty_idx:
		for i in range(empty_idx, target_idx, -1):
			PlayerData.player_party[i] = PlayerData.player_party[i-1]
	else:
		for i in range(empty_idx, target_idx):
			PlayerData.player_party[i] = PlayerData.player_party[i+1]
			
	PlayerData.player_party[target_idx] = null

func find_nearest_empty_slot(start_idx: int) -> int:
	for i in range(start_idx, party_slots.size()):
		if party_slots[i].slot_is_empty: return i
	for i in range(start_idx, -1, -1):
		if party_slots[i].slot_is_empty: return i
	return -1

func update_shop_UI() -> void:
	for i in range(party_slots.size()):
		if i < PlayerData.player_party.size() and PlayerData.player_party[i] != null:
			party_slots[i].display_item(PlayerData.player_party[i])
		else:
			party_slots[i].clear_slot()
	for i in range(shop_slots.size()):
		if shop_slots[i].slot_is_empty:
			shop_slots[i].clear_slot()
