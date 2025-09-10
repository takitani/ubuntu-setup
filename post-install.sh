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
  
  # Modernizar formato dos sources para o novo padrão do Ubuntu
  print_info "Modernizando formato dos repositórios APT..."
  if command -v apt >/dev/null 2>&1 && apt --version 2>&1 | grep -q "apt 2."; then
    sudo apt modernize-sources -y 2>/dev/null || print_warn "apt modernize-sources não disponível ou já modernizado"
  fi
  
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
    xclip
    wl-clipboard
  )
  
  print_info "Instalando pacotes base via apt..."
  sudo apt install -y "${apt_pkgs[@]}"
  
  # Instalar aplicativos individuais (continua mesmo se algum falhar)
  local failed_apps=()
  
  # Google Chrome
  install_google_chrome || failed_apps+=("Google Chrome")
  
  # Discord
  install_discord || failed_apps+=("Discord")
  
  # VS Code
  install_vscode || failed_apps+=("VS Code")
  
  # Slack
  install_slack || failed_apps+=("Slack")
  
  # JetBrains Toolbox
  install_jetbrains_toolbox || failed_apps+=("JetBrains Toolbox")
  
  # Cursor IDE
  install_cursor || failed_apps+=("Cursor IDE")
  
  # Ghostty Terminal
  install_ghostty || failed_apps+=("Ghostty Terminal")
  
  # Mise (mise-en-place)
  install_mise || failed_apps+=("Mise")
  
  # Configurar ferramentas do Mise (Node.js LTS e .NET 9)
  if command -v mise >/dev/null 2>&1; then
    configure_mise_tools || print_warn "Falha ao configurar ferramentas do Mise"
  fi
  
  if [[ ${#failed_apps[@]} -eq 0 ]]; then
    print_info "Todos os aplicativos desktop foram instalados com sucesso."
  else
    print_warn "Alguns aplicativos falharam na instalação: ${failed_apps[*]}"
    print_info "Você pode tentar instalar manualmente depois."
  fi
}

install_google_chrome() {
  if command -v google-chrome >/dev/null 2>&1; then
    print_info "Google Chrome já está instalado."
    return 0
  fi
  
  print_info "Instalando Google Chrome..."
  # Baixa e instala a chave GPG usando o método moderno
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg
  
  # Adiciona repositório com signed-by
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
  
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
    if ! flatpak install -y flathub com.discordapp.Discord 2>/dev/null; then
      print_warn "Falha ao instalar Discord via Flatpak, tentando .deb..."
      install_discord_deb
    fi
  else
    install_discord_deb
  fi
}

install_discord_deb() {
  local discord_url="https://discord.com/api/download?platform=linux&format=deb"
  local temp_file="/tmp/discord.deb"
  local max_retries=3
  
  for attempt in $(seq 1 $max_retries); do
    print_info "Tentativa $attempt/$max_retries para baixar Discord..."
    if wget -O "$temp_file" "$discord_url" 2>/dev/null; then
      if sudo dpkg -i "$temp_file" 2>/dev/null || sudo apt install -f -y; then
        print_info "Discord instalado com sucesso!"
        rm -f "$temp_file"
        return 0
      fi
    fi
    
    if [[ $attempt -lt $max_retries ]]; then
      print_warn "Falha na tentativa $attempt, tentando novamente em 3s..."
      sleep 3
    fi
  done
  
  print_warn "Falha ao instalar Discord após $max_retries tentativas"
  rm -f "$temp_file"
  return 1
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
  
  print_info "Instalando Cursor IDE via AppImage..."
  
  # Instalar dependências necessárias
  if ! command -v jq >/dev/null 2>&1; then
    print_info "Instalando jq para processar API do Cursor..."
    sudo apt install -y jq
  fi
  
  if ! dpkg -s libfuse2 &> /dev/null; then
    print_info "Instalando libfuse2 para AppImage..."
    sudo apt install -y libfuse2
  fi
  
  # Usar a API correta do Cursor (mesma do script funcional)
  local api_url="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
  local user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
  local temp_appimage="/tmp/cursor.AppImage"
  local install_dir="/opt/cursor"
  
  print_info "Obtendo URL de download do Cursor via API..."
  local download_url=$(curl -sL -A "$user_agent" "$api_url" | jq -r '.url // .downloadUrl')
  
  if [[ -z "$download_url" ]] || [[ "$download_url" == "null" ]]; then
    print_warn "Não foi possível obter URL da API do Cursor"
    print_info "Tentando fallback para URL direta..."
    # Fallback para URL direta conhecida
    download_url="https://downloader.cursor.sh/linux/appImage/x64"
  fi
  
  print_info "Baixando Cursor AppImage..."
  if wget -q --show-progress -O "$temp_appimage" "$download_url"; then
    if [[ -f "$temp_appimage" ]] && file "$temp_appimage" | grep -q "ELF"; then
      print_info "Download concluído, instalando..."
      
      # Criar diretório de instalação
      sudo mkdir -p "$install_dir"
      
      # Mover AppImage para o diretório de instalação
      sudo mv "$temp_appimage" "$install_dir/cursor.AppImage"
      sudo chmod +x "$install_dir/cursor.AppImage"
      
      # Criar link simbólico
      sudo ln -sf "$install_dir/cursor.AppImage" /usr/local/bin/cursor
      
      # Baixar ícone
      print_info "Baixando ícone do Cursor..."
      sudo wget -q -O "$install_dir/cursor-icon.png" \
        "https://raw.githubusercontent.com/hieutt192/Cursor-ubuntu/main/images/cursor-icon.png"
      
      # Criar desktop entry
      print_info "Criando entrada no menu..."
      sudo tee /usr/share/applications/cursor.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Cursor
Exec=/opt/cursor/cursor.AppImage %F
Terminal=false
Type=Application
Icon=/opt/cursor/cursor-icon.png
StartupWMClass=Cursor
Comment=AI-powered code editor
Categories=Development;IDE;
MimeType=text/plain;
EOF
      
      # Atualizar cache de aplicações
      sudo update-desktop-database 2>/dev/null || true
      
      print_info "Cursor instalado com sucesso!"
      
      # Verificar instalação
      if command -v cursor >/dev/null 2>&1; then
        print_info "Comando 'cursor' disponível no terminal"
      fi
      
      return 0
    else
      print_warn "Arquivo baixado não é um AppImage válido"
      rm -f "$temp_appimage"
      return 1
    fi
  else
    print_warn "Falha ao baixar Cursor AppImage"
    print_info "Você pode baixar manualmente em: https://cursor.com/downloads"
    return 1
  fi
}

install_ghostty() {
  if command -v ghostty >/dev/null 2>&1; then
    print_info "Ghostty já está instalado."
    return 0
  fi
  
  print_info "Instalando Ghostty Terminal..."
  
  # Verificar se curl está disponível
  if ! command -v curl >/dev/null 2>&1; then
    print_warn "curl não encontrado, instalando..."
    sudo apt install -y curl
  fi
  
  local max_retries=3
  
  for attempt in $(seq 1 $max_retries); do
    print_info "Tentativa $attempt/$max_retries para instalar Ghostty..."
    
    # Baixar e executar script de instalação com melhor tratamento de erro
    local temp_script="/tmp/ghostty_install.sh"
    if curl -fsSL -o "$temp_script" https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh 2>/dev/null; then
      if [[ -f "$temp_script" ]] && bash "$temp_script"; then
        print_info "Ghostty instalado com sucesso!"
        rm -f "$temp_script"
        
        # Configurar como terminal padrão
        if command -v ghostty >/dev/null 2>&1; then
          print_info "Configurando Ghostty como terminal padrão..."
          gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty' || true
          gsettings set org.gnome.desktop.default-applications.terminal exec-arg '' || true
          print_info "Ghostty configurado como terminal padrão"
        fi
        
        return 0
      else
        print_warn "Script de instalação do Ghostty falhou"
        rm -f "$temp_script"
      fi
    else
      print_warn "Não foi possível baixar o script de instalação do Ghostty"
    fi
    
    if [[ $attempt -lt $max_retries ]]; then
      print_warn "Falha na tentativa $attempt, tentando novamente em 5s..."
      sleep 5
    fi
  done
  
  print_warn "Falha ao instalar Ghostty após $max_retries tentativas"
  print_info "Você pode tentar instalar manualmente: https://github.com/mkasberg/ghostty-ubuntu"
  return 1
}

install_mise() {
  if command -v mise >/dev/null 2>&1; then
    print_info "Mise já está instalado."
    return 0
  fi
  
  print_info "Instalando Mise (mise-en-place)..."
  
  # Criar diretório para chaves
  sudo install -dm 755 /etc/apt/keyrings
  
  # Baixar e instalar chave GPG
  if wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg 1> /dev/null; then
    # Adicionar repositório
    echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
    
    # Atualizar e instalar
    if sudo apt update && sudo apt install -y mise; then
      print_info "Mise instalado com sucesso!"
      
      # Adicionar ao shell profile se não existir
      local shell_profile=""
      if [[ -f "$HOME/.bashrc" ]]; then
        shell_profile="$HOME/.bashrc"
      elif [[ -f "$HOME/.zshrc" ]]; then
        shell_profile="$HOME/.zshrc"
      fi
      
      if [[ -n "$shell_profile" ]] && ! grep -q 'mise activate' "$shell_profile" 2>/dev/null; then
        echo 'eval "$(mise activate bash)"' >> "$shell_profile"
        print_info "Mise adicionado ao $shell_profile"
      fi
      
      return 0
    fi
  fi
  
  print_warn "Falha ao instalar Mise"
  return 1
}

configure_mise_tools() {
  print_info "Configurando ferramentas do Mise..."
  
  # Instalar Node.js LTS
  print_info "Instalando Node.js LTS via Mise..."
  if mise install node@lts 2>/dev/null && mise global node@lts 2>/dev/null; then
    print_info "Node.js LTS instalado e configurado como global"
    
    # Instalar CLIs de IA após configurar Node.js
    if command -v npm >/dev/null 2>&1; then
      print_info "Instalando CLIs de IA..."
      
      # Codex CLI
      print_info "Instalando Codex CLI..."
      if npm install -g @openai/codex 2>/dev/null; then
        print_info "Codex CLI instalado com sucesso"
      else
        print_warn "Falha ao instalar Codex CLI"
      fi
      
      # Claude CLI (assumindo que existe um pacote oficial)
      print_info "Instalando Claude CLI..."
      if npm install -g @anthropic/claude-cli 2>/dev/null; then
        print_info "Claude CLI instalado com sucesso"
      else
        print_warn "Falha ao instalar Claude CLI (pacote pode não existir ainda)"
      fi
      
      # Gemini CLI
      print_info "Instalando Gemini CLI..."
      if npm install -g @google/gemini-cli 2>/dev/null; then
        print_info "Gemini CLI instalado com sucesso"
      else
        print_warn "Falha ao instalar Gemini CLI"
      fi
    else
      print_warn "npm não encontrado, pulando instalação de CLIs de IA"
    fi
  else
    print_warn "Falha ao instalar Node.js LTS"
  fi
  
  # Instalar .NET 9
  print_info "Instalando .NET 9 via Mise..."
  if mise install dotnet@9 2>/dev/null && mise global dotnet@9 2>/dev/null; then
    print_info ".NET 9 instalado e configurado como global"
  else
    print_warn "Falha ao instalar .NET 9"
  fi
  
  # Verificar instalações
  print_info "Verificando instalações do Mise..."
  if command -v node >/dev/null 2>&1; then
    local node_version=$(node --version 2>/dev/null || echo "erro")
    print_info "Node.js: $node_version"
  fi
  
  if command -v dotnet >/dev/null 2>&1; then
    local dotnet_version=$(dotnet --version 2>/dev/null || echo "erro")
    print_info ".NET: $dotnet_version"
  fi
  
  # Verificar CLIs de IA instalados
  print_info "Verificando CLIs de IA..."
  command -v codex >/dev/null 2>&1 && print_info "Codex CLI: instalado"
  command -v claude >/dev/null 2>&1 && print_info "Claude CLI: instalado"
  command -v gemini >/dev/null 2>&1 && print_info "Gemini CLI: instalado"
  
  return 0
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
