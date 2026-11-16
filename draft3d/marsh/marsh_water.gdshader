shader_type spatial;
// Eau du Marais des Marées (carte 8) : surface peinte, rides animées, écume le long des berges, levées noyées
// devinées sous l'eau. Coordonnées monde, une texture peinte = 6,144 m (0,024 m par texel, la grille du rendu pixel).
// Non éclairé : les images sont déjà peintes dans la palette du chapitre (draft3d/marsh/README.md).
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

const float TEXEL = 0.024;
const float TILE = 6.144;
const float FOAM_LENGTH = 12.288;
const float FOAM_DEPTH = 0.768;

uniform sampler2D surface_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2DArray ripple_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2DArray foam_tex : source_color, filter_nearest, repeat_enable;
// Carte des rives (DraftLevelMarsh.SHORE_MAP) : R distance à la terre sèche, G à toute terre, B levées basses.
uniform sampler2D shore_tex : filter_linear, repeat_disable;
uniform vec4 shore_rect = vec4(-60.0, -60.0, 120.0, 120.0);
uniform float shore_range = 8.0;
uniform int ripple_frames = 8;
uniform float ripple_frame_time = 0.1;
uniform int foam_frames = 6;
uniform float foam_frame_time = 0.12;
// Hauteur de l'eau (DraftLevelMarsh.water_level) et dessus des levées basses.
uniform float water_level = -0.35;
uniform float low_top = 0.0;
// Fondu de l'écume entre les deux cartes de distance, autour du dessus des levées basses (m).
uniform float tide_blend = 0.1;
uniform float water_alpha = 0.86;
// Sur une levée noyée, l'eau est peu profonde : on devine la levée, un peu éclaircie.
uniform float shallow_alpha = 0.5;
uniform vec4 shallow_color : source_color = vec4(0.443, 0.545, 0.502, 1.0);
uniform float shallow_mix = 0.3;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Tramage ordonné 4 × 4 sur la grille des texels (fondus en pixels francs).
float bayer4(vec2 cell) {
	ivec2 p = ivec2(mod(cell, 4.0));
	int index = p.x + p.y * 4;
	const float pattern[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (pattern[index] + 0.5) / 16.0;
}

vec3 shore_at(vec2 at) {
	return texture(shore_tex, (at - shore_rect.xy) / shore_rect.zw).rgb;
}

void fragment() {
	vec2 cell = floor(world.xz / TEXEL);
	vec2 at = (cell + 0.5) * TEXEL;
	vec2 uv = at / TILE;
	vec3 color = texture(surface_tex, uv).rgb;
	int ripple = int(mod(floor(TIME / ripple_frame_time), float(ripple_frames)));
	vec4 rides = texture(ripple_tex, vec3(uv, float(ripple)));
	color = mix(color, rides.rgb, rides.a);
	float alpha = water_alpha;

	// Marée : 0 tant que les levées basses émergent (berges = toute terre, G), 1 quand elles sont noyées (R).
	float flood = clamp((water_level - (low_top - tide_blend)) / (2.0 * tide_blend), 0.0, 1.0);
	bool dry_map = bayer4(cell) < flood;
	vec3 shore = shore_at(at);
	float distance_m = (dry_map ? shore.r : shore.g) * shore_range;

	// Levée noyée sous l'eau peu profonde.
	float over_dike = step(bayer4(cell + 2.0), shore.b) * step(low_top, water_level);
	color = mix(color, shallow_color.rgb, shallow_mix * over_dike);
	alpha = mix(alpha, shallow_alpha, over_dike);

	// Écume : bande de FOAM_DEPTH le long des berges, terre en haut de l'image ; le u suit la berge.
	float v = distance_m / FOAM_DEPTH;
	if (v < 1.0) {
		vec2 step_m = vec2(0.25, 0.0);
		float gx = (dry_map ? shore_at(at + step_m.xy).r - shore_at(at - step_m.xy).r
			: shore_at(at + step_m.xy).g - shore_at(at - step_m.xy).g);
		float gz = (dry_map ? shore_at(at + step_m.yx).r - shore_at(at - step_m.yx).r
			: shore_at(at + step_m.yx).g - shore_at(at - step_m.yx).g);
		// Berge orientée nord-sud (la distance varie en x) : la bande court en z, et inversement.
		float along = abs(gx) > abs(gz) ? at.y : at.x;
		int frame = int(mod(floor(TIME / foam_frame_time), float(foam_frames)));
		vec4 foam = texture(foam_tex, vec3(along / FOAM_LENGTH, clamp(v, 0.0, 0.999), float(frame)));
		color = mix(color, foam.rgb, foam.a);
		alpha = mix(alpha, 1.0, foam.a);
	}
	ALBEDO = color;
	ALPHA = alpha;
}
