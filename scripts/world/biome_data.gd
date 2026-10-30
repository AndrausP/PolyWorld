class_name BiomeData
extends Resource
## Definição de um bioma: faixa de altura/umidade onde aparece, cor do chão
## e a vegetação típica. Cada bioma é um .tres em data/biomes/.

@export var display_name: String = "Bioma"
@export var color: Color = Color.WHITE
## Variação aleatória de brilho por vértice.
@export_range(0.0, 0.5) var color_variation: float = 0.05
## Se true, encostas íngremes mostram a textura de rocha.
@export var rock_on_slopes: bool = true

@export_group("Faixas")
## Altura normalizada acima do mar (0 = nível do mar, 1 = altura máxima).
@export var min_height: float = -10.0
@export var max_height: float = 10.0
@export_range(0.0, 1.0) var min_moisture: float = 0.0
@export_range(0.0, 1.0) var max_moisture: float = 1.0

@export_group("Vegetação")
## Plantas, árvores e pedras do bioma. As densidades de cada camada
## (grande/rasteira) somam no máximo 1.
@export var vegetation: Array[VegetationEntry] = []


## Retorna true se a altura normalizada e a umidade estão dentro das faixas do bioma.
func matches(height: float, moisture: float) -> bool:
	return height >= min_height and height < max_height \
		and moisture >= min_moisture and moisture <= max_moisture
