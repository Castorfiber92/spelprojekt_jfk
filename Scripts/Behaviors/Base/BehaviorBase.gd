extends Resource
class_name BehaviorBase

@export var name : String
var owner_hero: Hero
@export var target_team: Enums.Team
@export var target_type: Enums.Target
##0 range for self-targeting or if we are not using a custom range
@export_range(0,5) var range : int
##Below we will have functions for every event we want to check
##which means on_hit, on_death, on_taking_damage etc etc.
##Then, we create resources for each behaviorData and define what said behavior is doing on every 
##event.

func on_execute_action(data):
	pass

func on_start_of_battle(data):
	pass

func on_attack(data):
	pass

func on_damage_dealt(data):
	pass

func on_damage_taken(data):
	pass
	
func on_death(data):
	pass
	
