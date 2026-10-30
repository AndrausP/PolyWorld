extends Node
## XP, níveis e pontos usados para abrir receitas da árvore tecnológica.

signal leveled_up(peer: int, level: int)
signal changed(peer: int)

const XP_STEP := 100
var _states: Dictionary = {}


func _ready() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected) == false:
		multiplayer.peer_connected.connect(_on_peer_connected)


func add_xp(peer: int, amount: int) -> void:
	if not _is_server() or amount <= 0:
		return
	var state := _state_for(peer)
	state["xp"] = int(state["xp"]) + amount
	while int(state["xp"]) >= int(state["level"]) * XP_STEP:
		state["xp"] = int(state["xp"]) - int(state["level"]) * XP_STEP
		state["level"] = int(state["level"]) + 1
		state["points"] = int(state["points"]) + 1
		leveled_up.emit(peer, int(state["level"]))
	changed.emit(peer)
	_sync(peer)


func level(peer: int) -> int:
	return int(_state_for(peer)["level"])


func xp_to_next(peer: int) -> int:
	var state := _state_for(peer)
	return maxi(int(state["level"]) * XP_STEP - int(state["xp"]), 0)


func points(peer: int) -> int:
	return int(_state_for(peer)["points"])


func is_unlocked(peer: int, recipe_id: StringName) -> bool:
	var recipe: Variant = Crafting.get_recipe(recipe_id)
	if recipe == null or level(peer) < recipe.unlock_level:
		return false
	var unlocked: Array = _state_for(peer)["unlocked"]
	if recipe.unlock_cost > 0 and recipe_id not in unlocked:
		return false
	for prerequisite: StringName in recipe.prerequisites:
		if not is_unlocked(peer, prerequisite):
			return false
	return true


func can_unlock(peer: int, recipe_id: StringName) -> bool:
	var recipe: Variant = Crafting.get_recipe(recipe_id)
	if recipe == null or recipe.unlock_cost <= 0 or level(peer) < recipe.unlock_level:
		return false
	if recipe_id in _state_for(peer)["unlocked"] or points(peer) < recipe.unlock_cost:
		return false
	for prerequisite: StringName in recipe.prerequisites:
		if not is_unlocked(peer, prerequisite):
			return false
	return true


func unlock_recipe(peer: int, recipe_id: StringName) -> bool:
	if not _is_server():
		_request_unlock_recipe.rpc_id(1, recipe_id)
		return true
	if not can_unlock(peer, recipe_id):
		return false
	var recipe: Variant = Crafting.get_recipe(recipe_id)
	var state := _state_for(peer)
	state["points"] = int(state["points"]) - recipe.unlock_cost
	state["unlocked"].append(recipe_id)
	changed.emit(peer)
	_sync(peer)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_unlock_recipe(recipe_id: StringName) -> void:
	if not _is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer > 0:
		unlock_recipe(peer, recipe_id)


func _state_for(peer: int) -> Dictionary:
	if not _states.has(peer):
		_states[peer] = {"xp": 0, "level": 1, "points": 0, "unlocked": []}
	return _states[peer]


func _sync(peer: int) -> void:
	if _is_server() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(peer):
		var state: Dictionary = _state_for(peer)
		_rpc_sync.rpc_id(peer, peer, int(state["xp"]), int(state["level"]), int(state["points"]), state["unlocked"])


func _on_peer_connected(new_peer: int) -> void:
	if not _is_server():
		return
	var state: Dictionary = _state_for(new_peer)
	if multiplayer.get_peers().has(new_peer):
		_rpc_sync.rpc_id(new_peer, new_peer, int(state["xp"]), int(state["level"]), int(state["points"]), state["unlocked"])


@rpc("authority", "call_remote", "reliable")
func _rpc_sync(peer: int, xp: int, level_value: int, points_value: int, unlocked: Array) -> void:
	if not _is_server() and peer != multiplayer.get_unique_id():
		return
	_states[peer] = {"xp": xp, "level": level_value, "points": points_value, "unlocked": unlocked.duplicate()}
	changed.emit(peer)


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
