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
	if path.is_empty():
		return
	WorldClock.time_scale = 0.0
	for i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
