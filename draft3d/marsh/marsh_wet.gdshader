shader_type spatial;
// Vase mouillée des levées basses (carte 8), posée par-dessus la dalle (material_overlay) : couvre la levée tant
// qu'elle est noyée, puis sèche par plaques, en pixels francs, pendant les secondes qui suivent le retrait.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

const float TEXEL = 0.024;
const float TILE = 6.144;

uniform sampler2D mud_tex : source_color, filter_nearest, repeat_enable;
// 1 : détrempée (noyée ou tout juste découverte) ; 0 : sèche. Réglé par DraftMarshWater.
uniform float wetness = 0.0;
uniform float opacity = 0.85;

varying vec3 world;
varying vec3 world_normal;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Bruit de valeur : la vase sèche par plaques irrégulières, pas en damier.
float patches(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

void fragment() {
	// Dessus : grille x/z ; flancs : le long du flanc et en hauteur.
	vec2 plane = abs(world_normal.y) > 0.5 ? world.xz
		: vec2(abs(world_normal.x) > abs(world_normal.z) ? world.z : world.x, -world.y);
	vec2 cell = floor(plane / TEXEL);
	vec3 mud = texture(mud_tex, (cell + 0.5) * TEXEL / TILE).rgb;
	// Plaques d'environ 0,7 m, bord grenu au texel près : chaque texel a son seuil de séchage.
	vec2 at = (cell + 0.5) * TEXEL;
	float threshold = patches(at / 0.7) * 0.6 + patches(at / 0.25) * 0.25 + hash(cell) * 0.15;
	float keep = step(threshold, wetness);
	ALBEDO = mud;
	ALPHA = opacity * keep;
}
