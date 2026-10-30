class_name FloraManager
extends Node3D
## Plantas coletáveis: golpear (lenha, pedra, fibra) e colher frutos sazonais.
## Servidor decide tudo; clientes só desenham os frutos e recebem o estado
## "já colhido nesta estação". Instâncias são identificadas pelo índice na lista
## de harvestables (a mesma em todos os peers, pois a seed é a mesma).

const CELL := 10.0
const REACH := 4.5
const FRUIT_VIEW := 60.0
const REGROW_SECONDS := 1200.0   ## uma jornada inteira

var island: IslandGenerator
var _list: Array = []                 ## [pos, entry, scale]
var _grid: Dictionary = {}            ## Vector2i -> Array[int]
var _depleted_until: Dictionary = {}  ## idx -> WorldClock.elapsed (golpeadas)
var _hits: Dictionary = {}            ## idx -> golpes acumulados
var _fruit_taken: Dictionary = {}     ## idx -> índice absoluto da estação em que foi colhido
var _player_pos_fn: Callable = func(_peer: int) -> Vector3: return Vector3.INF
var _fruit_mm: MultiMeshInstance3D
var _fruit_acc := 0.0
var _focus_fn: Callable = func() -> Vector3: return Vector3.INF
var _rng := RandomNumberGenerator.new()


func setup(isl: IslandGenerator, player_pos_fn: Callable, focus_fn: Callable) -> void:
	island = isl
	_list = isl.harvestables
	_player_pos_fn = player_pos_fn
	_focus_fn = focus_fn
	_rng.seed = isl.seed_value
	for i in _list.size():
		var p: Vector3 = _list[i][0]
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(i)
	_fruit_mm = MultiMeshInstance3D.new()
	_fruit_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fruit_mm)
	print("[Flora] %d plantas coletáveis" % _list.size())


# --- Consultas ----------------------------------------------------------------
func _abs_season() -> int:
	return int(WorldClock.day / WorldClock.DAYS_PER_SEASON)


func _has_fruit_gene(idx: int, entry: VegetationEntry) -> bool:
	return entry.fruit_item != &"" and ((idx * 2654435761) & 0xffff) / 65535.0 < entry.fruit_chance


func has_fruit(idx: int) -> bool:
	var entry: VegetationEntry = _list[idx][1]
	return _has_fruit_gene(idx, entry) \
		and WorldClock.season in entry.fruit_seasons \
		and _fruit_taken.get(idx, -1) != _abs_season()


func _nearby(pos: Vector3, radius: float) -> Array[int]:
	var out: Array[int] = []
	var r := int(ceil(radius / CELL))
	var c := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell: Array = _grid.get(c + Vector2i(dx, dz), [])
			for i: int in cell:
				out.append(i)
	return out


## Planta mais próxima do raio da câmera (distância ao raio < ~1,3 m).
func _pick(origin: Vector3, dir: Vector3, want_fruit: bool) -> int:
	var best := -1
	var best_score := INF
	for step in range(1, 5):
		var probe := origin + dir * (step * 1.1)
		for i in _nearby(probe, 3.0):
			var item: Array = _list[i]
			var entry: VegetationEntry = item[1]
			var centre: Vector3 = item[0] + Vector3.UP * (entry.fruit_height * 0.5 if want_fruit else 0.8)
			var to := centre - origin
			var along := to.dot(dir)
			if along < 0.3 or along > REACH:
				continue
			var off := (to - dir * along).length()
			var limit := 1.6 if want_fruit else 1.3
			if off < limit and off + along * 0.1 < best_score:
				if want_fruit and not has_fruit(i):
					continue
				best = i
				best_score = off + along * 0.1
	return best


# --- Ações (cliente -> servidor) ----------------------------------------------
func request_action(origin: Vector3, dir: Vector3, fruit: bool) -> void:
	if multiplayer.is_server():
		_do_action(1, origin, dir, fruit)
	else:
		_rpc_action.rpc_id(1, origin, dir, fruit)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_action(origin: Vector3, dir: Vector3, fruit: bool) -> void:
	if multiplayer.is_server():
		_do_action(multiplayer.get_remote_sender_id(), origin, dir, fruit)


func _do_action(peer: int, origin: Vector3, dir: Vector3, fruit: bool) -> void:
	var pp: Vector3 = _player_pos_fn.call(peer)
	if pp == Vector3.INF or pp.distance_to(origin) > 4.0:
		return
	dir = dir.normalized()
	var idx := _pick(origin, dir, fruit)
	if idx < 0:
		return
	var entry: VegetationEntry = _list[idx][1]
	if fruit:
		_fruit_taken[idx] = _abs_season()
		_give(peer, entry.fruit_item, _rng.randi_range(entry.fruit_amount.x, entry.fruit_amount.y))
		_add_xp(peer, 2)
		for p in multiplayer.get_peers():
			_rpc_taken.rpc_id(p, idx, _abs_season())
		_refresh_fruit()
		return
	if entry.harvest_item == &"" or _depleted_until.get(idx, 0.0) > WorldClock.elapsed:
		return
	_hits[idx] = _hits.get(idx, 0) + 1
	if _hits[idx] >= entry.harvest_hits:
		_hits[idx] = 0
		_depleted_until[idx] = WorldClock.elapsed + REGROW_SECONDS
		_give(peer, entry.harvest_item, _rng.randi_range(entry.harvest_amount.x, entry.harvest_amount.y))
		_add_xp(peer, 3)


func _give(peer: int, item: StringName, amount: int) -> void:
	var inv := get_node_or_null("/root/Inventory")
	if inv != null:
		inv.add(peer, item, amount)


func _add_xp(peer: int, amount: int) -> void:
	var prog := get_node_or_null("/root/Progression")
	if prog != null:
		prog.add_xp(peer, amount)


@rpc("authority", "call_remote", "reliable")
func _rpc_taken(idx: int, abs_season: int) -> void:
	_fruit_taken[idx] = abs_season
	_refresh_fruit()


func send_state(peer: int) -> void:
	for idx: int in _fruit_taken:
		_rpc_taken.rpc_id(peer, idx, _fruit_taken[idx])


# --- Frutos visíveis ----------------------------------------------------------------
func _ready() -> void:
	WorldClock.season_changed.connect(func(_s: int) -> void: _refresh_fruit())


func _process(delta: float) -> void:
	_fruit_acc += delta
	if _fruit_acc > 2.0:
		_fruit_acc = 0.0
		_refresh_fruit()


func _refresh_fruit() -> void:
	if island == null or _list.is_empty():
		return
	var focus: Vector3 = _focus_fn.call()
	if focus == Vector3.INF:
		return
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in _nearby(focus, FRUIT_VIEW):
		if not has_fruit(i):
			continue
		var item: Array = _list[i]
		var entry: VegetationEntry = item[1]
		var p: Vector3 = item[0]
		if p.distance_to(focus) > FRUIT_VIEW:
			continue
		var r := RandomNumberGenerator.new()
		r.seed = i * 7919
		var count := 4 + r.randi() % 5
		for k in count:
			var ang := r.randf() * TAU
			var rad: float = r.randf_range(0.5, 1.5) * float(item[2]) * (0.4 if entry.fruit_height < 1.5 else 1.0)
			var h: float = entry.fruit_height * float(item[2]) * r.randf_range(0.8, 1.15)
			xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.16), p + Vector3(cos(ang) * rad, h, sin(ang) * rad)))
			colors.append(entry.fruit_color)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	sphere.material = mat
	mm.mesh = sphere
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	_fruit_mm.multimesh = mm
