shader_type canvas_item;
// Reconstruction locale des contours ; aucun changement de palette ni de luminosité globale.
uniform float strength : hint_range(0.0, 0.5) = 0.22;
varying vec4 vertex_color;
void vertex() {
 vertex_color = COLOR;
}
void fragment() {
 vec4 c = texture(TEXTURE, UV);
 vec2 p = TEXTURE_PIXEL_SIZE * 3.0;
 vec3 n = texture(TEXTURE, UV + vec2(p.x, 0.0)).rgb;
 vec3 s = texture(TEXTURE, UV - vec2(p.x, 0.0)).rgb;
 vec3 e = texture(TEXTURE, UV + vec2(0.0, p.y)).rgb;
 vec3 w = texture(TEXTURE, UV - vec2(0.0, p.y)).rgb;
 vec3 low = min(c.rgb, min(min(n,s),min(e,w)));
 vec3 high = max(c.rgb, max(max(n,s),max(e,w)));
 vec3 refined = clamp(c.rgb + strength * (c.rgb - (n+s+e+w)*0.25), low, high);
 COLOR = vertex_color * vec4(refined, c.a);
}
