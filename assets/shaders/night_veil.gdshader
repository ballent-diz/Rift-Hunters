shader_type canvas_item;
// Voile de nuit (brique B2) : couvre le monde, percé de halos de lumière.
// lights[i] = (x, y, rayon, intensité) en unités du monde ; le nœud est à l'origine du monde.

const int MAX_LIGHTS = 16;
uniform vec4 lights[16];
uniform int light_count = 0;
uniform float darkness = 0.85;
uniform vec4 night_color : source_color = vec4(0.02, 0.035, 0.09, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float light = 0.0;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 l = lights[i];
		float d = distance(world_pos, l.xy);
		light = max(light, l.w * (1.0 - smoothstep(l.z * 0.45, l.z, d)));
	}
	COLOR = vec4(night_color.rgb, darkness * (1.0 - light));
}
