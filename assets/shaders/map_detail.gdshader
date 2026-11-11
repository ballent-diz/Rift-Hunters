shader_type canvas_item;
// Reconstruction locale des contours ; aucun changement de palette ni de luminosité globale.
// Carte réduite à l'écran (caméra large, decor_scale < 1, petite fenêtre) : plusieurs pixels de la carte tombent dans un
// pixel d'écran. On en fait la moyenne (4 prises dans l'empreinte du pixel) pour éviter le fourmillement, et le
// renforcement des contours s'efface à mesure que la carte rétrécit.
uniform float strength : hint_range(0.0, 0.5) = 0.22;
varying vec4 vertex_color;
void vertex() {
 vertex_color = COLOR;
}
void fragment() {
 vec2 du = dFdx(UV);
 vec2 dv = dFdy(UV);
 float shrink = max(length(du / TEXTURE_PIXEL_SIZE), length(dv / TEXTURE_PIXEL_SIZE));
 vec4 c;
 if (shrink > 1.05) {
  c = 0.25 * (texture(TEXTURE, UV + 0.125 * du + 0.375 * dv) + texture(TEXTURE, UV - 0.125 * du - 0.375 * dv)
   + texture(TEXTURE, UV + 0.375 * du - 0.125 * dv) + texture(TEXTURE, UV - 0.375 * du + 0.125 * dv));
 } else {
  c = texture(TEXTURE, UV);
 }
 vec2 p = TEXTURE_PIXEL_SIZE * max(3.0, shrink * 1.5);
 vec3 n = texture(TEXTURE, UV + vec2(p.x, 0.0)).rgb;
 vec3 s = texture(TEXTURE, UV - vec2(p.x, 0.0)).rgb;
 vec3 e = texture(TEXTURE, UV + vec2(0.0, p.y)).rgb;
 vec3 w = texture(TEXTURE, UV - vec2(0.0, p.y)).rgb;
 vec3 low = min(c.rgb, min(min(n,s),min(e,w)));
 vec3 high = max(c.rgb, max(max(n,s),max(e,w)));
 float amount = strength / sqrt(max(shrink, 1.0));
 vec3 refined = clamp(c.rgb + amount * (c.rgb - (n+s+e+w)*0.25), low, high);
 COLOR = vertex_color * vec4(refined, c.a);
}
