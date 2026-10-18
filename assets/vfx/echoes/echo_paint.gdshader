shader_type canvas_item;
render_mode unshaded;

uniform float effect_time = 0.0;
varying vec2 brush_position;

void vertex() {
	brush_position = VERTEX;
}

void fragment() {
	// Matière animée à l'intérieur des traits ; aucune nappe lumineuse plein écran.
	float flow = sin(brush_position.x * 0.19 - effect_time * 12.0
		+ sin(brush_position.y * 0.13 + effect_time * 7.0) * 1.7);
	float grain = fract(sin(dot(floor(brush_position * 1.4), vec2(12.9898, 78.233))) * 43758.5453);
	float lit = step(0.68, flow * 0.5 + 0.5);
	float shade = 0.78 + step(0.24, grain) * 0.16 + lit * 0.14;
	COLOR.rgb *= shade;
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.96, 0.84), lit * 0.12);
}
