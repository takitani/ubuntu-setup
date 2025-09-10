#!/bin/bash

# Criar launcher do Neovim para desktop e dash
# Determinar qual terminal usar (preferência: ghostty > gnome-terminal)
if command -v ghostty >/dev/null 2>&1; then
  terminal_exec="ghostty -e nvim %F"
elif command -v gnome-terminal >/dev/null 2>&1; then
  terminal_exec="gnome-terminal -- nvim %F"
else
  terminal_exec="x-terminal-emulator -e nvim %F"
fi

cat <<EOF >~/.local/share/applications/Neovim.desktop
[Desktop Entry]
Version=1.0
Name=Neovim
Comment=Editor de texto avançado
Exec=$terminal_exec
Terminal=false
Type=Application
Icon=nvim
Categories=Utilities;TextEditor;Development;
StartupNotify=false
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-dsrc;text/x-pascal;text/x-perl;text/x-python;application/x-php;application/x-httpd-php;application/xml;text/html;text/css;text/x-sql;text/x-diff;
EOF

# Tornar executável
chmod +x ~/.local/share/applications/Neovim.desktop

# Copiar para o Desktop se existir
if [ -d "$HOME/Desktop" ] || [ -d "$HOME/Área de Trabalho" ]; then
  desktop_dir="$HOME/Desktop"
  [ -d "$HOME/Área de Trabalho" ] && desktop_dir="$HOME/Área de Trabalho"
  
  cp ~/.local/share/applications/Neovim.desktop "$desktop_dir/"
  chmod +x "$desktop_dir/Neovim.desktop"
  # Marcar como confiável no GNOME
  gio set "$desktop_dir/Neovim.desktop" metadata::trusted true 2>/dev/null || true
fi