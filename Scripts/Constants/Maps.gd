class_name Maps

#Enchantment to status effect map

static func get_status_from_type(enchantment_type : Enums.StatusType):
	match enchantment_type:
		Enums.StatusType.BURN: 
			return preload("res://Resources/Behaviors/Effects/Debuffs/Basic Statuses/status_burn_basic.tres")
		Enums.StatusType.FREEZE: 
			pass
			#return preload()
		Enums.StatusType.POISON: 
			return preload("res://Resources/Behaviors/Effects/Debuffs/Basic Statuses/status_poison_basic.tres")
		Enums.StatusType.CURSE:
			return preload("res://Resources/Behaviors/Effects/Debuffs/Basic Statuses/status_curse_basic.tres")
		Enums.StatusType.ARMOR: 
			return preload("res://Resources/Behaviors/Effects/Buffs/Basic Statuses/status_armor_basic.tres")
		Enums.StatusType.COUNTERATTACK: 
			pass
			#return preload()
		Enums.StatusType.MULTICAST: 
			pass
			#return preload()
