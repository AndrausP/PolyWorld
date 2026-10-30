// Água de rios e lagos: semitransparente, com faixas de espuma que correm
// na direção do fluxo (cor do vértice: RG = direção, B = velocidade).
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, specular_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 water_color : source_color = vec4(0.18, 0.58, 0.72, 1.0);
uniform vec4 foam_color : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform float transparency : hint_range(0.0, 1.0) = 0.72;
uniform float flow_speed = 1.6;

varying vec3 world_pos;
varying vec3 flow;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow = vec3(COLOR.rg * 2.0 - 1.0, COLOR.b);
}

void fragment() {
	vec2 dir = length(flow.xy) > 0.05 ? normalize(flow.xy) : vec2(1.0, 0.0);
	float speed = flow.z;
	vec2 side = vec2(-dir.y, dir.x);
	float t = TIME * flow_speed * (0.25 + speed);
	// Coordenadas alinhadas ao fluxo: o ruído esticado rola rio abaixo.
	vec2 q = vec2(dot(world_pos.xz, dir) * 0.6 - t, dot(world_pos.xz, side) * 2.2);
	float streak = smoothstep(0.62, 0.9, value_noise(q) * 0.7 + value_noise(q * 2.7) * 0.3);
	float foam = streak * (0.25 + speed * 0.9);
	ALBEDO = mix(water_color.rgb, foam_color.rgb, clamp(foam, 0.0, 1.0));
	ALPHA = mix(transparency, 0.95, clamp(foam, 0.0, 1.0));
	ROUGHNESS = 0.3;
}
