// Céu estilizado: degradê, sol com halo e nuvens fofas (estáticas, para não
// recalcular o mapa de reflexo a cada quadro).
shader_type sky;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.22, 0.55, 0.93);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.88, 0.98);
uniform vec3 ground_color : source_color = vec3(0.55, 0.72, 0.85);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.72, 0.8, 0.92);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.52;
uniform float cloud_scale = 1.4;

void sky() {
	vec3 d = EYEDIR;
	vec3 col = mix(horizon_color, top_color, pow(clamp(d.y, 0.0, 1.0), 0.6));
	if (d.y < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-d.y * 4.0, 0.0, 1.0));
	}
	if (LIGHT0_ENABLED) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * (pow(s, 900.0) * 6.0 + pow(s, 16.0) * 0.25);
	}
	if (d.y > 0.0) {
		// Projeção num "teto" plano: nuvens achatadas perto do horizonte.
		vec2 uv = d.xz / (d.y + 0.12) * cloud_scale;
		float c = fbm(uv);
		float mask = smoothstep(cloud_coverage, cloud_coverage + 0.2, c) * smoothstep(0.0, 0.15, d.y);
		vec3 cc = mix(cloud_shadow, cloud_color, smoothstep(cloud_coverage, cloud_coverage + 0.3, fbm(uv + vec2(0.04, 0.06))));
		col = mix(col, cc, mask * 0.95);
	}
	COLOR = col;
}
