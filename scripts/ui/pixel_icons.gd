class_name PixelIcons
extends RefCounted
## Ícones em pixel art definidos como texto (sem assets externos).
## Cada caractere é um pixel; "." é transparente. As paletas mapeiam caractere -> cor.

const HEART := [
	".##...##.",
	"#WR#.#RR#",
	"#WRR#RRR#",
	"#RRRRRRR#",
	".#RRRRR#.",
	"..#RRR#..",
	"...#R#...",
	"....#....",
]
const HEART_FULL := {"#": Color(0.12, 0.02, 0.02), "R": Color(0.86, 0.08, 0.1), "W": Color(1.0, 0.8, 0.8)}
const HEART_EMPTY := {"#": Color(0.12, 0.02, 0.02), "R": Color(0.2, 0.16, 0.16, 0.85), "W": Color(0.26, 0.2, 0.2, 0.85)}

const HUNGER := [
	"....###..",
	"...#mMM#.",
	"..#mMMMM#",
	"..#MMMMM#",
	"..#MMMM#.",
	".##MMM#..",
	"#BB###...",
	"#B#......",
	".#.......",
]
const HUNGER_FULL := {"#": Color(0.16, 0.08, 0.03), "M": Color(0.78, 0.45, 0.22), "m": Color(0.95, 0.68, 0.4), "B": Color(0.95, 0.92, 0.85)}
const HUNGER_EMPTY := {"#": Color(0.16, 0.08, 0.03), "M": Color(0.22, 0.18, 0.15, 0.85), "m": Color(0.26, 0.21, 0.17, 0.85), "B": Color(0.3, 0.3, 0.3, 0.85)}


## Desenha um ícone. "fill" 1 = cheio, 0.5 = meio, 0 = vazio.
## "half_from_right" indica de que lado fica a metade cheia.
static func draw_icon(canvas: CanvasItem, rows: Array, full: Dictionary, empty: Dictionary,
		origin: Vector2, pixel: float, fill: float, half_from_right := false) -> void:
	var half_col: int = rows[0].length() / 2
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			var ch := row[c]
			if ch == ".":
				continue
			var in_half := c >= half_col if half_from_right else c < half_col
			var is_full := fill >= 1.0 or (fill > 0.0 and in_half)
			var palette := full if is_full else empty
			canvas.draw_rect(Rect2(origin + Vector2(c, r) * pixel, Vector2(pixel, pixel)), palette[ch])
