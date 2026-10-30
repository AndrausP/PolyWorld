extends Node
## Estado global do modo dev/criativo (autoload "DevMode").
## F4 liga/desliga. Também pode começar ligado com o argumento "--dev".

signal changed(enabled: bool)

var enabled := false: set = set_enabled


func _ready() -> void:
	if "--dev" in OS.get_cmdline_user_args():
		enabled = true


func set_enabled(value: bool) -> void:
	if value == enabled:
		return
	enabled = value
	print("Modo dev: %s" % ("ligado" if enabled else "desligado"))
	changed.emit(enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_dev_mode"):
		enabled = not enabled
