extends PanelContainer
class_name HeroSlot

@export var hero : Hero
#enum team {HERO_ENEMY, HERO_PLAYER}
@export var hp_label : Label 
@export var damage_label : Label
@export var name_label : Label

func _ready() -> void:
	update_info()


func toggle_visibility(show = true):
	if show:
		hp_label.visible = true
		damage_label.visible = true
		name_label.visible = true
	else:
		hp_label.visible = false
		damage_label.visible = false
		name_label.visible = false

func cleanup():
	set_modulate(Color.WHITE)

func highlight_slot(source = true):
	# This is not final, only simple for testing
	if source:
		set_modulate(Colors.user_color)
	else :
		set_modulate(Colors.target_color)

func update_info():
	##We are calling this whenever we need to update the labels
	##First we check that there is, in fact, a active hero in the slot (error-check)
	if hero != null:
		##If there is, we convert the correct variables to strings and update the information
		##First, we show the labels again
		toggle_visibility()
		hp_label.text = str(hero.current_HP)
		damage_label.text = str(hero.current_damage)
		name_label.text = hero.hero_data.name
	else:
		##If there is NO hero
		##Hide the labels
		toggle_visibility(false)
