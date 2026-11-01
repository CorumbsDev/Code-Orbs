#!/usr/bin/env bash
# Prepara editor settings + export templates da imagem barichello/godot-ci.
# Seguro com HOME=/github/home (Actions) e HOME=/root (docker local).
set -euo pipefail

mkdir -p "${HOME}"
mkdir -p "${HOME}/.local/share/godot/export_templates"
mkdir -p "${HOME}/.config"

git config --global --add safe.directory "${GITHUB_WORKSPACE:-$(pwd)}"

_godot_relocate() {
	local src="$1"
	local dst="$2"
	if [ ! -e "$src" ]; then
		return 0
	fi
	local src_real dst_real
	src_real="$(readlink -f "$src")"
	dst_real="$(readlink -f "$dst" 2>/dev/null || true)"
	if [ -n "$dst_real" ] && [ "$src_real" = "$dst_real" ]; then
		# Já está no lugar (ex.: HOME=/root).
		return 0
	fi
	mkdir -p "$(dirname "$dst")"
	rm -rf "$dst"
	mv "$src" "$dst"
}

_godot_relocate "/root/.config/godot" "${HOME}/.config/godot"
_godot_relocate \
	"/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
	"${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

echo "Godot setup OK (HOME=${HOME}, version=${GODOT_VERSION})."
