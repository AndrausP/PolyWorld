class_name ItemIcon
extends RefCounted
## Desenha o ícone de um item. Sem textura, desenha um "bloco" com topo claro,
## frente na cor base e base escura. Usado pela hotbar e pelo inventário criativo.


static func draw(canvas: CanvasItem, item: ItemData, rect: Rect2) -> void:
	if item.icon != null:
		canvas.draw_texture_rect(item.icon, rect, false)
		return
	var c := item.icon_color
	var top := rect.size.y * 0.3
	canvas.draw_rect(rect, c.darkened(0.35))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, top)), c.lightened(0.25))
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, top), Vector2(rect.size.x, rect.size.y * 0.45)), c)
	canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.8), false, 2.0)
