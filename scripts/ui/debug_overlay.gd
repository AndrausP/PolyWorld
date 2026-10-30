class_name DebugOverlay
extends Label
## Tela de debug (F3): FPS, posição, seed e bioma atual.

var _player: Player
var _island: IslandGenerator


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE


func setup(player: Player, island: IslandGenerator) -> void:
	_player = player
	_island = island


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or _player == null:
		return
	var pos := _player.global_position
	var biome := _island.get_biome_at(pos)
	text = "PolyWorld\nFPS: %d\nXYZ: %.2f / %.2f / %.2f\nSeed: %d\nBioma: %s\nNadando: %s\nModo: %s" % [
		Engine.get_frames_per_second(),
		pos.x, pos.y, pos.z,
		_island.seed_value,
		biome.display_name if biome else "-",
		"sim" if _player.is_swimming else "não",
		_mode_text(),
	]


func _mode_text() -> String:
	if not DevMode.enabled:
		return "normal"
	return "dev (noclip)" if _player.is_noclip else ("dev (voando)" if _player.is_flying else "dev")
