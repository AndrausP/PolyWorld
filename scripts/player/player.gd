class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa: andar, correr, pular, nadar e olhar com o mouse.
## No modo dev também voa (2x Espaço) e atravessa o terreno (noclip).
## Guarda vida e fome; o HUD reage aos sinais abaixo.

signal health_changed(current: float, maximum: float)
signal hunger_changed(current: float, maximum: float)
signal movement_mode_changed(flying: bool, noclip: bool)

const DOUBLE_TAP_MS := 300

@export_group("Movimento")
@export var walk_speed := 4.5
@export var sprint_speed := 7.5
@export var jump_velocity := 5.2
@export var ground_acceleration := 14.0
@export var air_acceleration := 3.0
@export var mouse_sensitivity := 0.0025

@export_group("Nado")
@export var swim_speed := 2.6
@export var swim_up_acceleration := 9.0
## Profundidade dos pés a partir da qual o jogador passa a nadar.
@export var swim_start_depth := 1.0
## Profundidade dos pés em que o jogador flutua parado (cabeça fora d'água).
@export var float_depth := 1.35
@export var buoyancy := 14.0
@export var water_drag := 2.5

@export_group("Voo (modo dev)")
@export var fly_speed := 10.0
## Multiplicador de velocidade com Shift durante o voo.
@export var fly_fast_multiplier := 3.0
@export var fly_acceleration := 8.0

@export_group("Status")
@export var max_health := 20.0
@export var max_hunger := 20.0

var health := 20.0: set = set_health
var hunger := 20.0: set = set_hunger
## Função que devolve o nível da água (mar, rio ou lago) acima de uma posição.
## Definida pelo main a partir do IslandGenerator.
var water_level_at: Callable = func(_pos: Vector3) -> float: return 0.0
var is_swimming := false
var is_flying := false
var is_noclip := false
## Quando true (menu aberto), ignora movimento/olhar e libera o mouse.
var input_locked := false: set = set_input_locked

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _last_jump_ms := -1000

@onready var _head: Node3D = $Head
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	health = max_health
	hunger = max_hunger
	_capture_mouse(true)
	DevMode.changed.connect(_on_dev_mode_changed)


func set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)


## Futuro: um sistema de metabolismo chamará isto para reduzir a fome com o tempo.
func set_hunger(value: float) -> void:
	hunger = clampf(value, 0.0, max_hunger)
	hunger_changed.emit(hunger, max_hunger)


func set_flying(value: bool) -> void:
	is_flying = value
	if not value:
		is_noclip = false
		_collision.disabled = false
	else:
		velocity.y = 0.0 # começa o voo parado na vertical
	movement_mode_changed.emit(is_flying, is_noclip)


## Noclip implica voo: sem colisão não há chão para andar.
func set_noclip(value: bool) -> void:
	is_noclip = value
	_collision.disabled = value
	if value:
		is_flying = true
	movement_mode_changed.emit(is_flying, is_noclip)


func set_input_locked(value: bool) -> void:
	input_locked = value
	_capture_mouse(not value)


## Posiciona o jogador olhando (no plano horizontal) para "look_target".
func spawn_at(pos: Vector3, look_target: Vector3) -> void:
	teleport_to(pos + Vector3.UP * 0.5)
	var dir := look_target - pos
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)


func teleport_to(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO


func _on_dev_mode_changed(enabled: bool) -> void:
	if not enabled:
		set_flying(false)


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		_capture_mouse(false)
	elif event is InputEventMouseButton and event.pressed and not captured:
		_capture_mouse(true)
	elif event is InputEventMouseMotion and captured:
		_look(event.relative)
	elif DevMode.enabled and event.is_action_pressed("jump") and not event.is_echo():
		_check_double_tap_jump()
	elif DevMode.enabled and event.is_action_pressed("toggle_noclip"):
		set_noclip(not is_noclip)


## Dois toques rápidos no Espaço alternam o voo (como no modo criativo do Minecraft).
func _check_double_tap_jump() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_jump_ms < DOUBLE_TAP_MS:
		set_flying(not is_flying)
		_last_jump_ms = -1000
	else:
		_last_jump_ms = now


func _physics_process(delta: float) -> void:
	var depth: float = water_level_at.call(global_position) - global_position.y
	is_swimming = depth > swim_start_depth and not is_flying
	var input := Vector2.ZERO if input_locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	if is_flying:
		_fly(delta, wish_dir)
	elif is_swimming:
		_swim(delta, wish_dir, depth)
	else:
		_walk(delta, wish_dir)
	move_and_slide()


func _walk(delta: float, wish_dir: Vector3) -> void:
	if is_on_floor():
		if _just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta
	var speed := sprint_speed if _pressed("sprint") else walk_speed
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	_apply_horizontal(wish_dir * speed, accel, delta)


func _swim(delta: float, wish_dir: Vector3, depth: float) -> void:
	var speed := swim_speed * (1.4 if _pressed("sprint") else 1.0)
	_apply_horizontal(wish_dir * speed, water_drag * 2.0, delta)
	# Flutuação: empurra para a profundidade de equilíbrio.
	velocity.y += clampf(depth - float_depth, -1.0, 1.0) * buoyancy * delta
	if _pressed("jump"):
		velocity.y += swim_up_acceleration * delta
	velocity.y *= exp(-water_drag * delta)


## Voo livre sem gravidade: Espaço sobe, Ctrl desce, Shift acelera.
func _fly(delta: float, wish_dir: Vector3) -> void:
	var speed := fly_speed * (fly_fast_multiplier if _pressed("sprint") else 1.0)
	var vertical := float(_pressed("jump")) - float(_pressed("fly_down"))
	var target := wish_dir * speed + Vector3.UP * vertical * speed
	velocity = velocity.lerp(target, 1.0 - exp(-fly_acceleration * delta))


## Aproxima a velocidade horizontal do alvo de forma suave e independente do FPS.
func _apply_horizontal(target: Vector3, acceleration: float, delta: float) -> void:
	var weight := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)


func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * mouse_sensitivity, -1.5, 1.5)


func _pressed(action: StringName) -> bool:
	return not input_locked and Input.is_action_pressed(action)


func _just_pressed(action: StringName) -> bool:
	return not input_locked and Input.is_action_just_pressed(action)


func _capture_mouse(capture: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
