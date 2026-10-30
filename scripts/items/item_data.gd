class_name ItemData
extends Resource
## Definição de um item. Cada item é um .tres em data/items/.

@export var id: StringName = &""
@export var display_name: String = "Item"
@export_multiline var description: String = ""
## Ícone opcional. Sem textura, o HUD desenha um bloco com "icon_color".
@export var icon: Texture2D
@export var icon_color: Color = Color.WHITE
@export_range(1, 999) var max_stack: int = 64
