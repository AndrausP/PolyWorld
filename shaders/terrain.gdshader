// Terreno: cor do bioma por vértice (sRGB) com variação de ruído pintada
// e textura de rocha triplanar nas encostas (onde o alpha da cor permite).
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 rock_tint : source_color = vec4(0.82, 0.82, 0.86, 1.0);
uniform float rock_scale = 0.08;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.12;
uniform float rock_slope_start : hint_range(0.0, 1.0) = 0.22;
uniform float rock_slope_end : hint_range(0.0, 1.0) = 0.4;

varying vec3 world_pos;
varying vec3 world_normal;

// Entrada presa em [0, 1]: valores fora disso geravam NaN (que o bloom espalha).
vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = srgb_to_linear(COLOR.rgb);
	// Manchas grandes e pequenas, como pinceladas.
	float n = value_noise(world_pos.xz * 0.05) * 0.6 + value_noise(world_pos.xz * 0.7) * 0.4;
	base *= 1.0 + (n - 0.5) * 2.0 * noise_strength;

	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 rock = texture(rock_tex, world_pos.zy * rock_scale).rgb * w.x
		+ texture(rock_tex, world_pos.xz * rock_scale).rgb * w.y
		+ texture(rock_tex, world_pos.xy * rock_scale).rgb * w.z;
	float slope = 1.0 - world_normal.y + (n - 0.5) * 0.08;
	float rock_w = smoothstep(rock_slope_start, rock_slope_end, slope) * COLOR.a;

	ALBEDO = mix(base, rock * rock_tint.rgb, rock_w);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
