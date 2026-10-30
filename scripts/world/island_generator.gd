class_name IslandGenerator
extends Node3D
## Orquestra a geração da ilha numa thread separada:
## relevo -> rios/lagos -> biomas -> malhas -> vegetação.
## Depois, na thread principal, cria os nós (chunks, colisões, água, plantas).
## Também responde consultas do jogo (bioma, nível da água, ponto de spawn).

signal progress(message: String)
signal generated(seed_value: int)

@export var config: WorldConfig
@export var terrain_material: Material
@export var river_material: Material

var seed_value := 0
var height_map: HeightMap
var hydrology: Hydrology
var biome_map: BiomeMap

var _library: VegetationLibrary
var _placer: VegetationPlacer
## Plantas coletáveis [posição, VegetationEntry, escala]; preenchido ao gerar.
var harvestables: Array = []
var _terrain_arrays: Array = []
var _water_arrays: Array = []
var _thread: Thread
var _start_ms := 0

@onready var _terrain: Node3D = $Terrain
@onready var _terrain_body: StaticBody3D = $TerrainBody
@onready var _rivers: Node3D = $Rivers
@onready var _seabed: MeshInstance3D = $Seabed
@onready var _water: Water = $Water
@onready var _vegetation: VegetationSpawner = $Vegetation


## Começa a gerar; "generated" é emitido quando tudo estiver na cena.
func generate(new_seed: int) -> void:
	seed_value = new_seed
	_start_ms = Time.get_ticks_msec()
	progress.emit("Carregando modelos...")
	# Carregar recursos é mais seguro na thread principal.
	_library = VegetationLibrary.new(config)
	_thread = Thread.new()
	_thread.start(_build_data)


func get_biome_at(world_position: Vector3) -> BiomeData:
	if biome_map == null:
		return null
	return biome_map.get_biome_at(world_position.x, world_position.z)


## Nível da água (mar, rio ou lago) acima do ponto.
func get_water_level_at(world_position: Vector3) -> float:
	if hydrology == null:
		return config.sea_level
	var level := hydrology.water_level[height_map.nearest_node(world_position.x, world_position.z)]
	return maxf(config.sea_level, level)


## Escolhe (de forma determinística pela seed) um ponto plano de praia.
func find_spawn_point() -> Vector3:
	var candidates: Array[Vector3] = []
	var spawn_index := config.biomes.find(config.spawn_biome)
	for z in range(0, height_map.resolution, 3):
		for x in range(0, height_map.resolution, 3):
			var i := height_map.index(x, z)
			if biome_map.get_biome_index(i) != spawn_index or hydrology.has_water(i):
				continue
			var p := height_map.get_vertex(x, z)
			if p.y > config.sea_level + 0.3 and height_map.get_vertex_normal(x, z).y > 0.97:
				candidates.append(p)
	if candidates.is_empty():
		push_warning("Nenhuma praia encontrada; nascendo no centro.")
		return Vector3(0.0, height_map.get_height_at(0.0, 0.0), 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return candidates[rng.randi_range(0, candidates.size() - 1)]


# --- Thread de geração -------------------------------------------------------

func _build_data() -> void:
	_report("Esculpindo o relevo...")
	height_map = HeightMap.new(config, seed_value)
	_report("Calculando rios e lagos...")
	hydrology = Hydrology.new(height_map, config)
	_report("Definindo biomas...")
	biome_map = BiomeMap.new(config, height_map, hydrology, seed_value)
	_report("Montando o terreno...")
	_terrain_arrays = TerrainMeshBuilder.build_all(height_map, biome_map, hydrology, config)
	_water_arrays = WaterMeshBuilder.build_all(height_map, hydrology, config)
	_report("Plantando a vegetação...")
	_placer = VegetationPlacer.new()
	_placer.place(height_map, biome_map, hydrology, config, _library, seed_value)
	_report("Criando a cena...")
	_apply.call_deferred()


func _report(message: String) -> void:
	progress.emit.call_deferred(message)


# --- Thread principal ---------------------------------------------------------

func _apply() -> void:
	_thread.wait_to_finish()
	for node in [_terrain, _terrain_body, _rivers]:
		for child in node.get_children():
			child.queue_free()
	for arrays: Array in _terrain_arrays:
		var mesh := _make_mesh(arrays, terrain_material)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		_terrain.add_child(instance)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		_terrain_body.add_child(shape)
	for arrays: Array in _water_arrays:
		var instance := MeshInstance3D.new()
		instance.mesh = _make_mesh(arrays, river_material)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rivers.add_child(instance)
	_water.place_at(config.sea_level)
	# Fundo do mar infinito na profundidade da borda da ilha (esconde a borda da malha).
	_seabed.position.y = config.sea_level - config.sea_threshold * config.max_height - 0.05
	harvestables = _placer.harvestables
	_vegetation.build(_placer, _library)
	_terrain_arrays.clear()
	_water_arrays.clear()
	_placer = null
	print("Ilha gerada (seed %d) em %d ms" % [seed_value, Time.get_ticks_msec() - _start_ms])
	generated.emit(seed_value)


static func _make_mesh(arrays: Array, material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
