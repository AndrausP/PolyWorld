class_name WorldMap
extends Control
## Mapa da ilha visto de cima (modo dev). Mostra o jogador e a direção
## em que olha; clicar num ponto pede um teletransporte para lá.

signal teleport_requested(world_x: float, world_z: float)

## Fração da menor dimensão da tela ocupada pelo mapa.
@export var map_fraction := 0.85

var _island: IslandGenerator
var _player: Player
var _texture: Texture2D


func _ready() -> void:
	visible = false
	texture_filter = TEXTURE_FILTER_NEAREST


func setup(island: IslandGenerator, player: Player) -> void:
	_island = island
	_player = player
	_island.generated.connect(func(_seed: int) -> void: _texture = null)


## A imagem é gerada só na primeira abertura (custa ~100 ms).
func open() -> void:
	if _texture == null:
		_texture = MapImageBuilder.build(_island)
	show()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rect := _map_rect()
		if rect.has_point(event.position):
			var world := _map_to_world(event.position, rect)
			teleport_requested.emit(world.x, world.y)
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.6))
	if _texture == null:
		return
	var rect := _map_rect()
	draw_texture_rect(_texture, rect, false)
	draw_rect(rect.grow(2.0), Color(0.05, 0.05, 0.05), false, 4.0)
	_draw_player(rect)
	var font := ThemeDB.fallback_font
	var hint := "Mapa (seed %d)  —  clique para teletransportar  •  M ou ESC fecha" % _island.seed_value
	draw_string(font, Vector2(rect.position.x, rect.position.y - 10.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16)


## Seta vermelha na posição do jogador apontando para onde ele olha.
func _draw_player(rect: Rect2) -> void:
	var pos := _world_to_map(_player.global_position, rect)
	var forward := -_player.global_basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	var tip := pos + dir * 12.0
	var points := PackedVector2Array([tip, pos - dir * 6.0 + side * 7.0, pos - dir * 6.0 - side * 7.0])
	draw_colored_polygon(points, Color(0.95, 0.15, 0.1))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color.WHITE, 2.0)


func _map_rect() -> Rect2:
	var side := minf(size.x, size.y) * map_fraction
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func _world_extent() -> float:
	return _island.config.size_cells * _island.config.cell_size


## O mapa cobre a ilha inteira, centrada na origem; o topo da imagem é -Z.
func _world_to_map(world: Vector3, rect: Rect2) -> Vector2:
	var extent := _world_extent()
	var uv := Vector2(world.x, world.z) / extent + Vector2(0.5, 0.5)
	return rect.position + uv.clamp(Vector2.ZERO, Vector2.ONE) * rect.size


func _map_to_world(point: Vector2, rect: Rect2) -> Vector2:
	var uv := (point - rect.position) / rect.size
	return (uv - Vector2(0.5, 0.5)) * _world_extent()
