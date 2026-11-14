shader_type spatial;
// Rendu pixel 3D (docs/art/RENDU_PIXEL_3D.md) : profondeur du décor seul, codée sur deux octets (rouge, vert).
// Le moteur de compatibilité (Godot 4.3) n'offre pas la texture de profondeur aux shaders : une vue jumelle dessine
// les copies des maillages du décor avec ce matériau, lue ensuite par pixel_post.gdshader pour tracer les contours.
// Caméra orthographique : FRAGCOORD.z (précision haute, contrairement à VERTEX) est linéaire entre near et far.
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

void fragment() {
	highp float t = clamp(FRAGCOORD.z, 0.0, 1.0) * 255.0;
	highp float coarse = floor(t);
	ALBEDO = vec3(coarse / 255.0, t - coarse, 0.0);
}
