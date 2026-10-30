class_name Water
extends MeshInstance3D
## Plano de água grande no nível do mar. As ondas são feitas no shader
## (shaders/water.gdshader); aqui só se cria a malha subdividida.

@export var size := 4000.0
@export var subdivisions := 200


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func place_at(sea_level: float) -> void:
	position.y = sea_level
