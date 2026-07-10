extends PanelContainer
class_name HeroSlot

@export var hero : Hero
@onready var hp_label : Label = $VBoxContainer/HBoxContainer/HP/Label
@onready var damage_label : Label = $VBoxContainer/HBoxContainer/DAMAGE/Label
@onready var name_label : Label = $VBoxContainer/PanelContainer2/HeroName
@onready var sprite: TextureRect = $VBoxContainer/PanelContainer/TextureRect
@onready var buff_slots_buffs: HBoxContainer = $VBoxContainer/BuffSlots/HBoxContainer

var index: int = 0

func is_occupied () -> bool:
	return hero != null

func _ready() -> void:
	update_info()

func play_animation(anim_name: String, anim_duration : float = 0.15) -> void:
	if hero and hero.hero_data.sprites and hero.hero_data.sprites.has_animation(anim_name):
		sprite.texture = hero.hero_data.sprites.get_frame_texture(anim_name, 0)
	await get_tree().create_timer(anim_duration).timeout
	# If we just played an attack/action pose, return them back to their resting posture
	if anim_name != "idle" and hero.hero_data.sprites and hero.hero_data.sprites.has_animation(anim_name):
		sprite.texture = hero.hero_data.sprites.get_frame_texture("idle", 0)

func apply_damage_effect(crit : bool) -> Tween:
	if crit:
		return VisualEffects.play_critical_hit(sprite)

	VisualEffects.flash_sprite(sprite, Color.FIREBRICK)
	return VisualEffects.shake_node(sprite)

func apply_damage_effect_old() -> Tween:
	var shake_intensity = 4.0
	var shake_duration = 0.05
	var flash_color = Color(1, 0.3, 0.3) # Soft red

	# 1. SOFT RED FLASH (Targets the sprite texture layout)
	var color_tween = create_tween()
	color_tween.tween_property(sprite, "modulate", flash_color, 0.1)
	color_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

	# 2. SPRITE POSITION SHAKE
	var shake_tween = create_tween()
	
	# ✅ FIX: Store the original local position of the SPRITE node, not the container panel
	var original_sprite_position = sprite.position
	
	for i in range(4):
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5)) * shake_intensity
		# ✅ FIX: Tween the 'sprite' node position property instead of 'self'
		shake_tween.tween_property(sprite, "position", original_sprite_position + offset, shake_duration)
	
	# Reset explicitly back to the original sprite coordinate base
	shake_tween.tween_property(sprite, "position", original_sprite_position, shake_duration)
	
	return shake_tween

func apply_heal_effect() -> Tween:
	var shake_intensity = 4.0
	var shake_duration = 0.05
	var flash_color = Color(0.0, 0.7, 0.407, 1.0) # Soft green

	# 1. SOFT GREEN FLASH
	var color_tween = create_tween()
	color_tween.tween_property(sprite, "modulate", flash_color, 0.1)
	color_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

	# 2. SPRITE POSITION SHAKE
	var shake_tween = create_tween()
	var original_sprite_position = sprite.position
	
	for i in range(4):
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5)) * shake_intensity
		shake_tween.tween_property(sprite, "position", original_sprite_position + offset, shake_duration)
	
	shake_tween.tween_property(sprite, "position", original_sprite_position, shake_duration)
	return shake_tween

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
	set_modulate(Color.WHITE) # Clears panel highlights
	sprite.set_modulate(Color.WHITE) # Clears color tints
	# Reset the sprite's relative canvas position back to zero if it got offset
	sprite.position = Vector2.ZERO 
	if hero == null:
		sprite.texture = null

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
		add_buff_slots()

	else:
		##If there is NO hero
		##Hide the labels
		toggle_visibility(false)

func add_buff_slots():
	for child in buff_slots_buffs.get_children():
			child.queue_free()
	var mg_container = MarginContainer.new()
	mg_container.custom_minimum_size = Vector2(0,40)
	buff_slots_buffs.add_child(mg_container)
	for b : Behavior in hero.behaviors.values():
		if b.type == b.BehaviorType.BUFF:
			var buff_slot = Preloads.buff_slot.instantiate()
			buff_slots_buffs.add_child(buff_slot)
			buff_slot.setup(b)
