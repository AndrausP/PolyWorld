class_name RecipeData
extends Resource
## Receita de crafting serializada em data/recipes/.

@export var id: StringName = &""
@export var display_name: String = "Receita"
@export_multiline var description: String = ""
@export var inputs: Dictionary = {}
@export var outputs: Dictionary = {}
@export var station: StringName = &""
@export_range(0, 3) var tier: int = 0
@export_range(0, 10000) var xp: int = 0
@export_range(1, 100) var unlock_level: int = 1
@export_range(0, 10) var unlock_cost: int = 0
@export var prerequisites: Array[StringName] = []
