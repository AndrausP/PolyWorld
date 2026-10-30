class_name SpeciesLibrary
extends RefCounted
## As 10 espécies, definidas em código para facilitar balanceamento.

static var _cache: Dictionary = {}


static func all() -> Array[SpeciesData]:
	if _cache.is_empty():
		for s in _build():
			_cache[s.id] = s
	var out: Array[SpeciesData] = []
	for s in _cache.values():
		out.append(s)
	return out


static func get_species(id: StringName) -> SpeciesData:
	all()
	return _cache.get(id)


static func _mk(id: String, name: String, diet: int, biomes: Array, size: float, speed: float, hp: float,
		aggr: float, dmg: float, herd: Vector2i, mating: int, gest: float, mat: float, litter: Vector2i,
		ca: Color, cb: Color, drops: Dictionary, body := &"quad", tame := false, eggs := false) -> SpeciesData:
	var s := SpeciesData.new()
	s.id = StringName(id); s.display_name = name; s.diet = diet as SpeciesData.Diet
	s.biomes = PackedStringArray(biomes); s.base_size = size; s.base_speed = speed; s.base_health = hp
	s.aggression = aggr; s.damage = dmg; s.herd_size = herd; s.mating_season = mating
	s.gestation_days = gest; s.maturity_days = mat; s.litter = litter
	s.color_a = ca; s.color_b = cb; s.drops = drops; s.body = body; s.tameable = tame; s.lays_eggs = eggs
	s.flees_from_player = aggr < 0.5
	return s


static func _build() -> Array[SpeciesData]:
	var H := SpeciesData.Diet.HERBIVORE
	var C := SpeciesData.Diet.CARNIVORE
	var O := SpeciesData.Diet.OMNIVORE
	return [
		_mk("rabbit", "Coelho", H, ["Planície", "Floresta"], 0.45, 5.5, 6, 0.0, 0.0, Vector2i(2, 4), 0, 1.0, 1.5, Vector2i(3, 5),
			Color("c9b79c"), Color("f2ede4"), {"raw_meat": [1, 1], "hide": [1, 1]}, &"quad", true),
		_mk("deer", "Cervo", H, ["Floresta", "Planície"], 1.3, 6.0, 30, 0.0, 0.0, Vector2i(3, 6), 2, 2.5, 4.0, Vector2i(1, 2),
			Color("a8693a"), Color("e8d6b8"), {"raw_meat": [2, 4], "hide": [1, 2], "bone": [1, 2]}, &"quad", true),
		_mk("boar", "Javali", O, ["Floresta", "Pampa"], 1.0, 5.0, 40, 0.55, 6.0, Vector2i(2, 5), 1, 2.0, 3.5, Vector2i(3, 6),
			Color("5b4636"), Color("2e241d"), {"raw_meat": [2, 4], "hide": [1, 1], "bone": [1, 1]}, &"quad"),
		_mk("goat", "Cabra-da-montanha", H, ["Montanha", "Nevado"], 0.9, 6.5, 24, 0.2, 3.0, Vector2i(2, 5), 0, 2.0, 3.0, Vector2i(1, 2),
			Color("e9e6df"), Color("8a8478"), {"raw_meat": [1, 3], "hide": [1, 1]}, &"quad", true),
		_mk("capybara", "Capivara", H, ["Planície", "Praia"], 0.85, 3.5, 28, 0.0, 0.0, Vector2i(3, 7), 1, 2.0, 3.0, Vector2i(2, 4),
			Color("8a6a46"), Color("6e5236"), {"raw_meat": [2, 3], "hide": [1, 1]}, &"quad", true),
		_mk("wolf", "Lobo", C, ["Floresta", "Montanha", "Nevado"], 1.0, 7.5, 45, 0.9, 8.0, Vector2i(2, 5), 3, 2.0, 4.0, Vector2i(2, 4),
			Color("6d7075"), Color("c4c7cc"), {"raw_meat": [1, 3], "hide": [1, 2], "bone": [1, 2]}, &"quad"),
		_mk("fox", "Raposa", C, ["Planície", "Pampa", "Floresta"], 0.6, 7.0, 16, 0.6, 3.0, Vector2i(1, 2), 3, 1.5, 2.5, Vector2i(2, 4),
			Color("d8742c"), Color("f4efe6"), {"raw_meat": [1, 2], "hide": [1, 1]}, &"quad"),
		_mk("bear", "Urso", O, ["Floresta", "Montanha"], 1.7, 5.0, 120, 0.8, 18.0, Vector2i(1, 1), 1, 3.5, 6.0, Vector2i(1, 2),
			Color("4a3426"), Color("2b1d14"), {"raw_meat": [4, 7], "hide": [2, 4], "bone": [2, 3]}, &"quad"),
		_mk("chicken", "Galinha-selvagem", O, ["Planície", "Pampa"], 0.45, 3.5, 8, 0.0, 0.0, Vector2i(3, 6), 0, 1.0, 2.0, Vector2i(2, 4),
			Color("b3563a"), Color("f0e2c2"), {"raw_meat": [1, 1], "feather": [1, 3], "egg": [0, 2]}, &"bird", true, true),
		_mk("turtle", "Tartaruga", H, ["Praia", "Planície"], 0.7, 1.2, 50, 0.0, 0.0, Vector2i(1, 3), 1, 3.0, 5.0, Vector2i(2, 5),
			Color("4f7a46"), Color("c2a46a"), {"raw_meat": [2, 3], "bone": [1, 2]}, &"turtle", true, true),
	]
