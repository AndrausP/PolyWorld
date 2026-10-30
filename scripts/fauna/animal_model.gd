class_name AnimalModel
extends RefCounted
## Malha low-poly procedural estilizada: troncos afunilados com faces planas,
## olhos, orelhas, caudas e marcas por espécie. Cores vêm dos genes.
## Devolve um Node3D; "legs" em meta guarda as pernas para animar a caminhada.

static var _mesh_cache: Dictionary = {}


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


## Tronco de pirâmide ao longo de Z (traseira -> frente), normais planas.
## back/front = (largura, altura) das duas faces.
static func _frustum(back: Vector2, front: Vector2, length: float) -> ArrayMesh:
	var key := "%s|%s|%s" % [back, front, length]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var z0 := -length * 0.5
	var z1 := length * 0.5
	var b := back * 0.5
	var f := front * 0.5
	var v := [
		Vector3(-b.x, -b.y, z0), Vector3(b.x, -b.y, z0), Vector3(b.x, b.y, z0), Vector3(-b.x, b.y, z0),
		Vector3(-f.x, -f.y, z1), Vector3(f.x, -f.y, z1), Vector3(f.x, f.y, z1), Vector3(-f.x, f.y, z1),
	]
	var quads := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(v[q[i]])
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func _part(parent: Node3D, back: Vector2, front: Vector2, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _frustum(back, front, length)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return _part_rot(parent, Vector2(size.x, size.y), Vector2(size.x, size.y), size.z, pos, mat, rot)


static func _part_rot(parent: Node3D, back: Vector2, front: Vector2, length: float, pos: Vector3, mat: Material, rot: Vector3) -> MeshInstance3D:
	var mi := _part(parent, back, front, length, pos, mat)
	mi.rotation = rot
	return mi


static func build(sp: SpeciesData, genes: PackedFloat32Array) -> Node3D:
	var root := Node3D.new()
	var ca := sp.color_a.lerp(sp.color_b, genes[Genes.G.COLOR] * 0.55)
	var cb := sp.color_b.lerp(sp.color_a, genes[Genes.G.PATTERN] * 0.5)
	var mat_a := _mat(ca)
	var mat_b := _mat(cb)
	var legs: Array[Node3D] = []
	match sp.body:
		&"bird": _bird(root, mat_a, mat_b, legs)
		&"turtle": _turtle(root, mat_a, mat_b, legs)
		_: _quad(root, sp, mat_a, mat_b, genes, legs)
	root.set_meta("legs", legs)
	return root


static func _leg(parent: Node3D, pos: Vector3, h: float, w: float, mat: Material, foot: Material = null) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	# afunila para baixo: frustum ao longo de Z girado para o eixo Y
	var mi := _part(pivot, Vector2(w, w), Vector2(w * 0.7, w * 0.7), h, Vector3(0, -h * 0.5, 0), mat)
	mi.rotation.x = PI * 0.5   # Z -> Y: face "frente" aponta para baixo
	if foot != null:
		_box(pivot, Vector3(w * 0.9, h * 0.18, w * 1.3), Vector3(0, -h + h * 0.09, w * 0.15), foot)
	return pivot


static func _eyes(head: Node3D, x: float, y: float, z: float, size: float) -> void:
	var dark := _mat(Color("15181c"))
	for sx in [-1, 1]:
		_box(head, Vector3(size * 0.5, size, size), Vector3(sx * x, y, z), dark)


static func _quad(root: Node3D, sp: SpeciesData, a: Material, b: Material, genes: PackedFloat32Array, legs: Array[Node3D]) -> void:
	var id := sp.id
	var carn := sp.diet == SpeciesData.Diet.CARNIVORE
	var heavy := id == &"bear" or id == &"boar" or id == &"capybara"
	var tall := id == &"deer" or id == &"goat"
	var leg_h := 0.42 if tall else (0.3 if heavy else (0.26 if id == &"fox" else 0.3))
	if id == &"rabbit": leg_h = 0.2
	var wide := 0.5 if id == &"bear" else (0.44 if heavy else (0.34 if tall else 0.32))
	var body_l := 0.95 if id == &"bear" else (0.9 if heavy else (0.85 if tall else 0.72))
	var rump_h := 0.38 if not heavy else 0.5
	var chest_h := rump_h * (1.25 if id in [&"deer", &"bear", &"boar", &"wolf"] else 1.0)
	var y := leg_h + rump_h * 0.5 - 0.02

	# Tronco: costas em a, barriga em b.
	_part(root, Vector2(wide * 0.9, rump_h), Vector2(wide, chest_h), body_l, Vector3(0, y + (chest_h - rump_h) * 0.15, 0), a)
	_part(root, Vector2(wide * 0.8, rump_h * 0.45), Vector2(wide * 0.88, chest_h * 0.45), body_l * 0.82,
			Vector3(0, leg_h + rump_h * 0.1, 0.02), b)
	if id == &"bear":   # corcova
		_box(root, Vector3(wide * 0.9, 0.18, 0.4), Vector3(0, y + chest_h * 0.55, 0.18), a)
	if id == &"capybara":
		_box(root, Vector3(wide * 0.8, 0.1, 0.5), Vector3(0, y + rump_h * 0.5, -0.05), a)

	# Pescoço + cabeça.
	var neck_len := 0.34 if tall else 0.08
	var head_s := 0.4 if id == &"bear" else (0.34 if heavy else (0.3 if not tall else 0.26))
	var head_pos := Vector3(0, y + chest_h * 0.45 + (0.22 if tall else 0.05), body_l * 0.5 + neck_len * 0.55)
	if tall:
		_part_rot(root, Vector2(0.2, 0.24), Vector2(0.15, 0.17), neck_len + 0.15,
				Vector3(0, y + chest_h * 0.45 + 0.1, body_l * 0.5 + 0.05), a, Vector3(-0.7, 0, 0))
	var head := Node3D.new()
	head.position = head_pos
	root.add_child(head)
	var snout_len := head_s * (1.1 if carn or id == &"boar" else 0.75)
	_part(head, Vector2(head_s, head_s * 0.9), Vector2(head_s * 0.7, head_s * 0.7), head_s, Vector3.ZERO, a)
	_part(head, Vector2(head_s * 0.62, head_s * 0.5), Vector2(head_s * 0.4, head_s * 0.38), snout_len,
			Vector3(0, -head_s * 0.12, head_s * 0.5 + snout_len * 0.4), b)
	var nose := _mat(Color("1c1a1a"))
	_box(head, Vector3(head_s * 0.22, head_s * 0.16, head_s * 0.12), Vector3(0, -head_s * 0.05, head_s * 0.5 + snout_len * 0.9), nose)
	_eyes(head, head_s * 0.42, head_s * 0.15, head_s * 0.3, head_s * 0.16)

	# Orelhas por espécie.
	match id:
		&"rabbit":
			for sx in [-1, 1]:
				_part_rot(head, Vector2(0.07, 0.03), Vector2(0.05, 0.02), 0.34,
						Vector3(sx * 0.08, 0.28, -0.05), b, Vector3(-0.2, 0, sx * 0.15))
		&"wolf", &"fox":
			var h := 0.2 if id == &"fox" else 0.15
			for sx in [-1, 1]:
				_part_rot(head, Vector2(0.1, 0.03), Vector2(0.02, 0.02), h, Vector3(sx * head_s * 0.32, head_s * 0.62, -0.02), b, Vector3(-PI * 0.5 + 0.0, 0, 0))
		&"capybara", &"boar", &"bear":
			for sx in [-1, 1]:
				_box(head, Vector3(0.07, 0.08, 0.05), Vector3(sx * head_s * 0.4, head_s * 0.52, -0.05), b)
		_:
			for sx in [-1, 1]:
				_part_rot(head, Vector2(0.1, 0.03), Vector2(0.04, 0.02), 0.2,
						Vector3(sx * head_s * 0.62, head_s * 0.28, -0.04), b, Vector3(0, 0, sx * 0.9))
	# Chifres / presas.
	if id == &"deer":
		var antler := _mat(Color("d9c7a0"))
		for sx in [-1, 1]:
			_box(head, Vector3(0.04, 0.34, 0.04), Vector3(sx * 0.09, 0.3, -0.06), antler, Vector3(0.15, 0, -sx * 0.25))
			_box(head, Vector3(0.035, 0.18, 0.035), Vector3(sx * 0.17, 0.42, -0.02), antler, Vector3(0.4, 0, -sx * 0.7))
			_box(head, Vector3(0.035, 0.16, 0.035), Vector3(sx * 0.13, 0.28, 0.05), antler, Vector3(0.9, 0, -sx * 0.3))
	if id == &"goat":
		var horn := _mat(Color("c9b98e"))
		for sx in [-1, 1]:
			_box(head, Vector3(0.05, 0.26, 0.05), Vector3(sx * 0.08, 0.26, -0.12), horn, Vector3(-0.6, 0, sx * 0.1))
		_box(head, Vector3(0.06, 0.12, 0.06), Vector3(0, -0.18, head_s * 0.45), b)   # barbicha
	if id == &"boar":
		var tusk := _mat(Color("efe6cf"))
		for sx in [-1, 1]:
			_box(head, Vector3(0.035, 0.12, 0.035), Vector3(sx * head_s * 0.3, -head_s * 0.28, head_s * 0.78), tusk, Vector3(-0.3, 0, 0))

	# Cauda.
	var tail_y := y + rump_h * 0.3
	match id:
		&"fox":
			_part_rot(root, Vector2(0.14, 0.14), Vector2(0.2, 0.2), 0.5, Vector3(0, tail_y, -body_l * 0.5 - 0.22), a, Vector3(0.35, 0, 0))
			_box(root, Vector3(0.18, 0.18, 0.16), Vector3(0, tail_y - 0.08, -body_l * 0.5 - 0.5), _mat(Color("f4f1ea")), Vector3(0.35, 0, 0))
		&"wolf":
			_part_rot(root, Vector2(0.1, 0.1), Vector2(0.15, 0.15), 0.5, Vector3(0, tail_y - 0.05, -body_l * 0.5 - 0.2), a, Vector3(0.7, 0, 0))
		&"rabbit":
			_box(root, Vector3(0.14, 0.14, 0.14), Vector3(0, tail_y, -body_l * 0.5 - 0.05), _mat(Color("f4f1ea")))
		&"deer":
			_box(root, Vector3(0.1, 0.12, 0.1), Vector3(0, tail_y + 0.05, -body_l * 0.5 - 0.04), _mat(Color("f4f1ea")))
		&"capybara", &"bear":
			_box(root, Vector3(0.1, 0.1, 0.06), Vector3(0, tail_y, -body_l * 0.5 - 0.02), b)
		_:
			_part_rot(root, Vector2(0.07, 0.07), Vector2(0.04, 0.04), 0.28, Vector3(0, tail_y + 0.04, -body_l * 0.5 - 0.1), b, Vector3(-0.5, 0, 0))

	# Marcas: manchas nas costas conforme o gene de padrão (cervo sempre malhado).
	var spots := int(round((genes[Genes.G.PATTERN] - 0.6) / 0.8 * 5.0))
	if id == &"deer": spots = maxi(spots, 3)
	if id in [&"rabbit", &"goat", &"capybara", &"fox", &"wolf"] or id == &"deer":
		var rng := RandomNumberGenerator.new()
		rng.seed = int(genes[Genes.G.COLOR] * 1000.0) + int(genes[Genes.G.PATTERN] * 777.0)
		for i in clampi(spots, 0, 6):
			var sz := rng.randf_range(0.07, 0.13)
			_box(root, Vector3(sz, 0.03, sz * 1.2),
					Vector3(rng.randf_range(-wide * 0.3, wide * 0.3), y + rump_h * 0.5 + 0.005 + 0.02, rng.randf_range(-body_l * 0.35, body_l * 0.3)), b)
	if id == &"wolf" or id == &"bear":
		_box(root, Vector3(wide * 0.7, 0.05, body_l * 0.6), Vector3(0, y + chest_h * 0.5 + 0.015, 0), b)   # faixa nas costas

	# Pernas (dianteiras e traseiras; pé em b).
	var lx := wide * 0.36
	var lz := body_l * 0.5 - 0.14
	var lw := 0.2 if id == &"bear" else (0.17 if heavy else 0.11)
	var foot_mat: Material = nose if not (id in [&"fox", &"deer"]) else nose
	for z in [lz, -lz]:
		for x in [-lx, lx]:
			legs.append(_leg(root, Vector3(x, leg_h + 0.02, z), leg_h + 0.02, lw, a if x < 0 else b, foot_mat if id in [&"fox", &"wolf", &"deer", &"goat"] else null))


static func _bird(root: Node3D, a: Material, b: Material, legs: Array[Node3D]) -> void:
	var orange := _mat(Color("e8a33a"))
	var red := _mat(Color("c22c2c"))
	_part(root, Vector2(0.3, 0.3), Vector2(0.34, 0.36), 0.44, Vector3(0, 0.34, 0), a)
	_part_rot(root, Vector2(0.22, 0.04), Vector2(0.2, 0.16), 0.2, Vector3(0, 0.4, -0.3), b, Vector3(0.7, 0, 0))   # cauda
	_part(root, Vector2(0.12, 0.2), Vector2(0.16, 0.22), 0.18, Vector3(0, 0.56, 0.22), a)                       # pescoço
	var head := Node3D.new()
	head.position = Vector3(0, 0.66, 0.26)
	root.add_child(head)
	_box(head, Vector3(0.17, 0.17, 0.18), Vector3.ZERO, a)
	_part(head, Vector2(0.1, 0.06), Vector2(0.02, 0.02), 0.12, Vector3(0, -0.02, 0.14), orange)                # bico
	_part_rot(head, Vector2(0.04, 0.14), Vector2(0.04, 0.02), 0.14, Vector3(0, 0.14, 0), red, Vector3(0, 0, 0))   # crista
	_box(head, Vector3(0.06, 0.08, 0.04), Vector3(0, -0.1, 0.1), red)                                          # barbela
	_eyes(head, 0.09, 0.03, 0.04, 0.035)
	for sx in [-1, 1]:
		_part_rot(root, Vector2(0.05, 0.2), Vector2(0.05, 0.12), 0.3, Vector3(sx * 0.19, 0.35, -0.02), b, Vector3(0, 0, 0))
		legs.append(_leg(root, Vector3(sx * 0.08, 0.2, 0), 0.2, 0.04, orange, orange))


static func _turtle(root: Node3D, a: Material, b: Material, legs: Array[Node3D]) -> void:
	var plate := _mat(b.albedo_color.lightened(0.15))
	_part(root, Vector2(0.55, 0.12), Vector2(0.7, 0.14), 0.8, Vector3(0, 0.18, 0), a)                      # plastrão
	_part(root, Vector2(0.5, 0.16), Vector2(0.62, 0.18), 0.66, Vector3(0, 0.3, -0.02), b)                  # casco
	_part(root, Vector2(0.3, 0.1), Vector2(0.38, 0.1), 0.38, Vector3(0, 0.42, -0.02), plate)               # placa alta
	for i in 3:
		_box(root, Vector3(0.52 - i * 0.04, 0.03, 0.04), Vector3(0, 0.38 + i * 0.0, -0.2 + i * 0.2), a)    # sulcos
	var head := Node3D.new()
	head.position = Vector3(0, 0.26, 0.5)
	root.add_child(head)
	_part(head, Vector2(0.16, 0.14), Vector2(0.12, 0.12), 0.22, Vector3.ZERO, a)
	_eyes(head, 0.07, 0.04, 0.08, 0.035)
	_box(root, Vector3(0.06, 0.05, 0.14), Vector3(0, 0.2, -0.45), a)
	for z in [0.25, -0.25]:
		for x in [-0.3, 0.3]:
			legs.append(_leg(root, Vector3(x, 0.14, z), 0.14, 0.14, a))
