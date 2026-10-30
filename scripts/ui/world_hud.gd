class_name WorldHud
extends CanvasLayer
## Camada extra do HUD: relógio/estação, inspetor de animal (genética) e dicas.
## Não mexe no HUD principal; só lê Player, FaunaManager e WorldClock.

const SEASON_ICONS := ["Primavera", "Verão", "Outono", "Inverno"]
const SEASON_COLORS := [Color("8fd16a"), Color("ffd24a"), Color("ee8a3a"), Color("9fd3ff")]

var player: Player
var fauna: FaunaManager

var _clock: Label
var _info: PanelContainer
var _info_label: RichTextLabel
var _hint: Label
var _players: Label
var _aimed: Animal
var _acc := 0.0


func _ready() -> void:
	layer = 5
	_clock = Label.new()
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.position = Vector2(-230, 10)
	_clock.custom_minimum_size = Vector2(220, 0)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.add_theme_font_size_override("font_size", 18)
	_clock.add_theme_color_override("font_outline_color", Color.BLACK)
	_clock.add_theme_constant_override("outline_size", 6)
	add_child(_clock)

	_players = Label.new()
	_players.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_players.position = Vector2(-230, 62)
	_players.custom_minimum_size = Vector2(220, 0)
	_players.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_players.add_theme_color_override("font_outline_color", Color.BLACK)
	_players.add_theme_constant_override("outline_size", 5)
	add_child(_players)

	_info = PanelContainer.new()
	_info.set_anchors_preset(Control.PRESET_CENTER)
	_info.position = Vector2(30, 20)
	_info.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.12, 0.78)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	_info.add_theme_stylebox_override("panel", sb)
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.custom_minimum_size = Vector2(250, 0)
	_info_label.scroll_active = false
	_info.add_child(_info_label)
	add_child(_info)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-150, -118)
	_hint.custom_minimum_size = Vector2(300, 0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 5)
	add_child(_hint)


func _process(delta: float) -> void:
	var t := WorldClock.time_of_day * 24.0
	var s := WorldClock.season
	_clock.text = "%s · Dia %d · %02d:%02d" % [WorldClock.season_name(), WorldClock.day + 1, int(t), int(fmod(t, 1.0) * 60.0)]
	_clock.add_theme_color_override("font_color", SEASON_COLORS[s])
	_acc += delta
	if _acc < 0.1:
		return
	_acc = 0.0
	_update_players()
	_update_aim()


func _update_players() -> void:
	if not Net.is_online():
		_players.text = ""
		return
	var names: Array[String] = [Net.local_name + " (você)"]
	for peer in Net.player_names:
		names.append(Net.player_names[peer])
	_players.text = "Online: %d\n%s" % [names.size(), "\n".join(names)]


func _update_aim() -> void:
	_aimed = null
	_info.visible = false
	_hint.text = ""
	if player == null or fauna == null or not is_instance_valid(player):
		return
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * 9.0, 1 << 3)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var area := hit.collider as Node
	if area == null or not area.has_meta("animal_uid"):
		return
	_aimed = fauna.animals.get(area.get_meta("animal_uid"))
	if _aimed == null:
		return
	_info.visible = true
	_info_label.text = _describe(_aimed)
	if _aimed.species.tameable and _aimed.tamed_by == 0:
		_hint.text = "[T] oferecer comida (domar)"


func _describe(a: Animal) -> String:
	var sp := a.species
	var sex := "♀ Fêmea" if a.female else "♂ Macho"
	var stage := "adulto" if a.is_adult else "filhote"
	var txt := "[b]%s[/b]  [color=gray]%s · %s[/color]\n" % [sp.display_name, sex, stage]
	var owner_txt := ""
	if a.tamed_by != 0:
		owner_txt = "[color=#8fd16a]Domado[/color]"
		if Net.player_names.has(a.tamed_by):
			owner_txt += " por " + Net.player_names[a.tamed_by]
		txt += owner_txt + "\n"
	elif sp.tameable and a.tame_progress > 0.0:
		txt += "[color=#e8c34a]Domando %d%%[/color]\n" % int(a.tame_progress)
	if a.pregnant_until >= 0.0:
		txt += "[color=#ff9ad0]Prenhe[/color]\n"
	txt += "Idade: %.1f dias\n" % a.age_days
	for i in Genes.G.COLOR:
		txt += "%s  %s\n" % [Genes.NAMES[i].rpad(14), _stars(a.genes[i])]
	return txt


## 0.6..1.4 -> 1..5 estrelas.
func _stars(v: float) -> String:
	var n := clampi(roundi((v - 0.6) / 0.8 * 4.0) + 1, 1, 5)
	return "[color=#ffd24a]%s[/color][color=#555]%s[/color]" % ["★".repeat(n), "★".repeat(5 - n)]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		if _aimed != null and fauna != null:
			if Net.is_server():
				fauna.request_tame(_aimed.uid)
			else:
				fauna.request_tame.rpc_id(1, _aimed.uid)
