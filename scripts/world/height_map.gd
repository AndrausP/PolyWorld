class_name HeightMap
extends RefCounted
## Mapa de alturas da ilha: ruído fractal (com distorção de domínio) + cordilheiras,
## multiplicados por uma máscara radial para que as bordas afundem no mar.
## A ilha fica centrada na origem; as consultas usam coordenadas de mundo.
## As alturas podem ser alteradas depois (a hidrologia escava os rios).

var config: WorldConfig
## Número de células por lado.
var cells: int
## Número de vértices por lado (cells + 1).
var resolution: int
var heights := PackedFloat32Array()

var _noise := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _coast := FastNoiseLite.new()
## Coordenada de mundo (X e Z) do vértice (0, 0).
var _origin: float


func _init(world_config: WorldConfig, seed_value: int) -> void:
	config = world_config
	cells = config.size_cells
	resolution = cells + 1
	_origin = -config.world_size() * 0.5
	_setup_noise(seed_value)
	_generate()


func _setup_noise(seed_value: int) -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = seed_value
	_noise.frequency = config.noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = config.noise_octaves
	_noise.fractal_lacunarity = config.noise_lacunarity
	_noise.fractal_gain = config.noise_gain
	_noise.domain_warp_enabled = config.warp_strength > 0.0
	_noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	_noise.domain_warp_amplitude = config.warp_strength
	_noise.domain_warp_frequency = config.warp_frequency

	_ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridges.seed = seed_value + 101
	_ridges.frequency = config.mountain_frequency
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 4

	_coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast.seed = seed_value + 202
	_coast.frequency = 0.0025
	_coast.fractal_octaves = 3


func _generate() -> void:
	heights.resize(resolution * resolution)
	var half := cells * 0.5
	var cs := config.cell_size
	for z in resolution:
		for x in resolution:
			var wx := _origin + x * cs
			var wz := _origin + z * cs
			# Distância normalizada ao centro, deformada para um litoral irregular.
			var dx := (x - half) / half
			var dz := (z - half) / half
			var distance := sqrt(dx * dx + dz * dz) + _coast.get_noise_2d(wx, wz) * config.coast_irregularity
			var mask := 1.0 - smoothstep(config.mask_inner, config.mask_outer, distance)
			var n := clampf(_noise.get_noise_2d(wx, wz) * 0.5 + 0.5, 0.0, 1.0)
			var ridge := clampf(_ridges.get_noise_2d(wx, wz) * 0.5 + 0.5, 0.0, 1.0)
			var h := mask * lerpf(config.base_elevation, 1.0, n) + ridge * ridge * mask * mask * config.mountain_strength
			h = pow(maxf(h, 0.0), config.height_exponent)
			heights[z * resolution + x] = config.sea_level + (h - config.sea_threshold) * config.max_height


func index(x: int, z: int) -> int:
	return z * resolution + x


## Altura do vértice (x, z) da grade.
func get_vertex_height(x: int, z: int) -> float:
	return heights[z * resolution + x]


## Posição de mundo do vértice (x, z) da grade.
func get_vertex(x: int, z: int) -> Vector3:
	return Vector3(_origin + x * config.cell_size, get_vertex_height(x, z), _origin + z * config.cell_size)


## Normal suave do vértice (diferenças centrais).
func get_vertex_normal(x: int, z: int) -> Vector3:
	var x0 := maxi(x - 1, 0)
	var x1 := mini(x + 1, cells)
	var z0 := maxi(z - 1, 0)
	var z1 := mini(z + 1, cells)
	var dhdx := (get_vertex_height(x1, z) - get_vertex_height(x0, z)) / ((x1 - x0) * config.cell_size)
	var dhdz := (get_vertex_height(x, z1) - get_vertex_height(x, z0)) / ((z1 - z0) * config.cell_size)
	return Vector3(-dhdx, 1.0, -dhdz).normalized()


## Índice do vértice da grade mais próximo do ponto de mundo.
func nearest_node(wx: float, wz: float) -> int:
	var g := _to_grid(wx, wz)
	return index(roundi(g.x), roundi(g.y))


## Altura exata da superfície, seguindo a mesma triangulação da malha
## (diagonal de (0,0) para (1,1) em cada célula).
func get_height_at(wx: float, wz: float) -> float:
	var g := _to_grid(wx, wz)
	var x := int(g.x)
	var z := int(g.y)
	var fx := g.x - x
	var fz := g.y - z
	var h00 := get_vertex_height(x, z)
	var h10 := get_vertex_height(x + 1, z)
	var h11 := get_vertex_height(x + 1, z + 1)
	var h01 := get_vertex_height(x, z + 1)
	if fx >= fz:
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz


## Normal do triângulo do terreno no ponto.
func get_normal_at(wx: float, wz: float) -> Vector3:
	var g := _to_grid(wx, wz)
	var x := int(g.x)
	var z := int(g.y)
	var h00 := get_vertex_height(x, z)
	var h10 := get_vertex_height(x + 1, z)
	var h11 := get_vertex_height(x + 1, z + 1)
	var h01 := get_vertex_height(x, z + 1)
	var dhdx: float
	var dhdz: float
	if g.x - x >= g.y - z:
		dhdx = h10 - h00
		dhdz = h11 - h10
	else:
		dhdx = h11 - h01
		dhdz = h01 - h00
	return Vector3(-dhdx, config.cell_size, -dhdz).normalized()


## Converte uma altura de mundo em altura normalizada acima do mar
## (0 = nível do mar, 1 = altura máxima possível).
func normalized_height(world_y: float) -> float:
	return (world_y - config.sea_level) / (config.max_height * (1.0 - config.sea_threshold))


## Converte coordenadas de mundo em coordenadas contínuas da grade (presas à ilha).
func _to_grid(wx: float, wz: float) -> Vector2:
	var limit := cells - 0.0001
	return Vector2(
		clampf((wx - _origin) / config.cell_size, 0.0, limit),
		clampf((wz - _origin) / config.cell_size, 0.0, limit))
