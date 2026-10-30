// Folhagem estilizada: folhas, grama e flores com recorte por alpha,
// vento, tinta por bioma, translucidez, clareamento no topo e neve.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/wind.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// Desloca o UV (escolhe a faixa de cor da paleta da grama).
uniform float uv_shift_x = 0.0;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
// A cor do vértice dos modelos escurece a base (oclusão).
uniform float ao_strength : hint_range(0.0, 1.0) = 0.45;
uniform float translucency : hint_range(0.0, 1.0) = 0.35;
uniform float top_light : hint_range(0.0, 1.0) = 0.3;
uniform float saturation : hint_range(0.0, 2.0) = 1.15;
uniform float mesh_height = 5.0;
uniform float wind_weight = 0.3;
uniform float flutter = 1.0;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
// 1 = folhagem decídua: muda de cor com a estação e perde folhas no inverno.
uniform float seasonal : hint_range(0.0, 1.0) = 0.0;
global uniform float season;

varying float v_height;
varying float v_up;

void vertex() {
	v_height = clamp(VERTEX.y / mesh_height, 0.0, 1.0);
	vec3 wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_up = wn.y / max(length(wn), 0.0001);
	VERTEX += wind_offset(MODEL_MATRIX, VERTEX, v_height, wind_weight, flutter, TIME);
}

vec3 season_color(float s) {
	// Chaves no início de cada estação: primavera, verão, outono, inverno.
	vec3 k0 = vec3(1.08, 1.16, 0.88);
	vec3 k1 = vec3(0.98, 1.02, 0.94);
	vec3 k2 = vec3(1.75, 0.78, 0.30);
	vec3 k3 = vec3(0.95, 0.80, 0.68);
	float f = smoothstep(0.0, 1.0, fract(s));
	int i = int(floor(s)) % 4;
	vec3 a = i == 0 ? k0 : (i == 1 ? k1 : (i == 2 ? k2 : k3));
	vec3 b = i == 0 ? k1 : (i == 1 ? k2 : (i == 2 ? k3 : k0));
	return mix(a, b, f);
}

float leaf_drop(float s) {
	// 0 fora do inverno; sobe no fim do outono e volta a zero no começo da primavera.
	return smoothstep(2.55, 3.35, s) - smoothstep(3.7, 3.98, s);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV + vec2(uv_shift_x, 0.0));
	vec3 col = tex.rgb * tint.rgb;
	float s_ = mod(season, 4.0);
	col = mix(col, col * season_color(s_), seasonal);
	float noise_ = fract(sin(dot(floor(UV * 90.0), vec2(12.9898, 78.233))) * 43758.5453);
	float keep = step(leaf_drop(s_) * 0.95 * seasonal, noise_);
	col *= mix(1.0 - ao_strength, 1.0, COLOR.r);
	col *= 1.0 + top_light * (v_height - 0.4);
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(gray), col, saturation);
	col = mix(col, vec3(0.92, 0.95, 1.0), smoothstep(0.2, 0.7, v_up) * snow_amount);
	ALBEDO = col;
	ALPHA = tex.a * keep;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	BACKLIGHT = col * translucency;
	ROUGHNESS = 0.9;
}
