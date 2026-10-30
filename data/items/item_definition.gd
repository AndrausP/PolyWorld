class_name ItemDefinition
extends ItemData
## Campos de gameplay adicionais, mantidos nos diretórios do Codex.

@export_range(0, 3) var tier: int = 0
@export var category: StringName = &"material"
@export var food_value: float = 0.0
@export var tool_type: StringName = &""
@export_range(0.0, 9999.0, 0.1) var damage: float = 0.0
@export_range(0, 9999) var durability: int = 0
