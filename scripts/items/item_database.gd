class_name ItemDatabase
extends RefCounted
## Carrega todos os itens (.tres) de data/items/. Basta criar um novo .tres
## lá para ele aparecer no inventário criativo.

const ITEMS_DIR := "res://data/items/"


static func load_all() -> Array[ItemData]:
	var result: Array[ItemData] = []
	# list_directory também funciona em builds exportadas (lida com .remap).
	for file in ResourceLoader.list_directory(ITEMS_DIR):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var item := load(ITEMS_DIR + file) as ItemData
		if item != null:
			result.append(item)
	result.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.display_name < b.display_name)
	return result
