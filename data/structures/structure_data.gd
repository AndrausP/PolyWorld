class_name StructureData
extends Resource
## Peça modular com custo e volume de colisão.

@export var id: StringName = &""
@export var display_name: String = "Estrutura"
@export_multiline var description: String = ""
@export var size: Vector3 = Vector3(2.0, 2.0, 0.25)
@export var color: Color = Color(0.55, 0.38, 0.22)
@export var costs: Dictionary = {}
@export_range(0, 3) var tier: int = 0
@export var station: StringName = &""
@export_range(0, 1000) var xp: int = 8
