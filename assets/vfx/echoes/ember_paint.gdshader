shader_type canvas_item;
render_mode unshaded;

uniform float effect_time = 0.0;
varying vec4 pigment;
varying vec2 brush_position;

void vertex() {
	pigment = COLOR;
	brush_position = VERTEX;
}

void fragment() {
	// La brosse cyan du Chasseur fournit sa matière, pas sa couleur à Cendrelame.
	vec4 brush = texture(TEXTURE, UV);
	float grain = dot(brush.rgb, vec3(0.299, 0.587, 0.114));
	float flow = sin(brush_position.x * 0.14 - effect_time * 16.0 + brush_position.y * 0.1);
	COLOR = vec4(pigment.rgb * (0.85 + grain * 0.15 + max(flow, 0.0) * 0.08), pigment.a * brush.a);
}
