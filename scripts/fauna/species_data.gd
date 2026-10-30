class_name SpeciesData
extends Resource
## Definição de uma espécie. As 10 espécies do jogo vêm de SpeciesLibrary.

enum Diet { HERBIVORE, CARNIVORE, OMNIVORE }

@export var id: StringName = &""
@export var display_name := ""
@export var diet: Diet = Diet.HERBIVORE
@export var biomes: PackedStringArray = []         ## nomes de bioma onde nasce
@export var base_size := 1.0
@export var base_speed := 3.0
@export var base_health := 20.0
@export var base_hunger := 100.0
@export var aggression := 0.0                      ## 0 foge, 1 ataca
@export var damage := 0.0
@export var herd_size := Vector2i(1, 1)
@export var mating_season: int = 0                 ## WorldClock.Season
@export var gestation_days := 2.0
@export var maturity_days := 3.0
@export var litter := Vector2i(1, 2)
@export var lays_eggs := false
@export var tameable := false
@export var color_a := Color.WHITE
@export var color_b := Color.GRAY
@export var drops: Dictionary = {}                 ## item_id -> [min, max]
@export var body: StringName = &"quad"             ## quad | bird | turtle
@export var flees_from_player := true
