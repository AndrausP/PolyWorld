class_name VegetationLibrary
extends RefCounted
## Prepara as malhas da vegetação a partir dos modelos glTF: extrai a malha de
## cada variante e troca os materiais importados pelos shaders do jogo
## (folhagem com vento/tinta/neve e "sólido" para troncos e pedras).
## Também indexa as entradas por bioma e camada para o posicionamento.

const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")
const SOLID_SHADER := preload("res://shaders/vegetation_solid.gdshader")
## Materiais de folha que têm uma versão branca (máscara) para tingir.
const TINT_MASKS := {
	"Leaves_NormalTree": "Leaves_NormalTree.png",
	"Leaves_Pine": "Leaf_Pine.png",
	"Leaves_TwistedTree": "Leaves_TwistedTree.png",
}
## Largura de cada faixa de cor da paleta Grass.png (28 px de 512).
const GRASS_STRIP_WIDTH := 28.0 / 512.0

## Todas as entradas usadas por algum bioma (o índice é o id da entrada).
var entries: Array[VegetationEntry] = []
## Por bioma (mesmo índice de config.biomes): [entradas LARGE, entradas GROUND] como ids.
var biome_layers: Array = []

var _meshes: Array = [] # por id: Array de Mesh (uma por variante)


func _init(config: WorldConfig) -> void:
	for biome in config.biomes:
		var layers := [PackedInt32Array(), PackedInt32Array()]
		for entry in biome.vegetation:
			if entry == null or entry.scenes.is_empty():
				continue
			var id := entries.find(entry)
			if id < 0:
				id = entries.size()
				entries.append(entry)
				_meshes.append(_build_variants(entry))
			layers[entry.layer].append(id)
		biome_layers.append(layers)


func get_mesh(entry_id: int, variant: int) -> Mesh:
	return _meshes[entry_id][variant]


func _build_variants(entry: VegetationEntry) -> Array:
	var meshes := []
	for scene in entry.scenes:
		meshes.append(_build_mesh(entry, scene))
	return meshes


func _build_mesh(entry: VegetationEntry, scene: PackedScene) -> Mesh:
	var root := scene.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		root.free()
		push_warning("Sem malha em %s" % scene.resource_path)
		return null
	var source: Mesh = (found[0] as MeshInstance3D).mesh
	root.free()
	var mesh: Mesh = source.duplicate()
	var height := maxf(mesh.get_aabb().end.y, 0.1)
	var folder := scene.resource_path.get_base_dir()
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, _make_material(entry, mesh.surface_get_material(s), height, folder))
	return mesh


func _make_material(entry: VegetationEntry, source: Material, height: float, folder: String) -> ShaderMaterial:
	var name := source.resource_name if source != null else ""
	var texture: Texture2D = null
	if source is BaseMaterial3D:
		texture = (source as BaseMaterial3D).albedo_texture
	if name.is_empty() and texture != null:
		name = texture.resource_path.get_file().get_basename()

	var is_foliage := name.begins_with("Leaves") or name == "Grass" or name == "Flowers"
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE_SHADER if is_foliage else SOLID_SHADER
	var tint := Color.WHITE
	if is_foliage and entry.leaf_tint.a > 0.0 and TINT_MASKS.has(name):
		texture = load(folder.path_join(TINT_MASKS[name]))
		tint = Color(entry.leaf_tint, 1.0)
	material.set_shader_parameter("albedo_tex", texture)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("mesh_height", height)
	material.set_shader_parameter("wind_weight", entry.wind_strength)
	material.set_shader_parameter("snow_amount", entry.snow_cover)
	if is_foliage:
		material.set_shader_parameter("flutter", 0.3 if name == "Grass" else 1.0)
		if name == "Grass":
			material.set_shader_parameter("uv_shift_x", entry.grass_palette_shift * GRASS_STRIP_WIDTH)
	return material
