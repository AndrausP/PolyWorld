class_name DayNight
extends Node
## Gira o sol conforme WorldClock e ajusta luz/cores por estação.
## Também publica o shader global "season" (0..3 contínuo) para as folhas.

@export var sun: DirectionalLight3D
@export var environment: Environment

const SEASON_SUN := [Color(1, 0.96, 0.86), Color(1, 0.93, 0.78), Color(1, 0.84, 0.66), Color(0.84, 0.9, 1.0)]
const SEASON_ENERGY := [1.25, 1.4, 1.1, 0.9]


func _process(_delta: float) -> void:
	if sun == null:
		return
	var t := WorldClock.time_of_day
	# 0.25 = nascer do sol, 0.5 = meio-dia, 0.75 = pôr do sol.
	var angle := (t - 0.25) * TAU * 0.5   # 0..PI durante o dia
	sun.rotation_degrees = Vector3(-rad_to_deg(sin(clampf(angle, 0.0, PI))) * 0.85 - 4.0, -35.0 + t * 360.0 * 0.25, 0)
	var day_amount := clampf(sin((t - 0.25) * TAU) * 1.6 + 0.25, 0.0, 1.0)
	var s := WorldClock.season
	sun.light_color = SEASON_SUN[s].lerp(Color(1.0, 0.55, 0.3), (1.0 - day_amount) * 0.6)
	sun.light_energy = lerpf(0.03, SEASON_ENERGY[s], day_amount)
	if environment != null:
		environment.ambient_light_energy = lerpf(0.12, 0.6, day_amount)
		environment.fog_light_color = Color(0.05, 0.07, 0.12).lerp(Color(0.62, 0.74, 0.86), day_amount)
	# 0..4 contínuo; o shader trata a virada 4 -> 0 com mod.
	RenderingServer.global_shader_parameter_set("season", float(s) + _frac_in_season())


## Progresso dentro da estação atual (0..1).
func _frac_in_season() -> float:
	return fmod(float(WorldClock.day % WorldClock.DAYS_PER_SEASON) + WorldClock.time_of_day, float(WorldClock.DAYS_PER_SEASON)) / WorldClock.DAYS_PER_SEASON
