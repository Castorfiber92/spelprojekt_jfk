extends PanelContainer

var active_hero : Hero
@onready var name_label : Label = $VBoxContainer/HeroName
var namn : String = "Namn"

func _ready() -> void:
	update_info()
	
func update_info():
	if active_hero != null:
		name_label.text = active_hero.hero.name
