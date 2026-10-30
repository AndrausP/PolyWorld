// Vento compartilhado pela vegetação. Os parâmetros globais ficam em
// Projeto > Configurações > Shader Globals (wind_direction, wind_strength, wind_speed).
global uniform vec2 wind_direction;
global uniform float wind_strength;
global uniform float wind_speed;

// Deslocamento (em espaço local do modelo) de um vértice.
// height01: altura relativa no modelo (0 base, 1 topo) -> a base fica parada.
// weight: metros de deslocamento do topo com vento 1. flutter: tremor das folhas.
vec3 wind_offset(mat4 model, vec3 vertex, float height01, float weight, float flutter, float time) {
	vec3 origin = model[3].xyz;
	vec3 world = (model * vec4(vertex, 1.0)).xyz;
	vec2 dir = normalize(wind_direction + vec2(0.0001));
	float t = time * wind_speed;
	float phase = dot(origin.xz, vec2(0.137, 0.171));
	// Rajadas: uma onda larga que atravessa o mapa na direção do vento.
	float gust = 0.5 + 0.5 * sin(dot(world.xz, dir) * 0.035 - t * 0.9);
	// Balanço próprio de cada planta.
	float sway = sin(t * 1.3 + phase) * 0.35 + sin(t * 2.7 + phase * 1.9) * 0.15;
	float bend = (gust * 0.75 + sway) * wind_strength * weight * height01 * height01;
	vec3 offset = vec3(dir.x, -0.15 * abs(bend), dir.y) * bend;
	float f = flutter * wind_strength * height01 * 0.05;
	offset += vec3(sin(t * 7.0 + world.x * 3.1 + world.y * 2.0),
		sin(t * 6.1 + world.y * 3.7) * 0.5,
		cos(t * 6.5 + world.z * 2.9)) * f;
	// Mundo -> local: a base é rotação * escala uniforme.
	mat3 m = mat3(model);
	return (transpose(m) * offset) / dot(m[0], m[0]);
}
