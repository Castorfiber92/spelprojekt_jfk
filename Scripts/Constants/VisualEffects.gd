extends Node

const FLASH_SHADER = preload("res://Graphics/Shader Materials/flash_shader.gdshader")
const crit_intensity : Vector2 = Vector2(15,-10)
const crit_duration = 0.025
const crit_loops = 4

func play_critical_hit(sprite : Control) -> Tween:
	shake_node(sprite, crit_intensity,crit_duration,crit_loops)
	return flicker_node(sprite)

func flash_sprite(sprite: CanvasItem, color: Color = Color.WHITE, duration: float = 0.03, loops: int = 2) -> Tween:
	var shader_material = ShaderMaterial.new()
	shader_material.shader = FLASH_SHADER
	sprite.material = shader_material
	
	shader_material.set_shader_parameter("flash_color", color)
	shader_material.set_shader_parameter("flash_modifier", 0.0) # Start at normal look

	var tween = create_tween()
	
	for i in range(loops):
		tween.tween_property(shader_material, "shader_parameter/flash_modifier", 1.0, duration)
		tween.tween_property(shader_material, "shader_parameter/flash_modifier", 0.0, duration)
	
	
	tween.tween_callback(func(): sprite.material = null)
	return tween

func shake_node(node: Control, intensity: Vector2 = Vector2(5, -5), duration: float = 0.05, loops: int = 3) -> Tween:
	var original_pos = node.position
	var tween = create_tween()
	
	for i in range(loops):
		tween.tween_property(node, "position", original_pos + intensity, duration)
		tween.tween_property(node, "position", original_pos - intensity, duration)
	
	tween.chain().tween_callback(func(): node.position = original_pos)
	return tween
	
func flicker_node(node: CanvasItem, frequency: float = 0.04, loops: int = 5) -> Tween:
	var tween = create_tween()
	
	for i in range(loops):
		tween.tween_property(node, "self_modulate", Color(1, 1, 1, 0), frequency)
		tween.tween_property(node, "self_modulate", Color(1, 1, 1, 1), frequency)
	return tween
