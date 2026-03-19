shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.02, 0.04, 0.08, 1.0);
uniform float outline_size = 1.0;


void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	vec2 outline_offset = TEXTURE_PIXEL_SIZE * outline_size;

	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(outline_offset.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-outline_offset.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, outline_offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, -outline_offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(outline_offset.x, outline_offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-outline_offset.x, outline_offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(outline_offset.x, -outline_offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-outline_offset.x, -outline_offset.y)).a);

	vec4 result = base_color;

	if (base_color.a <= 0.0 && neighbor_alpha > 0.0) {
		result = outline_color;
		result.a *= neighbor_alpha;
	}

	COLOR = result;
}
