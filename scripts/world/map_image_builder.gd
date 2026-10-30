class_name MapImageBuilder
extends RefCounted
## Gera a imagem do mapa visto de cima: 1 pixel por vértice, cor do bioma com
## sombreamento de relevo, rios/lagos e mar em tons de azul.

const WATER_SHALLOW := Color(0.36, 0.7, 0.84)
const WATER_DEEP := Color(0.1, 0.32, 0.55)
const RIVER := Color(0.25, 0.6, 0.85)
## Direção da luz do sombreamento (vinda do noroeste).
const LIGHT_DIR := Vector3(-0.5, 1.0, -0.5)


static func build(island: IslandGenerator) -> ImageTexture:
	var height_map := island.height_map
	var config := island.config
	var n := height_map.resolution
	var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	var light := LIGHT_DIR.normalized()
	for z in n:
		for x in n:
			var i := height_map.index(x, z)
			var y := height_map.heights[i]
			var color: Color
			if y < config.sea_level:
				var depth := clampf((config.sea_level - y) / 10.0, 0.0, 1.0)
				color = WATER_SHALLOW.lerp(WATER_DEEP, depth)
			elif island.hydrology.water_level[i] > y:
				color = RIVER
			else:
				var normal := height_map.get_vertex_normal(x, z)
				var biome := island.biome_map.get_biome(i)
				var shade := clampf(normal.dot(light) / light.y, 0.55, 1.25)
				var base := biome.color if biome != null else Color.MAGENTA
				color = Color(base.r * shade, base.g * shade, base.b * shade)
			image.set_pixel(x, z, color)
	return ImageTexture.create_from_image(image)
