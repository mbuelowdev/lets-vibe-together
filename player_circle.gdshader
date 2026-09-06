shader_type canvas_item;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	if (length(centered) > 0.5) {
		discard;
	}
}
