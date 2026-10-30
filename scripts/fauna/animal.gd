class_name Animal
extends Node3D
## Um animal. O servidor roda a IA (server_tick); clientes só interpolam
## posição/rotação recebidas (puppet). Visual vem de AnimalModel.

enum State { IDLE, WANDER, GRAZE, FLEE, HUNT, SLEEP }

const FOOD_BY_SEASON := [1.0, 1.0, 0.8, 0.35]  ## quanto pasto há por estação

var uid := 0
var species: SpeciesData
var genes := PackedFloat32Array()
var female := false
var age_days := 0.0
var health := 10.0
var max_health := 10.0
var hunger := 70.0
var max_hunger := 100.0
var state: State = State.IDLE
var pregnant_until := -1.0       ## WorldClock.elapsed do parto
var father_genes := PackedFloat32Array()
var tamed_by := 0                ## peer dono (0 = selvagem)

var _model: Node3D
var _target := Vector3.ZERO
var _timer := 0.0
var _walk_phase := 0.0
var _moving := false
# Puppet (cliente)
var puppet := false
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0

var scale_now: float:
	get:
		var maturity := clampf(age_days / maxf(species.maturity_days, 0.01), 0.0, 1.0)
		return species.base_size * genes[Genes.G.SIZE] * lerpf(0.5, 1.0, maturity)
var is_adult: bool:
	get: return age_days >= species.maturity_days


func setup(new_uid: int, sp: SpeciesData, g: PackedFloat32Array, is_female: bool, age: float) -> void:
	uid = new_uid
	species = sp
	genes = g
	female = is_female
	age_days = age
	max_health = sp.base_health * g[Genes.G.HEALTH]
	health = max_health
	max_hunger = sp.base_hunger * g[Genes.G.HUNGER]
	hunger = max_hunger * 0.7
	name = "Animal_%d" % uid
	_model = AnimalModel.build(sp, g)
	add_child(_model)
	_apply_scale()
	_add_hitbox()


func _add_hitbox() -> void:
	var area := Area3D.new()
	area.collision_layer = 1 << 3   # camada 4 = animais
	area.collision_mask = 0
	area.set_meta("animal_uid", uid)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.9, 1.1)
	cs.shape = shape
	cs.position = Vector3(0, 0.45, 0)
	area.add_child(cs)
	_model.add_child(area)


func _apply_scale() -> void:
	var s := scale_now
	_model.scale = Vector3.ONE * s


# --- Cliente ---------------------------------------------------------------
func puppet_update(delta: float) -> void:
	var moved := position.distance_to(_net_pos) > 0.02
	position = position.lerp(_net_pos, minf(delta * 10.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _net_yaw, minf(delta * 10.0, 1.0))
	_animate(delta, moved)


func set_net(p: Vector3, yaw: float) -> void:
	_net_pos = p
	_net_yaw = yaw


# --- Servidor --------------------------------------------------------------
## mgr: FaunaManager. Chamado a cada ~0.1 s com delta acumulado.
func server_tick(delta: float, mgr: Node) -> void:
	var now: float = WorldClock.elapsed
	age_days += delta / WorldClock.DAY_SECONDS
	hunger -= delta * 0.35
	if hunger <= 0.0:
		hunger = 0.0
		health -= delta * 0.8
		if health <= 0.0:
			mgr.kill_animal(uid, 0)
			return
	elif hunger > max_hunger * 0.6 and health < max_health:
		health = minf(max_health, health + delta * 0.3)
	_timer -= delta

	var threat: Node3D = mgr.nearest_threat(self)
	if threat != null:
		_target = position + (position - threat.global_position).normalized() * 12.0
		state = State.FLEE
		_timer = 2.0
	elif species.aggression > 0.5 and hunger < max_hunger * 0.65:
		var prey: Node3D = mgr.nearest_prey(self)
		if prey != null:
			state = State.HUNT
			_target = prey.global_position
			_timer = 1.0
			if position.distance_to(prey.global_position) < 1.6 * scale_now:
				mgr.attack(self, prey)

	if _timer <= 0.0:
		_choose_state(mgr)

	var speed := 0.0
	match state:
		State.WANDER: speed = species.base_speed * 0.35
		State.FLEE, State.HUNT: speed = species.base_speed * genes[Genes.G.SPEED]
		State.GRAZE:
			var food: float = FOOD_BY_SEASON[WorldClock.season]
			hunger = minf(max_hunger, hunger + delta * 3.0 * food)
	_move(delta, speed, mgr)
	_try_reproduce(now, mgr)


func _choose_state(mgr: Node) -> void:
	var hungry := hunger < max_hunger * 0.5
	if WorldClock.is_night and species.aggression < 0.5 and not hungry:
		state = State.SLEEP
		_timer = randf_range(8.0, 16.0)
	elif species.diet != SpeciesData.Diet.CARNIVORE and (hungry or randf() < 0.3):
		state = State.GRAZE
		_timer = randf_range(5.0, 10.0)
	elif randf() < 0.55:
		state = State.WANDER
		_target = mgr.pick_wander_point(self)
		_timer = randf_range(4.0, 9.0)
	else:
		state = State.IDLE
		_timer = randf_range(2.0, 6.0)


func _move(delta: float, speed: float, mgr: Node) -> void:
	_moving = speed > 0.05
	if _moving:
		var dir := _target - position
		dir.y = 0.0
		if dir.length() < 0.6:
			_timer = 0.0
			_moving = false
		else:
			dir = dir.normalized()
			var next := position + dir * speed * delta
			if mgr.is_walkable(next, species):
				position = next
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(delta * 8.0, 1.0))
			else:
				_timer = 0.0
				_moving = false
	position.y = mgr.ground_height(position)
	_animate(delta, _moving)


func _animate(delta: float, moving: bool) -> void:
	var legs: Array = _model.get_meta("legs", [])
	if moving:
		_walk_phase += delta * (6.0 + species.base_speed)
	for i in legs.size():
		var leg: Node3D = legs[i]
		var swing := sin(_walk_phase + (PI if i % 3 != 0 else 0.0)) * 0.6 if moving else 0.0
		leg.rotation.x = lerpf(leg.rotation.x, swing, 0.4)
	if state == State.SLEEP:
		_model.rotation.z = lerpf(_model.rotation.z, 0.0, 0.1)
	_apply_scale()


func _try_reproduce(now: float, mgr: Node) -> void:
	if not female or not is_adult:
		return
	if pregnant_until >= 0.0:
		if now >= pregnant_until:
			pregnant_until = -1.0
			mgr.give_birth(self)
		return
	if WorldClock.season != species.mating_season or hunger < max_hunger * 0.5:
		return
	if randf() > 0.02 * genes[Genes.G.FERTILITY]:
		return
	var mate: Animal = mgr.find_mate(self)
	if mate != null:
		pregnant_until = now + species.gestation_days * WorldClock.DAY_SECONDS * 0.25
		father_genes = mate.genes
