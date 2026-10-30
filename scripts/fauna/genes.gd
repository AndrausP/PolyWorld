class_name Genes
extends RefCounted
## Genética: vetor de floats em [0.6, 1.4] (multiplicadores) + cor em [0,1].
## Filhote = média dos pais + mutação gaussiana.

enum G { SIZE, SPEED, HEALTH, HUNGER, FERTILITY, AGGRESSION, COLOR, PATTERN, COUNT }
const MUTATION := 0.06
const NAMES := ["Tamanho", "Velocidade", "Vida", "Fome", "Fertilidade", "Agressividade", "Cor", "Padrão"]


static func random(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(G.COUNT)
	for i in G.COLOR:
		g[i] = clampf(rng.randfn(1.0, 0.1), 0.6, 1.4)
	g[G.COLOR] = rng.randf()
	g[G.PATTERN] = rng.randf()
	return g


static func breed(a: PackedFloat32Array, b: PackedFloat32Array, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(G.COUNT)
	for i in G.COUNT:
		var pick := (a[i] + b[i]) * 0.5
		# Às vezes herda de um só dos pais (dominância) para variedade visível.
		if rng.randf() < 0.3:
			pick = a[i] if rng.randf() < 0.5 else b[i]
		pick += rng.randfn(0.0, MUTATION)
		g[i] = clampf(pick, 0.6, 1.4) if i < G.COLOR else clampf(pick, 0.0, 1.0)
	return g
