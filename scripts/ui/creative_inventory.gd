class_name CreativeInventory
extends PanelContainer
## Inventário criativo (modo dev): grade com todos os itens do jogo.
## Clicar num item coloca-o no slot selecionado da hotbar.

signal item_picked(item: ItemData)
signal clear_requested

@export var slot_size := 48.0

@onready var _grid: GridContainer = $Margin/VBox/Grid
@onready var _clear_button: Button = $Margin/VBox/ClearButton


func _ready() -> void:
	visible = false
	_clear_button.focus_mode = FOCUS_NONE
	_clear_button.pressed.connect(clear_requested.emit)


func populate(items: Array[ItemData]) -> void:
	for child in _grid.get_children():
		child.queue_free()
	for item in items:
		var button := ItemButton.new()
		button.setup(item, slot_size)
		button.pressed.connect(item_picked.emit.bind(item))
		_grid.add_child(button)
