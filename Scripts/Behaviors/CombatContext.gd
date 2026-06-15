class_name CombatContext

var source: HeroSlot
var targets: Array[HeroSlot]
	
func _init(_source: HeroSlot, _targets: Array[HeroSlot] = []):
	self.source = _source
	self.targets = _targets
