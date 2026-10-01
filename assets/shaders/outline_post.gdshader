// Contours encrés plein écran (Wind Waker) : un quad collé à la caméra lit la profondeur
// et les normales de la scène et trace un trait sombre là où elles changent brutalement
// (silhouettes et arêtes). Il ne fait que se superposer (alpha) : l'eau, les particules
// et les textes restent intacts. Désactivé en qualité « Bas ».
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.1, 0.08, 0.12, 1.0);
uniform float thickness = 1.4;
// Écart relatif de profondeur qui crée un trait (silhouettes).
uniform float depth_threshold = 0.06;
// Écart d'orientation qui crée un trait (arêtes).
uniform float normal_threshold = 0.45;
// Au-delà de cette distance (m), les traits s'estompent (évite le « bruit » au loin).
uniform float fade_start = 25.0;
uniform float fade_end = 70.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view.z / view.w;
}

vec3 normal_at(vec2 uv) {
	return texture(normal_roughness_texture, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	float center = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 n = normal_at(SCREEN_UV);
	float depth_edge = 0.0;
	float normal_edge = 0.0;
	vec2 offsets[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offsets[i];
		float d = linear_depth(uv, INV_PROJECTION_MATRIX);
		depth_edge = max(depth_edge, step(depth_threshold, (d - center) / max(center, 0.001)));
		normal_edge = max(normal_edge, step(dot(n, normal_at(uv)), 1.0 - normal_threshold));
	}
	float edge = max(depth_edge, normal_edge * 0.75);
	float fade = 1.0 - smoothstep(fade_start, fade_end, center);
	// Rien sur le ciel (profondeur infinie).
	if (center > 900.0) {
		edge = 0.0;
	}
	ALBEDO = outline_color.rgb;
	ALPHA = edge * fade * outline_color.a;
}
