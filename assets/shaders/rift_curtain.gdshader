shader_type canvas_item;
render_mode unshaded;

uniform sampler2D energy_atlas : filter_linear, repeat_disable;
uniform float clock = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform bool dissolving = false;
uniform vec2 lift = vec2(18.0, -88.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
    float growth = dissolving ? 1.0 : smoothstep(0.0, 1.0, strength);
    VERTEX -= lift * (1.0 - UV.y) * (1.0 - growth);
    float wave = sin(UV.x * 11.0 - clock * 3.1 + UV.y * 4.0);
    VERTEX.x += wave * 5.0 * sin(UV.y * 3.14159) * growth;
    VERTEX.y += sin(UV.x * 16.0 + clock * 4.2) * 3.0 * (1.0 - UV.y) * growth;
}

void fragment() {
    float animation = clock * 12.0;
    float frame = mod(floor(animation), 8.0);
    vec2 local_uv = vec2(abs(fract(UV.x * 0.5 + sin(UV.y * 6.0 + clock) * 0.025) * 2.0 - 1.0), UV.y);
    local_uv = clamp(local_uv, vec2(0.002), vec2(0.998));
    vec4 a = texture(energy_atlas, vec2((local_uv.x + frame) / 8.0, local_uv.y));
    vec4 b = texture(energy_atlas, vec2((local_uv.x + mod(frame + 1.0, 8.0)) / 8.0, local_uv.y));
    vec4 energy = mix(a, b, smoothstep(0.0, 1.0, fract(animation)));
    float top = 0.025 + 0.035 * sin(UV.x * 19.0 - clock * 4.0);
    float veil = smoothstep(top, top + 0.08, UV.y);
    float arc_path = 0.4 + 0.19 * sin(UV.x * 8.0 - clock * 3.5) + 0.04 * sin(UV.x * 43.0 + clock * 7.0);
    float arc_distance = abs(UV.y - arc_path);
    float arc = 1.0 - smoothstep(0.004, 0.026, arc_distance);
    float foot = smoothstep(0.91, 0.99, UV.y);
    float noise = hash(floor(vec2(UV.x * 25.0, UV.y * 22.0)));
    float fragment_field = UV.y * 0.6 + noise * 0.4;
    float reveal = dissolving ? smoothstep(fragment_field - 0.12, fragment_field + 0.12, strength * 1.15) : 1.0;
    float ember = step(0.94, noise) * pow(max(0.0, sin(clock * 4.0 + noise * 30.0)), 5.0);
    vec3 color = mix(vec3(0.25, 0.10, 0.70), energy.rgb, energy.a);
    color = mix(color, vec3(0.81, 0.79, 1.0), clamp(arc + foot * 0.8 + ember, 0.0, 1.0));
    float alpha = (0.08 + energy.a * 0.50 + arc * 0.30 + foot * 0.15 + ember * 0.3) * veil;
    COLOR = vec4(color, alpha * reveal * smoothstep(0.0, 0.18, strength));
}
