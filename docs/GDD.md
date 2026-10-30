# PolyWorld — GDD (Minecraft x ARK, low-poly, online)

## Pilares
1. Mundo procedural 1 km (já existe) compartilhado por seed entre todos os jogadores.
2. Fauna viva: 10 espécies, genética herdável, reprodução sazonal, domesticação.
3. Flora com ciclo: árvores frutíferas e não frutíferas, frutos por estação, rebrota.
4. Sobrevivência + progressão: coleta, crafting, bases (construção modular), tiers tecnológicos.
5. Online: host-autoritativo, ENet. Modos: listen-server (Host) e dedicado (`--server`).

## Tempo e estações
- Dia = 20 min reais. Estação = 6 dias. Ano = 24 dias (Primavera, Verão, Outono, Inverno).
- Autoload `WorldClock` (Claude) expõe `day`, `time_of_day`, `season`, sinais `season_changed`, `day_started`.
- Estação afeta: frutos (Verão/Outono), cio dos animais, comida disponível, temperatura/neve visual.

## Espécies (10) — Claude
Herbívoros: Coelho, Cervo, Javali, Cabra-da-montanha, Capivara.
Predadores: Lobo, Raposa, Urso.
Aves/outros: Galinha-selvagem (domesticável, ovos), Tartaruga (praia/rio).
Cada espécie: .tres `SpeciesData` (dieta, bioma, estação de cio, gestação, maturidade, drops, domesticável).

## Genética
Genes por indivíduo: tamanho, velocidade, vida, fome, fertilidade, agressividade, cor primária/secundária.
Herança: média dos pais + mutação gaussiana (5%). Cor/tamanho visíveis (malha procedural). Linhagens.

## Itens/Crafting/Construção/Progressão — Codex (ver CONTRACTS.md)
Tiers: Mão → Madeira → Pedra → Ferro → (futuro).
Construção estilo grade (fundação, parede, teto, porta, baú, fogueira, bancada, cama de respawn).
Progressão: XP por ação, nível → pontos → desbloqueio de receitas (árvore de tecnologia).

## Surpresas planejadas
- Estações mudam cor das folhas e deixam o mundo nevado no inverno.
- Animais migram de bioma com a estação; filhotes herdam e mostram cor mista.
- Cama de respawn + base protegida por "reivindicação" de terreno (raio 20 m).
- Cozinha: fruta+carne cozida dão buffs; fome/sede/temperatura.
