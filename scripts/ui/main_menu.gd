class_name MainMenu
extends CanvasLayer
## Menu inicial feito em código: Solo, Hospedar, Entrar.

signal chosen(mode: int, address: String, port: int, player_name: String)

var _name_edit: LineEdit
var _addr_edit: LineEdit
var _port_edit: LineEdit
var _error: Label


func _ready() -> void:
	layer = 20
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.13, 0.19)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "PolyWorld"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "sobrevivência low-poly online"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.7, 0.8, 0.9)
	box.add_child(sub)
	_name_edit = _field(box, "Nome", "Jogador")
	_addr_edit = _field(box, "Endereço do servidor", "127.0.0.1")
	_port_edit = _field(box, "Porta", str(Net.DEFAULT_PORT))
	_button(box, "Jogar solo", func() -> void: _emit(Net.Mode.SINGLE))
	_button(box, "Hospedar partida", func() -> void: _emit(Net.Mode.HOST))
	_button(box, "Entrar em partida", func() -> void: _emit(Net.Mode.CLIENT))
	_error = Label.new()
	_error.modulate = Color(1, 0.5, 0.45)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_error)


func show_error(msg: String) -> void:
	_error.text = msg


func _field(parent: Control, label: String, value: String) -> LineEdit:
	var l := Label.new()
	l.text = label
	parent.add_child(l)
	var e := LineEdit.new()
	e.text = value
	parent.add_child(e)
	return e


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(cb)
	parent.add_child(b)


func _emit(mode: int) -> void:
	chosen.emit(mode, _addr_edit.text.strip_edges(), _port_edit.text.to_int(), _name_edit.text.strip_edges())
