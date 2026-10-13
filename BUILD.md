# Construção

Gera os executáveis do Code Orbs para Windows e Linux. O jogo em si continua sendo o projeto Godot 4.4 desta pasta. Para só abrir e jogar, use a seção **Instalação** do [README.md](README.md).

## Requisitos

- [Godot 4.4 stable](https://godotengine.org/download/archive)
- Export templates **4.4.stable**, instalados no editor em **Editor → Manage Export Templates → Download and Install**

Os presets usados pelo CI estão em `export_presets.cfg`:

| Preset | Saída no CI |
|---|---|
| `Windows Desktop` | `build/windows/code-orbs.exe` |
| `Linux` | `build/linux/code-orbs.x86_64` |

O preset `Android` existe no arquivo, mas não entra no pipeline de release.

## Pelo editor

1. Abra o projeto (`project.godot`) no Godot 4.4.
2. Espere o import dos recursos terminar.
3. Vá em **Project → Export**.
4. Selecione **Windows Desktop** ou **Linux**.
5. Escolha o caminho do arquivo e exporte em **Export Project** (release).

No Linux, marque o binário como executável: `chmod +x code-orbs.x86_64`.

## Pela linha de comando

Na raiz do repositório, com o binário `godot` da versão 4.4 no `PATH` e os export templates instalados:

```bash
mkdir -p build/windows build/linux
godot --headless --path . --import || true
godot --headless --path . --export-release "Windows Desktop" "$PWD/build/windows/code-orbs.exe"
godot --headless --path . --export-release "Linux" "$PWD/build/linux/code-orbs.x86_64"
chmod +x build/linux/code-orbs.x86_64
```

O primeiro comando importa os recursos. Aviso de fonte nesse passo é esperado. O export falha se o nome do preset ou a versão dos templates não for 4.4.

## No GitHub Actions

O workflow `.github/workflows/godot-ci.yml` repete esses dois exports em todo push na `main` e anexa os ZIPs a uma GitHub Release quando a tag é `v*` (por exemplo `v1.0.0`). A checagem anterior abre o projeto em modo headless e interrompe o build se houver `SCRIPT ERROR`.
