shader_type spatial;
// Rendu pixel 3D (docs/art/RENDU_PIXEL_3D.md) : ombrage en aplats des modules de décor.
// Lumière découpée en paliers, ombres projetées comprises ; transitions tramées (Bayer 4×4) sur la grille de pixels
// du rendu basse résolution. Palette, contours et liseré sont posés ensuite par pixel_post.gdshader.
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform bool use_vertex_color = false;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Nombre de paliers de lumière (3 ou 4 conseillés).
uniform int bands = 4;
// Intensité du tramage aux transitions de paliers (0 : coupure nette).
uniform float dither = 0.0;
// Teinte des faces à l'ombre (froide, violette) et des faces éclairées (chaude).
uniform vec4 shadow_tint : source_color = vec4(0.42, 0.38, 0.62, 1.0);
uniform vec4 light_tint : source_color = vec4(1.0, 0.97, 0.9, 1.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
}

void fragment() {
	vec4 base = albedo_color;
	if (use_texture) {
		base *= texture(albedo_texture, UV);
	}
	if (use_vertex_color) {
		base *= COLOR;
	}
	ALBEDO = base.rgb;
	EMISSION = emission_color.rgb * emission_energy;
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float steps = float(max(bands - 1, 1));
	float jitter = (bayer4(FRAGCOORD.xy) - 0.5) * dither;
	if (LIGHT_IS_DIRECTIONAL) {
		// Soleil : paliers arrondis ; l'ombre glisse vers le violet-bleu, la lumière vers l'ambre.
		float level = clamp(floor(lit * steps + 0.5 + jitter) / steps, 0.0, 1.0);
		vec3 tint = level < 0.5 ? mix(shadow_tint.rgb, vec3(1.0), level * 2.0) : mix(vec3(1.0), light_tint.rgb, level * 2.0 - 1.0);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * tint * mix(0.12, 1.0, level);
	} else {
		// Torches et lueurs : anneaux de paliers tramés (Bayer), rien au-delà du premier palier atteint.
		float ring = (bayer4(FRAGCOORD.xy) - 0.5) * 0.6;
		float level = clamp(floor(lit * steps + ring + 0.15) / steps, 0.0, 1.0);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * level * 0.75;
	}
}
