# Jogar online

Rede: ENet (UDP), porta padrão **7777**. O servidor é a autoridade (animais, plantas, inventário);
a ilha é gerada igual em todos os peers a partir da mesma seed.

## Formas de jogar
| Modo | Como |
|---|---|
| Solo | Menu → *Jogar solo* |
| Hospedar (amigos entram no seu PC) | Menu → *Hospedar partida* (ou `-- --host`) |
| Entrar | Menu → *Entrar em partida* + IP (ou `-- --join=IP`) |
| Servidor dedicado (sem janela) | `PolyWorld.exe --headless -- --server --seed=1234 --port=7777` |

## Pela internet
- Abra/encaminhe **UDP 7777** no roteador (ou use uma VPN tipo Tailscale/ZeroTier, sem mexer no roteador).
- VPS Linux: exporte o preset *Linux* (ou rode o projeto com o Godot headless) e use o comando dedicado acima.
- Até 16 jogadores (`Net.MAX_PLAYERS`).

## Argumentos
`--server` `--host` `--join=IP` `--port=N` `--seed=N` `--name=Nome` `--dev`
Depuração: `--shot=arq.png --season=0..3.9 --time=0..1 --animal=deer`.

## O que é sincronizado
Jogadores (20 Hz), animais (10 Hz, pacotes < MTU), spawn/morte/nascimentos, domesticação,
frutos colhidos por estação, relógio do mundo. Inventário/crafting/construção: ver `docs/CONTRACTS.md`.
