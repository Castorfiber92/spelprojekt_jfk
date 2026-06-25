extends Node

var reroll_cost : int = 2

var player_party : Array[HeroData] = []
var essence : int

var active_roster: Array[HeroData] = []

func can_pay(amount : int) -> bool:
	return essence >= amount 
	
func deduct_cost(amount : int):
	essence = max(0, essence - amount)
	
func get_reroll_cost() -> int:
	# put logic here if you have effects for the cost
	return essence
	
# This does not belong here, but it is to add it later.	
func add_hero_to_run_pool(selected_hero: HeroData) -> void:
	if not PlayerData.active_roster.has(selected_hero):
		PlayerData.active_roster.append(selected_hero)
		print("%s added to the active roll pool!" % selected_hero.name)
