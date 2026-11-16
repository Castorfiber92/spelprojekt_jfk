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
	roll_shop_slots(true)
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
		
		# Route visually: 0, 1 to Frontline; 2, 3, 4 to Backline
		if i <= 1:
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
		if i <= 1:
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
	var hero_to_sell: Hero = PlayerData.player_party[target_index]
	var blueprint: HeroData = hero_to_sell.hero_data
	
	# Calculate dynamic refund based on the Tier (Bronze=1, Silver=2, Gold=3)
	var refund_amount: int = 1 # Base backup cost
	
	match hero_to_sell.tier_component.current_tier:
		Enums.HeroTier.BRONZE:
			refund_amount = 1 # Cost to buy: 2
		Enums.HeroTier.SILVER:
			refund_amount = 2 # Cost to buy: 4
		Enums.HeroTier.GOLD, Enums.HeroTier.LEGENDARY:
			refund_amount = 3 # Cost to buy: 6
			
	# Process transaction data mutation
	PlayerData.essence += refund_amount
	PlayerData.player_party[target_index] = null
	
	print("Sold %s for %d Essence." % [blueprint.name, refund_amount])
	
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
	
	# _update_currency_ui() # Direct call to refresh gold/essence counters

func roll_shop_slots(shop_loaded = false) -> void:
	if current_phase != ShopPhase.IDLE: return
	#if PlayerData.active_roster.is_empty(): return
		
	current_phase = ShopPhase.ROLLING
	
	fetch_shop_heroes()
	if not shop_loaded:
		for i in shop_slots:
			VisualEffects.shake_node_rotation(i)
	current_phase = ShopPhase.IDLE

func execute_transaction(source_slot: ShopSlot, target_slot: ShopSlot) -> void:
	if current_phase != ShopPhase.IDLE: return
	if source_slot == target_slot: return # Can't drop onto itself
	var incoming_data = source_slot.slot_item
	if incoming_data == null: return
	
	# Check if we are moving an existing party member or buying a new one
	var is_rearrangement: bool = party_slots.has(source_slot)
	
	if is_rearrangement:
		_handle_party_rearrangement(source_slot, target_slot)
	else:
		# Guard clause, if there is an existing hero on the slot we try to drag on, we leave
		#if target_slot.slot_item != null: return
		current_phase = ShopPhase.TRANSACTION
		var blueprint = incoming_data as HeroData
		# Standard shop purchase logic
		if not PlayerData.can_pay(blueprint.cost):
			print("Cannot afford: ", blueprint.name)
			current_phase = ShopPhase.IDLE
			return

		_handle_hero_placement(blueprint, source_slot, target_slot)
		
	current_phase = ShopPhase.IDLE
	update_shop_UI()

func _handle_party_rearrangement(source: ShopSlot, target: ShopSlot) -> void:
	var source_index = source.slot_number - 1
	var target_index = target.slot_number - 1
	
	var source_hero: Hero = PlayerData.player_party[source_index]
	var target_hero: Hero = PlayerData.player_party[target_index]
	
	if source_hero == null:
		return

	# 1. Check if we can merge two existing party heroes
	if target_hero != null:
		var is_same_tier: bool = source_hero.tier_component.current_tier == target_hero.tier_component.current_tier
		if is_same_tier and target_hero.tier_component.can_merge_with(source_hero.hero_data):
			PlayerData.player_party[source_index] = null # Remove the consumed hero
			target_hero.tier_component.advance_tier()
			VisualEffects.shake_node_rotation(target)
			print("Merged %s into tier %s!" % [target_hero.hero_data.name, target_hero.tier_component.get_tier_string()])
			return

	# 2. Otherwise, perform a standard swap
	PlayerData.player_party[source_index] = target_hero
	PlayerData.player_party[target_index] = source_hero
	VisualEffects.shake_node_rotation(target)
	if target_hero != null:
		VisualEffects.shake_node_rotation(source)
	print("Rearranged party: Swapped slot %d and slot %d." % [source.slot_number, target.slot_number])

func _handle_hero_placement(blueprint: HeroData, source_slot: ShopSlot, target_slot: ShopSlot) -> void:
	var target_index: int = target_slot.slot_number - 1
	
	# Create a unique runtime node instance from the shop's blueprint resource
	var new_live_hero: Hero = Hero.create(blueprint)
	
	# Check if the target party slot already has a character standing there, then advance tier instead
	var existing_hero: Hero = PlayerData.player_party[target_index]
	if existing_hero != null:
		var is_same_tier: bool = new_live_hero.tier_component.current_tier == existing_hero.tier_component.current_tier
		if is_same_tier and existing_hero.tier_component.can_merge_with(blueprint):
			existing_hero.tier_component.advance_tier()
			PlayerData.deduct_cost(blueprint.cost)
			VisualEffects.shake_node_rotation(target_slot)
			source_slot.slot_item = null
		else:
			return
	else:
		PlayerData.player_party[target_index] = new_live_hero
		PlayerData.deduct_cost(blueprint.cost)
		VisualEffects.shake_node_rotation(target_slot)
		source_slot.slot_item = null 
	

func update_shop_UI() -> void:
	# 1. Update party grid board
	for i in range(party_slots.size()):
		if i < PlayerData.player_party.size() and PlayerData.player_party[i] != null:
			party_slots[i].display_item(PlayerData.player_party[i])
		else:
			party_slots[i].clear_slot()
	for i in range(shop_slots.size()):
		if shop_slots[i].slot_item != null:
			shop_slots[i].display_item(shop_slots[i].slot_item)
		else:
			shop_slots[i].clear_slot()


func fetch_shop_heroes() -> void:
	print("Rolling shop slots....")
	# 2. Update shop inventory 
	for i in range(shop_slots.size()):
		var random_hero: HeroData = DatabaseManager.get_all_heroes_by_tribe(PlayerData.active_tribe).pick_random()
		
		if random_hero != null:
			# Assign the raw data to the item state first
			var shelf_copy = random_hero.duplicate()
			shop_slots[i].display_item(shelf_copy)
			shop_slots[i].UI.visible = true
		else:
			shop_slots[i].clear_slot()
	update_shop_UI()
