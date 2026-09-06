shader_type canvas_item;

void fragment() {
	float cell_size = 48.0;
	vec2 grid = FRAGCOORD.xy / cell_size;
	vec2 cell = floor(grid);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 dark = vec3(0.10, 0.12, 0.16);
	vec3 light = vec3(0.18, 0.22, 0.28);
	vec3 color = mix(dark, light, checker);

	vec2 f = fract(grid);
	float line = step(f.x, 0.045) + step(f.y, 0.045);
	color = mix(color, vec3(0.06, 0.07, 0.10), clamp(line, 0.0, 1.0) * 0.55);

	COLOR = vec4(color, 1.0);
}
