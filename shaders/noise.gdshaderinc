// Ruído de valor simples, usado por terreno, rios e céu.
// Hash sem seno (Dave Hoskins): estável na GPU mesmo com coordenadas grandes.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += value_noise(p) * a;
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}
