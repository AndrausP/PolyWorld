class_name AnimalModel
extends RefCounted
## Malha low-poly procedural: corpo por caixas, cores vindas dos genes.
## Devolve um Node3D; "legs" em meta guarda pernas para animar a caminhada.


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
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
		_: _quad(root, sp, mat_a, mat_b, legs)
	root.set_meta("legs", legs)
	return root


static func _leg(parent: Node3D, pos: Vector3, h: float, w: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	_box(pivot, Vector3(w, h, w), Vector3(0, -h * 0.5, 0), mat)
	return pivot


static func _quad(root: Node3D, sp: SpeciesData, a: Material, b: Material, legs: Array[Node3D]) -> void:
	var carn := sp.diet == SpeciesData.Diet.CARNIVORE
	var big := sp.id == &"bear" or sp.id == &"boar"
	var leg_h := 0.28 if (sp.id == &"rabbit" or sp.id == &"capybara" or big) else 0.42
	if sp.id == &"fox": leg_h = 0.26
	var body_h := 0.34 if not big else 0.5
	var body_l := 0.8 if not big else 0.95
	_box(root, Vector3(0.38, body_h, body_l), Vector3(0, leg_h + body_h * 0.5, 0), a)
	_box(root, Vector3(0.3, 0.2, 0.5), Vector3(0, leg_h + body_h * 0.45, -0.08), b)  # barriga
	var head_y := leg_h + body_h * 0.8
	var neck_len := 0.25 if sp.id in [&"deer", &"goat"] else 0.0
	if neck_len > 0.0:
		head_y += 0.12
	var head := Node3D.new()
	head.position = Vector3(0, head_y, body_l * 0.5 + 0.1)
	root.add_child(head)
	var hs := 0.3 if not big else 0.4
	_box(head, Vector3(hs, hs * 0.9, hs * 1.1), Vector3.ZERO, a)
	_box(head, Vector3(hs * 0.55, hs * 0.45, hs * 0.55), Vector3(0, -hs * 0.15, hs * 0.7), b)  # focinho
	for sx in [-1, 1]:
		_box(head, Vector3(0.07, 0.16 if sp.id == &"rabbit" else 0.1, 0.06), Vector3(sx * hs * 0.35, hs * 0.65, -0.02), b)  # orelhas
	if sp.id == &"deer":
		for sx in [-1, 1]:
			_box(head, Vector3(0.04, 0.3, 0.04), Vector3(sx * 0.1, 0.35, -0.05), b)
	if sp.id == &"goat":
		for sx in [-1, 1]:
			_box(head, Vector3(0.05, 0.2, 0.05), Vector3(sx * 0.1, 0.25, -0.1), b)
	_box(root, Vector3(0.1, 0.1, 0.22 if carn else 0.12), Vector3(0, leg_h + body_h * 0.8, -body_l * 0.5 - 0.05), b)  # cauda
	var lx := 0.15
	var lz := body_l * 0.5 - 0.12
	var lw := 0.12 if not big else 0.18
	for z in [lz, -lz]:
		for x in [-lx, lx]:
			legs.append(_leg(root, Vector3(x, leg_h, z), leg_h, lw, b if (x > 0) else a))


static func _bird(root: Node3D, a: Material, b: Material, legs: Array[Node3D]) -> void:
	_box(root, Vector3(0.3, 0.3, 0.42), Vector3(0, 0.3, 0), a)
	_box(root, Vector3(0.2, 0.2, 0.2), Vector3(0, 0.55, 0.22), a)
	_box(root, Vector3(0.08, 0.06, 0.12), Vector3(0, 0.53, 0.38), _mat(Color("e8a33a")))
	_box(root, Vector3(0.05, 0.1, 0.1), Vector3(0, 0.68, 0.2), _mat(Color("c22c2c")))
	_box(root, Vector3(0.24, 0.22, 0.1), Vector3(0, 0.42, -0.3), b)
	for sx in [-1, 1]:
		_box(root, Vector3(0.05, 0.18, 0.28), Vector3(sx * 0.17, 0.32, 0), b)
		legs.append(_leg(root, Vector3(sx * 0.07, 0.17, 0), 0.17, 0.04, _mat(Color("e8a33a"))))


static func _turtle(root: Node3D, a: Material, b: Material, legs: Array[Node3D]) -> void:
	_box(root, Vector3(0.6, 0.22, 0.75), Vector3(0, 0.22, 0), b)
	_box(root, Vector3(0.45, 0.14, 0.55), Vector3(0, 0.38, 0), b)
	_box(root, Vector3(0.18, 0.14, 0.2), Vector3(0, 0.2, 0.45), a)
	for z in [0.25, -0.25]:
		for x in [-0.3, 0.3]:
			legs.append(_leg(root, Vector3(x, 0.12, z), 0.12, 0.12, a))
