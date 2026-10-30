class_name DevToolsUI
extends Control
## Interface do modo dev: indicador na tela, inventário criativo (E) e mapa (M).
## Abre/fecha os painéis e trava o jogador enquanto um deles está aberto.

@onready var _label: Label = $DevLabel
@onready var _inventory: CreativeInventory = $CreativeInventory
@onready var _map: WorldMap = $WorldMap

var _player: Player
var _island: IslandGenerator
var _hotbar: Hotbar


func setup(player: Player, island: IslandGenerator, hotbar: Hotbar) -> void:
	_player = player
	_island = island
	_hotbar = hotbar
	_inventory.populate(ItemDatabase.load_all())
	_inventory.item_picked.connect(func(item: ItemData) -> void: _hotbar.set_item(_hotbar.selected_index, item))
	_inventory.clear_requested.connect(_clear_hotbar)
	_map.setup(island, player)
	_map.teleport_requested.connect(_on_teleport_requested)
	_player.movement_mode_changed.connect(func(_f: bool, _n: bool) -> void: _update_label())
	DevMode.changed.connect(_on_dev_mode_changed)
	_on_dev_mode_changed(DevMode.enabled)


func _unhandled_input(event: InputEvent) -> void:
	if not DevMode.enabled:
		return
	if event.is_action_pressed("open_inventory"):
		_toggle_panel(_inventory)
	elif event.is_action_pressed("toggle_map"):
		_toggle_panel(_map)
	elif event.is_action_pressed("ui_cancel") and _is_panel_open():
		_close_panels()
	else:
		return
	get_viewport().set_input_as_handled()


func _toggle_panel(panel: Control) -> void:
	var was_open := panel.visible
	_close_panels()
	if was_open:
		return
	if panel == _map:
		_map.open()
	else:
		panel.show()
	_player.input_locked = true


func _close_panels() -> void:
	_inventory.hide()
	_map.hide()
	_player.input_locked = false


func _is_panel_open() -> bool:
	return _inventory.visible or _map.visible


func _on_dev_mode_changed(enabled: bool) -> void:
	visible = enabled
	if not enabled and _is_panel_open():
		_close_panels()
	_update_label()


func _on_teleport_requested(world_x: float, world_z: float) -> void:
	var ground := _island.height_map.get_height_at(world_x, world_z)
	var water := _island.get_water_level_at(Vector3(world_x, 0.0, world_z))
	_player.teleport_to(Vector3(world_x, maxf(ground, water) + 1.0, world_z))
	_close_panels()


func _clear_hotbar() -> void:
	for i in Hotbar.SLOT_COUNT:
		_hotbar.set_item(i, null)


func _update_label() -> void:
	var mode := "noclip" if _player.is_noclip else ("voando" if _player.is_flying else "a pé")
	_label.text = "MODO DEV (F4)  —  %s\n2× Espaço: voar  •  Ctrl: descer  •  Shift: rápido\nN: noclip  •  E: itens  •  M: mapa" % mode
