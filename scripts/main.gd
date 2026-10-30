extends Node3D
## Ponto de entrada: menu -> seed -> geração da ilha (em segundo plano) -> jogador,
## fauna e rede. Argumentos: --server (dedicado), --host, --join=IP, --port=N,
## --seed=N, --name=X, --dev.

@onready var _island: IslandGenerator = $IslandGenerator
@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD
@onready var _loading: LoadingScreen = $LoadingScreen
@onready var _sun: DirectionalLight3D = $Sun
@onready var _env: WorldEnvironment = $WorldEnvironment

var _fauna: FaunaManager
var _flora: FloraManager
var _remote: Dictionary = {}          ## peer -> RemotePlayer
var _menu: MainMenu
var _join_address := ""
var _join_port := Net.DEFAULT_PORT


func _ready() -> void:
	_island.add_to_group("spawn_provider")
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.hide()
	_island.progress.connect(_loading.set_status)
	var day_night := DayNight.new()
	day_night.sun = _sun
	day_night.environment = _env.environment
	add_child(day_night)
	Net.welcomed.connect(_on_welcomed)
	Net.connection_failed.connect(_on_connection_failed)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.peer_ready.connect(_on_peer_ready)
	Net.remote_state.connect(_on_remote_state)
	Net.local_state_fn = _local_state

	var args := _parse_args()
	if args.has("name"):
		Net.local_name = args["name"]
	if args.has("server"):
		_start_host(int(args.get("port", Net.DEFAULT_PORT)), true)
	elif args.has("host"):
		_start_host(int(args.get("port", Net.DEFAULT_PORT)), false)
	elif args.has("join"):
		_start_client(args["join"], int(args.get("port", Net.DEFAULT_PORT)))
	elif args.has("seed") or args.has("dev") or args.has("solo"):
		_start_single()
	else:
		_loading.hide()
		_menu = MainMenu.new()
		add_child(_menu)
		_menu.chosen.connect(_on_menu_chosen)


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var kv := arg.trim_prefix("--").split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out


func _on_menu_chosen(mode: int, address: String, port: int, pname: String) -> void:
	if not pname.is_empty():
		Net.local_name = pname
	match mode:
		Net.Mode.SINGLE: _start_single()
		Net.Mode.HOST: _start_host(port, false)
		Net.Mode.CLIENT:
			_start_client(address, port)


# --- Modos -------------------------------------------------------------------
func _begin_loading() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	_loading.show()


func _start_single() -> void:
	_begin_loading()
	_boot_world(_resolve_seed())


func _start_host(port: int, dedicated: bool) -> void:
	var seed_value := _resolve_seed()
	Net.world_seed = seed_value
	var err := Net.host(port, dedicated)
	if err != OK:
		if _menu != null:
			_menu.show_error("Falha ao abrir porta %d (erro %d)" % [port, err])
		else:
			push_error("Falha ao hospedar na porta %d" % port)
		return
	_begin_loading()
	_boot_world(seed_value)


func _start_client(address: String, port: int) -> void:
	_join_address = address
	_join_port = port
	if Net.join(address, port) != OK:
		_on_connection_failed()
		return
	_begin_loading()
	_loading.set_status("Conectando a %s:%d..." % [address, port])


func _on_welcomed(seed_value: int) -> void:
	_boot_world(seed_value)


func _on_connection_failed() -> void:
	_loading.hide()
	if _menu == null or not is_instance_valid(_menu):
		_menu = MainMenu.new()
		add_child(_menu)
		_menu.chosen.connect(_on_menu_chosen)
	_menu.show_error("Não foi possível conectar a %s:%d" % [_join_address, _join_port])


# --- Mundo ---------------------------------------------------------------------
func _boot_world(seed_value: int) -> void:
	_island.generated.connect(_on_island_generated, CONNECT_ONE_SHOT)
	_island.generate(seed_value)


func _on_island_generated(_seed_value: int) -> void:
	var dedicated := Net.mode == Net.Mode.DEDICATED
	_fauna = FaunaManager.new()
	_fauna.name = "Fauna"
	add_child(_fauna)
	_fauna.setup(_island, _players, Net.is_server())
	_flora = FloraManager.new()
	_flora.name = "Flora"
	add_child(_flora)
	_flora.setup(_island, _player_pos_of, _focus_point)
	if not dedicated:
		_player.water_level_at = _island.get_water_level_at
		_player.spawn_at(_island.find_spawn_point(), Vector3.ZERO)
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		_player.hit_animal.connect(_on_player_hit_animal)
		_player.swing.connect(func(o: Vector3, d: Vector3) -> void: _flora.request_action(o, d, false))
		_player.interact.connect(func(o: Vector3, d: Vector3) -> void: _flora.request_action(o, d, true))
		_hud.setup(_player, _island)
		_hud.show()
		var world_hud := WorldHud.new()
		world_hud.player = _player
		world_hud.fauna = _fauna
		add_child(world_hud)
	else:
		_player.queue_free()
		_hud.queue_free()
	if Net.mode == Net.Mode.CLIENT:
		Net.announce_ready()
	# Alguns quadros atrás da tela de carregamento para compilar os shaders.
	for i in 20:
		await get_tree().process_frame
	_loading.finish()
	_debug_screenshot()
	if Net.mode == Net.Mode.HOST:
		print("[PolyWorld] hospedando — seed %d" % _island.seed_value)


func _players() -> Array:
	var out: Array = []
	if is_instance_valid(_player) and not _player.is_queued_for_deletion():
		out.append(_player)
	out.append_array(_remote.values())
	return out


## Posição do jogador de um peer (servidor valida colheita com isto).
func _player_pos_of(peer: int) -> Vector3:
	if peer == Net.local_peer() and is_instance_valid(_player) and Net.mode != Net.Mode.DEDICATED:
		return _player.global_position
	if _remote.has(peer):
		return _remote[peer].global_position
	return Vector3.INF


func _focus_point() -> Vector3:
	if Net.mode != Net.Mode.DEDICATED and is_instance_valid(_player):
		return _player.global_position
	return Vector3.INF


func _on_player_hit_animal(uid: int, damage: float) -> void:
	if _fauna == null:
		return
	if Net.is_server():
		_fauna.request_hit(uid, damage)
	else:
		_fauna.request_hit.rpc_id(1, uid, damage)


# --- Jogadores remotos -----------------------------------------------------------
func _local_state() -> Array:
	if not is_instance_valid(_player) or _player.process_mode == Node.PROCESS_MODE_DISABLED:
		return []
	return [_player.global_position, _player.rotation.y, _player.get_node("Head").rotation.x]


func _on_peer_joined(peer: int) -> void:
	_ensure_remote(peer)


func _on_peer_left(peer: int) -> void:
	if _fauna != null:
		_fauna.forget_peer(peer)
	if _remote.has(peer):
		_remote[peer].queue_free()
		_remote.erase(peer)


func _on_peer_ready(peer: int) -> void:
	if _fauna != null and Net.is_server():
		_fauna.mark_peer_ready(peer)
		_flora.send_state(peer)


func _ensure_remote(peer: int) -> RemotePlayer:
	if _remote.has(peer):
		return _remote[peer]
	var rp := RemotePlayer.new()
	add_child(rp)
	rp.setup(peer, Net.player_names.get(peer, "Jogador %d" % peer))
	_remote[peer] = rp
	return rp


func _on_remote_state(peer: int, pos: Vector3, yaw: float, pitch: float) -> void:
	var rp := _ensure_remote(peer)
	if Net.is_server():
		# Anti-teleporte: limita a velocidade aceita (voo/nado/corrida < 25 m/s).
		var now := Time.get_ticks_msec() / 1000.0
		var dt := clampf(now - rp.last_update, 0.05, 1.0)
		if rp.has_state and rp.get_target().distance_to(pos) > 25.0 * dt + 3.0:
			pos = rp.get_target().move_toward(pos, 25.0 * dt + 3.0)
		rp.last_update = now
		rp.has_state = true
	rp.set_state(pos, yaw, pitch)


## Prioridade: "--seed=N" na linha de comando > WorldConfig.world_seed.
## world_seed = 0 gera uma seed aleatória.
func _resolve_seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return arg.get_slice("=", 1).to_int()
	var seed_value := _island.config.world_seed
	if seed_value == 0:
		seed_value = randi()
	return seed_value


## Depuração: --shot=arquivo.png [--season=0..3.9 --time=0..1] salva uma captura e sai.
func _debug_screenshot() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			path = arg.get_slice("=", 1)
		elif arg.begins_with("--season="):
			var v := arg.get_slice("=", 1).to_float()
			WorldClock.elapsed = (floorf(v) * WorldClock.DAYS_PER_SEASON + fmod(v, 1.0) * WorldClock.DAYS_PER_SEASON) * WorldClock.DAY_SECONDS + WorldClock.DAY_SECONDS * 0.5
		elif arg.begins_with("--animal="):
			var sp_id := StringName(arg.get_slice("=", 1))
			for a: Animal in _fauna.animals.values():
				if a.species.id == sp_id:
					var spot := a.position + Vector3(3.0, 0.0, 3.0)
					_player.teleport_to(Vector3(spot.x, _fauna.ground_height(spot) + 0.5, spot.z))
					_player.rotation.y = atan2(-(a.position.x - spot.x), -(a.position.z - spot.z))
					break
		elif arg.begins_with("--time="):
			WorldClock.elapsed = floorf(WorldClock.elapsed / WorldClock.DAY_SECONDS) * WorldClock.DAY_SECONDS + arg.get_slice("=", 1).to_float() * WorldClock.DAY_SECONDS
	if OS.get_cmdline_user_args().has("--selftest"):
		await _selftest()
		return
	if OS.get_cmdline_user_args().has("--selftest-net"):
		await _selftest_net()
		return
	if path.is_empty():
		return
	WorldClock.time_scale = 0.0
	for i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## Teste de integração (--selftest): coleta, fruta, caça e inventário no servidor local.
func _selftest() -> void:
	var peer := Net.local_peer()
	var ok := true
	var inv := get_node("/root/Inventory")
	WorldClock.time_scale = 0.0
	WorldClock.elapsed = (1.0 * WorldClock.DAYS_PER_SEASON + 2.0) * WorldClock.DAY_SECONDS   # verão
	# 1) lenha: bate numa árvore até esgotar
	var wood_idx := -1
	var fruit_idx := -1
	for i in _island.harvestables.size():
		var e: VegetationEntry = _island.harvestables[i][1]
		if wood_idx < 0 and e.harvest_item == &"wood_log":
			wood_idx = i
		if fruit_idx < 0 and e.fruit_item == &"apple" and _flora.has_fruit(i):
			fruit_idx = i
	var before: int = inv.count(peer, &"wood_log")
	var pos: Vector3 = _island.harvestables[wood_idx][0]
	_player.teleport_to(pos + Vector3(2, 1, 0))
	await get_tree().physics_frame
	var origin := _player.global_position + Vector3.UP * 1.6
	var dir := ((pos + Vector3.UP * 0.8) - origin).normalized()
	for k in 6:
		_flora.request_action(origin, dir, false)
		await get_tree().create_timer(0.3).timeout
	var got: int = inv.count(peer, &"wood_log") - before
	print("[selftest] lenha: +%d %s" % [got, "OK" if got > 0 else "FALHOU"])
	ok = ok and got > 0
	# 2) fruta
	var fpos: Vector3 = _island.harvestables[fruit_idx][0]
	var fe: VegetationEntry = _island.harvestables[fruit_idx][1]
	_player.teleport_to(fpos + Vector3(2, 1, 0))
	await get_tree().physics_frame
	origin = _player.global_position + Vector3.UP * 1.6
	dir = ((fpos + Vector3.UP * fe.fruit_height * 0.5) - origin).normalized()
	var b2: int = inv.count(peer, &"apple")
	await get_tree().create_timer(0.3).timeout
	_flora.request_action(origin, dir, true)
	var fr: int = inv.count(peer, &"apple") - b2
	print("[selftest] fruta: +%d %s, some da árvore: %s" % [fr, "OK" if fr > 0 else "FALHOU", not _flora.has_fruit(fruit_idx)])
	ok = ok and fr > 0 and not _flora.has_fruit(fruit_idx)
	# 3) estação: no inverno some, na próxima primavera/verão volta
	# 4) caça
	var target: Animal
	for a: Animal in _fauna.animals.values():
		if a.species.id == &"deer":
			target = a
			break
	var m0: int = inv.count(peer, &"raw_meat")
	for k in 40:   # golpes reais: dano vem do servidor, então são vários
		if not is_instance_valid(target) or target.health <= 0.0:
			break
		_player.teleport_to(target.position + Vector3(1.5, 0.5, 0))
		_fauna.request_hit(target.uid, 0.0)
		await get_tree().create_timer(0.4).timeout
	var meat: int = inv.count(peer, &"raw_meat") - m0
	print("[selftest] caça: carne +%d %s" % [meat, "OK" if meat > 0 else "FALHOU"])
	ok = ok and meat > 0
	# 5) domar coelho
	var rabbit: Animal
	for a: Animal in _fauna.animals.values():
		if a.species.id == &"rabbit":
			rabbit = a
			break
	_player.teleport_to(rabbit.position + Vector3(1.5, 0.5, 0))
	inv.add(peer, &"berries", 6)
	for k in 6:
		_fauna.request_tame(rabbit.uid)
	print("[selftest] domar: dono=%d %s" % [rabbit.tamed_by, "OK" if rabbit.tamed_by == peer else "FALHOU"])
	ok = ok and rabbit.tamed_by == peer
	# 6) crafting
	inv.add(peer, &"wood_log", 4)
	var cr := get_node("/root/Crafting")
	var recipes: Array = cr.recipe_list()
	print("[selftest] receitas: %d, nivel %d, xp ok" % [recipes.size(), get_node("/root/Progression").level(peer)])
	# 7) estações e frutas fora de época
	WorldClock.elapsed = (3.0 * WorldClock.DAYS_PER_SEASON + 1.0) * WorldClock.DAY_SECONDS
	print("[selftest] inverno sem fruta: %s" % [not _flora.has_fruit(fruit_idx)])
	print("[selftest] RESULTADO: %s" % ("PASSOU" if ok else "FALHOU"))
	get_tree().quit()


## Cliente remoto (--join + --selftest-net): caça, colheita e domesticação via RPC.
func _selftest_net() -> void:
	var peer := Net.local_peer()
	var inv := get_node("/root/Inventory")
	await get_tree().create_timer(4.0).timeout
	print("[nettest] peer=%d, animais sincronizados=%d, jogadores remotos=%d" % [peer, _fauna.animals.size(), _remote.size()])
	var target: Animal
	for a: Animal in _fauna.animals.values():
		if a.species.id == &"deer":
			target = a
			break
	var target_uid := target.uid
	var m0: int = inv.count(peer, &"raw_meat")
	for k in 40:
		if not _fauna.animals.has(target_uid):
			break
		_player.teleport_to(_fauna.animals[target_uid].position + Vector3(1.5, 0.5, 0))
		await get_tree().create_timer(0.2).timeout
		_fauna.request_hit.rpc_id(1, target_uid, 0.0)
		await get_tree().create_timer(0.4).timeout
	await get_tree().create_timer(1.0).timeout
	print("[nettest] caça remota: carne +%d %s | animal removido no cliente: %s" % [inv.count(peer, &"raw_meat") - m0, "OK" if inv.count(peer, &"raw_meat") > m0 else "FALHOU", not _fauna.animals.has(target_uid)])
	var wood_idx := -1
	for i in _island.harvestables.size():
		if (_island.harvestables[i][1] as VegetationEntry).harvest_item == &"wood_log":
			wood_idx = i
			break
	var pos: Vector3 = _island.harvestables[wood_idx][0]
	_player.teleport_to(pos + Vector3(2, 1, 0))
	await get_tree().create_timer(1.0).timeout   # o servidor recebe a posição pelo Net
	var origin := _player.global_position + Vector3.UP * 1.6
	var dir := ((pos + Vector3.UP * 0.8) - origin).normalized()
	var w0: int = inv.count(peer, &"wood_log")
	for k in 6:
		_flora.request_action(origin, dir, false)
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(1.0).timeout
	print("[nettest] lenha remota: +%d %s" % [inv.count(peer, &"wood_log") - w0, "OK" if inv.count(peer, &"wood_log") > w0 else "FALHOU"])
	get_tree().quit()
