extends Control
## Mira no centro da tela, desenhada por código.

@export var arm_length := 8.0
@export var thickness := 2.0
@export var color := Color(1.0, 1.0, 1.0, 0.9)
@export var shadow_color := Color(0.0, 0.0, 0.0, 0.5)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	_draw_cross(center + Vector2.ONE, shadow_color)
	_draw_cross(center, color)


func _draw_cross(c: Vector2, col: Color) -> void:
	var t := thickness * 0.5
	draw_rect(Rect2(c.x - arm_length, c.y - t, arm_length * 2.0, thickness), col)
	draw_rect(Rect2(c.x - t, c.y - arm_length, thickness, arm_length - t), col)
	draw_rect(Rect2(c.x - t, c.y + t, thickness, arm_length - t), col)
