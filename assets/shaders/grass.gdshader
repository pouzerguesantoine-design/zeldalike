// Brins d'herbe (MultiMesh, voir GrassField) : couleur du pied à la pointe, balancement au
// vent par rafales, et les brins s'écartent quand le joueur marche dedans.
// Rendue dans la passe transparente (ALPHA = 1) : elle n'écrit pas la profondeur, donc le
// contour encré ne cerne pas chaque brin.
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled, depth_draw_never;

uniform vec4 root_color : source_color = vec4(0.22, 0.52, 0.17, 1.0);
uniform vec4 tip_color : source_color = vec4(0.62, 0.88, 0.36, 1.0);
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.6;
uniform float gust_scale = 0.06;
// Position du joueur (mise à jour par GrassField) et rayon d'écrasement.
uniform vec3 player_position = vec3(0.0, -100.0, 0.0);
uniform float push_radius = 1.1;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// UV.y = 0 au pied, 1 à la pointe : seule la pointe bouge.
	float tip = UV.y * UV.y;
	float gust = sin(TIME * 0.7 + root.x * gust_scale + root.z * gust_scale * 0.7) * 0.5 + 0.5;
	float sway = sin(TIME * wind_speed + root.x * 0.8 + root.z * 0.6) * (0.4 + gust * 0.8);
	vec3 offset = vec3(sway, 0.0, sway * 0.5) * wind_strength * tip;
	// Écrasement autour du joueur.
	vec3 away = root - player_position;
	away.y = 0.0;
	float d = length(away);
	if (d < push_radius && d > 0.001) {
		float push = (1.0 - d / push_radius) * 0.6 * tip;
		offset += normalize(away) * push;
		offset.y -= push * 0.5;
	}
	// Décalage exprimé dans le repère du brin (instances tournées et mises à l'échelle).
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset, 0.0)).xyz;
}

void fragment() {
	ALBEDO = mix(root_color.rgb, tip_color.rgb, UV.y);
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
	// Les deux faces reçoivent la même lumière (brins fins).
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float shadow = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float falloff = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	float lit = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0) * shadow;
	float tone = mix(0.55, 1.0, smoothstep(0.35, 0.45, lit));
	DIFFUSE_LIGHT += tone * LIGHT_COLOR * ALBEDO / PI * falloff;
}
