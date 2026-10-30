class_name VegetationPlacer
extends RefCounted
## Decide onde cada planta/árvore/pedra nasce (roda na thread de geração).
## Amostra pontos com jitter em duas grades (grande e rasteira); em cada ponto
## sorteia no máximo uma entrada do bioma local, pela densidade.
## O resultado são grupos por (chunk, entrada, variante) com o buffer pronto
## para MultiMesh, mais a lista de colisões.

## Um grupo de instâncias que vira um MultiMeshInstance3D.
class Group:
	var entry_id: int
	var variant: int
	var center: Vector3
	var data: Array = [] # 12 floats por instância (Transform3D relativo ao centro)

## Grupos de instâncias (Array[Group]).
var groups: Array = []
## Colisões: Array de [posição: Vector3, entrada: VegetationEntry, escala: float].
var colliders: Array = []

var _lookup := {}


func place(height_map: HeightMap, biome_map: BiomeMap, hydrology: Hydrology,
		config: WorldConfig, library: VegetationLibrary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	_place_layer(VegetationEntry.Layer.LARGE, config.large_step, config.large_chunk_size, height_map, biome_map, hydrology, config, library, rng)
	_place_layer(VegetationEntry.Layer.GROUND, config.ground_step, config.ground_chunk_size, height_map, biome_map, hydrology, config, library, rng)


func _place_layer(layer: int, step: float, chunk_size: float, height_map: HeightMap, biome_map: BiomeMap,
		hydrology: Hydrology, config: WorldConfig, library: VegetationLibrary, rng: RandomNumberGenerator) -> void:
	var size := config.world_size()
	var origin := -size * 0.5
	var count := int(size / step)
	var min_y := config.sea_level + config.vegetation_min_height
	for gz in count:
		for gx in count:
			var wx := origin + (gx + rng.randf()) * step
			var wz := origin + (gz + rng.randf()) * step
			var node := height_map.nearest_node(wx, wz)
			var ids: PackedInt32Array = library.biome_layers[biome_map.get_biome_index(node)][layer]
			if ids.is_empty():
				continue
			var roll := rng.randf()
			var chosen := -1
			var accumulated := 0.0
			for id in ids:
				accumulated += library.entries[id].density
				if roll < accumulated:
					chosen = id
					break
			if chosen < 0:
				continue
			var y := height_map.get_height_at(wx, wz)
			if y < min_y or hydrology.water_level[node] > y - 0.15:
				continue
			var entry := library.entries[chosen]
			var normal := height_map.get_normal_at(wx, wz)
			if 1.0 - normal.y > entry.max_slope:
				continue
			var s := rng.randf_range(entry.min_scale, entry.max_scale)
			var basis := Basis(Vector3.UP, rng.randf() * TAU)
			if entry.align_to_ground:
				basis = Basis(Quaternion(Vector3.UP, normal)) * basis
			basis = basis.scaled(Vector3.ONE * s)
			var pos := Vector3(wx, y - entry.sink * s, wz)
			var variant := rng.randi() % entry.scenes.size()
			_add_instance(chosen, variant, pos, basis, chunk_size, origin)
			if entry.collision_radius > 0.0:
				colliders.append([pos, entry, s])


func _add_instance(entry_id: int, variant: int, pos: Vector3, basis: Basis, chunk_size: float, origin: float) -> void:
	var cx := int((pos.x - origin) / chunk_size)
	var cz := int((pos.z - origin) / chunk_size)
	var key := "%d:%d:%d:%d:%d" % [entry_id, variant, cx, cz, int(chunk_size)]
	var group: Group = _lookup.get(key)
	if group == null:
		group = Group.new()
		group.entry_id = entry_id
		group.variant = variant
		group.center = Vector3(origin + (cx + 0.5) * chunk_size, 0.0, origin + (cz + 0.5) * chunk_size)
		_lookup[key] = group
		groups.append(group)
	var o := pos - group.center
	# Formato do buffer de MultiMesh (TRANSFORM_3D): matriz 3x4 por linhas.
	group.data.append_array([basis.x.x, basis.y.x, basis.z.x, o.x,
		basis.x.y, basis.y.y, basis.z.y, o.y,
		basis.x.z, basis.y.z, basis.z.z, o.z])
