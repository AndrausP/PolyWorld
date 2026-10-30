class_name Hud
extends CanvasLayer
## Liga o HUD ao jogador: barras reagem aos sinais de vida/fome e
## o nome do item selecionado aparece brevemente acima da hotbar.

@onready var _health_bar: StatBar = %HealthBar
@onready var _hunger_bar: StatBar = %HungerBar
@onready var _hotbar: Hotbar = %Hotbar
@onready var _item_name: Label = %ItemName
@onready var _debug: DebugOverlay = %DebugOverlay
@onready var _dev_tools: DevToolsUI = %DevTools

var _fade_tween: Tween


func setup(player: Player, island: IslandGenerator) -> void:
	player.health_changed.connect(_health_bar.set_values)
	player.hunger_changed.connect(_hunger_bar.set_values)
	_health_bar.set_values(player.health, player.max_health)
	_hunger_bar.set_values(player.hunger, player.max_hunger)
	_hotbar.selected_changed.connect(_on_hotbar_selected)
	_debug.setup(player, island)
	_dev_tools.setup(player, island, _hotbar)
	_on_hotbar_selected(_hotbar.selected_index, _hotbar.get_item(_hotbar.selected_index))


func _on_hotbar_selected(_index: int, item: ItemData) -> void:
	_item_name.text = item.display_name if item else ""
	_item_name.modulate.a = 1.0
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_interval(1.5)
	_fade_tween.tween_property(_item_name, "modulate:a", 0.0, 0.5)
