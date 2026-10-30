extends Node
## Autoload Net: multiplayer ENet host-autoritativo.
## Modos: single (sem rede), host (listen-server), client, dedicated (--server).
## O servidor decide a seed; clientes geram a mesma ilha a partir dela.

signal welcomed(world_seed: int)          ## cliente recebeu a seed do servidor
signal peer_joined(peer: int)
signal peer_left(peer: int)
signal peer_ready(peer: int)              ## cliente terminou de gerar o mundo
signal connection_failed
signal remote_state(peer: int, pos: Vector3, yaw: float, pitch: float)

enum Mode { SINGLE, HOST, CLIENT, DEDICATED }

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 16
const SEND_RATE := 1.0 / 20.0

var mode: Mode = Mode.SINGLE
var world_seed := 0
var player_names: Dictionary = {}         ## peer -> nome
var local_name := "Jogador"
## Preenchido pelo main: devolve [pos, yaw, pitch] do jogador local.
var local_state_fn: Callable = func() -> Array: return []

var _send_acc := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(func() -> void:
		mode = Mode.SINGLE
		connection_failed.emit())
	multiplayer.server_disconnected.connect(_on_server_gone)


func is_server() -> bool:
	return mode != Mode.CLIENT


func is_online() -> bool:
	return mode != Mode.SINGLE


func local_peer() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


func host(port := DEFAULT_PORT, dedicated := false) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.DEDICATED if dedicated else Mode.HOST
	print("[Net] servidor na porta %d" % port)
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	return OK


func disconnect_all() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = Mode.SINGLE
	player_names.clear()


# --- Conexão -------------------------------------------------------------------
func _on_peer_connected(peer: int) -> void:
	if multiplayer.is_server():
		_rpc_welcome.rpc_id(peer, world_seed, WorldClock.elapsed)
	peer_joined.emit(peer)


func _on_peer_disconnected(peer: int) -> void:
	player_names.erase(peer)
	peer_left.emit(peer)


func _on_connected_ok() -> void:
	_rpc_set_name.rpc_id(1, local_name)


func _on_server_gone() -> void:
	disconnect_all()
	get_tree().reload_current_scene()


@rpc("authority", "call_remote", "reliable")
func _rpc_welcome(seed_value: int, elapsed: float) -> void:
	world_seed = seed_value
	WorldClock.elapsed = elapsed
	welcomed.emit(seed_value)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_name(pname: String) -> void:
	player_names[multiplayer.get_remote_sender_id()] = pname.substr(0, 16)


## Cliente avisa que gerou o mundo e já pode receber o estado dinâmico.
func announce_ready() -> void:
	if mode == Mode.CLIENT:
		_rpc_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ready() -> void:
	peer_ready.emit(multiplayer.get_remote_sender_id())


# --- Estado dos jogadores ----------------------------------------------------------
func _process(delta: float) -> void:
	if mode == Mode.SINGLE or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server() and Engine.get_process_frames() % 300 == 0:
		WorldClock.sync_clock.rpc(WorldClock.elapsed)
	_send_acc += delta
	if _send_acc < SEND_RATE:
		return
	_send_acc = 0.0
	var st: Array = local_state_fn.call()
	if st.size() == 3:
		_rpc_state.rpc(st[0], st[1], st[2])


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_state(pos: Vector3, yaw: float, pitch: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	remote_state.emit(sender, pos, yaw, pitch)
	# O servidor repassa aos outros clientes.
	if multiplayer.is_server():
		for p in multiplayer.get_peers():
			if p != sender:
				_rpc_relay.rpc_id(p, sender, pos, yaw, pitch)


@rpc("authority", "call_remote", "unreliable")
func _rpc_relay(peer: int, pos: Vector3, yaw: float, pitch: float) -> void:
	remote_state.emit(peer, pos, yaw, pitch)


## Servidor -> dono do jogador: tomou dano (animais, quedas...).
@rpc("authority", "call_remote", "reliable")
func rpc_damage(amount: float) -> void:
	var pl := get_tree().get_first_node_in_group("local_player")
	if pl != null and pl.has_method("take_damage"):
		pl.take_damage(amount)
