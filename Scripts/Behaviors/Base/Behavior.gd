class_name Behavior

@export var name : String
##var owner_hero: Hero

##Below we will have functions for every event we want to check
##which means on_hit, on_death, on_taking_damage etc etc.
##Then, we create resources for each behaviorData and define what said behavior is doing on every 
##event.

func on_attack():
	print("Notcrit")
	pass
	
func on_death():
	pass
	
