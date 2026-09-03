extends PanelContainer
class_name HeroSlot

@export var hero : Hero
@onready var hp_label : Label = $HBoxContainer/HP/Label
@onready var damage_label : Label = $HBoxContainer/DAMAGE/Label
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


func apply_visual_effect(type : Enums.EffectType, crit : bool,value : int, shake = true) -> Tween:
	var master_tween = create_tween()
	var duration: float = 0.20 # Set our exact desired time here
	var text_duration: float = 1.25
	#var buffer_duration: float = 0.15 # The tiny pause after it finishes
	# Both functions inject their animations into the same timeline side-by-side
	var flash_color = Color.FIREBRICK if type == Enums.EffectType.DAMAGE else Color.WEB_GREEN
	var text_color = Color.RED if type == Enums.EffectType.DAMAGE else Color.GREEN
	var prefix = "-" if type == Enums.EffectType.DAMAGE else "+"
	VisualEffects.flash_sprite(sprite, flash_color, duration, 6)
	
	if shake:
		VisualEffects.shake_node(sprite, Vector2(5, -5), duration, 2)
	if crit:
		VisualEffects.flicker_node(sprite, 0.03, 4)

	# Guard clause in case we dont want any floating text we use -1 for value
	if value >= 0:
		# below is temporary, we can change it to something else later
		var text_string = str(prefix, value)
		VisualEffects.spawn_floating_text(sprite, crit, text_string, text_color, text_duration)
	# .chain() forces this step to wait until the flash/shake steps finish
	#tween.chain().tween_interval(buffer_duration)
	master_tween.tween_interval(duration)
	return master_tween 



func toggle_visibility(show = true):
	if show:
		sprite.visible = true
		hp_label.visible = true
		damage_label.visible = true
		name_label.visible = true
	else:
		sprite.visible = false
		hp_label.visible = false
		damage_label.visible = false
		name_label.text = ""

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
	if hero != null:
		toggle_visibility()
		var max_health = hero.current_HP
		hp_label.text = str(max_health)
		var dynamic_damage = hero.get_stat(Enums.StatType.DAMAGE)
		damage_label.text = str(dynamic_damage)
		name_label.text = hero.hero_data.name
		update_buff_slots()
	else:
		
		clear_all_buff_slots()
		toggle_visibility(false)


func update_buff_slots():
	
	# 1. Ensure the container container exists once
	if buff_slots_buffs.get_child_count() == 0:
		var mg_container = MarginContainer.new()
		mg_container.custom_minimum_size = Vector2(0, 40)
		buff_slots_buffs.add_child(mg_container)

	# 2. Gather currently valid buffs from the hero
	var current_buffs: Array = []
	
	# FIXED: Instead of reading the obsolete .behaviors dictionary, 
	# we call our backwards-compatible array function getter!
	for b in hero.get_behaviors():
		if b.data.type == BehaviorData.BehaviorType.BUFF:
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
			var buff_slot = Preloads.buff_slot.instantiate()
			buff_slots_buffs.add_child(buff_slot)
			buff_slot.setup(b)
			
			active_slots[b] = buff_slot
			animate_in(buff_slot)
		else:
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
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(buff_slot, "scale", Vector2(1.3, 1.3), 0.20)
	
	# Step 2: Smoothly settle back down to normal size (1.0)
	tween.set_trans(Tween.TRANS_CUBIC) # A smoother, cleaner transition for settling
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(buff_slot, "scale", Vector2.ONE, 0.10)

func animate_out_and_free(buff_slot: Control):
	buff_slot.pivot_offset = buff_slot.size / 2
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN) # Eases in so it shrinks away quickly
	tween.tween_property(buff_slot, "scale", Vector2.ZERO, 0.10)
	
	# Free the memory automatically once the animation finishes
	tween.tween_callback(buff_slot.queue_free)
