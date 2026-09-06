shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	float aa = fwidth(r);
	float alpha = 1.0 - smoothstep(0.5 - aa, 0.5, r);
	if (alpha <= 0.0) {
		discard;
	}
	COLOR.a *= alpha;
}
