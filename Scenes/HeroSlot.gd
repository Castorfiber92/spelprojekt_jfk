extends PanelContainer
class_name HeroSlot

@export var active_hero : Hero
enum team {HERO_ENEMY, HERO_PLAYER}
@export var hp_label : Label
@export var damage_label : Label
@export var name_label : Label

func _ready() -> void:
	update_info()

func set_hero(hero : Hero):
	active_hero = hero
	update_info()

func remove_hero():
	active_hero = null
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

func update_info():
	##We are callilng this whenever we need to update the labels
	##First we check that there is, in fact, a active hero in the slot (error-check)
	if active_hero != null:
		##If there is, we convert the correct variables to strings and update the information
		##First, we show the labels again
		toggle_visibility()
		hp_label.text = str(active_hero.current_HP)
		damage_label.text = str(active_hero.current_damage)
		name_label.text = active_hero.hero.name
	else:
		##If there is NO hero
		##Hide the labels
		toggle_visibility(false)
