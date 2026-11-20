shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// UV d'un quad, dans l'orientation du geste. Les motifs sont tramés à l'échelle du décor.
uniform vec4 pigment : source_color = vec4(0.62, 0.27, 0.93, 1.0);
uniform vec4 highlight : source_color = vec4(0.94, 0.77, 1.0, 1.0);
uniform vec2 extent = vec2(2.0);
uniform int shape = 0;
uniform int motif = 0;
uniform int beat = 0; // 0 : persistant, 1 : annonce, 2 : impact, 3 : retrait
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float cone_cos = -1.0;

float band(float d, float width) {
	return 1.0 - smoothstep(width * 0.5, width, abs(d));
}

void vertex() {
	if (shape == 4) {
		// Le même billboard s'oriente pour la vue pixel et pour la caméra de jeu directe.
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		VERTEX.z += 0.12;
	}
}

void fragment() {
	float time = floor(TIME * 16.0) / 16.0;
	vec2 grid = max(vec2(12.0), extent / 0.0375);
	vec2 uv = (floor(UV * grid) + 0.5) / grid;
	vec2 p = uv * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x + 0.00001) / 6.2831853;
	float edge = 1.0 - radius;
	float rim_width = clamp(0.2 / min(extent.x, extent.y), 0.028, 0.14);
	float extent_mask = step(0.0, edge) * step(cone_cos, -p.y / max(radius, 0.001));
	float stripe = band(fract(angle * 24.0) - 0.5, 0.18);
	float flow = radius;
	if (shape == 1 || shape == 2 || shape == 7) {
		edge = 1.0 - max(abs(p.x), abs(p.y));
		extent_mask = 1.0;
		flow = 1.0 - uv.y;
		stripe = band(fract(uv.y * max(4.0, extent.y * 1.5)) - 0.5, 0.16);
	} else if (shape == 3 || shape == 4 || shape == 6) {
		extent_mask = 1.0;
	} else if (cone_cos > -0.99) {
		float side = sqrt(max(0.0, 1.0 - cone_cos * cone_cos));
		edge = min(edge, -p.y * side - abs(p.x) * cone_cos);
	}
	vec2 tiles = uv * max(vec2(4.0), extent * 2.0);
	float seed = fract(sin(dot(floor(tiles), vec2(37.71, 91.37))) * 43758.54);
	vec2 tile = fract(tiles) - 0.5;
	float grain = 0.0;
	if (motif == 1) {
		// Facettes et éclats de glace ou de prisme.
		grain = step(0.72, seed) * band(abs(tile.x) * 1.35 + abs(tile.y) - 0.23, 0.095);
	} else if (motif == 2) {
		// Braises qui descendent le courant par paliers.
		grain = step(0.63, seed) * band(tile.x + 0.18 - seed * 0.55, 0.11)
			* band(fract(tile.y + seed - time * 0.55) - 0.5, 0.20);
	} else if (motif == 3) {
		// Filets d'eau et de brume.
		grain = band(fract(flow * 8.0 + sin(angle * 25.1327) * 0.23 - time * 0.65) - 0.5, 0.095)
			* smoothstep(0.36, 0.88, seed);
	} else if (motif == 4) {
		// Nervures en fourche pour les racines.
		grain = band(fract(tile.x * 0.7 + abs(tile.y) * 0.8 + seed) - 0.5, 0.12) * step(0.48, seed);
	} else if (motif == 5) {
		// Gravures et runes de garde.
		grain = step(0.55, seed) * max(band(abs(tile.x) - 0.18, 0.065) * step(abs(tile.y), 0.24),
			band(tile.y, 0.065) * step(abs(tile.x), 0.22));
	} else {
		// Fissures disjointes, facettes de vide.
		grain = step(0.47, seed) * band(fract(tile.x + tile.y * 0.65 + seed) - 0.5, 0.105)
			* step(abs(tile.y), 0.37);
	}

	float rim = 1.0 - smoothstep(rim_width * 0.45, rim_width, edge);
	float ink = 1.0 - smoothstep(rim_width, rim_width * 1.9, edge);
	float key = rim * (0.47 + 0.53 * stripe);
	float bed = 0.06 + grain * 0.085;
	float light = key * 0.75 + grain * 0.22;
	float alpha = max(rim * 0.46 + bed, ink * 0.43);
	if (beat == 1) {
		float fill = smoothstep(flow - 0.035, flow + 0.035, progress);
		float sweep = band(flow - progress, rim_width * 1.3);
		alpha = max(alpha, bed + fill * 0.27 + sweep * 0.34 + key * 0.39);
		light = max(light, sweep * 0.82);
	} else if (beat == 2 || beat == 3) {
		float cursor = progress;
		if (shape == 0 && beat == 2) {
			cursor = 0.26 + 0.74 * sqrt(progress);
		}
		if (beat == 3) {
			cursor = 1.0 - progress;
		}
		float wave = band(flow - cursor, 0.15);
		float ribbon = band(flow - cursor + 0.07 + stripe * 0.045, 0.065);
		if (shape == 1) {
			wave = max(wave, band(p.x, 0.19 + 0.35 * (1.0 - progress)) * (1.0 - progress));
		}
		alpha = (bed + key * 0.48 + wave * 0.68 + ribbon * 0.32 + grain * 0.22)
			* pow(1.0 - progress, 0.8);
		light = max(light, max(wave, ribbon * 0.90));
	}
	if (shape == 2) {
		// Chaque tronçon disparaît avec son tronçon physique ; une crête claire et une traîne courte.
		float crest = band(p.y + 0.34, 0.25);
		alpha = 0.18 + crest * 0.68 + grain * 0.14;
		light = max(crest, grain * 0.5);
	} else if (shape == 3) {
		// Surface verticale du Mur : mèches, montants clairs, cendre clairsemée au sommet.
		float filaments = band(fract(uv.x * extent.x * 3.0 + sin(p.y * 3.0 - time * 2.4) * 0.26) - 0.5, 0.12);
		float ground = pow(uv.y, 5.0);
		float crown = band(uv.y - 0.14 + sin(uv.x * 41.0 - time * 2.5) * 0.054, 0.095);
		float posts = step(0.94, abs(p.x)) * uv.y;
		alpha = (0.19 + filaments * 0.37 + grain * 0.31) * uv.y + ground * 0.35 + posts * 0.45 + crown * 0.31;
		light = max(ground * 0.82, max(filaments * 0.72, max(posts, crown * 0.8)));
	} else if (shape == 4) {
		// Étincelles de silhouette : deux ailes sur les côtés, centre transparent.
		float arm = band(abs(p.x) - (0.32 + progress * 0.25), 0.23);
		float taper = 1.0 - abs(p.y);
		alpha = arm * taper * (grain * 0.85 + band(abs(p.x) + abs(p.y) * 0.38 - 0.63, 0.08) * 0.57);
		alpha *= beat == 0 ? 0.65 + 0.35 * sin(time * 4.0) : (1.0 - progress);
		light = 0.92;
	} else if (shape == 5) {
		// Périmètre (duel) : anneau incurvé, balises et braises, intérieur libre.
		alpha = ink * 0.52 + key * 0.44 + grain * ink * 0.13;
		light = key * 0.8 + grain * ink * 0.46;
	} else if (shape == 6) {
		// Orbe : cœur facetté et arcs à la surface, avec une arête froide côté opposé.
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float arc = band(fract(p.x * 6.0 + p.y * 1.7 + time * 0.8) - 0.5, 0.12);
		light = 0.24 + grain * 0.44 + arc * 0.2 + (1.0 - facing) * 0.42;
		alpha = 0.54 + facing * 0.4 + grain * 0.1;
	} else if (shape == 7) {
		// Plasma : cœur plein liseré de deux filaments en escalier, bord dissous dans l'air.
		float ripple = sin(uv.y * 75.0 - time * 25.0) * 0.13;
		float core = band(p.x - ripple * 0.24, 0.30);
		float outer = band(p.x, 0.96);
		float filaments = band(abs(p.x + ripple) - 0.54, 0.18);
		alpha = (core * 0.82 + outer * 0.25 + filaments * 0.46) * (1.0 - progress);
		light = max(core, max(filaments * 0.85, grain * 0.55));
	}
	vec3 dark = pigment.rgb * 0.21;
	vec3 base = mix(pigment.rgb * 0.62, dark, clamp(ink - light, 0.0, 1.0));
	ALBEDO = mix(base, highlight.rgb, clamp(light, 0.0, 1.0));
	ALPHA = clamp(alpha * opacity * extent_mask, 0.0, 1.0);
}
