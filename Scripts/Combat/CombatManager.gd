extends Node
class_name CombatManager

@export var combat_ui : CombatUI
@export var slots : Array[HeroSlot]
##Below is temporary, for testing
@export var player_heroes : Array[HeroData]
@export var enemy_heroes : Array[HeroData]

func _ready() -> void:
	create_slots()

func create_slots():
	##Here we will create slots according to the playerparty (which does not exist right now)
	## and according to what type of enemies we want to generate. Right now this is temporary,
	## so that we might begin just testing it. The generating/loading we will cover later on.
	load_player_party()
	load_enemy_party()
		

func set_hero(slot : HeroSlot, hero : Hero):
	slot.active_hero = hero

func remove_hero(slot : HeroSlot):
	slot.active_hero = null
	
func initialize_combat():
	pass
	
func load_player_party():
	for i in player_heroes:
		var slot = HeroSlot.new()
		##Add it to the UI
		combat_ui.player_party.add_child(slot)
		##Assign the team to Player
		slot.team = slot.team.HERO_PLAYER
		##Add it to our array
		slots.append(slot)
		##Create a Hero class from the HeroData (so we don't mess up the Resource)
		var hero = Hero.new()
		##Set the Hero class data according to the HeroData in the array above
		hero.hero = i
		##Update the slot with the correct hero
		set_hero(slot, hero)

func load_enemy_party():
	for i in enemy_heroes:
		var slot = HeroSlot.new()
		##Add it to the UI
		combat_ui.enemy_party.add_child(slot)
		##Assign the team to Player
		slot.team = slot.team.HERO_ENEMY
		##Add it to our array
		slots.append(slot)
		##Create a Hero class from the HeroData (so we don't mess up the Resource)
		var hero = Hero.new()
		##Set the Hero class data according to the HeroData in the array above
		hero.hero = i
		##Update the slot with the correct hero
		set_hero(slot, hero)
