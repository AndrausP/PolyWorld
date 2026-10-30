class_name Hydrology
extends RefCounted
## Escoamento da água sobre o HeightMap:
## 1. "Priority flood" a partir do mar: preenche depressões (viram lagos) e define
##    para qual vizinho cada vértice drena, garantindo que tudo chegue ao mar.
## 2. Acumula o fluxo de montante para jusante.
## 3. Onde o fluxo passa do limiar vira rio: escava o leito e define o nível da água.

const NO_WATER := -1.0e9
## Diferença mínima de altura ao preencher planos (força um declive até o mar).
const FILL_EPSILON := 0.002
const BUCKET_SIZE := 0.05
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DZ := [0, 0, 1, -1, 1, -1, 1, -1]

## Nível da água doce em cada vértice (NO_WATER = seco). O mar não entra aqui.
var water_level := PackedFloat32Array()
## Vértice para onde cada vértice drena (-1 = mar/borda).
var receiver := PackedInt32Array()
## Fluxo acumulado: quantos vértices drenam por aqui.
var flow := PackedFloat32Array()

var _height_map: HeightMap
var _config: WorldConfig
var _res: int


func _init(height_map: HeightMap, world_config: WorldConfig) -> void:
	_height_map = height_map
	_config = world_config
	_res = height_map.resolution
	var filled := PackedFloat32Array()
	var order := _flood(filled)
	_accumulate(order)
	_mark_lakes(filled)
	_carve_rivers(filled)


func has_water(i: int) -> bool:
	return water_level[i] > NO_WATER


## Priority flood com fila de baldes (O(n)). Retorna a ordem de visita
## (cada vértice aparece depois do vértice para onde ele drena).
func _flood(filled: PackedFloat32Array) -> PackedInt32Array:
	var h := _height_map.heights
	var n := h.size()
	var sea := _config.sea_level
	filled.resize(n)
	receiver.resize(n)
	receiver.fill(-1)
	var closed := PackedByteArray()
	closed.resize(n)
	var order := PackedInt32Array()
	order.resize(n)
	var count := 0

	var max_h := sea
	for i in n:
		max_h = maxf(max_h, h[i])
	var bucket_count := int((max_h - sea) / BUCKET_SIZE) + 3
	var buckets := []
	buckets.resize(bucket_count)
	for b in bucket_count:
		buckets[b] = []

	# Sementes: todo o mar e a borda da grade.
	for i in n:
		var x := i % _res
		@warning_ignore("integer_division")
		var z := i / _res
		if h[i] < sea or x == 0 or z == 0 or x == _res - 1 or z == _res - 1:
			closed[i] = 1
			filled[i] = maxf(h[i], sea)
			buckets[int((filled[i] - sea) / BUCKET_SIZE)].append(i)

	for b in bucket_count:
		var bucket: Array = buckets[b]
		var k := 0
		while k < bucket.size():
			var c: int = bucket[k]
			k += 1
			order[count] = c
			count += 1
			var level := filled[c]
			var cx := c % _res
			@warning_ignore("integer_division")
			var cz := c / _res
			for d in 8:
				var nx: int = cx + DX[d]
				var nz: int = cz + DZ[d]
				if nx < 0 or nz < 0 or nx >= _res or nz >= _res:
					continue
				var ni := nz * _res + nx
				if closed[ni] == 1:
					continue
				closed[ni] = 1
				var fl := maxf(h[ni], level + FILL_EPSILON)
				filled[ni] = fl
				receiver[ni] = c
				var nb := clampi(int((fl - sea) / BUCKET_SIZE), b, bucket_count - 1)
				buckets[nb].append(ni)
		buckets[b] = []
	order.resize(count)
	return order


## Cada vértice de terra contribui com 1; o fluxo desce pela ordem inversa.
func _accumulate(order: PackedInt32Array) -> void:
	var h := _height_map.heights
	var sea := _config.sea_level
	flow.resize(h.size())
	for i in h.size():
		flow[i] = 1.0 if h[i] >= sea else 0.0
	for j in range(order.size() - 1, -1, -1):
		var c := order[j]
		var r := receiver[c]
		if r >= 0:
			flow[r] += flow[c]


func _mark_lakes(filled: PackedFloat32Array) -> void:
	var h := _height_map.heights
	water_level.resize(h.size())
	water_level.fill(NO_WATER)
	for i in h.size():
		if h[i] >= _config.sea_level and filled[i] - h[i] > _config.lake_min_depth:
			water_level[i] = filled[i]


## Escava um leito em "U" ao redor de cada vértice de rio e suaviza as margens.
func _carve_rivers(filled: PackedFloat32Array) -> void:
	var original := _height_map.heights
	var h := original.duplicate() # cópia local; devolvida ao HeightMap no fim
	var threshold := _config.river_threshold
	var bank_cells := 2.0
	for i in h.size():
		if flow[i] < threshold or original[i] < _config.sea_level:
			continue
		var strength := clampf(log(flow[i] / threshold) / log(_config.river_flow_range), 0.0, 1.0)
		var depth := lerpf(_config.river_min_depth, _config.river_max_depth, strength)
		var radius := lerpf(_config.river_min_width, _config.river_max_width, strength)
		var level := filled[i]
		var cx := i % _res
		@warning_ignore("integer_division")
		var cz := i / _res
		var reach := radius + bank_cells
		var r := ceili(reach)
		for oz in range(-r, r + 1):
			for ox in range(-r, r + 1):
				var nx := cx + ox
				var nz := cz + oz
				if nx < 0 or nz < 0 or nx >= _res or nz >= _res:
					continue
				var d := sqrt(float(ox * ox + oz * oz))
				if d > reach:
					continue
				var j := nz * _res + nx
				var target: float
				if d <= radius:
					var t := d / maxf(radius, 0.001)
					target = level - depth * (1.0 - t * t)
					# Só alaga vizinhos na mesma cota: encosta abaixo a água seria uma "parede".
					if original[j] > level - depth - 0.5:
						water_level[j] = maxf(water_level[j], level)
				else:
					target = level + (d - radius) * _config.cell_size * _config.river_bank_slope
				if target < h[j]:
					h[j] = target
	_height_map.heights = h
