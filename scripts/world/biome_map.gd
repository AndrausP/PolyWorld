class_name BiomeMap
extends RefCounted
## Decide o bioma de cada vértice a partir da altura, inclinação e umidade.
## A umidade vem de um ruído próprio e aumenta perto dos rios.
## O resultado fica em biome_ids (índice em config.biomes) para consultas rápidas.

var biome_ids := PackedByteArray()

var _config: WorldConfig
var _height_map: HeightMap
var _hydrology: Hydrology
var _moisture := FastNoiseLite.new()
var _border := FastNoiseLite.new()


func _init(world_config: WorldConfig, height_map: HeightMap, hydrology: Hydrology, seed_value: int) -> void:
	_config = world_config
	_height_map = height_map
	_hydrology = hydrology
	_moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moisture.seed = seed_value + 1
	_moisture.frequency = _config.moisture_frequency
	_moisture.fractal_octaves = 3
	_border.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_border.seed = seed_value + 2
	_border.frequency = 0.02
	_border.fractal_octaves = 2
	_classify_all()


func _classify_all() -> void:
	var res := _height_map.resolution
	biome_ids.resize(res * res)
	for z in res:
		for x in res:
			var p := _height_map.get_vertex(x, z)
			var normal := _height_map.get_vertex_normal(x, z)
			var biome := classify(p.y, normal, p.x, p.z, z * res + x)
			biome_ids[z * res + x] = maxi(_config.biomes.find(biome), 0)


## Umidade em [0, 1]; "node" (opcional) soma a umidade dos rios próximos.
func get_moisture(wx: float, wz: float, node := -1) -> float:
	var m := _moisture.get_noise_2d(wx, wz) * 0.75 + 0.5
	if node >= 0:
		m += clampf(_hydrology.flow[node] / (_config.river_threshold * 4.0), 0.0, 1.0) * _config.river_moisture
	return clampf(m, 0.0, 1.0)


func classify(height: float, normal: Vector3, wx: float, wz: float, node := -1) -> BiomeData:
	var h := _height_map.normalized_height(height) + _border.get_noise_2d(wx, wz) * _config.biome_border_noise
	if _config.slope_biome != null and h > _config.slope_min_height \
			and 1.0 - normal.y > _config.slope_threshold:
		return _config.slope_biome
	var moisture := get_moisture(wx, wz, node)
	for biome in _config.biomes:
		if biome.matches(h, moisture):
			return biome
	return null if _config.biomes.is_empty() else _config.biomes.back()


func get_biome_index(node: int) -> int:
	return biome_ids[node]


func get_biome(node: int) -> BiomeData:
	return _config.biomes[biome_ids[node]] if not _config.biomes.is_empty() else null


## Bioma no ponto de mundo (vértice mais próximo).
func get_biome_at(wx: float, wz: float) -> BiomeData:
	return get_biome(_height_map.nearest_node(wx, wz))
