// Cel-shading façon Wind Waker / BotW : lumière en aplats (3 tons nets), ombres teintées
// de bleu plutôt que noires, liseré lumineux sur les bords (rim) côté soleil.
// Appliqué automatiquement aux modèles par ToonMaterials (scripts/components/toon_materials.gd).
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Seuils des tons : ombre / mi-teinte / lumière (en N·L).
uniform float shadow_threshold : hint_range(-1.0, 1.0) = 0.0;
uniform float highlight_threshold : hint_range(-1.0, 1.0) = 0.55;
uniform float band_softness : hint_range(0.0, 0.2) = 0.03;
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.66, 0.9, 1.0);
uniform float midtone = 0.72;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.35;
uniform float rim_width : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	ALBEDO = albedo.rgb;
	EMISSION = emission_color.rgb * emission_energy;
	ROUGHNESS = 1.0;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	// Soleil / lune : ATTENUATION = ombre portée (elle passe dans le ton d'ombre).
	// Lumières ponctuelles : ATTENUATION = baisse avec la distance (sinon chaque lumière
	// éclairerait toute sa zone d'un ton minimum).
	float shadow = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float falloff = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	float lit = n_dot_l * shadow;
	float mid = smoothstep(shadow_threshold - band_softness, shadow_threshold + band_softness, lit);
	float high = smoothstep(highlight_threshold - band_softness, highlight_threshold + band_softness, lit);
	vec3 tone = mix(shadow_tint.rgb * 0.45, vec3(midtone), mid);
	tone = mix(tone, vec3(1.0), high);
	// Liseré lumineux sur la silhouette, seulement du côté éclairé.
	float rim = smoothstep(1.0 - rim_width, 1.0, 1.0 - max(dot(NORMAL, VIEW), 0.0)) * mid * rim_strength;
	DIFFUSE_LIGHT += (tone + rim) * LIGHT_COLOR * ALBEDO / PI * falloff;
}
