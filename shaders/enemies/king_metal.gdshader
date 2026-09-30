shader_type spatial;
// Polished metal of the King's armor and greatsword (docs/specs/boss-king-rework.md).
// Flat color, no textures: the standard PBR term gives the highlight of the scene's
// lights, and a procedural reflection (ground, horizon and sky gradient looked up with the
// reflected view ray) gives the shine that a flat-color background cannot reflect.
// Every face of the model has its own normal, so the metal reads faceted.

uniform vec4 albedo : source_color = vec4(0.66, 0.69, 0.74, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;
uniform vec4 sky_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.95, 0.95, 0.9, 1.0);
uniform vec4 ground_color : source_color = vec4(0.2, 0.18, 0.16, 1.0);
// Strength of the procedural reflection (0 = none) and how much the grazing angles add.
uniform float reflection : hint_range(0.0, 1.0) = 0.85;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.93, 0.6, 1.0);
// Own light of the metal (the greatsword in phase 2), set per instance.
instance uniform float glow : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	vec3 view_dir = normalize(VIEW);
	vec3 reflected = (INV_VIEW_MATRIX * vec4(reflect(-view_dir, NORMAL), 0.0)).xyz;
	float up = reflected.y;
	vec3 env = mix(ground_color.rgb, horizon_color.rgb, smoothstep(-0.7, 0.05, up));
	env = mix(env, sky_color.rgb, smoothstep(0.0, 0.85, up));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, view_dir), 0.0, 1.0), fresnel_power);
	// A floor of light so that a face turned away from every light never goes black.
	EMISSION = albedo.rgb * 0.1 + env * albedo.rgb * reflection * (0.55 + 0.9 * fresnel) + glow_color.rgb * glow;
}
