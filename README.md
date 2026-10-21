# Code Orbs

Jogo educativo sobre **tipos de dados** e **variáveis**. O jogador manipula orbes (dados) e os organiza em recipientes (memória/variáveis), com feedback visual e linhas de Python geradas em tempo real.

## Instalação

Há duas formas de usar o jogo. A primeira não exige o Godot.

### A partir de uma release

1. Abra a aba [Releases](../../releases) e baixe o ZIP da versão desejada.
2. Extraia o arquivo.
3. Execute o jogo:
   - **Windows:** `code-orbs.exe`
   - **Linux:** `chmod +x code-orbs.x86_64` e depois `./code-orbs.x86_64`

### A partir do código-fonte

1. Instale o [Godot 4.4](https://godotengine.org/download/archive) (a mesma versão do projeto).
2. Clone este repositório.
3. No Godot, use **Import** e selecione o `project.godot` desta pasta.
4. Abra o projeto e pressione **F5** (ou o botão Play). A cena inicial é o menu principal.

Para gerar os binários de Windows e Linux, siga o [BUILD.md](BUILD.md).

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
| `godot-ci.yml` | Checagem GDScript (headless) + export Windows/Linux; Release na tag `v*` |
| `auto-tag.yml` | Tag automática após CI na `main` (`feat:` → minor, `fix:` → patch) |
| `weekly-digest.yml` | Resumo semanal (Issue) — toda **quarta 20:00** (Brasília) |

Para pular uma release automática, use `[skip release]` na mensagem do commit.
