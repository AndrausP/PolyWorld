extends Node
## Snap em grade, preview local e colocação validada no servidor.

signal placed(peer: int, structure_id: StringName, transform: Transform3D)
signal placement_failed(peer: int, structure_id: StringName, reason: String)

const STRUCTURES_DIR := "res://data/structures/"
const GRID_SIZE := 2.0
var _structures: Dictionary = {}
var _preview: MeshInstance3D
var _preview_camera: Camera3D
var _preview_id: StringName = &""
var _preview_transform := Transform3D.IDENTITY


func _ready() -> void:
	for file: String in ResourceLoader.list_directory(STRUCTURES_DIR):
		if not file.ends_with(".tres") and not file.ends_with(".res"):
			continue
		var structure: Variant = load(STRUCTURES_DIR + file)
		if structure != null and structure.id != &"":
			_structures[structure.id] = structure


func get_structure(structure_id: StringName) -> Variant:
	return _structures.get(structure_id)


func structure_list() -> Array:
	var result: Array = []
	for structure: Variant in _structures.values():
		result.append(structure)
	result.sort_custom(func(a, b) -> bool: return a.display_name < b.display_name)
	return result


func snap_transform(value: Transform3D) -> Transform3D:
	var snapped := value
	snapped.origin.x = round(value.origin.x / GRID_SIZE) * GRID_SIZE
	snapped.origin.z = round(value.origin.z / GRID_SIZE) * GRID_SIZE
	var yaw := value.basis.get_euler().y
	var quarter_turn: float = round(yaw / (PI * 0.5)) * (PI * 0.5)
	snapped.basis = Basis.from_euler(Vector3(0.0, quarter_turn, 0.0))
	return snapped


func begin_preview(structure_id: StringName, camera: Camera3D = null) -> bool:
	var structure: Variant = get_structure(structure_id)
	if structure == null or get_tree().current_scene == null:
		return false
	cancel_preview()
	_preview_id = structure_id
	_preview_camera = camera if camera != null else get_viewport().get_camera_3d()
	if _preview_camera == null:
		_preview_id = &""
		return false
	_preview = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = structure.size
	_preview.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(structure.color.r, structure.color.g, structure.color.b, 0.38)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	_preview.material_override = material
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	get_tree().current_scene.add_child(_preview)
	_preview_transform = Transform3D.IDENTITY
	return true


func confirm_preview() -> void:
	if _preview_id == &"" or _preview == null or not _preview.visible:
		return
	request_place(_preview_id, _preview_transform)
	cancel_preview()


func cancel_preview() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	_preview_id = &""
	_preview_camera = null


func _process(_delta: float) -> void:
	if _preview == null or not is_instance_valid(_preview):
		return
	if _preview_camera == null or not is_instance_valid(_preview_camera):
		_preview_camera = get_viewport().get_camera_3d()
	if _preview_camera == null:
		_preview.visible = false
		return
	var origin := _preview_camera.global_position
	var direction := -_preview_camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 80.0)
	var hit := _preview_camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_preview.visible = false
		return
	_preview_transform = snap_transform(Transform3D(Basis(), hit["position"]))
	var ground_ray := PhysicsRayQueryParameters3D.create(
		_preview_transform.origin + Vector3.UP * 8.0,
		_preview_transform.origin - Vector3.UP * 8.0
	)
	var ground_hit := _preview_camera.get_world_3d().direct_space_state.intersect_ray(ground_ray)
	if not ground_hit.is_empty():
		_preview_transform.origin.y = ground_hit["position"].y
	_preview.global_transform = Transform3D(_preview_transform.basis, _preview_transform.origin + Vector3.UP * (get_structure(_preview_id).size.y * 0.5))
	_preview.visible = _has_material_under_preview(_preview_transform, _preview_id)


@rpc("any_peer", "call_remote", "reliable")
func request_place(structure_id: StringName, requested_transform: Transform3D) -> void:
	if not _is_server():
		request_place.rpc_id(1, structure_id, requested_transform)
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer <= 0:
		peer = 1
	var structure: Variant = get_structure(structure_id)
	if structure == null:
		_send_placement_result(peer, structure_id, requested_transform, false, "Peca nao encontrada.")
		placement_failed.emit(peer, structure_id, "Peça inexistente.")
		return
	if structure.tier > floori(float(Progression.level(peer) - 1) / 2.0):
		_send_placement_result(peer, structure_id, requested_transform, false, "Nivel insuficiente.")
		placement_failed.emit(peer, structure_id, "Nível insuficiente.")
		return
	var snapped := snap_transform(requested_transform)
	if not _validate_placement(peer, structure, snapped):
		_send_placement_result(peer, structure_id, snapped, false, "Terreno, colisao ou reivindicacao invalida.")
		placement_failed.emit(peer, structure_id, "Terreno, colisão ou reivindicação inválida.")
		return
	if not Inventory.transact(peer, _placement_costs(peer, structure), {}):
		_send_placement_result(peer, structure_id, snapped, false, "Materiais insuficientes.")
		placement_failed.emit(peer, structure_id, "Materiais insuficientes.")
		return
	_spawn_structure(structure, snapped, peer)
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_spawn_structure.rpc(structure_id, snapped, peer)
	Progression.add_xp(peer, structure.xp)
	_send_placement_result(peer, structure_id, snapped, true, "")
	placed.emit(peer, structure_id, snapped)


func _validate_placement(peer: int, structure: Variant, value: Transform3D) -> bool:
	if not is_finite(value.origin.x) or not is_finite(value.origin.y) or not is_finite(value.origin.z):
		return false
	if not _has_material_under_preview(value, structure.id):
		return false
	if not _claim_allows(peer, value.origin):
		return false
	var world := get_viewport().get_world_3d()
	if world == null:
		return false
	var ray := PhysicsRayQueryParameters3D.create(value.origin + Vector3.UP * 8.0, value.origin - Vector3.UP * 8.0)
	var ground_hit := world.direct_space_state.intersect_ray(ray)
	if ground_hit.is_empty() or not _is_terrain_collider(ground_hit.get("collider")):
		return false
	if absf(float(ground_hit["position"].y) - value.origin.y) > 0.75:
		return false
	var query_shape := BoxShape3D.new()
	query_shape.size = Vector3(maxf(structure.size.x - 0.08, 0.05), maxf(structure.size.y - 0.08, 0.05), maxf(structure.size.z - 0.08, 0.05))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	query.transform = Transform3D(value.basis, value.origin + Vector3.UP * (structure.size.y * 0.5 + 0.06))
	query.collide_with_areas = false
	var collider: Variant = ground_hit.get("collider")
	if collider is CollisionObject3D:
		query.exclude = [collider.get_rid()]
	return world.direct_space_state.intersect_shape(query, 1).is_empty()


func _has_material_under_preview(value: Transform3D, structure_id: StringName) -> bool:
	var structure: Variant = get_structure(structure_id)
	if structure == null:
		return false
	var world := get_viewport().get_world_3d()
	if world == null:
		return false
	var ray := PhysicsRayQueryParameters3D.create(value.origin + Vector3.UP * 8.0, value.origin - Vector3.UP * 8.0)
	var hit := world.direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and _is_terrain_collider(hit.get("collider"))


func _is_terrain_collider(collider: Variant) -> bool:
	if not collider is Node:
		return false
	var node := collider as Node
	while node != null:
		if node.is_in_group("build_terrain") or node.name == "TerrainBody":
			return true
		node = node.get_parent()
	return false


func _placement_costs(peer: int, structure: Variant) -> Dictionary:
	var kit_id := StringName("%s_kit" % str(structure.id))
	if structure.id == &"window_wall":
		kit_id = &"window_kit"
	if Inventory.count(peer, kit_id) > 0:
		return {kit_id: 1}
	return structure.costs


func _send_placement_result(peer: int, structure_id: StringName, value: Transform3D, succeeded: bool, reason: String) -> void:
	if peer != 1 and multiplayer.has_multiplayer_peer():
		_rpc_placement_result.rpc_id(peer, peer, structure_id, value, succeeded, reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_placement_result(peer: int, structure_id: StringName, value: Transform3D, succeeded: bool, reason: String) -> void:
	if succeeded:
		placed.emit(peer, structure_id, value)
	else:
		placement_failed.emit(peer, structure_id, reason)


func _claim_allows(peer: int, position: Vector3) -> bool:
	var claims := get_tree().get_nodes_in_group("land_claim")
	if claims.is_empty():
		return true
	for claim: Node in claims:
		if claim.has_method("can_build_at") and bool(claim.call("can_build_at", peer, position)):
			return true
	return false


func _spawn_structure(structure: Variant, value: Transform3D, peer: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var root := Node3D.new()
	root.name = "%s_%d" % [str(structure.id), peer]
	root.global_transform = Transform3D(value.basis, value.origin + Vector3.UP * (structure.size.y * 0.5))
	var body := StaticBody3D.new()
	root.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = structure.size
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = structure.color
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = structure.size
	collision.shape = shape
	body.add_child(collision)
	if structure.station != &"":
		body.add_to_group("crafting_station")
		body.set_meta("station_id", structure.station)
	scene.add_child(root)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_structure(structure_id: StringName, value: Transform3D, peer: int) -> void:
	var structure: Variant = get_structure(structure_id)
	if structure != null:
		_spawn_structure(structure, value, peer)


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _unhandled_input(event: InputEvent) -> void:
	if _preview == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		confirm_preview()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_preview()
		get_viewport().set_input_as_handled()
