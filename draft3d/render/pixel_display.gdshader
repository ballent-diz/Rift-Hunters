shader_type canvas_item;
// Rendu pixel 3D (docs/art/RENDU_PIXEL_3D.md) : agrandissement de la vue basse résolution à l'écran.
// Gros pixels nets à toute échelle (même non entière) : échantillonnage « nearest lissé » qui n'adoucit que la
// rangée de pixels d'écran à cheval sur deux texels. `origin` décale la fenêtre visible d'une fraction de texel :
// la caméra est calée sur la grille (aucun scintillement), le défilement reste fluide.
uniform vec2 texture_texels = vec2(320.0, 180.0);
uniform vec2 view_texels = vec2(318.0, 178.0);
uniform vec2 origin = vec2(1.0, 1.0);

void fragment() {
	vec2 texel = origin + UV * view_texels;
	vec2 seam = floor(texel + 0.5);
	vec2 width = max(fwidth(texel), vec2(1e-4));
	texel = seam + clamp((texel - seam) / width, -0.5, 0.5);
	COLOR = vec4(texture(TEXTURE, texel / texture_texels).rgb, 1.0);
}
