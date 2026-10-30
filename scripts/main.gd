extends Node3D
## Ponto de entrada: escolhe a seed, gera a ilha (em segundo plano), depois
## posiciona o jogador e liga o HUD.

@onready var _island: IslandGenerator = $IslandGenerator
@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD
@onready var _loading: LoadingScreen = $LoadingScreen


func _ready() -> void:
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.hide()
	_island.progress.connect(_loading.set_status)
	_island.generated.connect(_on_island_generated, CONNECT_ONE_SHOT)
	_island.generate(_resolve_seed())


func _on_island_generated(_seed_value: int) -> void:
	_player.water_level_at = _island.get_water_level_at
	_player.spawn_at(_island.find_spawn_point(), Vector3.ZERO)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_hud.setup(_player, _island)
	_hud.show()
	# Alguns quadros atrás da tela de carregamento para compilar os shaders.
	for i in 20:
		await get_tree().process_frame
	_loading.finish()


## Prioridade: argumento "--seed=N" na linha de comando > WorldConfig.world_seed.
## world_seed = 0 gera uma seed aleatória.
func _resolve_seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return arg.get_slice("=", 1).to_int()
	var seed_value := _island.config.world_seed
	if seed_value == 0:
		seed_value = randi()
	return seed_value
