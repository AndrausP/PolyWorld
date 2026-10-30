class_name WaterMeshBuilder
extends RefCounted
## Gera a superfície da água doce (rios e lagos), um array de malha por chunk.
## Cada célula com água vira um quad na altura do nível da água; vértices secos
## da célula usam o nível do vizinho molhado, então a água encosta nas margens.
## A cor do vértice guarda a direção do fluxo (RG) e a velocidade (B) para o shader.

## Desnível máximo (m) dentro de um quad; trechos íngremes viram corredeira inclinada.
const MAX_STEP := 5.0


static func build_all(height_map: HeightMap, hydrology: Hydrology, config: WorldConfig) -> Array:
	var chunks := []
	var size := config.chunk_cells
	for cz in range(0, height_map.cells, size):
		for cx in range(0, height_map.cells, size):
			var arrays := _build_chunk(height_map, hydrology, config, cx, cz,
				mini(size, height_map.cells - cx), mini(size, height_map.cells - cz))
			if not arrays.is_empty():
				chunks.append(arrays)
	return chunks


static func _build_chunk(height_map: HeightMap, hydrology: Hydrology, config: WorldConfig,
		x0: int, z0: int, w: int, d: int) -> Array:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var corner_ids := PackedInt32Array([0, 0, 0, 0])
	var corner_levels := PackedFloat32Array([0, 0, 0, 0])
	for z in range(z0, z0 + d):
		for x in range(x0, x0 + w):
			corner_ids[0] = height_map.index(x, z)
			corner_ids[1] = height_map.index(x + 1, z)
			corner_ids[2] = height_map.index(x + 1, z + 1)
			corner_ids[3] = height_map.index(x, z + 1)
			var wet_level := Hydrology.NO_WATER
			for c in 4:
				wet_level = maxf(wet_level, hydrology.water_level[corner_ids[c]])
			if wet_level <= Hydrology.NO_WATER:
				continue
			var visible := false
			var lowest := wet_level
			for c in 4:
				var level := hydrology.water_level[corner_ids[c]]
				var ground := height_map.heights[corner_ids[c]]
				# Canto seco: encosta na margem; se o chão for mais baixo, desce até ele
				# (e o teste de desnível abaixo descarta a célula se a queda for grande).
				corner_levels[c] = level if level > Hydrology.NO_WATER else minf(wet_level, ground)
				lowest = minf(lowest, corner_levels[c])
				if corner_levels[c] > ground:
					visible = true
			if not visible or wet_level - lowest > MAX_STEP:
				continue
			var points := [
				Vector3(height_map.get_vertex(x, z).x, corner_levels[0], height_map.get_vertex(x, z).z),
				Vector3(height_map.get_vertex(x + 1, z).x, corner_levels[1], height_map.get_vertex(x + 1, z).z),
				Vector3(height_map.get_vertex(x + 1, z + 1).x, corner_levels[2], height_map.get_vertex(x + 1, z + 1).z),
				Vector3(height_map.get_vertex(x, z + 1).x, corner_levels[3], height_map.get_vertex(x, z + 1).z),
			]
			for c in [0, 1, 2, 0, 2, 3]:
				vertices.append(points[c])
				colors.append(_flow_color(height_map, hydrology, config, corner_ids[c], corner_levels[c]))
	if vertices.is_empty():
		return []
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	return arrays


## Direção (para onde o vértice drena) e velocidade (pela queda do nível).
static func _flow_color(height_map: HeightMap, hydrology: Hydrology, config: WorldConfig, node: int, level: float) -> Color:
	var target := hydrology.receiver[node]
	if target < 0:
		return Color(0.5, 0.5, 0.0)
	var res := height_map.resolution
	@warning_ignore("integer_division")
	var dir := Vector2(target % res - node % res, target / res - node / res).normalized()
	var target_level := hydrology.water_level[target]
	if target_level <= Hydrology.NO_WATER:
		target_level = maxf(height_map.heights[target], config.sea_level)
	var speed := clampf((level - target_level) / config.cell_size * 6.0, 0.0, 1.0)
	return Color(dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5, speed)
