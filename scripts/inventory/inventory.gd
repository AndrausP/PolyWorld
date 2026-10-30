extends Node
## Inventário autoritativo por peer, com replicação de snapshots.

signal changed(peer: int)
signal hotbar_changed(peer: int)
signal hotbar_selected(index: int)

const SLOT_COUNT := 36
const HOTBAR_COUNT := 9
const ItemDatabaseScript = preload("res://scripts/items/item_database.gd")
const InventoryUIScript = preload("res://scenes/ui_inv/inventory_ui.gd")

var _item_data: Dictionary = {}
var _states: Dictionary = {}
var selected_hotbar_slot := 0
var _ui: CanvasLayer


func _ready() -> void:
	for item: ItemData in ItemDatabaseScript.load_all():
		_item_data[item.id] = item
	if multiplayer.peer_connected.is_connected(_on_peer_connected) == false:
		multiplayer.peer_connected.connect(_on_peer_connected)
	call_deferred("_create_ui")


func add(peer: int, item_id: StringName, amount: int) -> int:
	if not _is_server() or amount <= 0 or not _item_data.has(item_id):
		return maxi(amount, 0)
	var state := _state_for(peer)
	var slots: Array = state["slots"]
	var remainder := _add_to_slots(slots, item_id, amount)
	if remainder != amount:
		state["slots"] = slots
		_commit_state(peer)
	return remainder


func remove(peer: int, item_id: StringName, amount: int) -> bool:
	if not _is_server() or amount <= 0:
		return false
	var state := _state_for(peer)
	if _count_in_slots(state["slots"], item_id) < amount:
		return false
	_remove_from_slots(state["slots"], item_id, amount)
	_commit_state(peer)
	return true


func count(peer: int, item_id: StringName) -> int:
	if not _states.has(peer):
		return 0
	return _count_in_slots(_states[peer]["slots"], item_id)


func slot_snapshot(peer: int) -> Array:
	return _state_for(peer)["slots"].duplicate(true)


func item_data(item_id: StringName) -> ItemData:
	return _item_data.get(item_id) as ItemData


func transact(peer: int, costs: Dictionary, rewards: Dictionary) -> bool:
	if not _is_server():
		return false
	var state := _state_for(peer)
	var candidate: Array = state["slots"].duplicate(true)
	for raw_id: Variant in costs:
		var item_id := StringName(str(raw_id))
		var quantity := int(costs[raw_id])
		if quantity < 0 or _count_in_slots(candidate, item_id) < quantity:
			return false
		_remove_from_slots(candidate, item_id, quantity)
	for raw_id: Variant in rewards:
		var item_id := StringName(str(raw_id))
		var quantity := int(rewards[raw_id])
		if quantity < 0 or not _item_data.has(item_id):
			return false
		if _add_to_slots(candidate, item_id, quantity) > 0:
			return false
	state["slots"] = candidate
	_commit_state(peer)
	return true


func set_hotbar_slot(peer: int, slot: int, item_id: StringName) -> bool:
	if not _is_server() or slot < 0 or slot >= HOTBAR_COUNT:
		return false
	var state := _state_for(peer)
	if item_id != &"" and _count_in_slots(state["slots"], item_id) <= 0:
		return false
	state["hotbar"][slot] = item_id
	_commit_state(peer)
	return true


func assign_hotbar_slot(slot: int, item_id: StringName) -> bool:
	if _is_server():
		var peer := multiplayer.get_unique_id()
		if peer <= 0:
			peer = 1
		return set_hotbar_slot(peer, slot, item_id)
	_request_hotbar_assignment.rpc_id(1, slot, item_id)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_hotbar_assignment(slot: int, item_id: StringName) -> void:
	if not _is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer > 0:
		set_hotbar_slot(peer, slot, item_id)


func hotbar_snapshot(peer: int) -> Array:
	return _state_for(peer)["hotbar"].duplicate()


func select_hotbar_slot(index: int) -> void:
	selected_hotbar_slot = wrapi(index, 0, HOTBAR_COUNT)
	hotbar_selected.emit(selected_hotbar_slot)


func _state_for(peer: int) -> Dictionary:
	if not _states.has(peer):
		var slots: Array = []
		for _index in SLOT_COUNT:
			slots.append({"id": &"", "amount": 0})
		var hotbar: Array[StringName] = []
		hotbar.resize(HOTBAR_COUNT)
		_states[peer] = {"slots": slots, "hotbar": hotbar}
	return _states[peer]


func _add_to_slots(slots: Array, item_id: StringName, amount: int) -> int:
	var data := _item_data.get(item_id) as ItemData
	if data == null:
		return amount
	var remaining := amount
	for slot: Dictionary in slots:
		if slot["id"] == item_id and int(slot["amount"]) < data.max_stack:
			var moved: int = mini(remaining, data.max_stack - int(slot["amount"]))
			slot["amount"] = int(slot["amount"]) + moved
			remaining -= moved
			if remaining == 0:
				return 0
	for slot: Dictionary in slots:
		if slot["id"] == &"":
			var moved: int = mini(remaining, data.max_stack)
			slot["id"] = item_id
			slot["amount"] = moved
			remaining -= moved
			if remaining == 0:
				return 0
	return remaining


func _remove_from_slots(slots: Array, item_id: StringName, amount: int) -> void:
	var remaining := amount
	for slot: Dictionary in slots:
		if slot["id"] != item_id:
			continue
		var removed: int = mini(remaining, int(slot["amount"]))
		slot["amount"] = int(slot["amount"]) - removed
		remaining -= removed
		if int(slot["amount"]) == 0:
			slot["id"] = &""
		if remaining == 0:
			return


func _count_in_slots(slots: Array, item_id: StringName) -> int:
	var total := 0
	for slot: Dictionary in slots:
		if slot["id"] == item_id:
			total += int(slot["amount"])
	return total


func _commit_state(peer: int) -> void:
	var state := _state_for(peer)
	for index in HOTBAR_COUNT:
		var item_id: StringName = state["hotbar"][index]
		if item_id != &"" and _count_in_slots(state["slots"], item_id) == 0:
			state["hotbar"][index] = &""
	changed.emit(peer)
	hotbar_changed.emit(peer)
	if _is_server() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_sync_peer.rpc(peer, _serialize_slots(peer), _serialize_hotbar(peer))


func _serialize_slots(peer: int) -> Array:
	var serialized: Array = []
	for slot: Dictionary in _state_for(peer)["slots"]:
		serialized.append({"id": str(slot["id"]), "amount": int(slot["amount"])})
	return serialized


func _serialize_hotbar(peer: int) -> Array:
	var serialized: Array = []
	for item_id: StringName in _state_for(peer)["hotbar"]:
		serialized.append(str(item_id))
	return serialized


func _on_peer_connected(new_peer: int) -> void:
	if not _is_server():
		return
	for peer: Variant in _states:
		_rpc_sync_peer.rpc_id(new_peer, int(peer), _serialize_slots(int(peer)), _serialize_hotbar(int(peer)))


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_peer(peer: int, slots: Array, hotbar: Array) -> void:
	var converted_slots: Array = []
	for slot: Dictionary in slots:
		converted_slots.append({"id": StringName(str(slot.get("id", ""))), "amount": int(slot.get("amount", 0))})
	var converted_hotbar: Array[StringName] = []
	for item_id: Variant in hotbar:
		converted_hotbar.append(StringName(str(item_id)))
	var resized: Array = []
	for index in SLOT_COUNT:
		if index < converted_slots.size():
			resized.append(converted_slots[index])
		else:
			resized.append({"id": &"", "amount": 0})
	converted_hotbar.resize(HOTBAR_COUNT)
	_states[peer] = {"slots": resized, "hotbar": converted_hotbar}
	changed.emit(peer)
	hotbar_changed.emit(peer)


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _create_ui() -> void:
	if _ui != null or get_tree() == null:
		return
	_ui = InventoryUIScript.new()
	get_tree().root.add_child(_ui)


func toggle_ui() -> void:
	if _ui == null:
		return
	_ui.toggle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory") and not DevMode.enabled:
		toggle_ui()
		get_viewport().set_input_as_handled()
		return
	for index in HOTBAR_COUNT:
		if event.is_action_pressed("hotbar_%d" % (index + 1)):
			select_hotbar_slot(index)
			return
