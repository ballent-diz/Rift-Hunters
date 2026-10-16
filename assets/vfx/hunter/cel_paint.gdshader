shader_type canvas_item;
// Palette alliée limitée, alpha conservé, déchirure progressive sans flou.
uniform float erosion : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 palette[8] = vec3[8](
		vec3(1.0, 0.98, 0.91), vec3(0.84, 0.98, 1.0),
		vec3(0.48, 0.89, 0.97), vec3(0.16, 0.72, 0.84),
		vec3(0.07, 0.48, 0.64), vec3(0.04, 0.28, 0.42),
		vec3(0.03, 0.14, 0.24), vec3(0.96, 0.78, 0.49));
	float distance_best = 10.0;
	vec3 chosen = source.rgb;
	for (int i = 0; i < 8; i++) {
		float difference = dot(source.rgb - palette[i], source.rgb - palette[i]);
		if (difference < distance_best) {
			distance_best = difference;
			chosen = palette[i];
		}
	}
	vec2 cell = floor(UV * 128.0);
	float grain = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float mask = smoothstep(erosion - 0.04, erosion + 0.10, grain);
	float alpha = floor(source.a * 4.0 + 0.5) / 4.0;
	COLOR = vec4(chosen, alpha * mix(1.0, mask, step(0.001, erosion))) * vertex_tint;
}
