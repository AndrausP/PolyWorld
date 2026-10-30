class_name VegetationSpawner
extends Node3D
## Transforma o resultado do VegetationPlacer em nós: um MultiMeshInstance3D por
## grupo (chunk + tipo + variante), com distância de visão própria, e um corpo
## estático com as colisões de troncos e pedras.


func build(placer: VegetationPlacer, library: VegetationLibrary) -> void:
	_clear()
	var total := 0
	for group: VegetationPlacer.Group in placer.groups:
		var entry := library.entries[group.entry_id]
		var mesh := library.get_mesh(group.entry_id, group.variant)
		if mesh == null:
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = group.data.size() / 12
		multimesh.buffer = PackedFloat32Array(group.data)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.position = group.center
		instance.visibility_range_end = entry.view_distance
		instance.visibility_range_end_margin = 8.0
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if entry.cast_shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		total += multimesh.instance_count
	_build_collision(placer.colliders)
	print("Vegetação: %d instâncias em %d grupos, %d colisões" % [total, placer.groups.size(), placer.colliders.size()])


func _clear() -> void:
	for child in get_children():
		child.queue_free()


func _build_collision(colliders: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "VegetationBody"
	add_child(body)
	var trunks := {} # um CylinderShape3D compartilhado por entrada
	for item: Array in colliders:
		var pos: Vector3 = item[0]
		var entry: VegetationEntry = item[1]
		var s: float = item[2]
		var shape: Shape3D
		var offset := Vector3.ZERO
		if entry.collision_is_sphere:
			var sphere := SphereShape3D.new()
			sphere.radius = entry.collision_radius * s
			shape = sphere
			offset.y = entry.collision_radius * s * 0.3
		else:
			if not trunks.has(entry):
				var cylinder := CylinderShape3D.new()
				cylinder.radius = entry.collision_radius
				cylinder.height = entry.collision_height
				trunks[entry] = cylinder
			shape = trunks[entry]
			offset.y = entry.collision_height * 0.5
		var owner_id := body.create_shape_owner(body)
		body.shape_owner_add_shape(owner_id, shape)
		body.shape_owner_set_transform(owner_id, Transform3D(Basis.IDENTITY, pos + offset))
