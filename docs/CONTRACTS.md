# Contratos de integração (Claude <-> Codex)

## Regra de ouro
Cada lado só edita seus diretórios. Mudou contrato? Edite ESTE arquivo e avise.
Godot 4.x, GDScript tipado, comentários em português curtos. Sem plugins externos.
Godot exe: C:/Users/AndrausFelipeRibeiro/Downloads/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe
Validar: `<exe> --headless --path . --quit-after 300` sem erros de parse.

## Donos
- CODEX: scripts/inventory/, scripts/crafting/, scripts/building/, scripts/progression/, data/items/, data/recipes/, data/structures/, scenes/ui_inv/
- CLAUDE: scripts/net/, scripts/sim/, scripts/fauna/, scripts/flora/, data/species/, main.gd, player.gd

## APIs que o Codex DEVE expor (autoloads)
- `Inventory` (autoload, scripts/inventory/inventory.gd): por jogador (peer id).
  - `add(peer:int, item_id:StringName, amount:int) -> int` (retorna resto não coube)
  - `remove(peer:int, item_id:StringName, amount:int) -> bool`
  - `count(peer:int, item_id:StringName) -> int`
  - sinal `changed(peer:int)`
  - Estado autoritativo no servidor; clientes recebem via RPC.
- `Crafting` (scripts/crafting/crafting.gd): `request_craft(recipe_id)` RPC any_peer->server; receitas em data/recipes/*.tres (`RecipeData`: id, inputs{item:qty}, outputs, station, tier, xp).
- `Building` (scripts/building/building.gd): `request_place(structure_id, transform)` RPC; valida terreno/colisão/reivindicação; `StructureData` em data/structures/*.tres; peças: fundação, parede, teto, porta, baú, fogueira, bancada, cama.
- `Progression` (scripts/progression/progression.gd): `add_xp(peer, amount)`, `level(peer)`, `is_unlocked(peer, recipe_id)`, sinal `leveled_up(peer, level)`.
- Itens: estender `ItemData` (scripts/items/item_data.gd) com campos `tier`, `category`, `food_value`, `tool_type`, `durability` SEM quebrar os campos existentes.
- UI: inventário (E em modo normal; modo dev mantém inventário criativo), crafting, hotbar ligada ao Inventory.

## APIs que o Claude expõe
- `WorldClock`: `season` (0..3), `time_of_day` (0..1), sinais.
- `Net`: `is_server()`, `local_peer()`, `players` dict; `world_seed` sincronizado.
- `Fauna`/`Flora`: drops chamam `Inventory.add(peer, item_id, n)`. IDs usados por mim: raw_meat, hide, bone, egg, feather, apple, berries, wood_log, stick, stone, fiber.
