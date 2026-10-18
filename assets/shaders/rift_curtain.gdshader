shader_type canvas_item;
render_mode unshaded;

uniform sampler2D energy_atlas : filter_linear, repeat_disable;
uniform float clock = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform bool dissolving = false;
uniform vec2 lift = vec2(18.0, -108.0);
varying float along;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
               mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void vertex() {
    along = COLOR.r;
    float growth = dissolving ? 1.0 : smoothstep(0.0, 1.0, strength);
    VERTEX -= lift * (1.0 - UV.y) * (1.0 - growth);
    float crest = sin(UV.x * 4.3 - clock * 1.8) * 7.0 + sin(UV.x * 11.0 + clock * 2.6) * 3.0;
    VERTEX.x += sin(UV.x * 6.0 - clock * 2.4 + UV.y * 4.0) * 7.0 * sin(UV.y * 3.14159) * growth;
    VERTEX.y += crest * (1.0 - UV.y) * growth;
}

void fragment() {
    float animation = clock * 12.0;
    float frame = mod(floor(animation), 8.0);
    float flowing = noise(vec2(UV.x * 3.0, UV.y * 4.5 + clock * 0.7));
    vec2 local_uv = vec2(abs(fract(UV.x * 0.5 + flowing * 0.10) * 2.0 - 1.0), UV.y);
    local_uv = clamp(local_uv, vec2(0.002), vec2(0.998));
    vec4 a = texture(energy_atlas, vec2((local_uv.x + frame) / 8.0, local_uv.y));
    vec4 b = texture(energy_atlas, vec2((local_uv.x + mod(frame + 1.0, 8.0)) / 8.0, local_uv.y));
    vec4 energy = mix(a, b, smoothstep(0.0, 1.0, fract(animation)));
    float jagged = noise(vec2(UV.x * 10.0 - clock * 0.3, clock * 0.6));
    float crest = 0.10 + jagged * 0.19 + 0.04 * sin(UV.x * 21.0 - clock * 3.0);
    float veil = smoothstep(crest - 0.025, crest + 0.07, UV.y);
    float crest_glow = 1.0 - smoothstep(0.0, 0.025, abs(UV.y - crest - 0.045));
    float arc1 = 0.43 + 0.15 * sin(UV.x * 4.0 - clock * 3.0) + (flowing - 0.5) * 0.16;
    float arc2 = 0.75 + 0.10 * sin(UV.x * 8.0 + clock * 2.4) + (flowing - 0.5) * 0.10;
    float arc_distance = min(abs(UV.y - arc1), abs(UV.y - arc2));
    float arc = 1.0 - smoothstep(0.003, 0.022, arc_distance);
    float glow = 1.0 - smoothstep(0.02, 0.10, arc_distance);
    float islands = noise(vec2(UV.x * 18.0 + clock * 0.2, UV.y * 15.0 - clock * 0.5));
    float fragment_field = UV.y * 0.5 + islands * 0.5;
    float reveal = dissolving ? smoothstep(fragment_field - 0.10, fragment_field + 0.10, strength * 1.15) : 1.0;
    float ends = smoothstep(0.0, 0.035, along) * smoothstep(0.0, 0.035, 1.0 - along);
    vec3 color = mix(vec3(0.12, 0.025, 0.34), energy.rgb * vec3(1.15, 0.55, 1.05), energy.a * 0.65);
    color += vec3(0.19, 0.08, 0.35) * glow;
    color = mix(color, vec3(0.82, 0.79, 1.0), clamp(arc * 0.9 + crest_glow * 0.45, 0.0, 1.0));
    float alpha = (0.18 + energy.a * 0.45 + glow * 0.12 + arc * 0.38 + crest_glow * 0.3) * veil;
    COLOR = vec4(color, alpha * reveal * ends * smoothstep(0.0, 0.18, strength));
}
