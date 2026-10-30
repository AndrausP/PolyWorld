// Partes sólidas da vegetação (troncos, pedras, cogumelos): textura,
// oclusão pela cor do vértice, o mesmo vento das folhas e neve no topo.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/wind.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ao_strength : hint_range(0.0, 1.0) = 0.35;
uniform float mesh_height = 5.0;
uniform float wind_weight = 0.3;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;

varying float v_up;

void vertex() {
	float h = clamp(VERTEX.y / mesh_height, 0.0, 1.0);
	vec3 wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_up = wn.y / max(length(wn), 0.0001);
	// Sem tremor (flutter = 0): galhos acompanham o balanço das folhas.
	VERTEX += wind_offset(MODEL_MATRIX, VERTEX, h, wind_weight, 0.0, TIME);
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb * tint.rgb;
	col *= mix(1.0 - ao_strength, 1.0, COLOR.r);
	col = mix(col, vec3(0.92, 0.95, 1.0), smoothstep(0.3, 0.8, v_up) * snow_amount);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
