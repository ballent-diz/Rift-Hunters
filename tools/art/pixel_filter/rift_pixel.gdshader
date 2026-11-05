shader_type canvas_item;
render_mode unshaded;

// Traitement de texture reutilisable : aucune image derivee, aucune collision modifiee.
uniform float pixel_world_pitch = 0.75;
uniform float texture_density = 1.333333;
uniform float color_steps = 18.0;
uniform float chroma_steps = 18.0;
uniform float grouping = 0.35;
uniform float contrast = 1.03;
uniform float sharpening = 0.20;
uniform float palette_strength = 0.65;
uniform float grouping_range = 85.0;
uniform float grouping_radius = 1.0;
uniform vec2 grid_origin = vec2(0.0);
varying vec4 tint;
varying vec2 world_position;

void vertex() {
	tint = COLOR;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 bounded_sample(sampler2D tex, vec2 uv, vec2 pixel_size) {
	return texture(tex, clamp(uv, pixel_size * 0.5, vec2(1.0) - pixel_size * 0.5)).rgb;
}

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * pixel_world_pitch * texture_density;
	vec2 sample_uv = step_uv * grouping_radius;
	vec2 snapped = (floor((world_position - grid_origin) / pixel_world_pitch) + 0.5) * pixel_world_pitch + grid_origin;
	vec2 uv = UV + (snapped - world_position) * TEXTURE_PIXEL_SIZE * texture_density;
	vec3 c = bounded_sample(TEXTURE, uv, TEXTURE_PIXEL_SIZE);
	vec3 n = bounded_sample(TEXTURE, uv + vec2(0.0, sample_uv.y), TEXTURE_PIXEL_SIZE);
	vec3 s = bounded_sample(TEXTURE, uv - vec2(0.0, sample_uv.y), TEXTURE_PIXEL_SIZE);
	vec3 e = bounded_sample(TEXTURE, uv + vec2(sample_uv.x, 0.0), TEXTURE_PIXEL_SIZE);
	vec3 w = bounded_sample(TEXTURE, uv - vec2(sample_uv.x, 0.0), TEXTURE_PIXEL_SIZE);
	// Lisser les petites variations de matiere sans moyenner les silhouettes contrastees.
	vec4 weight = exp(-vec4(dot(n-c,n-c), dot(s-c,s-c), dot(e-c,e-c), dot(w-c,w-c)) * grouping_range);
	vec3 ne = bounded_sample(TEXTURE, uv + sample_uv, TEXTURE_PIXEL_SIZE);
	vec3 nw = bounded_sample(TEXTURE, uv + vec2(-sample_uv.x,sample_uv.y), TEXTURE_PIXEL_SIZE);
	vec3 se = bounded_sample(TEXTURE, uv + vec2(sample_uv.x,-sample_uv.y), TEXTURE_PIXEL_SIZE);
	vec3 sw = bounded_sample(TEXTURE, uv - sample_uv, TEXTURE_PIXEL_SIZE);
	vec4 dw = exp(-vec4(dot(ne-c,ne-c),dot(nw-c,nw-c),dot(se-c,se-c),dot(sw-c,sw-c))*grouping_range);
	vec3 grouped = (c * 2.0 + n*weight.x + s*weight.y + e*weight.z + w*weight.w + ne*dw.x + nw*dw.y + se*dw.z + sw*dw.w) / (2.0 + dot(weight, vec4(1.0)) + dot(dw,vec4(1.0)));
	vec3 low = min(c, min(min(n,s), min(e,w)));
	vec3 high = max(c, max(max(n,s), max(e,w)));
	vec3 clean = mix(c, grouped, grouping);
	clean = clamp(clean + sharpening * (clean - (n+s+e+w)*0.25), low, high);
	clean = clamp((clean - 0.5) * contrast + 0.5, 0.0, 1.0);
	// Quantification luminance/chrominance : garde les teintes des biomes et des dangers.
	float y = dot(clean, vec3(0.25,0.5,0.25));
	float co = clean.r - clean.b;
	float cg = clean.g - (clean.r + clean.b)*0.5;
	float qy = floor(y * color_steps + 0.5) / color_steps;
	float qco = floor(co * chroma_steps + 0.5) / chroma_steps;
	float qcg = floor(cg * chroma_steps + 0.5) / chroma_steps;
	vec3 quantized = vec3(qy + qco*0.5 - qcg*0.5, qy + qcg*0.5, qy - qco*0.5 - qcg*0.5);
	COLOR = vec4(clamp(mix(clean, quantized, palette_strength),0.0,1.0), texture(TEXTURE, uv).a) * tint;
}
