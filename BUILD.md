# Construção

Gera os executáveis do Code Orbs para Windows, Linux e Web. O jogo em si continua sendo o projeto Godot 4.4 desta pasta. Para só abrir e jogar, use a seção **Instalação** do [README.md](README.md). A build Web das releases vai para o [GitHub Pages](https://corumbsdev.github.io/Code-Orbs/) e para o [itch.io](https://itch.io/) (canal `html5`).

## Requisitos

- [Godot 4.4 stable](https://godotengine.org/download/archive)
- Export templates **4.4.stable**, instalados no editor em **Editor → Manage Export Templates → Download and Install**

Os presets usados pelo CI estão em `export_presets.cfg`:

| Preset | Saída no CI |
|---|---|
| `Windows Desktop` | `build/windows/code-orbs.exe` |
| `Linux` | `build/linux/code-orbs.x86_64` |
| `Web` | `build/web/index.html` (só em tags `v*`; GitHub Pages + itch.io) |

O preset `Android` existe no arquivo, mas não entra no pipeline de release.

## Pelo editor

1. Abra o projeto (`project.godot`) no Godot 4.4.
2. Espere o import dos recursos terminar.
3. Vá em **Project → Export**.
4. Selecione **Windows Desktop**, **Linux** ou **Web**.
5. Escolha o caminho do arquivo e exporte em **Export Project** (release).

No Linux, marque o binário como executável: `chmod +x code-orbs.x86_64`.

## Pela linha de comando

Na raiz do repositório, com o binário `godot` da versão 4.4 no `PATH` e os export templates instalados:

```bash
mkdir -p build/windows build/linux build/web
godot --headless --path . --import || true
godot --headless --path . --export-release "Windows Desktop" "$PWD/build/windows/code-orbs.exe"
godot --headless --path . --export-release "Linux" "$PWD/build/linux/code-orbs.x86_64"
godot --headless --path . --export-release "Web" "$PWD/build/web/index.html"
chmod +x build/linux/code-orbs.x86_64
```

O primeiro comando importa os recursos. Aviso de fonte nesse passo é esperado. O export falha se o nome do preset ou a versão dos templates não for 4.4.

Para servir a pasta Web localmente (headers CORS simples), use um servidor HTTP estático na pasta `build/web`.

## No GitHub Actions

O workflow `.github/workflows/godot-ci.yml` roda em todo push na `main` (e em tags `v*`):

1. `python3 scripts/check_docs.py` — confere se README/BUILD batem com a versão do Godot, presets e nomes dos binários
2. `python3 tools/gen_plano_aula_sequence.py` no runner host — garante que `sequencia_base.tres` está sincronizada (sem `apt` dentro do container Godot)
3. `scripts/ci_setup_godot.sh` — prepara o Godot 4.4 e os export templates no runner
4. Abre o projeto em modo headless (smoke) e interrompe o build se houver `SCRIPT ERROR`
5. Exporta Windows e Linux (mesmos presets da tabela acima)
6. Em tags `v*` (ex.: `v1.0.0`): anexa os ZIPs a uma GitHub Release, exporta **Web**, faz deploy no GitHub Pages e publica no itch.io (`butler push …:html5`)

Pages (admin do repo): Settings → Pages → Source = **GitHub Actions**.

Secrets do repositório para o itch.io:

| Secret | Exemplo | Uso |
|---|---|---|
| `ITCH_API_KEY` | chave da API do itch (Account → API keys) | autenticação do butler |
| `ITCH_GAME` | `usuario/code-orbs` | alvo `usuario/jogo:html5` |

O preset `Android` continua só no editor; o pipeline de release não o exporta.
