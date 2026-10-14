shader_type canvas_item;

// Retire les résidus du fond vert sans changer la feuille de référence.
void fragment() {
    vec4 original = texture(TEXTURE, UV);
    float dominance = original.g - max(original.r, original.b);
    float matte = smoothstep(0.035, 0.15, dominance);
    COLOR.a *= 1.0 - matte;
}
