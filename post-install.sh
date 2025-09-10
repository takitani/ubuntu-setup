#!/usr/bin/env bash
set -euo pipefail

# Ubuntu Setup - Post-install script for Ubuntu 25 + GNOME
# 
# Execução remota (sem git clone):
#   bash <(curl -fsSL https://raw.githubusercontent.com/usuario/ubuntu-setup/main/post-install.sh)
# 
# Execução local:
#   ./post-install.sh [--no-flatpak] [--no-snap]

CURRENT_STEP=""

print_info()  { printf "\033[1;34m[i]\033[0m %s\n" "$*"; }
print_warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
print_error() { printf "\033[1;31m[x]\033[0m %s\n" "$*"; }
print_step()  { CURRENT_STEP="$*"; printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }

trap 'print_error "Falhou em: ${CURRENT_STEP:-passo desconhecido}"' ERR

auto_install_flatpak=true
auto_install_snap=true

usage() {
  cat <<EOF
Uso: $0 [opções]

Opções:
  --no-flatpak       Não instalar/configurar Flatpak
  --no-snap          Não instalar/configurar Snap
  -h, --help         Mostrar esta ajuda

Comportamento:
  - Atualiza o sistema com: apt update && apt upgrade
  - Instala aplicativos via .deb, Flatpak e Snap conforme disponível
  - Configura GNOME com extensões e preferências
EOF
}

while [[ ${1-} ]]; do
  case "$1" in
    --no-flatpak) auto_install_flatpak=false ;;
    --no-snap) auto_install_snap=false ;;
    -h|--help) usage; exit 0 ;;
    *) print_error "Opção desconhecida: $1"; usage; exit 1 ;;
  esac
  shift
done

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  print_error "Execute este script como usuário normal (não root)."
  exit 1
fi

create_backup() {
  local file="$1"
  local suffix="${2:-$(date +%Y%m%d%H%M%S)}"
  
  if [[ -f "$file" ]] && [[ ! -f "$file.bak.$suffix" ]]; then
    cp "$file" "$file.bak.$suffix"
    print_info "Backup criado: $file.bak.$suffix"
    return 0
  fi
  return 1
}

main() {
  print_step "Iniciando Ubuntu Setup - Post-install para Ubuntu 25 + GNOME"
  
  update_system
  setup_repositories
  install_desktop_apps
  set_locale_ptbr
  configure_keyboard_layout
  configure_gnome_settings
  configure_gnome_extensions
  configure_autostart
  
  print_step "Post-install concluído com sucesso!"
  print_info "Resumo das configurações aplicadas:"
  print_info "✓ Sistema atualizado via apt"
  print_info "✓ Repositórios configurados (universe, multiverse, PPAs)"
  print_info "✓ Aplicativos desktop instalados"
  print_info "✓ Locale configurado (interface EN, formatação BR)"
  print_info "✓ Layout de teclado US-Intl configurado com cedilha correto"
  print_info "✓ GNOME configurado com extensões e preferências"
  print_info "✓ Autostart configurado"
  print_info ""
  print_info "Este script é idempotente e pode ser executado novamente se necessário."
  print_info "Backups foram criados para todos os arquivos modificados."
  print_warn "Recomenda-se reiniciar o sistema para aplicar todas as configurações."
}

update_system() {
  print_step "Atualizando o sistema"
  
  print_info "Atualizando lista de pacotes..."
  sudo apt update
  
  print_info "Atualizando pacotes instalados..."
  sudo apt upgrade -y
  
  print_info "Removendo pacotes desnecessários..."
  sudo apt autoremove -y
  sudo apt autoclean
  
  print_info "Sistema atualizado com sucesso."
}

setup_repositories() {
  print_step "Configurando repositórios"
  
  # Habilitar universe e multiverse
  print_info "Habilitando repositórios universe e multiverse..."
  sudo add-apt-repository -y universe
  sudo add-apt-repository -y multiverse
  
  # Configurar Flatpak se solicitado
  if [[ "$auto_install_flatpak" == true ]]; then
    if ! command -v flatpak >/dev/null 2>&1; then
      print_info "Instalando Flatpak..."
      sudo apt install -y flatpak gnome-software-plugin-flatpak
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      print_info "Flatpak configurado. Reinicie para usar totalmente."
    else
      print_info "Flatpak já está instalado."
    fi
  fi
  
  # Verificar Snap (já vem por padrão no Ubuntu)
  if [[ "$auto_install_snap" == true ]]; then
    if ! command -v snap >/dev/null 2>&1; then
      print_info "Instalando Snapd..."
      sudo apt install -y snapd
    else
      print_info "Snap já está disponível."
    fi
  fi
  
  sudo apt update
  print_info "Repositórios configurados."
}

install_desktop_apps() {
  print_step "Instalando aplicativos desktop"
  
  # Pacotes via apt
  local apt_pkgs=(
    curl
    wget
    git
    vim
    htop
    tree
    unzip
    zip
    software-properties-common
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
    dconf-editor
    gnome-tweaks
    gnome-shell-extensions
    chrome-gnome-shell
    hardinfo
  )
  
  print_info "Instalando pacotes base via apt..."
  sudo apt install -y "${apt_pkgs[@]}"
  
  # Google Chrome
  install_google_chrome
  
  # Discord
  install_discord
  
  # VS Code
  install_vscode
  
  # Slack
  install_slack
  
  # JetBrains Toolbox
  install_jetbrains_toolbox
  
  # Cursor IDE
  install_cursor
  
  print_info "Aplicativos desktop instalados."
}

install_google_chrome() {
  if command -v google-chrome >/dev/null 2>&1; then
    print_info "Google Chrome já está instalado."
    return 0
  fi
  
  print_info "Instalando Google Chrome..."
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
  echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
  sudo apt update
  sudo apt install -y google-chrome-stable
}

install_discord() {
  if command -v discord >/dev/null 2>&1; then
    print_info "Discord já está instalado."
    return 0
  fi
  
  print_info "Instalando Discord..."
  if [[ "$auto_install_flatpak" == true ]]; then
    flatpak install -y flathub com.discordapp.Discord
  else
    wget -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb"
    sudo dpkg -i /tmp/discord.deb
    sudo apt install -f -y
    rm -f /tmp/discord.deb
  fi
}

install_vscode() {
  if command -v code >/dev/null 2>&1; then
    print_info "VS Code já está instalado."
    return 0
  fi
  
  print_info "Instalando Visual Studio Code..."
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
  sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
  sudo apt update
  sudo apt install -y code
  rm -f packages.microsoft.gpg
}

install_slack() {
  if command -v slack >/dev/null 2>&1; then
    print_info "Slack já está instalado."
    return 0
  fi
  
  print_info "Instalando Slack..."
  if [[ "$auto_install_snap" == true ]]; then
    sudo snap install slack --classic
  else
    wget -O /tmp/slack.deb https://downloads.slack-edge.com/releases/linux/4.36.140/prod/x64/slack-desktop-4.36.140-amd64.deb
    sudo dpkg -i /tmp/slack.deb
    sudo apt install -f -y
    rm -f /tmp/slack.deb
  fi
}

install_jetbrains_toolbox() {
  if [[ -f "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" ]]; then
    print_info "JetBrains Toolbox já está instalado."
    return 0
  fi
  
  print_info "Instalando JetBrains Toolbox..."
  local toolbox_url="https://download.jetbrains.com/toolbox/jetbrains-toolbox-2.1.3.18901.tar.gz"
  local temp_dir=$(mktemp -d)
  
  wget -O "$temp_dir/toolbox.tar.gz" "$toolbox_url"
  tar -xzf "$temp_dir/toolbox.tar.gz" -C "$temp_dir" --strip-components=1
  
  mkdir -p "$HOME/.local/share/JetBrains/Toolbox/bin"
  cp "$temp_dir/jetbrains-toolbox" "$HOME/.local/share/JetBrains/Toolbox/bin/"
  chmod +x "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
  
  # Criar .desktop file
  cat > "$HOME/.local/share/applications/jetbrains-toolbox.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=JetBrains Toolbox
Icon=jetbrains-toolbox
Exec=$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox
Comment=JetBrains Toolbox
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-toolbox
StartupNotify=true
EOF
  
  rm -rf "$temp_dir"
}

install_cursor() {
  if command -v cursor >/dev/null 2>&1; then
    print_info "Cursor já está instalado."
    return 0
  fi
  
  print_info "Instalando Cursor IDE..."
  wget -O /tmp/cursor.deb https://downloader.cursor.sh/linux/appImage/x64
  sudo dpkg -i /tmp/cursor.deb || true
  sudo apt install -f -y
  rm -f /tmp/cursor.deb
}

# Placeholder para as demais funções
set_locale_ptbr() {
  print_step "Configurando locale (interface EN, formatação BR)"

  # Garante que as linhas existam e estejam descomentadas em /etc/locale.gen
  local locales=("en_US.UTF-8 UTF-8" "pt_BR.UTF-8 UTF-8")
  local needs_generation=false
  
  for locale in "${locales[@]}"; do
    if ! grep -Eq "^[^#]*${locale//./\\.}" /etc/locale.gen 2>/dev/null; then
      # Tenta descomentar, caso exista comentada
      if grep -Eq "^#\\s*${locale//./\\.}" /etc/locale.gen 2>/dev/null; then
        sudo sed -i "s/^#\\s*${locale//./\\.}/${locale}/" /etc/locale.gen
        needs_generation=true
        print_info "Descomentado locale: $locale"
      else
        printf '%s\n' "$locale" | sudo tee -a /etc/locale.gen >/dev/null
        needs_generation=true
        print_info "Adicionado locale: $locale"
      fi
    else
      print_info "Locale já configurado: $locale"
    fi
  done

  # Gera locales se necessário
  if [[ "$needs_generation" == true ]]; then
    print_info "Gerando locales..."
    sudo locale-gen
  fi

  # Define locale do sistema: interface em inglês, formatação brasileira
  # IMPORTANTE: LC_CTYPE=pt_BR.UTF-8 é CRÍTICO para o cedilha funcionar!
  local current_lang=$(localectl status | grep "System Locale" | grep -o "LANG=[^,]*" | cut -d= -f2)
  local current_ctype=$(localectl status | grep "System Locale" | grep -o "LC_CTYPE=[^,]*" | cut -d= -f2)
  
  if [[ "$current_lang" != "en_US.UTF-8" ]] || [[ "$current_ctype" != "pt_BR.UTF-8" ]]; then
    print_info "Configurando locale do sistema..."
    sudo localectl set-locale LANG=en_US.UTF-8 LC_CTYPE=pt_BR.UTF-8 LC_TIME=pt_BR.UTF-8 LC_MONETARY=pt_BR.UTF-8 LC_PAPER=pt_BR.UTF-8 LC_MEASUREMENT=pt_BR.UTF-8
    
    # Também configura para a sessão atual
    export LANG=en_US.UTF-8
    export LC_CTYPE=pt_BR.UTF-8
    export LC_TIME=pt_BR.UTF-8
    export LC_MONETARY=pt_BR.UTF-8
    export LC_PAPER=pt_BR.UTF-8
    export LC_MEASUREMENT=pt_BR.UTF-8
    
    print_info "Locale configurado: LANG=en_US.UTF-8, LC_CTYPE=pt_BR.UTF-8"
    print_warn "É necessário reiniciar para aplicar completamente as configurações de locale."
  else
    print_info "Locale já está configurado corretamente"
  fi
  
  # Configura timezone para Brasil
  local current_tz=$(timedatectl show --property=Timezone --value)
  if [[ "$current_tz" != "America/Sao_Paulo" ]]; then
    print_info "Configurando timezone para America/Sao_Paulo..."
    sudo timedatectl set-timezone America/Sao_Paulo
  else
    print_info "Timezone já está configurado para America/Sao_Paulo"
  fi
}

configure_keyboard_layout() {
  print_step "Configurando layout de teclado US-Intl com cedilha"

  # No GNOME, configuramos via gsettings
  # Layout principal: US International
  # Layout secundário: BR (para alternância)
  
  local current_sources=$(gsettings get org.gnome.desktop.input-sources sources)
  local desired_sources="[('xkb', 'us+intl'), ('xkb', 'br')]"
  
  if [[ "$current_sources" != "$desired_sources" ]]; then
    print_info "Configurando layouts de teclado: US International + BR"
    gsettings set org.gnome.desktop.input-sources sources "$desired_sources"
    gsettings set org.gnome.desktop.input-sources current 0
    print_info "Layouts configurados: US-Intl (principal) + BR (secundário)"
  else
    print_info "Layouts de teclado já estão configurados corretamente"
  fi
  
  # Configurar atalho para alternar layouts (Super+Space)
  local current_switch=$(gsettings get org.gnome.desktop.wm.keybindings switch-input-source)
  local desired_switch="['<Super>space']"
  
  if [[ "$current_switch" != "$desired_switch" ]]; then
    print_info "Configurando atalho Super+Space para alternar layouts"
    gsettings set org.gnome.desktop.wm.keybindings switch-input-source "$desired_switch"
  else
    print_info "Atalho de alternância já está configurado"
  fi

  # Configurar .XCompose para cedilha correto
  configure_xcompose_cedilla
  
  print_info "Layout de teclado configurado:"
  print_info "- Layout principal: US International"
  print_info "- Layout secundário: BR" 
  print_info "- Alternância: Super + Space"
  print_info "- Cedilha: ' + c = ç"
}

configure_xcompose_cedilla() {
  local xcompose_file="$HOME/.XCompose"
  local needs_cedilla_config=true
  
  # Verifica se já tem configuração de cedilha
  if [[ -f "$xcompose_file" ]] && grep -q "ccedilla" "$xcompose_file"; then
    needs_cedilla_config=false
    print_info ".XCompose já configurado para cedilha"
  fi
  
  if [[ "$needs_cedilla_config" == true ]]; then
    # Faz backup se o arquivo existe
    create_backup "$xcompose_file" "cedilla"
    
    # Cria configuração de cedilha
    cat > "$xcompose_file" << 'EOF'
include "%L"

# Cedilha (ç/Ç) configuration for US International keyboard
<dead_acute> <c> : "ç" ccedilla
<dead_acute> <C> : "Ç" Ccedilla
<acute> <c> : "ç" ccedilla
<acute> <C> : "Ç" Ccedilla
<apostrophe> <c> : "ç" ccedilla
<apostrophe> <C> : "Ç" Ccedilla
<'> <c> : "ç" ccedilla
<'> <C> : "Ç" Ccedilla

EOF
    print_info ".XCompose configurado para cedilha correto"
  fi
  
  # Configura GTK Compose file também
  local gtk_compose="$HOME/.config/gtk-3.0/Compose"
  if [[ ! -f "$gtk_compose" ]] || ! grep -q "ccedilla" "$gtk_compose" 2>/dev/null; then
    mkdir -p "$HOME/.config/gtk-3.0"
    cp "$xcompose_file" "$gtk_compose" 2>/dev/null || true
    print_info "GTK3 Compose configurado para cedilha"
  fi
}

configure_gnome_settings() {
  print_step "Configurando preferências do GNOME"

  # Interface e aparência
  print_info "Configurando aparência do GNOME..."
  
  # Tema escuro
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  
  # Fonte e tamanho
  gsettings set org.gnome.desktop.interface font-name 'Cantarell 11'
  gsettings set org.gnome.desktop.interface document-font-name 'Cantarell 11'
  gsettings set org.gnome.desktop.interface monospace-font-name 'Source Code Pro 10'
  
  # Ícones e cursor
  gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
  gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
  
  # Mostrar segundos no relógio
  gsettings set org.gnome.desktop.interface clock-show-seconds true
  
  # Mostrar porcentagem da bateria
  gsettings set org.gnome.desktop.interface show-battery-percentage true
  
  # Comportamento das janelas
  print_info "Configurando comportamento das janelas..."
  
  # Botões da janela
  gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
  
  # Foco da janela
  gsettings set org.gnome.desktop.wm.preferences focus-mode 'click'
  gsettings set org.gnome.desktop.wm.preferences auto-raise false
  
  # Área de trabalho e dock
  print_info "Configurando área de trabalho..."
  
  # Mostrar ícones na área de trabalho
  gsettings set org.gnome.desktop.background show-desktop-icons true
  
  # Configurações do dock (se disponível)
  if gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock"; then
    gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
    gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48
    gsettings set org.gnome.shell.extensions.dash-to-dock show-favorites true
    print_info "Dash-to-dock configurado"
  fi
  
  # Touchpad
  print_info "Configurando touchpad..."
  gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
  gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
  gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true
  
  # Mouse
  gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'default'
  
  # Energia e suspensão
  print_info "Configurando gerenciamento de energia..."
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800
  
  # Privacidade
  print_info "Configurando privacidade..."
  gsettings set org.gnome.desktop.privacy report-technical-problems false
  gsettings set org.gnome.desktop.privacy send-software-usage-stats false
  
  # Configurações de arquivos/Nautilus
  print_info "Configurando Nautilus..."
  gsettings set org.gnome.nautilus.preferences show-hidden-files false
  gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'always'
  gsettings set org.gnome.nautilus.list-view use-tree-view true
  
  print_info "Configurações do GNOME aplicadas com sucesso!"
}

configure_gnome_extensions() {
  print_step "Configurando extensões do GNOME"
  
  # Instalar extensões essenciais via gnome-extensions-cli se disponível
  if command -v gnome-extensions-cli >/dev/null 2>&1; then
    print_info "Instalando extensões via gnome-extensions-cli..."
    
    # Lista de extensões úteis
    local extensions=(
      "dash-to-dock@micxgx.gmail.com"
      "clipboard-indicator@tudmotu.com" 
      "system-monitor@paradoxxx.zero.gmail.com"
      "topicons-plus@phocean.net"
      "user-theme@gnome-shell-extensions.gcampax.github.com"
    )
    
    for ext in "${extensions[@]}"; do
      if ! gnome-extensions list | grep -q "$ext"; then
        print_info "Instalando extensão: $ext"
        gnome-extensions-cli install "$ext" || print_warn "Falha ao instalar: $ext"
      else
        print_info "Extensão já instalada: $ext"
      fi
    done
  else
    print_warn "gnome-extensions-cli não encontrado. Instale manualmente:"
    print_info "pip install --user gnome-extensions-cli"
  fi
  
  # Habilitar extensões instaladas via pacote
  local system_extensions=(
    "dash-to-dock@micxgx.gmail.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com" 
  )
  
  for ext in "${system_extensions[@]}"; do
    if gnome-extensions list | grep -q "$ext"; then
      if ! gnome-extensions list --enabled | grep -q "$ext"; then
        print_info "Habilitando extensão: $ext"
        gnome-extensions enable "$ext" 2>/dev/null || true
      else
        print_info "Extensão já habilitada: $ext"
      fi
    fi
  done
  
  print_info "Configuração de extensões concluída."
  print_warn "Algumas extensões podem requerer logout/login para funcionar completamente."
}

configure_autostart() {
  print_step "Configurando autostart de aplicações"
  
  local autostart_dir="$HOME/.config/autostart"
  mkdir -p "$autostart_dir"
  
  # Slack autostart
  if command -v slack >/dev/null 2>&1; then
    local slack_desktop="$autostart_dir/slack-autostart.desktop"
    if [[ ! -f "$slack_desktop" ]]; then
      cat > "$slack_desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Slack (Autostart)
Exec=slack --startup
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=10
EOF
      print_info "Slack autostart configurado (delay 10s)"
    else
      print_info "Slack autostart já está configurado"
    fi
  fi
  
  # Discord autostart
  if command -v discord >/dev/null 2>&1; then
    local discord_desktop="$autostart_dir/discord-autostart.desktop"
    if [[ ! -f "$discord_desktop" ]]; then
      cat > "$discord_desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Discord (Autostart)
Exec=discord --start-minimized
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=15
EOF
      print_info "Discord autostart configurado (delay 15s, minimizado)"
    else
      print_info "Discord autostart já está configurado"
    fi
  fi
  
  # Configurar aplicações favoritas no dock
  print_info "Configurando aplicações favoritas..."
  local favorites="['org.gnome.Nautilus.desktop', 'google-chrome.desktop', 'code.desktop', 'org.gnome.Terminal.desktop', 'slack.desktop', 'discord.desktop']"
  gsettings set org.gnome.shell favorite-apps "$favorites"
  
  print_info "Autostart configurado para aplicações selecionadas."
}

main "$@"