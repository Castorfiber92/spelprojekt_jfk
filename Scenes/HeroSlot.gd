extends PanelContainer

var activeHero : Hero
@onready var nameLabel : Label = %HeroName
var namn : String = "Namn"

func _ready() -> void:
	UpdateInfo()
	
func UpdateInfo():
	nameLabel.text = activeHero.hero.name
