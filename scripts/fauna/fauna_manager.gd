class_name FaunaManager
extends Node3D
## Gerencia todos os animais. Servidor: spawn por bioma, IA, nascimentos, mortes.
## Clientes: recebem spawn/despawn (reliable) e posições (unreliable, 10 Hz).

signal animal_killed(species_id: StringName, pos: Vector3, killer_peer: int)

const TICK := 0.1
const POP_CAP := 140

var island: IslandGenerator
var animals: Dictionary = {}     ## uid -> Animal
var _next_uid := 1
var _acc := 0.0
var _sync_acc := 0.0
var _respawn_acc := 0.0
var _rng := RandomNumberGenerator.new()
var _players_fn: Callable = func() -> Array: return []   ## -> Array[Node3D]
var _is_server := true
var _ready_peers: Array[int] = []   ## clientes que já geraram o mundo


func setup(isl: IslandGenerator, players_getter: Callable, is_server: bool) -> void:
	island = isl
	_players_fn = players_getter
	_is_server = is_server
	_rng.seed = isl.seed_value
	if is_server:
		_populate_initial()
		var counts := {}
		for a: Animal in animals.values():
			counts[a.species.id] = counts.get(a.species.id, 0) + 1
		print("[Fauna] %d animais: %s" % [animals.size(), counts])


# --- Consultas de mundo ------------------------------------------------------
func ground_height(p: Vector3) -> float:
	return island.height_map.get_height_at(p.x, p.z)


func _half_extent() -> float:
	return island.config.size_cells * island.config.cell_size * 0.5


func is_walkable(p: Vector3, sp: SpeciesData) -> bool:
	var half := _half_extent() - 8.0
	if absf(p.x) > half or absf(p.z) > half:
		return false
	var depth := island.get_water_level_at(p) - ground_height(p)
	if sp.body == &"turtle":
		return depth < 0.9
	return depth < 0.25 and island.height_map.get_normal_at(p.x, p.z).y > 0.7


func pick_wander_point(a: Animal) -> Vector3:
	for i in 6:
		var ang := randf() * TAU
		var p := a.position + Vector3(sin(ang), 0, cos(ang)) * randf_range(4.0, 14.0)
		if is_walkable(p, a.species):
			return p
	return a.position


func _players() -> Array:
	return _players_fn.call()


func nearest_threat(a: Animal) -> Node3D:
	var best: Node3D
	var best_d := INF
	if a.species.flees_from_player and a.tamed_by == 0:
		for p: Node3D in _players():
			var d := a.position.distance_to(p.global_position)
			if d < 11.0 * a.genes[Genes.G.SPEED] and d < best_d:
				best = p
				best_d = d
	if a.species.diet != SpeciesData.Diet.CARNIVORE and a.species.aggression < 0.5:
		for other: Animal in animals.values():
			if other.species.diet == SpeciesData.Diet.CARNIVORE and other.species.aggression > 0.5:
				var d := a.position.distance_to(other.position)
				if d < 14.0 and d < best_d:
					best = other
					best_d = d
	return best


func nearest_prey(a: Animal) -> Node3D:
	var best: Node3D
	var best_d := 22.0
	for other: Animal in animals.values():
		if other == a or other.species.diet == SpeciesData.Diet.CARNIVORE:
			continue
		if other.species.id == a.species.id or other.species.base_size > a.species.base_size * 1.3:
			continue
		var d := a.position.distance_to(other.position)
		if d < best_d:
			best = other
			best_d = d
	if best == null and a.species.aggression > 0.7:
		for p: Node3D in _players():
			var d := a.position.distance_to(p.global_position)
			if d < 14.0 and d < best_d:
				best = p
				best_d = d
	return best


func attack(a: Animal, target: Node3D) -> void:
	if target is Animal:
		var t := target as Animal
		t.health -= a.species.damage * a.genes[Genes.G.AGGRESSION]
		if t.health <= 0.0:
			a.hunger = minf(a.max_hunger, a.hunger + 60.0)
			kill_animal(t.uid, 0)
	elif target.has_method("take_damage"):
		target.take_damage(a.species.damage * a.genes[Genes.G.AGGRESSION])


func player_of(peer: int) -> Node3D:
	for p: Node3D in _players():
		if p is RemotePlayer and (p as RemotePlayer).peer == peer:
			return p
		if p is Player and peer == multiplayer.get_unique_id():
			return p
	return null


## Comidas aceitas para domesticar, por dieta.
const TAME_FOOD := {
	SpeciesData.Diet.HERBIVORE: [&"berries", &"apple", &"carrot", &"seeds"],
	SpeciesData.Diet.OMNIVORE: [&"berries", &"apple", &"cooked_meat", &"seeds"],
	SpeciesData.Diet.CARNIVORE: [&"cooked_meat", &"raw_meat", &"dried_meat"],
}


## Jogador alimenta um animal manso o bastante: 3 a 4 oferendas o domam.
@rpc("any_peer", "call_local", "reliable")
func request_tame(uid: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = 1
	var a: Animal = animals.get(uid)
	var pl := player_of(peer)
	if a == null or pl == null or not a.species.tameable or a.tamed_by != 0:
		return
	if pl.global_position.distance_to(a.position) > 4.5:
		return
	var inv := get_node_or_null("/root/Inventory")
	if inv != null:
		var paid := false
		for item: StringName in TAME_FOOD[a.species.diet]:
			if inv.remove(peer, item, 1):
				paid = true
				break
		if not paid:
			return
	a.tame_progress += 100.0 / (3.0 + a.genes[Genes.G.AGGRESSION] * 2.0)
	a.hunger = minf(a.max_hunger, a.hunger + 25.0)
	if a.tame_progress >= 100.0:
		a.tamed_by = peer
		a.state = Animal.State.IDLE
		for p in _ready_peers:
			_rpc_tamed.rpc_id(p, uid, peer)
		_rpc_tamed(uid, peer)
		_add_xp(peer, 25)


@rpc("authority", "call_remote", "reliable")
func _rpc_tamed(uid: int, peer: int) -> void:
	var a: Animal = animals.get(uid)
	if a != null:
		a.tamed_by = peer


func _add_xp(peer: int, amount: int) -> void:
	var prog := get_node_or_null("/root/Progression")
	if prog != null:
		prog.add_xp(peer, amount)


func find_mate(a: Animal) -> Animal:
	for other: Animal in animals.values():
		if other != a and not other.female and other.is_adult and other.species.id == a.species.id \
				and other.position.distance_to(a.position) < 8.0:
			return other
	return null


# --- Ciclo de vida -------------------------------------------------------------
func _populate_initial() -> void:
	for sp in SpeciesLibrary.all():
		for h in 5:
			var center := _random_spawn_point(sp)
			if center == Vector3.INF:
				continue
			var n := _rng.randi_range(sp.herd_size.x, sp.herd_size.y)
			for i in n:
				var p := center + Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
				if is_walkable(p, sp):
					_spawn(sp, Genes.random(_rng), _rng.randf() < 0.5, p,
							_rng.randf_range(sp.maturity_days, sp.maturity_days * 3.0))


func _random_spawn_point(sp: SpeciesData) -> Vector3:
	var half := _half_extent()
	for i in 60:
		var p := Vector3(_rng.randf_range(-half, half), 0, _rng.randf_range(-half, half)) * 0.9
		p.y = ground_height(p)
		var biome := island.get_biome_at(p)
		if biome != null and sp.biomes.has(biome.display_name) and is_walkable(p, sp):
			return p
	return Vector3.INF


func _spawn(sp: SpeciesData, genes: PackedFloat32Array, female: bool, pos: Vector3, age: float, uid := -1) -> Animal:
	if uid < 0:
		uid = _next_uid
		_next_uid += 1
	var a := Animal.new()
	a.setup(uid, sp, genes, female, age)
	a.position = Vector3(pos.x, ground_height(pos), pos.z)
	a.puppet = not _is_server
	a.set_net(a.position, 0.0)
	add_child(a)
	animals[uid] = a
	if _is_server:
		for peer in _ready_peers:
			_rpc_spawn.rpc_id(peer, uid, sp.id, genes, female, a.position, age)
	return a


func give_birth(mother: Animal) -> void:
	if animals.size() >= POP_CAP:
		return
	var n := _rng.randi_range(mother.species.litter.x, mother.species.litter.y)
	n = maxi(1, roundi(n * 0.5))   # ninhadas menores evitam explosão populacional
	var dad := mother.father_genes if mother.father_genes.size() > 0 else mother.genes
	for i in n:
		var g := Genes.breed(mother.genes, dad, _rng)
		var off := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
		_spawn(mother.species, g, _rng.randf() < 0.5, mother.position + off, 0.0)


func kill_animal(uid: int, killer_peer: int) -> void:
	var a: Animal = animals.get(uid)
	if a == null:
		return
	if killer_peer != 0:
		_give_drops(a, killer_peer)
	animal_killed.emit(a.species.id, a.position, killer_peer)
	animals.erase(uid)
	a.queue_free()
	for peer in _ready_peers:
		_rpc_despawn.rpc_id(peer, uid)


func _give_drops(a: Animal, peer: int) -> void:
	var inv := get_node_or_null("/root/Inventory")
	if inv == null:
		return
	var mult := a.scale_now / maxf(a.species.base_size, 0.01)
	for item_id: String in a.species.drops:
		var r: Array = a.species.drops[item_id]
		var n := roundi(_rng.randi_range(r[0], r[1]) * mult)
		if n > 0:
			inv.add(peer, StringName(item_id), n)


## Cliente -> servidor: jogador bateu num animal.
@rpc("any_peer", "call_local", "reliable")
func request_hit(uid: int, damage: float) -> void:
	if not multiplayer.is_server():
		return
	var a: Animal = animals.get(uid)
	if a == null:
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = 1
	a.health -= clampf(damage, 0.0, 30.0)
	a.state = Animal.State.FLEE
	if a.health <= 0.0:
		kill_animal(uid, peer)


# --- Loop ----------------------------------------------------------------------
func _process(delta: float) -> void:
	if island == null:
		return
	if not _is_server:
		for a: Animal in animals.values():
			a.puppet_update(delta)
		return
	_acc += delta
	if _acc >= TICK:
		var step := _acc
		_acc = 0.0
		for a: Animal in animals.values().duplicate():
			if is_instance_valid(a):
				a.server_tick(step, self)
		_respawn_pass(step)
	_sync_acc += delta
	if _sync_acc >= 0.1 and not _ready_peers.is_empty():
		_sync_acc = 0.0
		_send_snapshots()


## Mantém a população: repõe espécies raras longe dos jogadores.
func _respawn_pass(step: float) -> void:
	_respawn_acc += step
	if _respawn_acc < 20.0 or animals.size() >= POP_CAP * 0.6:
		return
	_respawn_acc = 0.0
	var counts := {}
	for a: Animal in animals.values():
		counts[a.species.id] = counts.get(a.species.id, 0) + 1
	for sp in SpeciesLibrary.all():
		if counts.get(sp.id, 0) < 4:
			var c := _random_spawn_point(sp)
			if c != Vector3.INF and not _near_player(c, 60.0):
				_spawn(sp, Genes.random(_rng), _rng.randf() < 0.5, c, sp.maturity_days * 1.5)


func _near_player(p: Vector3, r: float) -> bool:
	for pl: Node3D in _players():
		if pl.global_position.distance_to(p) < r:
			return true
	return false


# --- Rede ----------------------------------------------------------------------
## Pacotes de até 40 animais (24 bytes cada) para ficar abaixo do MTU do ENet.
func _send_snapshots() -> void:
	var s := PackedFloat32Array()
	var n := 0
	for a: Animal in animals.values():
		s.append_array(PackedFloat32Array([a.uid, a.position.x, a.position.y, a.position.z, a.rotation.y, a.age_days]))
		n += 1
		if n == 40:
			_flush(s)
			s = PackedFloat32Array()
			n = 0
	if n > 0:
		_flush(s)


func _flush(s: PackedFloat32Array) -> void:
	for peer in _ready_peers:
		_rpc_snapshot.rpc_id(peer, s)


func mark_peer_ready(peer: int) -> void:
	if peer not in _ready_peers:
		_ready_peers.append(peer)
	send_full_state(peer)


func forget_peer(peer: int) -> void:
	_ready_peers.erase(peer)


@rpc("authority", "call_remote", "unreliable")
func _rpc_snapshot(s: PackedFloat32Array) -> void:
	for i in range(0, s.size(), 6):
		var a: Animal = animals.get(int(s[i]))
		if a != null:
			a.set_net(Vector3(s[i + 1], s[i + 2], s[i + 3]), s[i + 4])
			a.age_days = s[i + 5]


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn(uid: int, sp_id: StringName, genes: PackedFloat32Array, female: bool, pos: Vector3, age: float) -> void:
	if animals.has(uid):
		return
	_spawn(SpeciesLibrary.get_species(sp_id), genes, female, pos, age, uid)


@rpc("authority", "call_remote", "reliable")
func _rpc_despawn(uid: int) -> void:
	var a: Animal = animals.get(uid)
	if a != null:
		animals.erase(uid)
		a.queue_free()


## Servidor manda o estado completo para quem acabou de entrar.
func send_full_state(peer: int) -> void:
	for a: Animal in animals.values():
		_rpc_spawn.rpc_id(peer, a.uid, a.species.id, a.genes, a.female, a.position, a.age_days)
		if a.tamed_by != 0:
			_rpc_tamed.rpc_id(peer, a.uid, a.tamed_by)
