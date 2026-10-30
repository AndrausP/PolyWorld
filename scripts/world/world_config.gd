class_name WorldConfig
extends Resource
## Parâmetros da geração da ilha. Edite data/world/default_world.tres
## (ou crie outro) para mudar seed, tamanho, relevo, rios e biomas sem tocar no código.

@export_group("Mundo")
## Seed do mundo. Use 0 para gerar uma seed aleatória a cada execução.
@export var world_seed: int = 1337
## Número de células por lado da grade.
@export var size_cells: int = 512
## Tamanho de cada célula em metros (lado da ilha = size_cells * cell_size).
@export var cell_size: float = 2.0
## Altura máxima do terreno (metros).
@export var max_height: float = 110.0
## Altura (Y de mundo) do nível do mar.
@export var sea_level: float = 0.0
## Fração da altura normalizada que fica abaixo do mar (0..1).
@export_range(0.0, 1.0) var sea_threshold: float = 0.18
## Células por lado de cada pedaço (chunk) da malha do terreno.
@export var chunk_cells: int = 64

@export_group("Ruído")
## Frequência do relevo, em ciclos por metro.
@export var noise_frequency: float = 0.003
@export_range(1, 8) var noise_octaves: int = 6
@export var noise_lacunarity: float = 2.0
@export var noise_gain: float = 0.5
## Altura mínima (0..1) antes de aplicar o ruído: evita "buracos" no meio da ilha.
@export_range(0.0, 1.0) var base_elevation: float = 0.25
## Expoente aplicado à altura: valores > 1 achatam as planícies e afinam os picos.
@export var height_exponent: float = 1.6
## Peso das cordilheiras (ruído "ridged") no centro da ilha.
@export var mountain_strength: float = 0.28
@export var mountain_frequency: float = 0.0022
## Distorção do espaço (metros) que deixa relevo e litoral mais orgânicos.
@export var warp_strength: float = 60.0
@export var warp_frequency: float = 0.002

@export_group("Máscara da ilha")
## Raio normalizado (0 = centro, 1 = borda) onde o terreno começa a afundar.
@export_range(0.0, 1.5) var mask_inner: float = 0.45
## Raio normalizado onde o terreno fica totalmente submerso.
@export_range(0.0, 1.5) var mask_outer: float = 1.05
## Irregularidade do litoral (deforma o raio da máscara).
@export_range(0.0, 0.5) var coast_irregularity: float = 0.12

@export_group("Rios e lagos")
## Quantos vértices precisam drenar para um ponto para ele virar rio.
@export var river_threshold: float = 1500.0
## Fluxo (múltiplos do limiar) em que o rio atinge largura/profundidade máximas.
@export var river_flow_range: float = 25.0
## Meia-largura do rio em células (mínima e máxima).
@export var river_min_width: float = 0.8
@export var river_max_width: float = 3.5
## Profundidade do leito em metros (mínima e máxima).
@export var river_min_depth: float = 0.6
@export var river_max_depth: float = 2.6
## Inclinação das margens (metros de subida por metro).
@export var river_bank_slope: float = 0.45
## Profundidade mínima para uma depressão virar lago.
@export var lake_min_depth: float = 1.5
@export var riverbed_color: Color = Color(0.62, 0.57, 0.44)

@export_group("Biomas")
## Biomas avaliados em ordem; o primeiro que aceitar altura/umidade vence.
@export var biomes: Array[BiomeData] = []
## Bioma usado em encostas íngremes (precisa estar na lista acima).
@export var slope_biome: BiomeData
## Inclinação (1 - normal.y) acima da qual vira encosta. 0.3 ≈ 46°.
@export_range(0.0, 1.0) var slope_threshold: float = 0.42
## Altura normalizada mínima para aplicar o bioma de encosta (preserva praias).
@export var slope_min_height: float = 0.03
## Frequência da umidade (ciclos por metro).
@export var moisture_frequency: float = 0.0025
## Quanto os rios umedecem o entorno (favorece florestas nas margens).
@export var river_moisture: float = 0.2
## Ruído aplicado às faixas de altura dos biomas (bordas irregulares).
@export var biome_border_noise: float = 0.05

@export_group("Vegetação")
## Espaçamento (m) da amostragem de árvores, arbustos e pedras.
@export var large_step: float = 3.0
## Espaçamento (m) da amostragem de grama e flores.
@export var ground_step: float = 1.1
## Tamanho (m) dos chunks de vegetação grande e rasteira (para culling).
@export var large_chunk_size: float = 128.0
@export var ground_chunk_size: float = 32.0
## Distância mínima acima do mar para nascer vegetação.
@export var vegetation_min_height: float = 0.5

@export_group("Spawn")
## Bioma onde o jogador nasce (praia).
@export var spawn_biome: BiomeData


func world_size() -> float:
	return size_cells * cell_size
