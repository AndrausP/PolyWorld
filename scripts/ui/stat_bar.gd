class_name StatBar
extends Control
## Fileira de ícones (corações ou coxinhas) estilo Minecraft.
## Cada ícone vale (max_value / icon_count) pontos e pode estar cheio, meio ou vazio.

enum IconType { HEART, HUNGER }

@export var icon_type: IconType = IconType.HEART
@export var icon_count := 10
@export var pixel_size := 2.0
## Espaço entre ícones, em pixels do ícone.
@export var spacing := 1
## Se true, o primeiro ícone fica à direita (como a fome no Minecraft).
@export var right_to_left := false

var value := 20.0
var max_value := 20.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var rows := _rows()
	custom_minimum_size = Vector2(icon_count * (rows[0].length() + spacing), rows.size()) * pixel_size


## Conectado aos sinais do Player (health_changed / hunger_changed).
func set_values(current: float, maximum: float) -> void:
	value = current
	max_value = maximum
	queue_redraw()


func _draw() -> void:
	var rows := _rows()
	var per_icon := max_value / icon_count
	var icon_width: int = rows[0].length()
	var step := (icon_width + spacing) * pixel_size
	for i in icon_count:
		var slot := icon_count - 1 - i if right_to_left else i
		var fill := clampf((value - i * per_icon) / per_icon, 0.0, 1.0)
		fill = 1.0 if fill >= 0.75 else (0.5 if fill >= 0.25 else 0.0)
		var full := PixelIcons.HEART_FULL if icon_type == IconType.HEART else PixelIcons.HUNGER_FULL
		var empty := PixelIcons.HEART_EMPTY if icon_type == IconType.HEART else PixelIcons.HUNGER_EMPTY
		PixelIcons.draw_icon(self, rows, full, empty, Vector2(slot * step, 0.0), pixel_size, fill, right_to_left)


func _rows() -> Array:
	return PixelIcons.HEART if icon_type == IconType.HEART else PixelIcons.HUNGER
