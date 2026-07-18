extends Node
##Paths to various packedscene objects
@onready var hero_slot: = preload("res://Scenes/HeroSlot.tscn")
@onready var shop_slot = preload("res://Scenes/Shop/shop_slot.tscn")
@onready var buff_slot: = preload("res://Scenes/BuffSlot.tscn")
@onready var overworld_scene: = preload("res://Scripts/Overworld/OverworldManager.tscn")
@onready var combat_scene: = preload("res://Scenes/Combat/CombatScene.tscn")
@onready var shop_scene: = preload("res://Scenes/Shop/shop_manager.tscn")
@onready var combat_event: = preload("res://Resources/Overworld/Events/combat_event_basic.tres")
@onready var tavern_event: = preload("res://Resources/Overworld/Events/tavern_event_basic.tres")
@onready var shop_event: = preload("res://Resources/Overworld/Events/shop_event_basic.tres")
@onready var encounter_event: = preload("res://Resources/Overworld/Events/encounter_event_basic.tres")
@onready var combat_boss_event: = preload("res://Resources/Overworld/Events/combat_boss_event.tres")
