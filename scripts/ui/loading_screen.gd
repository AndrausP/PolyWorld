class_name LoadingScreen
extends CanvasLayer
## Tela exibida enquanto a ilha é gerada em segundo plano.

@onready var _status: Label = $Background/Center/VBox/Status


func set_status(message: String) -> void:
	_status.text = message


func finish() -> void:
	var tween := create_tween()
	tween.tween_property($Background, "modulate:a", 0.0, 0.4)
	tween.tween_callback(hide)
