shader_type canvas_item;
// Masquage par le décor peint (docs/maps/MASQUAGE_PAR_LE_DECOR.md). Partagé par tous les visuels d'entités d'une
// partie : aucun paramètre propre à une entité. Le pied est l'origine du nœud dessiné (point d'appui du sprite).
// Texture de profondeur : par texel, ligne de pied (Y monde) de l'élément de décor visible à cet endroit, codée sur
// 16 bits (R = octet fort, G = octet faible), 0 = aucun élément. Un pixel de l'entité est caché si son pied est
// au-dessus (plus loin) que cette ligne : il est alors dessiné en silhouette claire translucide.
uniform sampler2D depth_map : filter_nearest, repeat_disable;
// Rectangle du monde couvert par la texture (position, taille).
uniform vec4 depth_rect = vec4(0.0, 0.0, 1.0, 1.0);
// Décodage des profondeurs : Y monde du haut de la carte, hauteur de la carte.
uniform vec2 depth_range = vec2(0.0, 1.0);
uniform vec4 ghost_color : source_color = vec4(0.9, 0.92, 0.97, 0.55);
// Contour de la silhouette, plus sombre : lisible aussi sur la pierre claire.
uniform vec4 ghost_edge : source_color = vec4(0.3, 0.33, 0.45, 0.8);
// Ombre au sol : la partie cachée n'est pas dessinée (pas de silhouette).
uniform bool is_shadow = false;
// Détourage du fond vert de certaines feuilles (ancien green_matte.gdshader).
uniform bool green_matte = false;

varying vec2 world_pos;
varying float foot_y;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	foot_y = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
}

void fragment() {
	vec4 c = COLOR;
	if (green_matte) {
		vec4 original = texture(TEXTURE, UV);
		float dominance = original.g - max(original.r, original.b);
		c.a *= 1.0 - smoothstep(0.035, 0.15, dominance);
	}
	vec2 uv = (world_pos - depth_rect.xy) / depth_rect.zw;
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		vec2 rg = texture(depth_map, uv).rg;
		float code = floor(rg.r * 255.0 + 0.5) * 256.0 + floor(rg.g * 255.0 + 0.5);
		if (code > 0.5 && foot_y < depth_range.x + code / 65535.0 * depth_range.y) {
			if (is_shadow) {
				c = vec4(0.0);
			} else {
				vec2 texel = TEXTURE_PIXEL_SIZE;
				float around = min(min(texture(TEXTURE, UV + vec2(texel.x, 0.0)).a, texture(TEXTURE, UV - vec2(texel.x, 0.0)).a),
					min(texture(TEXTURE, UV + vec2(0.0, texel.y)).a, texture(TEXTURE, UV - vec2(0.0, texel.y)).a));
				vec4 ghost = around < 0.5 ? ghost_edge : ghost_color;
				c = vec4(ghost.rgb, ghost.a * c.a);
			}
		}
	}
	COLOR = c;
}
