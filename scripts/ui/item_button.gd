class_name ItemButton
extends Button
## Botão quadrado que mostra o ícone de um item (inventário criativo).

var item: ItemData


func setup(new_item: ItemData, slot_size: float) -> void:
	item = new_item
	custom_minimum_size = Vector2(slot_size, slot_size)
	focus_mode = FOCUS_NONE # Espaço/Enter não devem acionar o botão
	tooltip_text = item.display_name
	if not item.description.is_empty():
		tooltip_text += "\n" + item.description


func _draw() -> void:
	if item != null:
		ItemIcon.draw(self, item, Rect2(Vector2.ZERO, size).grow(-9.0))
