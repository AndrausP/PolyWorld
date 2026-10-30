// Água low-poly: plano semitransparente com ondas suaves e facetas planas.
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.25, 0.68, 0.82, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.3, 0.55, 1.0);
uniform float transparency : hint_range(0.0, 1.0) = 0.68;
uniform float wave_height = 0.15;
uniform float wave_scale = 0.15;
uniform float wave_speed = 0.9;

float wave(vec2 p, float t) {
	return sin(p.x * wave_scale + t) * cos(p.y * wave_scale * 0.8 + t * 0.7)
		+ 0.5 * sin((p.x + p.y) * wave_scale * 1.7 + t * 1.3);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave(world_pos.xz, TIME * wave_speed) * wave_height;
}

void fragment() {
	// Normal da face calculada pelas derivadas: dá o visual facetado.
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	// Fresnel: mais opaca e escura quando vista de lado.
	float fresnel = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, clamp(fresnel * 1.5, 0.0, 1.0));
	ALPHA = mix(transparency, 0.95, fresnel);
	ROUGHNESS = 0.15;
	SPECULAR = 0.5;
}
