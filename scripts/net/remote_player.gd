class_name RemotePlayer
extends Node3D
## Representação de outro jogador: corpo low-poly + etiqueta com o nome.
## No servidor também serve de "alvo" para a IA dos animais.

var peer := 0
var _target_pos := Vector3.ZERO
var last_update := 0.0
var has_state := false
var _target_yaw := 0.0
var _label: Label3D
var _head: Node3D
var _walk := 0.0
var _limbs: Array[Node3D] = []


func setup(peer_id: int, display_name: String) -> void:
	peer = peer_id
	name = "Remote_%d" % peer_id
	add_to_group("remote_players")
	var skin := _mat(Color("e0b48a"))
	var shirt := _mat(Color.from_hsv(fmod(peer_id * 0.37, 1.0), 0.55, 0.85))
	var pants := _mat(Color("3a4a6b"))
	_box(Vector3(0.5, 0.7, 0.28), Vector3(0, 1.05, 0), shirt)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.6, 0)
	add_child(_head)
	_box(Vector3(0.36, 0.36, 0.36), Vector3.ZERO, skin, _head)
	for sx in [-1, 1]:
		_limbs.append(_limb(Vector3(sx * 0.17, 0.7, 0), 0.7, 0.2, pants))
		_limbs.append(_limb(Vector3(sx * 0.36, 1.38, 0), 0.65, 0.16, shirt))
	_label = Label3D.new()
	_label.text = display_name
	_label.position = Vector3(0, 2.1, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.006
	_label.outline_size = 8
	add_child(_label)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _limb(pivot_pos: Vector3, h: float, w: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	add_child(pivot)
	_box(Vector3(w, h, w), Vector3(0, -h * 0.5, 0), mat, pivot)
	return pivot


func get_target() -> Vector3:
	return _target_pos


func set_state(pos: Vector3, yaw: float, pitch: float) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_head.rotation.x = pitch


func _process(delta: float) -> void:
	var moved := global_position.distance_to(_target_pos) > 0.03
	global_position = global_position.lerp(_target_pos, minf(delta * 14.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(delta * 14.0, 1.0))
	if moved:
		_walk += delta * 9.0
	for i in _limbs.size():
		var sw := sin(_walk + (PI if i % 2 == 0 else 0.0)) * 0.7 if moved else 0.0
		_limbs[i].rotation.x = lerpf(_limbs[i].rotation.x, sw, 0.3)


## Só no servidor: encaminha o dano para o dono do jogador.
func take_damage(amount: float) -> void:
	if multiplayer.is_server() and peer != 1:
		Net.rpc_damage.rpc_id(peer, amount)
