extends PanelContainer
class_name HeroSlot

@export var hero : Hero
@export var hp_label : Label 
@export var damage_label : Label
@export var name_label : Label

func _ready() -> void:
	update_info()

func apply_damage_effect() -> Tween:
	var tween = create_tween().set_parallel(true)
	var shake_intensity = 4.0
	var shake_duration = 0.05
	var flash_color = Color(1, 0.3, 0.3) # Soft red

	# 1. SOFT RED FLASH
	# Tweens the color to red, then back to white (normal)
	var color_tween = create_tween()
	color_tween.tween_property(self, "modulate", flash_color, 0.1)
	color_tween.tween_property(self, "modulate", Color.WHITE, 0.2)

	# 2. SHAKE EFFECT (Sequential loop within the parallel tween)
	# Creates 4 quick random movements
	for i in range(4):
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
		tween.tween_property(self, "position", position + offset, shake_duration)
	
	# Reset position to original at the end
	tween.chain().tween_property(self, "position", position, shake_duration)
	return tween
	
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
