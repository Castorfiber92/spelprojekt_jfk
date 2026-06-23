shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	// Mix between the original texture and the solid flash color based on the modifier
	vec3 mixed_color = mix(texture_color.rgb, flash_color.rgb, flash_modifier);
	COLOR = vec4(mixed_color, texture_color.a);
	}