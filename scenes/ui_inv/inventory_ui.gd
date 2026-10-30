extends CanvasLayer
## Interface simples criada em GDScript, sem cena ou fragmento XML.

var _panel: PanelContainer
var _inventory_grid: GridContainer
var _recipe_list: VBoxContainer
var _structure_list: VBoxContainer
var _hotbar_row: HBoxContainer
var _status: Label
var _selected_item: StringName = &""
var _selected_hotbar := 0
var _is_open := false
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	_build_ui()
	Inventory.changed.connect(_on_inventory_changed)
	Inventory.hotbar_changed.connect(_on_inventory_changed)
	Inventory.hotbar_selected.connect(_on_hotbar_selected)
	Progression.changed.connect(_on_progression_changed)
	Crafting.crafted.connect(_on_crafted)
	Crafting.craft_failed.connect(_on_craft_failed)
	Building.placed.connect(_on_placed)
	Building.placement_failed.connect(_on_placement_failed)
	refresh()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_local_player_locked(true)
	_panel.visible = true
	refresh()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_panel.visible = false
	_set_local_player_locked(false)
	Input.mouse_mode = _previous_mouse_mode


func refresh() -> void:
	if not is_instance_valid(_panel):
		return
	_refresh_inventory()
	_refresh_hotbar()
	_refresh_recipes()
	_refresh_structures()
	_status.text = "Nível %d  ·  XP até o próximo: %d  ·  Pontos: %d" % [Progression.level(_local_peer()), Progression.xp_to_next(_local_peer()), Progression.points(_local_peer())]


func _build_ui() -> void:
	var background := Control.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(900.0, 570.0)
	_panel.size = Vector2(900.0, 570.0)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-450.0, -285.0)
	background.add_child(_panel)
	var layout := VBoxContainer.new()
	_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "Inventário e sobrevivência"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(860.0, 450.0)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	_build_inventory_tab(tabs)
	_build_crafting_tab(tabs)
	_build_building_tab(tabs)
	var status_row := HBoxContainer.new()
	layout.add_child(status_row)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_status)
	var assign_button := Button.new()
	assign_button.text = "Atribuir item selecionado"
	assign_button.pressed.connect(_assign_selected_item)
	status_row.add_child(assign_button)
	_hotbar_row = HBoxContainer.new()
	_hotbar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar_row.custom_minimum_size = Vector2(760.0, 48.0)
	_hotbar_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar_row.position = Vector2(-380.0, -60.0)
	_hotbar_row.size = Vector2(760.0, 48.0)
	background.add_child(_hotbar_row)
	_panel.visible = false


func _build_inventory_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Inventário"
	tabs.add_child(page)
	var hint := Label.new()
	hint.text = "Selecione um item e atribua-o ao atalho escolhido."
	page.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 6
	_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inventory_grid)
	for index in Inventory.SLOT_COUNT:
		var button := Button.new()
		button.custom_minimum_size = Vector2(124.0, 58.0)
		button.pressed.connect(_select_inventory_slot.bind(index))
		_inventory_grid.add_child(button)


func _build_crafting_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Crafting"
	tabs.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipe_list)


func _build_building_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Construção"
	tabs.add_child(page)
	var hint := Label.new()
	hint.text = "Escolha uma peça; clique no mundo para posicionar e confirme com o botão esquerdo."
	page.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	_structure_list = VBoxContainer.new()
	_structure_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_structure_list)
	var confirm_row := HBoxContainer.new()
	page.add_child(confirm_row)
	var confirm_button := Button.new()
	confirm_button.text = "Confirmar construção"
	confirm_button.pressed.connect(Building.confirm_preview)
	confirm_row.add_child(confirm_button)
	var cancel_button := Button.new()
	cancel_button.text = "Cancelar prévia"
	cancel_button.pressed.connect(Building.cancel_preview)
	confirm_row.add_child(cancel_button)


func _refresh_inventory() -> void:
	if _inventory_grid == null:
		return
	var slots := Inventory.slot_snapshot(_local_peer())
	for index in _inventory_grid.get_child_count():
		var button := _inventory_grid.get_child(index) as Button
		var slot: Dictionary = slots[index]
		var item_id := StringName(str(slot["id"]))
		var amount := int(slot["amount"])
		if item_id == &"":
			button.text = "Vazio"
		else:
			var data := Inventory.item_data(item_id)
			button.text = "%s\n× %d" % [data.display_name if data != null else str(item_id), amount]
		button.modulate = Color(1.0, 0.9, 0.55) if item_id == _selected_item else Color.WHITE


func _refresh_hotbar() -> void:
	if _hotbar_row == null:
		return
	for child: Node in _hotbar_row.get_children():
		child.queue_free()
	var slots := Inventory.hotbar_snapshot(_local_peer())
	for index in Inventory.HOTBAR_COUNT:
		var item_id := StringName(str(slots[index]))
		var label := "—"
		if item_id != &"":
			var data := Inventory.item_data(item_id)
			label = data.display_name if data != null else str(item_id)
			label = "%s x%d" % [label, Inventory.count(_local_peer(), item_id)]
		var button := Button.new()
		button.custom_minimum_size = Vector2(82.0, 42.0)
		button.text = "%d: %s" % [index + 1, label]
		button.modulate = Color(0.7, 1.0, 0.7) if index == _selected_hotbar else Color.WHITE
		button.pressed.connect(_on_hotbar_slot_pressed.bind(index))
		_hotbar_row.add_child(button)


func _refresh_recipes() -> void:
	if _recipe_list == null:
		return
	for child: Node in _recipe_list.get_children():
		child.queue_free()
	for recipe in Crafting.recipe_list():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s  ·  %s" % [recipe.display_name, _recipe_summary(recipe)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		if Progression.is_unlocked(_local_peer(), recipe.id):
			button.text = "Criar"
			button.disabled = not Crafting.can_craft(_local_peer(), recipe.id)
			button.pressed.connect(Crafting.request_craft.bind(recipe.id))
		else:
			button.text = "Desbloquear (%d)" % recipe.unlock_cost
			button.disabled = not Progression.can_unlock(_local_peer(), recipe.id)
			button.pressed.connect(_unlock_recipe.bind(recipe.id))
		row.add_child(button)
		_recipe_list.add_child(row)


func _refresh_structures() -> void:
	if _structure_list == null:
		return
	for child: Node in _structure_list.get_children():
		child.queue_free()
	for structure in Building.structure_list():
		var row := HBoxContainer.new()
		var label := Label.new()
		var kit_id := StringName("%s_kit" % str(structure.id))
		if structure.id == &"window_wall":
			kit_id = &"window_kit"
		var kit_data := Inventory.item_data(kit_id)
		var kit_name := kit_data.display_name if kit_data != null else str(kit_id)
		label.text = "%s - %s x1 or %s" % [structure.display_name, kit_name, _cost_summary(structure.costs)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.text = "Pré-visualizar"
		button.pressed.connect(_begin_preview.bind(structure.id))
		row.add_child(button)
		_structure_list.add_child(row)


func _select_inventory_slot(index: int) -> void:
	var slots := Inventory.slot_snapshot(_local_peer())
	_selected_item = StringName(str(slots[index]["id"]))
	refresh()


func _assign_selected_item() -> void:
	if _selected_item == &"":
		return
	if Inventory.assign_hotbar_slot(_selected_hotbar, _selected_item):
		_status.text = "Item atribuído ao atalho %d." % (_selected_hotbar + 1)
	else:
		_status.text = "Não foi possível atribuir esse item."


func _on_hotbar_slot_pressed(index: int) -> void:
	_selected_hotbar = index
	Inventory.select_hotbar_slot(index)
	_refresh_hotbar()


func _on_hotbar_selected(index: int) -> void:
	_selected_hotbar = index
	_refresh_hotbar()


func _unlock_recipe(recipe_id: StringName) -> void:
	if not Progression.unlock_recipe(_local_peer(), recipe_id):
		_status.text = "A receita exige mais pontos, nível ou pré-requisitos."
	refresh()


func _begin_preview(structure_id: StringName) -> void:
	if not Building.begin_preview(structure_id):
		_status.text = "Não foi possível iniciar a prévia sem uma câmera ativa."
	else:
		_status.text = "Prévia ativa: mova a mira até uma superfície válida."


func _recipe_summary(recipe) -> String:
	var parts: PackedStringArray = []
	for raw_id: Variant in recipe.inputs:
		parts.append("%s × %d" % [str(raw_id), int(recipe.inputs[raw_id])])
	return ", ".join(parts)


func _cost_summary(costs: Dictionary) -> String:
	var parts: PackedStringArray = []
	for raw_id: Variant in costs:
		parts.append("%s × %d" % [str(raw_id), int(costs[raw_id])])
	return ", ".join(parts)


func _local_peer() -> int:
	var peer := multiplayer.get_unique_id()
	return peer if peer > 0 else 1


func _set_local_player_locked(locked: bool) -> void:
	for player: Node in get_tree().get_nodes_in_group("local_player"):
		player.set("input_locked", locked)


func _on_inventory_changed(peer: int) -> void:
	if peer == _local_peer():
		refresh()


func _on_progression_changed(peer: int) -> void:
	if peer == _local_peer():
		refresh()


func _on_crafted(peer: int, _recipe_id: StringName) -> void:
	if peer == _local_peer():
		_status.text = "Receita criada."
		refresh()


func _on_craft_failed(peer: int, _recipe_id: StringName, reason: String) -> void:
	if peer == _local_peer():
		_status.text = reason


func _on_placement_failed(peer: int, _structure_id: StringName, reason: String) -> void:
	if peer == _local_peer():
		_status.text = reason


func _on_placed(peer: int, structure_id: StringName, _transform: Transform3D) -> void:
	if peer == _local_peer():
		var structure: Variant = Building.get_structure(structure_id)
		_status.text = "%s colocada." % (structure.display_name if structure != null else str(structure_id))


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
