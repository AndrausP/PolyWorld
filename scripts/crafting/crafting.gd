extends Node
## Valida e executa receitas no servidor.

signal crafted(peer: int, recipe_id: StringName)
signal craft_failed(peer: int, recipe_id: StringName, reason: String)

const RECIPES_DIR := "res://data/recipes/"
var _recipes: Dictionary = {}


func _ready() -> void:
	for file: String in ResourceLoader.list_directory(RECIPES_DIR):
		if not file.ends_with(".tres") and not file.ends_with(".res"):
			continue
		var recipe: Variant = load(RECIPES_DIR + file)
		if recipe != null and recipe.id != &"":
			_recipes[recipe.id] = recipe


func get_recipe(recipe_id: StringName) -> Variant:
	return _recipes.get(recipe_id)


func recipe_list() -> Array:
	var result: Array = []
	for recipe: Variant in _recipes.values():
		result.append(recipe)
	result.sort_custom(func(a, b) -> bool: return a.display_name < b.display_name)
	return result


func can_craft(peer: int, recipe_id: StringName) -> bool:
	var recipe: Variant = get_recipe(recipe_id)
	if recipe == null or not Progression.is_unlocked(peer, recipe_id):
		return false
	if recipe.tier > floori(float(Progression.level(peer) - 1) / 2.0):
		return false
	if not _has_station(recipe.station, peer):
		return false
	for raw_id: Variant in recipe.inputs:
		if Inventory.count(peer, StringName(str(raw_id))) < int(recipe.inputs[raw_id]):
			return false
	return true


@rpc("any_peer", "call_remote", "reliable")
func request_craft(recipe_id: StringName) -> void:
	if not _is_server():
		request_craft.rpc_id(1, recipe_id)
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer <= 0:
		peer = 1
	var recipe: Variant = get_recipe(recipe_id)
	if recipe == null:
		_send_remote_result(peer, recipe_id, false, "Receita nao encontrada.")
		craft_failed.emit(peer, recipe_id, "Receita inexistente.")
		return
	if not can_craft(peer, recipe_id):
		_send_remote_result(peer, recipe_id, false, "Faltam itens, nivel, estacao ou desbloqueio.")
		craft_failed.emit(peer, recipe_id, "Faltam recursos, nível, estação ou desbloqueio.")
		return
	if not Inventory.transact(peer, recipe.inputs, recipe.outputs):
		_send_remote_result(peer, recipe_id, false, "Inventario cheio ou recursos insuficientes.")
		craft_failed.emit(peer, recipe_id, "Inventário cheio ou recursos insuficientes.")
		return
	Progression.add_xp(peer, recipe.xp)
	_send_remote_result(peer, recipe_id, true, "")
	crafted.emit(peer, recipe_id)


func _has_station(station: StringName, peer: int) -> bool:
	if station == &"":
		return true
	for node: Node in get_tree().get_nodes_in_group("crafting_station"):
		if StringName(str(node.get_meta("station_id", ""))) != station:
			continue
		if node.has_method("can_craft_for") and bool(node.call("can_craft_for", peer)):
			return true
		var player := _player_for_peer(peer)
		if player != null and node is Node3D and player.global_position.distance_to((node as Node3D).global_position) <= 8.0:
			return true
	return false


func _player_for_peer(peer: int) -> Node3D:
	for player: Node in get_tree().get_nodes_in_group("players"):
		if player is Node3D and int(player.get_meta("peer_id", player.get_multiplayer_authority())) == peer:
			return player as Node3D
	for remote: Node in get_tree().get_nodes_in_group("remote_players"):
		if remote is Node3D and int(remote.get("peer")) == peer:
			return remote as Node3D
	return null


func _send_remote_result(peer: int, recipe_id: StringName, succeeded: bool, reason: String) -> void:
	if peer != 1 and multiplayer.has_multiplayer_peer():
		_rpc_craft_result.rpc_id(peer, peer, recipe_id, succeeded, reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_craft_result(peer: int, recipe_id: StringName, succeeded: bool, reason: String) -> void:
	if succeeded:
		crafted.emit(peer, recipe_id)
	else:
		craft_failed.emit(peer, recipe_id, reason)


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
