// Feuillage cel-shadé qui ondule au vent : même éclairage que toon.gdshader, plus un
// balancement des sommets qui augmente avec la hauteur (le tronc reste immobile).
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float shadow_threshold : hint_range(-1.0, 1.0) = 0.0;
uniform float highlight_threshold : hint_range(-1.0, 1.0) = 0.55;
uniform float band_softness : hint_range(0.0, 0.2) = 0.05;
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.68, 0.85, 1.0);
uniform float midtone = 0.75;
uniform float wind_strength = 0.08;
uniform float wind_speed = 1.3;
// Hauteur (m) à partir de laquelle le feuillage bouge.
uniform float sway_start = 1.2;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = clamp((VERTEX.y - sway_start) / 2.0, 0.0, 1.0);
	float phase = TIME * wind_speed + world.x * 0.35 + world.z * 0.25;
	VERTEX.x += (sin(phase) + 0.4 * sin(phase * 2.3)) * wind_strength * weight;
	VERTEX.z += cos(phase * 0.8) * wind_strength * 0.6 * weight;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float shadow = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float falloff = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	float lit = dot(NORMAL, LIGHT) * shadow;
	float mid = smoothstep(shadow_threshold - band_softness, shadow_threshold + band_softness, lit);
	float high = smoothstep(highlight_threshold - band_softness, highlight_threshold + band_softness, lit);
	vec3 tone = mix(shadow_tint.rgb * 0.5, vec3(midtone), mid);
	tone = mix(tone, vec3(1.0), high);
	DIFFUSE_LIGHT += tone * LIGHT_COLOR * ALBEDO / PI * falloff;
}
