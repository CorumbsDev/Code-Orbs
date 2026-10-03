# Code Orbs

Jogo educativo sobre **tipos de dados** e **variáveis**. O jogador manipula orbes (dados) e os organiza em recipientes (memória/variáveis), com feedback visual e linhas de Python geradas em tempo real.

## Requisitos

- [Godot 4.4](https://godotengine.org/download/archive), **ou**
- builds prontos na aba [Releases](../../releases)

Abra a pasta do projeto no editor Godot (ou execute o binário da release).

## Mecânicas

- **Orbes** — cada tipo de dado (int, float, bool, etc.)
- **Recipientes de memória** — variáveis com tipagem
- **Console** — ações viram código Python
- **Criador de fases** — sequências, conquistas e QR

## Stack

| Camada | Tecnologia |
|---|---|
| Engine | Godot 4.4 |
| Lógica do jogo | GDScript |
| Linguagem alvo (console) | Python |

## CI e releases

Workflows em `.github/workflows/`:

| Workflow | Função |
|---|---|
| `godot-ci.yml` | Smoke test + export Windows/Linux; Release na tag `v*` |
| `auto-tag.yml` | Tag automática após CI na `main` (`feat:` → minor, `fix:` → patch) |
| `weekly-digest.yml` | Resumo semanal (Issue) — toda **quarta 19:00** (Brasília) |

Para pular uma release automática, use `[skip release]` na mensagem do commit.
