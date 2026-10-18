shader_type canvas_item;
render_mode unshaded;

uniform float effect_time = 0.0;
varying vec2 brush_position;
varying vec4 pigment;

void vertex() {
	brush_position = VERTEX;
	pigment = COLOR;
}

void fragment() {
	// Matière animée à l'intérieur des traits ; aucune nappe lumineuse plein écran.
	float flow = sin(brush_position.x * 0.19 - effect_time * 12.0
		+ sin(brush_position.y * 0.13 + effect_time * 7.0) * 1.7);
	vec4 brush = texture(TEXTURE, UV);
	float grain = dot(brush.rgb, vec3(0.299, 0.587, 0.114));
	float lit = step(0.78, flow * 0.5 + 0.5);
	// Réutiliser la matière de la brosse sans imposer son bleu aux palettes des Échos.
	float shade = 0.88 + grain * 0.12 + lit * 0.10;
	COLOR = vec4(pigment.rgb * shade, pigment.a * brush.a);
}
