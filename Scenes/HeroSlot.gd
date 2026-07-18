extends PanelContainer
class_name HeroSlot

@export var hero : Hero
@onready var hp_label : Label = $VBoxContainer/HBoxContainer/HP/Label
@onready var damage_label : Label = $VBoxContainer/HBoxContainer/DAMAGE/Label
@onready var name_label : Label = $VBoxContainer/PanelContainer2/HeroName
@onready var sprite: TextureRect = $VBoxContainer/PanelContainer/TextureRect
@onready var buff_slots_buffs: HBoxContainer = $VBoxContainer/BuffSlots/HBoxContainer
var active_slots: Dictionary = {}
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

func apply_heal_effect() -> Tween:
	var shake_intensity = 1.0
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
		name_label.text = "DEAD"

func cleanup():
	set_modulate(Color.WHITE) # Clears panel highlights
	sprite.set_modulate(Color.WHITE) # Clears color tints
	# Reset the sprite's relative canvas position back to zero if it got offset
	sprite.position = Vector2.ZERO 
	if hero == null:
		sprite.texture = null
		clear_all_buff_slots()
		# 1. Clear the dictionary tracking the nodes
		active_slots.clear()

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
		update_buff_slots()

	else:
		##If there is NO hero
		##Hide the labels
		toggle_visibility(false)


func update_buff_slots():
	# 1. Ensure the container container exists once
	if buff_slots_buffs.get_child_count() == 0:
		var mg_container = MarginContainer.new()
		mg_container.custom_minimum_size = Vector2(0, 40)
		buff_slots_buffs.add_child(mg_container)

	# 2. Gather currently valid buffs from the hero
	var current_buffs: Array = []
	for b : Behavior in hero.behaviors.values():
		if b.type == b.BehaviorType.BUFF:
			current_buffs.append(b)

	# 3. Clean up expired buffs (removed from hero, but still have an icon)
	for b in active_slots.keys():
		if not b in current_buffs:
			var old_slot = active_slots[b]
			active_slots.erase(b)
			animate_out_and_free(old_slot)

	# 4. Add new buffs or refresh existing ones
	for b in current_buffs:
		if not active_slots.has(b):
			# This is a brand new buff -> Create and animate it
			var buff_slot = Preloads.buff_slot.instantiate()
			buff_slots_buffs.add_child(buff_slot)
			buff_slot.setup(b)
			
			active_slots[b] = buff_slot
			animate_in(buff_slot)
		else:
			# Buff already exists -> Just refresh its values (no animation)
			active_slots[b].setup(b)

func clear_all_buff_slots():
	for buff_slot in active_slots.values():
		if is_instance_valid(buff_slot):
			buff_slot.queue_free()

	active_slots.clear()

# --- Animation Helper Functions ---

func animate_in(buff_slot: Control):
	buff_slot.pivot_offset = buff_slot.size / 2
	buff_slot.scale = Vector2.ZERO
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(buff_slot, "scale", Vector2.ONE, 0.25)

func animate_out_and_free(buff_slot: Control):
	buff_slot.pivot_offset = buff_slot.size / 2
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN) # Eases in so it shrinks away quickly
	tween.tween_property(buff_slot, "scale", Vector2.ZERO, 0.15)
	
	# Free the memory automatically once the animation finishes
	tween.tween_callback(buff_slot.queue_free)
