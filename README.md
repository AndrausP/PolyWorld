# PolyWorld

Sobrevivência estilizada em primeira pessoa feita em **Godot 4.6** (GDScript).
Ilha procedural de 1 km por seed, com biomas, rios que correm até o mar, lagos, vegetação com vento (modelos do *Stylized Nature MegaKit*), jogador com nado, HUD estilo Minecraft e modo dev.

## Como rodar

1. Abra o Godot 4.6 (testado com `Godot_v4.6.3-stable`; a versão .NET também serve).
2. No Gerenciador de Projetos: **Importar** → selecione `project.godot` desta pasta.
   Na primeira abertura o editor importa os modelos e texturas (demora um pouco).
3. Aperte **F5**. A ilha é gerada em segundo plano (~7 s) com uma tela de carregamento.

Pela linha de comando:

```bash
godot --path .                      # roda o jogo
godot --path . -- --seed=42         # outra seed
godot --path . -- --dev             # já começa no modo dev
godot --headless --path . --quit-after 1500   # checagem de erros sem janela
```

## Controles

| Tecla | Ação |
|---|---|
| WASD | andar |
| Mouse | olhar |
| Espaço | pular / subir na água |
| Shift | correr / nadar mais rápido |
| 1–9 / roda do mouse | selecionar slot da hotbar |
| F3 | tela de debug (FPS, XYZ, seed, bioma) |
| ESC | libera o mouse (clique na tela para capturar de novo) |

## Modo dev (criativo)

Liga/desliga com **F4** (ou `-- --dev`).

| Tecla | Ação |
|---|---|
| 2× Espaço | liga/desliga o voo |
| Espaço / Ctrl | sobe / desce voando |
| Shift | voo rápido (3×) |
| N | noclip (atravessa terreno e árvores) |
| E | inventário criativo: clique num item para pôr no slot selecionado |
| M | mapa da ilha: clique num ponto para se teletransportar |
| ESC | fecha o painel aberto |

## O mundo

- **Tamanho:** 512 × 512 células de 2 m = 1024 m de lado (`size_cells`, `cell_size` no `default_world.tres`).
- **Relevo:** ruído fractal com distorção de domínio + cordilheiras ("ridged") no centro, vezes uma máscara radial com litoral irregular.
- **Água doce:** a água escoa sempre para o ponto mais baixo. O algoritmo *priority flood* parte do mar:
  depressões viram **lagos**, cada ponto ganha uma direção de escoamento e o fluxo é acumulado.
  Onde o fluxo passa de `river_threshold` nasce um **rio**, que é escavado no terreno e fica mais largo e fundo rio abaixo até chegar ao mar.
  A água do rio corre visualmente na direção do fluxo e o jogador nada em rios e lagos.
- **Biomas** (`data/biomes/`): fundo do mar, praia, planície, floresta, pampa, montanha e nevado.
  São escolhidos por altura, inclinação e umidade; a margem dos rios é mais úmida (favorece floresta).

| Bioma | Vegetação |
|---|---|
| Planície | árvores verde-limão esparsas, arbustos floridos, grama baixa, flores, trevos |
| Floresta | pinheiros + árvores verdes densas, samambaias, arbustos, grama alta escura, cogumelos |
| Pampa | capim dourado alto, capim laranja/amarelo, árvores outonais e retorcidas vermelhas raras |
| Montanha | pinheiros escuros, rochas, árvores secas, capim ralo |
| Nevado | pinheiros e pedras com neve, árvores secas |
| Praia | seixos e capim de praia |

## Vegetação e vento

- Cada tipo de planta é um `VegetationEntry` em `data/vegetation/` com: modelos (variantes), camada
  (grande ou rasteira), densidade, escala, **cor das folhas** (`leaf_tint`), faixa de cor da grama, neve, força do vento,
  distância de visão e colisão. Um bioma lista as entradas que usa.
- Os modelos glTF ficam em `assets/Stylized Nature MegaKit[Standard]/glTF` (licença CC0, Quaternius).
  As pastas FBX/OBJ/Textures são ignoradas pelo Godot (`.gdignore`) por serem duplicatas.
- Shaders: `foliage.gdshader` (folhas/grama: recorte por alpha, tinta, translucidez, neve) e
  `vegetation_solid.gdshader` (troncos/pedras). Ambos usam `wind.gdshaderinc`: balanço por planta + rajadas que atravessam o mapa.
- O vento é global: *Projeto → Configurações → Shader Globals* (`wind_direction`, `wind_strength`, `wind_speed`).
  Pode ser alterado em jogo com `RenderingServer.global_shader_parameter_set("wind_strength", 2.0)`.
- Desempenho: tudo em `MultiMeshInstance3D` por chunk, grama visível só de perto (70 m), árvores até ~380 m, LOD automático dos modelos.

## Como mudar a seed

- **Fixa:** abra `data/world/default_world.tres` no Inspetor e mude `world_seed`.
- **Aleatória a cada execução:** use `world_seed = 0`.
- **Temporária:** passe `-- --seed=N` na linha de comando (tem prioridade sobre o `.tres`).
  No editor: *Projeto → Configurações → Run → Main Run Args* (ex.: `-- --seed=42`).

## Renderer

O padrão é **Forward+**. Para hardware mais fraco use **Compatibility**:

- permanente: *Projeto → Configurações → Rendering → Renderer → Rendering Method* = `gl_compatibility`;
- só uma vez: `godot --path . --rendering-method gl_compatibility`.

## Estrutura

```
scenes/          main.tscn (mundo + tela de carregamento), player.tscn, hud.tscn
scripts/main.gd  seed, geração assíncrona, spawn do jogador, HUD
scripts/world/
  world_config.gd          Resource com os parâmetros do mundo
  biome_data.gd            Resource de bioma (faixas, cor, vegetação)
  vegetation_entry.gd      Resource de tipo de vegetação
  height_map.gd            alturas + consultas de altura/normal
  hydrology.gd             escoamento, lagos, rios (priority flood)
  biome_map.gd             bioma de cada vértice
  terrain_mesh_builder.gd  malha do terreno em chunks
  water_mesh_builder.gd    superfície de rios e lagos (com direção do fluxo)
  vegetation_library.gd    malhas/materiais da vegetação a partir dos glTF
  vegetation_placer.gd     onde cada planta nasce (thread)
  vegetation_spawner.gd    MultiMesh por chunk + colisões
  map_image_builder.gd     imagem do mapa (modo dev)
  water.gd                 plano do mar
  island_generator.gd      orquestra tudo numa thread; consultas de bioma/água/spawn
scripts/player/player.gd   movimento, nado (mar/rio/lago), voo dev, vida e fome
scripts/items/             ItemData e ItemDatabase
scripts/dev/dev_mode.gd    autoload DevMode
scripts/ui/                hud, hotbar, barras, mira, debug, inventário criativo, mapa, tela de carregamento
shaders/                   terrain, foliage, vegetation_solid, river, water, sky + includes (wind, noise)
data/world/ biomes/ vegetation/ items/
```

## Como estender

- **Novo bioma:** crie um `BiomeData` em `data/biomes/` e adicione à lista `biomes` do `default_world.tres` (a ordem importa).
- **Nova planta/árvore:** crie um `VegetationEntry` em `data/vegetation/` apontando para os `.gltf` e adicione ao bioma.
- **Novo item:** crie um `ItemData` em `data/items/` — aparece sozinho no inventário criativo.
- **Fome com o tempo:** chame `player.hunger -= x`; o HUD já reage ao sinal `hunger_changed`.

## Etapa 2 — sobrevivência online (Claude + Codex)

Veja `docs/GDD.md` (design), `docs/CONTRACTS.md` (divisão e APIs) e `docs/ONLINE.md` (como hospedar).

- **Online:** solo, host, cliente e servidor dedicado (ENet, host-autoritativo, até 16 jogadores).
- **Estações:** 24 dias por ano (20 min por dia); folhas ficam laranja no outono e caem no inverno; frutos e cio dependem da estação.
- **Fauna (10 espécies):** coelho, cervo, javali, cabra-da-montanha, capivara, lobo, raposa, urso, galinha, tartaruga.
  Genes herdáveis (tamanho, velocidade, vida, fome, fertilidade, agressividade, cor, padrão) com mutação,
  gestação, filhotes que crescem, predação, domesticação (T com comida) e inspetor de genética ao mirar.
- **Flora:** árvores/arbustos dão lenha, fibra, pedra; várias frutificam por estação (F colhe). Pinheiros dão sementes.
- **Itens/crafting/construção/progressão (Codex):** 50 itens, 40 receitas, 10 peças de construção, XP e níveis.
- **Controles novos:** botão esquerdo bate/coleta, F colhe fruto, T doma, E inventário/crafting.
- **Testes:** `godot --headless --path . -- --solo --seed=42 --selftest` (integração) e
  `--server` + `--join=127.0.0.1 --selftest-net` (rede).
