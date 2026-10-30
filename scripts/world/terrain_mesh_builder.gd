class_name TerrainMeshBuilder
extends RefCounted
## Gera os arrays de malha do terreno, um por chunk: vértices compartilhados,
## normais suaves e cor por vértice (bioma; leito de rio). O alpha da cor diz
## ao shader se a encosta pode mostrar a textura de rocha.
## Roda numa thread: só produz arrays, os nós são criados depois.


## Retorna uma lista de arrays de superfície (Mesh.ARRAY_MAX), um por chunk.
static func build_all(height_map: HeightMap, biome_map: BiomeMap, hydrology: Hydrology, config: WorldConfig) -> Array:
	var colors := _node_colors(height_map, biome_map, hydrology, config)
	var chunks := []
	var size := config.chunk_cells
	for cz in range(0, height_map.cells, size):
		for cx in range(0, height_map.cells, size):
			chunks.append(_build_chunk(height_map, colors, cx, cz, mini(size, height_map.cells - cx), mini(size, height_map.cells - cz)))
	return chunks


## Cor de cada vértice da grade.
static func _node_colors(height_map: HeightMap, biome_map: BiomeMap, hydrology: Hydrology, config: WorldConfig) -> PackedColorArray:
	var n := height_map.heights.size()
	var colors := PackedColorArray()
	colors.resize(n)
	for i in n:
		var biome := biome_map.get_biome(i)
		var base := biome.color if biome != null else Color.MAGENTA
		var rock := 1.0 if biome != null and biome.rock_on_slopes else 0.0
		var variation := biome.color_variation if biome != null else 0.0
		var shade := 1.0 + (_hash01(i) - 0.5) * 2.0 * variation
		var color := Color(minf(base.r * shade, 1.0), minf(base.g * shade, 1.0), minf(base.b * shade, 1.0), rock)
		# Leito de rio/lago: mistura com a cor de cascalho conforme a profundidade.
		var depth := hydrology.water_level[i] - height_map.heights[i]
		if depth > 0.0:
			color = color.lerp(config.riverbed_color, clampf(depth * 2.0, 0.0, 1.0))
			color.a = 0.0
		colors[i] = color
	return colors


static func _build_chunk(height_map: HeightMap, colors: PackedColorArray, x0: int, z0: int, w: int, d: int) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var vertex_colors := PackedColorArray()
	var indices := PackedInt32Array()
	var stride := w + 1
	vertices.resize(stride * (d + 1))
	normals.resize(vertices.size())
	vertex_colors.resize(vertices.size())
	var k := 0
	for z in range(z0, z0 + d + 1):
		for x in range(x0, x0 + w + 1):
			vertices[k] = height_map.get_vertex(x, z)
			normals[k] = height_map.get_vertex_normal(x, z)
			vertex_colors[k] = colors[height_map.index(x, z)]
			k += 1
	indices.resize(w * d * 6)
	k = 0
	for z in d:
		for x in w:
			var i00 := z * stride + x
			var i10 := i00 + 1
			var i01 := i00 + stride
			var i11 := i01 + 1
			# Mesma diagonal usada em HeightMap.get_height_at() (ordem horária).
			indices[k] = i00
			indices[k + 1] = i10
			indices[k + 2] = i11
			indices[k + 3] = i00
			indices[k + 4] = i11
			indices[k + 5] = i01
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = vertex_colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


static func _hash01(i: int) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
