extends Resource
class_name HeroData

@export var name : String
@export var description : String
@export var sprites : SpriteFrames
@export var tribe : Enums.Tribe
@export_range(10,50) var base_HP : int
@export_range(1,10) var base_damage : int
@export_range(1,100) var base_speed : int
@export_range(1,5) var base_range : int
@export var base_action : Behavior
@export_group("Base abilities")
@export var abilities : Array[Behavior]
