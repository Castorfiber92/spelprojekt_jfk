extends Control
class_name ShopManager

var party_slots: Array[ShopSlot] = []
var shop_slots: Array[ShopSlot] = []
@export var shop_ui : ShopUi
@export var max_party_size: int = 5
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
	# 1. Fetch player party sub-containers
	var party_frontline_ui = shop_ui.party_slots.get_node("Frontline")
	var party_backline_ui = shop_ui.party_slots.get_node("Backline")

	for i in range(max_party_size):
		var party_slot: ShopSlot = Preloads.shop_slot.instantiate()
		party_slot.shop_manager = self
		party_slot.slot_number = i + 1 # (1 to 5)
		
		# Route visually: 0, 1, 2 to Frontline; 3, 4 to Backline
		if i <= 2:
			party_frontline_ui.add_child(party_slot)
		else:
			party_backline_ui.add_child(party_slot)
			
		party_slots.append(party_slot)
		
	# 2. Fetch shop inventory sub-containers
	var shop_frontline_ui = shop_ui.shop_slots.get_node("Frontline")
	var shop_backline_ui = shop_ui.shop_slots.get_node("Backline")

	for i in range(max_shop_size):
		var shop_slot: ShopSlot = Preloads.shop_slot.instantiate()
		shop_slot.shop_manager = self
		shop_slot.slot_number = i + 1 # (1 to 5)
		
		# Route visually: 0, 1, 2 to Shop Frontline; 3, 4 to Shop Backline
		if i <= 2:
			shop_frontline_ui.add_child(shop_slot)
		else:
			shop_backline_ui.add_child(shop_slot)
			
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
	var item_to_sell: PurchaseableData = PlayerData.player_party[target_index]
	
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
	PlayerData.player_party[target_index] = null
	
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
	if current_phase != ShopPhase.IDLE: return
	if PlayerData.active_roster.is_empty(): return
		
	current_phase = ShopPhase.ROLLING
	
	for slot in shop_slots:
		var random_index: int = randi() % PlayerData.active_roster.size()
		var hero: HeroData = PlayerData.active_roster[random_index]
		
		slot.display_item(hero)
		# Ensure the graphic is turned back on after being bought out previously
		slot.UI.visible = true 
		
	current_phase = ShopPhase.IDLE


func execute_transaction(source_slot: ShopSlot, target_slot: ShopSlot) -> void:
	if current_phase != ShopPhase.IDLE: return
	if source_slot == target_slot: return # Can't drop onto itself
	
	var incoming_data = source_slot.slot_item
	if incoming_data == null: return
	
	current_phase = ShopPhase.TRANSACTION
	
	# Check if we are moving an existing party member or buying a new one
	var is_rearrangement: bool = party_slots.has(source_slot)
	
	if is_rearrangement:
		_handle_party_rearrangement(source_slot, target_slot)
	else:
		# Standard shop purchase logic
		if not PlayerData.can_pay(incoming_data.cost):
			print("Cannot afford: ", incoming_data.spiritName)
			current_phase = ShopPhase.IDLE
			return
			
		if incoming_data is HeroData:
			_handle_hero_placement(incoming_data, source_slot, target_slot)
		
	current_phase = ShopPhase.IDLE
	update_shop_UI()

func _handle_party_rearrangement(source: ShopSlot, target: ShopSlot) -> void:
	var source_index = source.slot_number - 1
	var target_index = target.slot_number - 1
	
	# Grab references from the actual player party array
	var source_hero = PlayerData.player_party[source_index]
	var target_hero = PlayerData.player_party[target_index]
	
	# Swap the data positions in the backend array
	PlayerData.player_party[target_index] = source_hero
	PlayerData.player_party[source_index] = target_hero
	
	print("Rearranged party: Swapped slot %d and slot %d." % [source.slot_number, target.slot_number])

func _handle_hero_placement(hero: HeroData, shop: ShopSlot, target: ShopSlot) -> void:
	var target_index = target.slot_number - 1
	
	# Ensure backend data array matches our exact 5-slot grid boundary
	if PlayerData.player_party.size() < 5:
		PlayerData.player_party.resize(5)
	
	# RULE 1: Merge Check (Same hero, upgrade tier)
	if not target.slot_is_empty and target.slot_item is HeroData:
		var target_hero: HeroData = PlayerData.player_party[target_index]
		
		if target_hero.can_merge_with(hero):
			PlayerData.deduct_cost(hero.cost)
			target_hero.advance_tier() 
			shop.clear_slot()
			update_shop_UI() 
			return
		else:
			# ---- FIXED: Deny placement outright if it's a different hero ----
			print("Placement rejected: Slot is occupied.")
			return
		
	# RULE 2: Open Slot (Clean placement)
	if target.slot_is_empty:
		PlayerData.deduct_cost(hero.cost)
		
		var hero_instance: HeroData = hero.duplicate() 
		PlayerData.player_party[target_index] = hero_instance
		
		shop.clear_slot()
		update_shop_UI()
		return

func update_shop_UI() -> void:
	# 1. Update party grid board
	for i in range(party_slots.size()):
		if i < PlayerData.player_party.size() and PlayerData.player_party[i] != null:
			party_slots[i].display_item(PlayerData.player_party[i])
		else:
			party_slots[i].clear_slot()

	# 2. Update shop inventory 
	for i in range(shop_slots.size()):
		if shop_slots[i].slot_item != null:
			# Re-trigger display to ensure graphics/labels refresh cleanly
			shop_slots[i].display_item(shop_slots[i].slot_item)
		else:
			shop_slots[i].clear_slot()
