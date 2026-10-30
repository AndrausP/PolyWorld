class_name Hotbar
extends Control
## Barra de atalhos com 9 slots. Seleção pela roda do mouse ou teclas 1-9.

signal selected_changed(index: int, item: ItemData)

const SLOT_COUNT := 9

@export var slot_size := 44.0
## Itens iniciais (de teste). Slots além do tamanho do array ficam vazios.
@export var items: Array[ItemData] = []

var selected_index := 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(slot_size * SLOT_COUNT, slot_size)
	items.resize(SLOT_COUNT) # slots extras ficam vazios (null)


func get_item(index: int) -> ItemData:
	return items[index]


## Coloca um item num slot (usado pelo inventário criativo).
func set_item(index: int, item: ItemData) -> void:
	items[index] = item
	queue_redraw()
	if index == selected_index:
		selected_changed.emit(selected_index, item)


func select(index: int) -> void:
	var new_index := wrapi(index, 0, SLOT_COUNT)
	if new_index == selected_index:
		return
	selected_index = new_index
	queue_redraw()
	selected_changed.emit(selected_index, get_item(selected_index))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select(selected_index - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select(selected_index + 1)
		return
	for i in SLOT_COUNT:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select(i)
			return


func _draw() -> void:
	for i in SLOT_COUNT:
		var rect := _slot_rect(i)
		draw_rect(rect, Color(0.08, 0.08, 0.08, 0.6))
		draw_rect(rect.grow(-1.0), Color(0.55, 0.55, 0.55, 0.9), false, 2.0)
		var item := get_item(i)
		if item != null:
			ItemIcon.draw(self, item, rect.grow(-10.0))
	# Destaque do slot selecionado por cima dos vizinhos.
	var selected := _slot_rect(selected_index).grow(2.0)
	draw_rect(selected, Color(0.0, 0.0, 0.0, 0.8), false, 5.0)
	draw_rect(selected, Color.WHITE, false, 3.0)


func _slot_rect(index: int) -> Rect2:
	return Rect2(Vector2(index * slot_size, 0.0), Vector2(slot_size, slot_size))

