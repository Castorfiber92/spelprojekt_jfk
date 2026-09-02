extends Node

const FLASH_SHADER = preload("res://Graphics/Shader Materials/flash_shader.gdshader")
const crit_intensity : Vector2 = Vector2(10,-10)
const crit_duration = 0.025
const crit_loops = 4

func play_critical_hit(sprite : Control) -> Tween:
	var tween = create_tween()
		
	var crit_duration: float = 0.20
	var crit_loops: int = 4
	var crit_intensity: Vector2 = Vector2(10, -10) # Stronger shake for crits!
		
	# 1. Strong shake
	shake_node(sprite, crit_intensity, crit_duration, crit_loops)
	
	# 2. Bright white/yellow flash instead of an alpha flicker
	flash_sprite(sprite, Color.GOLD, crit_duration, crit_loops)
	
	return tween


func flash_sprite(sprite: CanvasItem, color: Color = Color.WHITE, total_duration: float = 0.20, loops: int = 6) -> Tween:
	var tween = create_tween()
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = FLASH_SHADER
	sprite.material = shader_material
	
	shader_material.set_shader_parameter("flash_color", color)
	shader_material.set_shader_parameter("flash_modifier", 0.0)

	# Calculate single step duration based on total desired time
	var single_flash_duration = total_duration / (loops * 2.0) ## this number is according to the amount of loops
	
	for i in range(loops):
		# Chain these internal steps sequentially
		tween.tween_property(shader_material, "shader_parameter/flash_modifier", 1.0, single_flash_duration)
		tween.tween_property(shader_material, "shader_parameter/flash_modifier", 0.0, single_flash_duration)
	
	tween.tween_callback(func(): sprite.material = null)
	return tween

func shake_node(node: Control, intensity: Vector2 = Vector2(5, -5), total_duration: float = 0.15, loops: int = 3) -> Tween:
	var tween = create_tween()
		
	var original_pos = node.position
	var single_step_duration = total_duration / (loops * 2.0) ## this number is according to the amount of loops
	
	for i in range(loops):
		tween.tween_property(node, "position", original_pos + intensity, single_step_duration)
		tween.tween_property(node, "position", original_pos - intensity, single_step_duration)
	
	tween.tween_callback(func(): node.position = original_pos)
	return tween

func shake_node_rotation(node: Control, angle_degrees: float = 4.0, duration: float = 0.04, loops: int = 3) -> Tween:
	node.pivot_offset = node.size / 2.0
	var tween = create_tween()
	
	for i in range(loops):
		tween.tween_property(node, "rotation_degrees", angle_degrees, duration)
		tween.tween_property(node, "rotation_degrees", -angle_degrees, duration)
		
	tween.chain().tween_property(node, "rotation_degrees", 0.0, duration)
	return tween

func flicker_node(node: CanvasItem, frequency: float = 0.04, loops: int = 5) -> Tween:
	var tween = create_tween()
	for i in range(loops):
		tween.tween_property(node, "self_modulate", Color(1, 1, 1, 0), frequency)
		tween.tween_property(node, "self_modulate", Color(1, 1, 1, 1), frequency)
	return tween
	
func spawn_floating_text(target_node: Control, crit : bool, text: String, color: Color = Color.WHITE, total_duration: float = 0.5) -> Tween:
		
	# 1. Create and configure the label
	var label = Label.new()
	label.text = text
	label.text_direction = TextServer.DIRECTION_LTR
	
	# Match styling (Optional: apply a theme or custom font if you have one)
	label.add_theme_color_override("font_color", color)
	var custom_font = Preloads.custom_font
	# Apply it to the label
	label.add_theme_font_override("font", custom_font)
	label.add_theme_font_size_override("font_size", 50)
	

	# --- 1. FORCE THE LABEL TO CENTER ITS OWN TEXT INTERNAL TO ITS BOUNDS ---
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_size = label.get_combined_minimum_size()
	label.pivot_offset = label_size / 2.0
	# --- 2. CALCULATE THE TRUE CENTER POSITION ---
	# Find the middle point of the slot sprite using its size
	var target_center_x = target_node.global_position.x + (target_node.size.x / 2.0)
	var final_x = target_center_x - (label_size.x / 2.0)
	
	# Set the corrected start position (slightly above the target top)
	label.position = Vector2(final_x, target_node.global_position.y - 20)
	label.top_level = true # Prevents the sprite's alpha from hiding the text!
	label.z_index = 100    # Ensures it renders on top of everything else
	
	# Add it to the tree so it actually renders
	target_node.get_tree().current_scene.add_child(label)
	
	var tween = target_node.create_tween()
	
	if crit:
		# Start shrunken to zero for the center explosion pop
		label.scale = Vector2.ZERO
		
		# --- PHASE 1: THE CRUNCHY/SNAPPY POP ENTRY (0.25 seconds total) ---
		# Fast burst to 2.0x scale from center pivot
		tween.tween_property(label, "scale", Vector2(2.0, 2.0), 0.15)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
			
		# Fast snap back down to standard 1.0x scale
		tween.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.10)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
			
		# --- PHASE 2: MOVE AND FADE AWAY ---
		var remainder_duration = max(0.05, total_duration - 0.25)
		
		# Chain forces the upward drift to wait until the scaling snaps back to 1.0
		#tween.chain().tween_property(label, "position:y", label.position.y - 50, remainder_duration)\
			#.set_trans(Tween.TRANS_CUBIC)\
			#.set_ease(Tween.EASE_OUT)
			
		# Parallel runs the fade-out side-by-side with the upward drift phase
		tween.parallel().tween_property(label, "modulate:a", 0.0, remainder_duration)

	else:
		label.scale = Vector2.ONE
		# Slide upwards smoothly
		tween.tween_property(label, "position", label.position + Vector2(0, -40), total_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	
		# Fade out over the same time
		tween.parallel().tween_property(label, "modulate:a", 0.0, total_duration)
	
	# 3. Clean up the label from memory when the tween is completely done
	tween.tween_callback(func(): label.queue_free())
	
	return tween
