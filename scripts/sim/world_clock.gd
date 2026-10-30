extends Node
## Autoload WorldClock: dia/noite e estações. O servidor é a fonte da verdade;
## clientes avançam localmente e se corrigem a cada sync.

signal season_changed(season: int)
signal day_started(day: int)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }
const SEASON_NAMES := ["Primavera", "Verão", "Outono", "Inverno"]
const DAY_SECONDS := 1200.0
const DAYS_PER_SEASON := 6
const DAYS_PER_YEAR := DAYS_PER_SEASON * 4

## Segundos de jogo desde o início do mundo (começa às 8h da manhã).
var elapsed := DAY_SECONDS * 0.33
var time_scale := 1.0

var day: int:
	get: return int(elapsed / DAY_SECONDS)
## 0..1 (0 = meia-noite, 0.5 = meio-dia).
var time_of_day: float:
	get: return fmod(elapsed, DAY_SECONDS) / DAY_SECONDS
var season: int:
	get: return (day % DAYS_PER_YEAR) / DAYS_PER_SEASON
## 0..1 progresso dentro da estação atual.
var season_progress: float:
	get: return (float(day % DAYS_PER_SEASON) + time_of_day) / DAYS_PER_SEASON
var is_night: bool:
	get: return time_of_day < 0.22 or time_of_day > 0.78

var _last_day := -1
var _last_season := -1


func _process(delta: float) -> void:
	elapsed += delta * time_scale
	if day != _last_day:
		_last_day = day
		day_started.emit(day)
	if season != _last_season:
		_last_season = season
		season_changed.emit(season)


func season_name() -> String:
	return SEASON_NAMES[season]


## Chamado pelo Net para alinhar clientes ao servidor.
@rpc("authority", "call_remote", "unreliable")
func sync_clock(server_elapsed: float) -> void:
	elapsed = server_elapsed
