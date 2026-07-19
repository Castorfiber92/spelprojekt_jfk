extends Resource
class_name CombatComposition
enum CombatType {NORMAL, ELITE, BOSS}
# index 0-1 frontline, index 2-4 backline
@export var enemy_team: Array[HeroData] = [null, null, null, null, null]
@export var encounter_name: String = ""
@export var encounter_type: CombatType = CombatType.NORMAL
