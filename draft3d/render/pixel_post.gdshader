shader_type spatial;
// Rendu pixel 3D (docs/art/RENDU_PIXEL_3D.md) : passe plein écran, dans la vue basse résolution, après le décor opaque
// et avant les sprites, effets et cristaux (qui restent intacts). Trois étapes :
// 1. contours sombres (silhouettes et pied des objets) et arêtes saillantes éclaircies, tirés de la profondeur ;
// 2. tramage léger optionnel ;
// 3. quantification vers la palette du chapitre (couleur la plus proche en OKLab).
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// Profondeur du décor seul (vue jumelle, pixel_depth.gdshader) : les sprites n'y figurent pas.
uniform sampler2D depth_tex : filter_nearest;
uniform float depth_range = 96.0;
uniform vec3 palette_lab[64];
uniform int palette_size = 0;
// Contour sélectif (bible graphique § 3) : sombre côté ombre (bas-droite) avec le liseré violet de la Faille, teinte
// sombre du matériau côté lumière (haut-gauche).
uniform vec4 outline_color : source_color = vec4(0.055, 0.039, 0.09, 1.0);
uniform vec4 rim_color : source_color = vec4(0.71, 0.42, 0.94, 1.0);
uniform float rim_strength = 0.4;
uniform float lit_outline = 0.55;
// Mètres de dénivelé (entre un pixel et ses voisins) au-delà desquels on dessine une silhouette.
uniform float silhouette_depth = 0.35;
// Seuil d'une arête (pli de surface), en mètres de courbure de profondeur.
uniform float crease_depth = 0.012;
// Assombrissement des creux (pied des objets, angles rentrants) et éclaircissement des arêtes saillantes.
uniform float crease_dark = 0.45;
uniform float edge_light = 0.18;
uniform float dither = 0.0;
// Exposition du décor : le rendu pixel passe le tonemap en linéaire, ce facteur rend la luminosité du filmic d'origine.
uniform float exposure = 1.34;
uniform bool outlines = true;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec3 oklab(vec3 srgb) {
	vec3 c = to_linear(srgb);
	float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
	l = pow(l, 1.0 / 3.0);
	m = pow(m, 1.0 / 3.0);
	s = pow(s, 1.0 / 3.0);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

vec3 from_oklab(vec3 lab) {
	float l = pow(lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z, 3.0);
	float m = pow(lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z, 3.0);
	float s = pow(lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z, 3.0);
	vec3 c = vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

float bayer4(vec2 p) {
	int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

float view_depth(vec2 uv) {
	vec2 code = texture(depth_tex, uv).rg;
	return (code.r * 255.0 + code.g) / 255.0 * depth_range;
}

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 color = min(texture(screen_tex, SCREEN_UV).rgb * exposure, vec3(1.0));
	bool exact = false;
	if (outlines) {
		float d = view_depth(SCREEN_UV);
		float l = view_depth(SCREEN_UV - vec2(px.x, 0.0));
		float r = view_depth(SCREEN_UV + vec2(px.x, 0.0));
		float u = view_depth(SCREEN_UV - vec2(0.0, px.y));
		float b = view_depth(SCREEN_UV + vec2(0.0, px.y));
		// Le plus proche des voisins : un pixel de premier plan au bord d'une silhouette porte le contour.
		float nearest_jump = max(max(l, r), max(u, b)) - d;
		float laplace = l + r + u + b - 4.0 * d;
		if (nearest_jump > silhouette_depth) {
			if (max(r, b) - d > silhouette_depth) {
				// Bord bas-droite : contour sombre et liseré violet, hors palette (couleurs exactes).
				color = mix(outline_color.rgb, rim_color.rgb, rim_strength);
				exact = true;
			} else {
				color = mix(color, outline_color.rgb, lit_outline);
			}
		} else if (laplace < -crease_depth && laplace > -silhouette_depth) {
			// Pli rentrant (pied d'un objet, angle intérieur) : le pixel est plus loin que ses voisins.
			color = mix(color, outline_color.rgb, crease_dark);
		} else if (laplace > crease_depth) {
			// Arête saillante : un pixel de lumière, comme le liseré clair des sprites.
			color = mix(color, vec3(1.0, 0.96, 0.86), edge_light);
		}
	}
	if (palette_size > 0 && !exact) {
		vec3 lab = oklab(color);
		lab.x += (bayer4(FRAGCOORD.xy) - 0.5) * dither * 0.08;
		float best = 1e9;
		vec3 pick = lab;
		for (int i = 0; i < 64; i++) {
			if (i >= palette_size) {
				break;
			}
			vec3 delta = (palette_lab[i] - lab) * vec3(1.0, 1.3, 1.3);
			float dist = dot(delta, delta);
			if (dist < best) {
				best = dist;
				pick = palette_lab[i];
			}
		}
		color = from_oklab(pick);
	}
	ALBEDO = color;
	ALPHA = 1.0;
}
