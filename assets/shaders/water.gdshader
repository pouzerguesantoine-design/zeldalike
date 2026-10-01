// Eau stylisée : dégradé de couleur selon la profondeur, petites vagues, reflets en aplats
// et écume blanche là où l'eau touche le décor (rivage). Pour la rivière (posée sur le
// sol), l'écume suit les berges (bords du maillage) et des traînées montrent le courant.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform vec4 shallow_color : source_color = vec4(0.36, 0.82, 0.9, 0.75);
uniform vec4 deep_color : source_color = vec4(0.09, 0.36, 0.7, 0.95);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float depth_fade = 3.5;
// Largeur de l'écume au contact du décor (m).
uniform float foam_width = 0.7;
uniform float wave_height = 0.06;
uniform float wave_speed = 1.0;
// Rivière : écume sur les bords du maillage (UV) au lieu de la profondeur, et courant.
uniform bool river_mode = false;
uniform vec2 flow_direction = vec2(1.0, 0.0);
uniform float flow_speed = 0.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += (sin(world_position.x * 0.6 + t) + cos(world_position.z * 0.5 + t * 0.8)) * wave_height;
}

void fragment() {
	vec2 flow = river_mode ? flow_direction * TIME * flow_speed : vec2(TIME * 0.05);
	float ripples = noise(world_position.xz * 0.8 + flow) * 0.6 + noise(world_position.xz * 2.1 - flow * 1.3) * 0.4;
	float foam;
	float depth_mix;
	if (river_mode) {
		float edge = min(UV.y, 1.0 - UV.y);
		foam = 1.0 - smoothstep(0.04, 0.12 + ripples * 0.06, edge);
		foam = max(foam, step(0.78, noise(world_position.xz * vec2(0.6, 3.0) - flow * 2.0)) * 0.7);
		depth_mix = smoothstep(0.0, 0.5, edge);
	} else {
		// Profondeur de la scène derrière l'eau → épaisseur d'eau traversée.
		float scene_depth = texture(depth_texture, SCREEN_UV).r;
		vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
		float scene_distance = -scene_view.z / scene_view.w;
		float water_distance = -VERTEX.z;
		float thickness = max(scene_distance - water_distance, 0.0);
		depth_mix = clamp(thickness / depth_fade, 0.0, 1.0);
		foam = 1.0 - smoothstep(foam_width * (0.5 + ripples * 0.6), foam_width * (0.9 + ripples * 0.6), thickness);
	}
	vec4 water = mix(shallow_color, deep_color, depth_mix);
	// Reflets du ciel en petites taches claires, en aplats.
	float sparkle = step(0.82, ripples) * 0.25;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * 0.35;
	ALBEDO = mix(water.rgb + sparkle + fresnel, foam_color.rgb, foam);
	ALPHA = mix(water.a, 1.0, foam);
	ROUGHNESS = 0.2;
}
