class_name VegetationEntry
extends Resource
## Um tipo de vegetação (ou pedra) usado pelos biomas: quais modelos,
## densidade, escala, cor das folhas, vento e colisão. Arquivos em data/vegetation/.

enum Layer { LARGE, GROUND }

@export var display_name: String = ""
## Variantes do modelo (cenas glTF importadas); uma é sorteada por instância.
@export var scenes: Array[PackedScene] = []
## LARGE: árvores, arbustos, pedras (amostragem esparsa, vista de longe).
## GROUND: grama, flores (amostragem densa, vista só de perto).
@export var layer: Layer = Layer.LARGE
## Chance (0..1) de nascer em cada ponto de amostragem do bioma.
@export_range(0.0, 1.0) var density: float = 0.1
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
## Inclinação máxima (1 - normal.y) do terreno.
@export_range(0.0, 1.0) var max_slope: float = 0.35
## Quanto o modelo afunda no chão (metros, multiplicado pela escala).
@export var sink: float = 0.1
## Inclina o modelo seguindo o terreno (bom para grama e pedras pequenas).
@export var align_to_ground: bool = false

@export_group("Aparência")
## Cor das folhas. Alpha 0 = usa a textura original do modelo.
@export var leaf_tint: Color = Color(1, 1, 1, 0)
## Desloca a faixa de cor da paleta Grass.png (0 lima, -1 laranja, -2 verde, -3 amarelo).
@export var grass_palette_shift: int = 0
## Neve acumulada no topo das folhas/galhos (0..1).
@export_range(0.0, 1.0) var snow_cover: float = 0.0
@export var cast_shadows: bool = true
## Distância máxima (m) em que aparece.
@export var view_distance: float = 300.0

@export_group("Vento")
## Deslocamento (m) do topo do modelo com vento de força 1.
@export var wind_strength: float = 0.3

@export_group("Colisão")
## 0 = sem colisão. Raio em metros (multiplicado pela escala nas pedras).
@export var collision_radius: float = 0.0
## Altura do cilindro de colisão (troncos). Pedras usam esfera.
@export var collision_height: float = 3.0
@export var collision_is_sphere: bool = false
