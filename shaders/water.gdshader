// Água low-poly: facetas planas, cor por profundidade, espuma na margem,
// cristas de onda e brilho do sol. Lê a profundidade da cena para a margem.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.34, 0.82, 0.84, 1.0);
uniform vec4 mid_color : source_color = vec4(0.12, 0.52, 0.72, 1.0);
uniform vec4 deep_color : source_color = vec4(0.03, 0.17, 0.42, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float wave_height = 0.32;
uniform float wave_scale = 0.16;
uniform float wave_speed = 0.8;
uniform float depth_fade = 5.0;      // metros até a cor "funda"
uniform float foam_width = 1.1;      // largura da espuma na margem
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

float wave(vec2 p, float t) {
	float w = sin(p.x * wave_scale + t) * cos(p.y * wave_scale * 0.8 + t * 0.7);
	w += 0.5 * sin((p.x + p.y) * wave_scale * 1.7 + t * 1.3);
	w += 0.25 * sin((p.x - p.y * 1.3) * wave_scale * 3.1 - t * 1.9);
	return w;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave(world_pos.xz, TIME * wave_speed) * wave_height;
	world_pos.y += VERTEX.y;
}

void fragment() {
	// Normal da face: visual facetado low-poly.
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	// Facetas extras: cada célula de ~3 m inclina a normal um pouco (look cristalino).
	vec2 fc = floor(world_pos.xz / 3.0 + vec2(TIME * 0.05, 0.0));
	n = normalize(n + vec3(hash(fc) - 0.5, 0.0, hash(fc + 17.0) - 0.5) * 0.22);
	NORMAL = n;

	// Profundidade da água atrás da superfície.
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	float depth = max(-v.z + VERTEX.z, 0.0);
	float k = clamp(depth / depth_fade, 0.0, 1.0);

	vec3 col = mix(shallow_color.rgb, mid_color.rgb, smoothstep(0.0, 0.45, k));
	col = mix(col, deep_color.rgb, smoothstep(0.35, 1.0, k));

	// Fundo visível em águas rasas (refração simples).
	vec2 off = n.xz * 0.02 * (1.0 - k);
	vec3 bottom = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	col = mix(bottom * vec3(0.85, 1.0, 1.0), col, clamp(0.35 + k * 0.75, 0.0, 1.0));

	// Fresnel e céu.
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, vec3(0.5, 0.72, 0.92), fres * 0.18);

	// Cristas de onda claras (facetas no topo).
	float crest = smoothstep(0.55, 1.0, wave(world_pos.xz, TIME * wave_speed) * 0.5 + 0.35);
	col += crest * 0.06;

	// Espuma na margem: faixa que pulsa com a onda + pontilhado.
	float pulse = 0.5 + 0.5 * sin(TIME * 1.2 + world_pos.x * 0.35 + world_pos.z * 0.3);
	float edge = 1.0 - smoothstep(0.0, foam_width * (0.65 + 0.5 * pulse), depth);
	vec2 cell = floor(world_pos.xz * 1.7 + vec2(TIME * 0.15, 0.0));
	float speckle = step(0.35, hash(cell));
	float foam = edge * mix(0.65, 1.0, speckle);
	foam += smoothstep(0.0, 0.35, 0.35 - depth) * 0.6;
	foam = clamp(foam, 0.0, 1.0);
	col = mix(col, foam_color.rgb, foam);

	ALBEDO = col;
	ALPHA = clamp(mix(0.55, 0.94, k) + fres * 0.2 + foam, 0.0, 1.0);
	ALPHA *= smoothstep(0.0, 0.12, depth + 0.05);   // some suavemente na linha da areia
	ROUGHNESS = mix(0.05, 0.5, foam);
	SPECULAR = 1.0;
	METALLIC = 0.0;
}
