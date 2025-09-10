#!/usr/bin/env bash
set -euo pipefail

# Configurar instalação não-interativa para evitar prompts
export DEBIAN_FRONTEND=noninteractive

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
    # Usar sudo se o arquivo for do sistema (em /etc, /usr, etc.)
    if [[ "$file" == /etc/* ]] || [[ "$file" == /usr/* ]] || [[ "$file" == /var/* ]]; then
      sudo cp "$file" "$file.bak.$suffix" 2>/dev/null || {
        print_warn "Não foi possível criar backup de $file (sem permissão)"
        return 1
      }
    else
      cp "$file" "$file.bak.$suffix" 2>/dev/null || {
        print_warn "Não foi possível criar backup de $file"
        return 1
      }
    fi
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
  print_info "DEBUG: MAIN: Chamando configure_keyboard_layout"
  configure_keyboard_layout
  print_info "DEBUG: MAIN: configure_keyboard_layout terminou, chamando configure_system_settings"
  configure_system_settings
  print_info "DEBUG: MAIN: configure_system_settings terminou, chamando configure_gnome_settings"
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
  print_info "✓ Configurações do sistema aplicadas (terminal padrão, atalhos)"
  print_info "✓ GNOME configurado com extensões e preferências"
  print_info "✓ Autostart configurado"
  print_info "✓ Zsh configurado com Starship e Zoxide"
  print_info ""
  print_info "Este script é idempotente e pode ser executado novamente se necessário."
  print_info "Backups foram criados para todos os arquivos modificados."
  print_warn "Recomenda-se reiniciar o sistema para aplicar todas as configurações."
}

update_system() {
  print_step "Atualizando o sistema"
  
  # Pré-configurar iperf3 para não fazer prompts interativos
  print_info "Pré-configurando pacotes para instalação não-interativa..."
  echo 'iperf3 iperf3/start_daemon boolean false' | sudo debconf-set-selections 2>/dev/null || true
  
  # Modernizar formato dos sources para o novo padrão do Ubuntu
  print_info "Modernizando formato dos repositórios APT..."
  if command -v apt >/dev/null 2>&1 && apt --version 2>&1 | grep -q "apt 2."; then
    sudo apt modernize-sources -y 2>/dev/null || print_warn "apt modernize-sources não disponível ou já modernizado"
  fi
  
  print_info "Atualizando lista de pacotes..."
  if ! sudo apt update; then
    print_warn "Alguns repositórios falharam, tentando corrigir..."
    fix_broken_repositories
    sudo apt update || print_warn "Alguns repositórios ainda com problemas, continuando..."
  fi
  
  print_info "Atualizando pacotes instalados..."
  sudo apt upgrade -y --fix-missing || print_warn "Alguns pacotes não puderam ser atualizados"
  
  print_info "Corrigindo dependências quebradas..."
  sudo apt install -f -y
  
  print_info "Removendo pacotes desnecessários..."
  sudo apt autoremove -y
  sudo apt autoclean
  
  print_info "Sistema atualizado com sucesso."
}

fix_broken_repositories() {
  print_info "Corrigindo repositórios com problemas..."
  
  # Detectar versão do Ubuntu
  local ubuntu_version=$(lsb_release -rs 2>/dev/null)
  local ubuntu_codename=$(lsb_release -cs 2>/dev/null)
  
  if [[ "$ubuntu_version" == "25.04" ]] || [[ "$ubuntu_codename" == "plucky" ]]; then
    print_info "Ubuntu 25.04 detectado, aplicando correções específicas..."
    
    # Backup dos sources atuais
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup-$(date +%Y%m%d) 2>/dev/null || true
    
    # Criar sources.list mais conservador para Ubuntu 25.04
    sudo tee /etc/apt/sources.list > /dev/null << EOF
# Ubuntu 25.04 (Plucky Puffin) - Repositórios principais
deb http://archive.ubuntu.com/ubuntu/ plucky main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ plucky main restricted universe multiverse

# Updates
deb http://archive.ubuntu.com/ubuntu/ plucky-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ plucky-updates main restricted universe multiverse

# Security
deb http://security.ubuntu.com/ubuntu/ plucky-security main restricted universe multiverse
deb-src http://security.ubuntu.com/ubuntu/ plucky-security main restricted universe multiverse

# Backports
deb http://archive.ubuntu.com/ubuntu/ plucky-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ plucky-backports main restricted universe multiverse
EOF
    
    print_info "Sources.list atualizado para Ubuntu 25.04"
  fi
  
  # Limpar cache de apt
  sudo apt clean
  sudo rm -rf /var/lib/apt/lists/*
  
  # Recriar cache
  sudo apt update --fix-missing || true
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
  
  # ZapZap (WhatsApp)
  install_zapzap || failed_apps+=("ZapZap")
  
  # Obsidian
  install_obsidian || failed_apps+=("Obsidian")
  
  # Mission Center
  install_mission_center || failed_apps+=("Mission Center")
  
  # Postman
  install_postman || failed_apps+=("Postman")
  
  # VS Code
  install_vscode || failed_apps+=("VS Code")
  
  # Slack
  install_slack || failed_apps+=("Slack")
  
  # JetBrains IDEs (Rider, DataGrip)
  install_jetbrains_ides || failed_apps+=("JetBrains IDEs")
  
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
  
  # Zsh, Starship e Zoxide
  install_zsh_starship_zoxide || failed_apps+=("Zsh/Starship/Zoxide")
  
  # LocalSend
  install_localsend || failed_apps+=("LocalSend")
  
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

install_obsidian() {
  if command -v obsidian >/dev/null 2>&1 || flatpak list | grep -q md.obsidian.Obsidian; then
    print_info "Obsidian já está instalado."
    return 0
  fi
  
  print_info "Instalando Obsidian..."
  if [[ "$auto_install_flatpak" == true ]]; then
    if flatpak install -y flathub md.obsidian.Obsidian 2>/dev/null; then
      print_info "Obsidian instalado com sucesso via Flatpak!"
      return 0
    else
      print_warn "Falha ao instalar Obsidian via Flatpak"
      return 1
    fi
  else
    print_info "Flatpak desabilitado, Obsidian não foi instalado"
    print_info "Para instalar manualmente: flatpak install flathub md.obsidian.Obsidian"
    return 1
  fi
}

install_zapzap() {
  if command -v com.rtosta.zapzap >/dev/null 2>&1 || flatpak list | grep -q com.rtosta.zapzap; then
    print_info "ZapZap já está instalado."
    return 0
  fi
  
  print_info "Instalando ZapZap (WhatsApp Web)..."
  
  if [[ "$auto_install_flatpak" == true ]]; then
    print_info "Instalando ZapZap via Flatpak..."
    if flatpak install -y flathub com.rtosta.zapzap 2>/dev/null; then
      print_info "ZapZap instalado com sucesso via Flatpak!"
      return 0
    else
      print_warn "Falha ao instalar ZapZap via Flatpak"
      return 1
    fi
  else
    print_warn "Flatpak desabilitado, ZapZap não pode ser instalado"
    print_info "Para instalar manualmente: flatpak install flathub com.rtosta.zapzap"
    return 1
  fi
}

install_mission_center() {
  if flatpak list | grep -q io.missioncenter.MissionCenter; then
    print_info "Mission Center já está instalado."
    return 0
  fi
  
  print_info "Instalando Mission Center (Monitor do Sistema)..."
  
  if [[ "$auto_install_flatpak" == true ]]; then
    print_info "Instalando Mission Center via Flatpak..."
    if flatpak install -y flathub io.missioncenter.MissionCenter 2>/dev/null; then
      print_info "Mission Center instalado com sucesso via Flatpak!"
      return 0
    else
      print_warn "Falha ao instalar Mission Center via Flatpak"
      return 1
    fi
  else
    print_warn "Flatpak desabilitado, Mission Center não pode ser instalado"
    print_info "Para instalar manualmente: flatpak install flathub io.missioncenter.MissionCenter"
    return 1
  fi
}

install_postman() {
  if flatpak list | grep -q com.getpostman.Postman; then
    print_info "Postman já está instalado."
    return 0
  fi
  
  print_info "Instalando Postman (API Client)..."
  
  if [[ "$auto_install_flatpak" == true ]]; then
    print_info "Instalando Postman via Flatpak..."
    if flatpak install -y flathub com.getpostman.Postman 2>/dev/null; then
      print_info "Postman instalado com sucesso via Flatpak!"
      return 0
    else
      print_warn "Falha ao instalar Postman via Flatpak"
      return 1
    fi
  else
    print_warn "Flatpak desabilitado, Postman não pode ser instalado"
    print_info "Para instalar manualmente: flatpak install flathub com.getpostman.Postman"
    return 1
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

install_jetbrains_ides() {
  print_info "Instalando JetBrains IDEs via Snap..."
  
  # Verificar se Snap está habilitado
  if [[ "$auto_install_snap" != true ]]; then
    print_warn "Snap desabilitado, JetBrains IDEs não podem ser instalados"
    print_info "Para instalar manualmente:"
    print_info "  sudo snap install rider --classic"
    print_info "  sudo snap install datagrip --classic"
    return 1
  fi
  
  local failed_ides=()
  local install_jobs=()
  
  # Verificar e preparar instalações paralelas
  local rider_needed=false
  local datagrip_needed=false
  
  if snap list rider >/dev/null 2>&1; then
    print_info "JetBrains Rider já está instalado."
  else
    rider_needed=true
  fi
  
  if snap list datagrip >/dev/null 2>&1; then
    print_info "JetBrains DataGrip já está instalado."
  else
    datagrip_needed=true
  fi
  
  # Instalar em paralelo se necessário
  if [[ "$rider_needed" == true ]] || [[ "$datagrip_needed" == true ]]; then
    print_info "Iniciando instalação paralela das IDEs JetBrains..."
    
    # Instalar Rider em background se necessário
    if [[ "$rider_needed" == true ]]; then
      print_info "Instalando JetBrains Rider..."
      (
        if sudo snap install rider --classic 2>/dev/null; then
          echo "rider:success"
        else
          echo "rider:failed"
        fi
      ) &
      install_jobs+=($!)
    fi
    
    # Instalar DataGrip em background se necessário
    if [[ "$datagrip_needed" == true ]]; then
      print_info "Instalando JetBrains DataGrip..."
      (
        if sudo snap install datagrip --classic 2>/dev/null; then
          echo "datagrip:success"
        else
          echo "datagrip:failed"
        fi
      ) &
      install_jobs+=($!)
    fi
    
    # Aguardar conclusão das instalações paralelas
    print_info "Aguardando conclusão das instalações..."
    local results=()
    for job in "${install_jobs[@]}"; do
      wait "$job"
      # Capturar resultado seria mais complexo, então verificamos depois
    done
    
    # Verificar resultados das instalações
    if [[ "$rider_needed" == true ]]; then
      if snap list rider >/dev/null 2>&1; then
        print_info "Rider instalado com sucesso!"
      else
        print_warn "Falha ao instalar Rider"
        failed_ides+=("Rider")
      fi
    fi
    
    if [[ "$datagrip_needed" == true ]]; then
      if snap list datagrip >/dev/null 2>&1; then
        print_info "DataGrip instalado com sucesso!"
      else
        print_warn "Falha ao instalar DataGrip"
        failed_ides+=("DataGrip")
      fi
    fi
  fi
  
  # Relatório de instalação
  if [[ ${#failed_ides[@]} -eq 0 ]]; then
    print_info "Todas as JetBrains IDEs foram instaladas com sucesso!"
    print_info "Auto-updates via Snap habilitados automaticamente"
  else
    print_warn "Algumas IDEs falharam na instalação: ${failed_ides[*]}"
    return 1
  fi
}


update_cursor() {
  print_info "Verificando atualização do Cursor..."
  
  if [[ ! -f "/opt/cursor/cursor.AppImage" ]]; then
    print_warn "Cursor não está instalado. Execute install_cursor() primeiro."
    return 1
  fi
  
  # Instalar dependências se necessário
  if ! command -v jq >/dev/null 2>&1; then
    sudo apt install -y jq
  fi
  
  local api_url="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
  local user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
  local temp_appimage="/tmp/cursor-update.AppImage"
  
  print_info "Obtendo informações da versão mais recente..."
  local download_url=$(curl -sL -A "$user_agent" "$api_url" | jq -r '.url // .downloadUrl')
  
  if [[ -z "$download_url" ]] || [[ "$download_url" == "null" ]]; then
    print_warn "Não foi possível obter URL da API do Cursor para atualização"
    return 1
  fi
  
  # Fazer verificação conservadora primeiro
  print_info "Verificando se há nova versão disponível..."
  local remote_size=$(timeout 10 curl -sI -L -A "$user_agent" "$download_url" 2>/dev/null | grep -i "^content-length:" | awk '{print $2}' | tr -d '\r\n' 2>/dev/null)
  local current_size=$(stat -c%s "/opt/cursor/cursor.AppImage" 2>/dev/null || echo "0")
  
  # Validações rigorosas
  if [[ -z "$remote_size" ]] || [[ ! "$remote_size" =~ ^[0-9]+$ ]]; then
    print_warn "Não foi possível verificar tamanho do arquivo remoto"
    return 1
  fi
  
  if [[ "$remote_size" -eq "$current_size" ]]; then
    print_info "Cursor já está na versão mais recente (${remote_size} bytes)"
    return 0
  fi
  
  if [[ "$remote_size" -lt 1000000 ]]; then
    print_warn "Arquivo remoto muito pequeno (${remote_size} bytes), provavelmente erro"
    return 1
  fi
  
  print_info "Nova versão detectada, baixando atualização..."
  if wget -q --show-progress -O "$temp_appimage" "$download_url"; then
    if [[ -f "$temp_appimage" ]] && file "$temp_appimage" | grep -q "ELF"; then
      # Verificar novamente após download se realmente é diferente
      local downloaded_size=$(stat -c%s "$temp_appimage" 2>/dev/null || echo "1")
      
      if [[ "$downloaded_size" == "$current_size" ]]; then
        print_info "Após verificação, versão baixada é igual à atual"
        rm -f "$temp_appimage"
        return 0
      fi
      
      print_info "Download concluído, atualizando..."
      
      # Backup da versão atual
      sudo cp "/opt/cursor/cursor.AppImage" "/opt/cursor/cursor.AppImage.backup" 2>/dev/null || true
      
      # Substituir AppImage
      sudo mv "$temp_appimage" "/opt/cursor/cursor.AppImage"
      sudo chmod +x "/opt/cursor/cursor.AppImage"
      
      print_info "Cursor atualizado com sucesso!"
      print_info "Feche e reabra o Cursor para usar a nova versão"
      
      return 0
    else
      print_warn "Arquivo baixado não é um AppImage válido"
      rm -f "$temp_appimage"
      return 1
    fi
  else
    print_warn "Falha ao baixar atualização do Cursor"
    return 1
  fi
}

setup_cursor_autoupdate() {
  print_info "Configurando serviço de auto-update do Cursor..."
  
  # Criar script de update
  sudo tee /opt/cursor/cursor-updater.sh > /dev/null <<'EOF'
#!/bin/bash
# Auto-updater para Cursor IDE

LOG_FILE="/var/log/cursor-update.log"

log() {
  echo "$(date): $1" >> "$LOG_FILE"
}

# Verificar se Cursor está instalado
if [[ ! -f "/opt/cursor/cursor.AppImage" ]]; then
  log "Cursor não encontrado, pulando atualização"
  exit 0
fi

# Instalar jq se necessário
if ! command -v jq >/dev/null 2>&1; then
  apt update && apt install -y jq >> "$LOG_FILE" 2>&1
fi

API_URL="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
TEMP_FILE="/tmp/cursor-autoupdate.AppImage"

# Obter URL de download
DOWNLOAD_URL=$(curl -sL -A "$USER_AGENT" "$API_URL" | jq -r '.url // .downloadUrl')

if [[ -z "$DOWNLOAD_URL" ]] || [[ "$DOWNLOAD_URL" == "null" ]]; then
  log "Falha ao obter URL da API do Cursor"
  exit 1
fi

# Verificar se há nova versão antes de baixar
log "Verificando se há nova versão disponível..."
REMOTE_SIZE=$(curl -sI -L -A "$USER_AGENT" "$DOWNLOAD_URL" 2>/dev/null | grep -i content-length | awk '{print $2}' | tr -d '\r' 2>/dev/null)
CURRENT_SIZE=$(stat -c%s "/opt/cursor/cursor.AppImage" 2>/dev/null || echo "0")

if [[ -n "$REMOTE_SIZE" ]] && [[ "$REMOTE_SIZE" != "0" ]] && [[ "$REMOTE_SIZE" == "$CURRENT_SIZE" ]]; then
  log "Cursor já está na versão mais recente (tamanhos iguais: $REMOTE_SIZE bytes)"
  exit 0
elif [[ -z "$REMOTE_SIZE" ]] || [[ "$REMOTE_SIZE" == "0" ]]; then
  log "Não foi possível obter tamanho do arquivo remoto, pulando verificação"
  exit 0
fi

# Baixar nova versão
log "Nova versão detectada, baixando atualização..."
if wget -q -O "$TEMP_FILE" "$DOWNLOAD_URL"; then
  if [[ -f "$TEMP_FILE" ]] && file "$TEMP_FILE" | grep -q "ELF"; then
    # Verificar novamente após download se realmente é diferente
    NEW_SIZE=$(stat -c%s "$TEMP_FILE" 2>/dev/null || echo "1")
    
    if [[ "$NEW_SIZE" != "$CURRENT_SIZE" ]]; then
      log "Atualizando para nova versão..."
      
      # Backup
      cp "/opt/cursor/cursor.AppImage" "/opt/cursor/cursor.AppImage.backup"
      
      # Atualizar
      mv "$TEMP_FILE" "/opt/cursor/cursor.AppImage"
      chmod +x "/opt/cursor/cursor.AppImage"
      
      log "Cursor atualizado com sucesso!"
    else
      log "Após verificação, versão baixada é igual à atual"
      rm -f "$TEMP_FILE"
    fi
  else
    log "Arquivo baixado inválido"
    rm -f "$TEMP_FILE"
  fi
else
  log "Falha ao baixar atualização"
fi
EOF

  sudo chmod +x /opt/cursor/cursor-updater.sh
  
  # Criar systemd service
  sudo tee /etc/systemd/system/cursor-updater.service > /dev/null <<EOF
[Unit]
Description=Cursor IDE Auto Updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/cursor/cursor-updater.sh
User=root
EOF

  # Criar systemd timer (executa diariamente às 09:00)
  sudo tee /etc/systemd/system/cursor-updater.timer > /dev/null <<EOF
[Unit]
Description=Cursor IDE Auto Updater Timer
Requires=cursor-updater.service

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
EOF

  # Habilitar e iniciar timer
  sudo systemctl daemon-reload
  sudo systemctl enable cursor-updater.timer
  sudo systemctl start cursor-updater.timer
  
  print_info "Serviço de auto-update configurado!"
  print_info "Cursor será verificado diariamente para atualizações"
  print_info "Logs em: /var/log/cursor-update.log"
}

install_cursor() {
  # Verificar se Cursor está instalado E se tem o wrapper correto
  if [[ -f "/usr/local/bin/cursor" ]] && [[ -f "/opt/cursor/cursor.AppImage" ]]; then
    # Verificar se o wrapper tem --no-sandbox
    if grep -q "\-\-no-sandbox" /usr/local/bin/cursor 2>/dev/null; then
      print_info "Cursor já está instalado com wrapper correto."
      return 0
    else
      print_info "Cursor encontrado, mas wrapper precisa ser atualizado..."
      # Continuar instalação para corrigir wrapper
    fi
  elif command -v cursor >/dev/null 2>&1; then
    print_info "Cursor encontrado em instalação antiga, reinstalando..."
    # Limpar instalação antiga
    sudo rm -f /usr/local/bin/cursor 2>/dev/null || true
    sudo rm -rf /opt/cursor 2>/dev/null || true
  fi
  
  print_info "Instalando Cursor IDE via AppImage..."
  
  # Instalar dependências necessárias
  if ! command -v jq >/dev/null 2>&1; then
    print_info "Instalando jq para processar API do Cursor..."
    sudo apt install -y jq
  fi
  
  # Instalar libfuse2t64 para Ubuntu 25+ (substitui libfuse2)
  if ! dpkg -s libfuse2t64 &> /dev/null && ! dpkg -s libfuse2 &> /dev/null; then
    print_info "Instalando libfuse2t64 para AppImage..."
    # Tentar libfuse2t64 primeiro (Ubuntu 25+), fallback para libfuse2
    if ! sudo apt install -y libfuse2t64 2>/dev/null; then
      print_info "libfuse2t64 não encontrado, tentando libfuse2..."
      sudo apt install -y libfuse2
    fi
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
      
      # Criar script wrapper para evitar problemas de sandbox
      print_info "Criando script wrapper..."
      sudo tee /usr/local/bin/cursor > /dev/null <<'EOF'
#!/bin/bash
exec /opt/cursor/cursor.AppImage --no-sandbox "$@"
EOF
      sudo chmod +x /usr/local/bin/cursor
      
      # Baixar ícone
      print_info "Baixando ícone do Cursor..."
      sudo wget -q -O "$install_dir/cursor-icon.png" \
        "https://raw.githubusercontent.com/hieutt192/Cursor-ubuntu/main/images/cursor-icon.png"
      
      # Criar desktop entry com flags de sandbox
      print_info "Criando entrada no menu..."
      sudo tee /usr/share/applications/cursor.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Cursor
Exec=/opt/cursor/cursor.AppImage --no-sandbox %F
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
      
      # Configurar serviço de auto-update
      setup_cursor_autoupdate
      
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
    
    # Instalar CLIs de IA após configurar Node.js (com verificação prévia)
    if command -v npm >/dev/null 2>&1; then
      print_info "Instalando CLIs de IA..."
      
      # Lista de CLIs para instalar com verificação prévia
      local ai_clis=(
        "codex:@openai/codex:Codex CLI"
        "claude-code:@anthropic-ai/claude-code:Claude CLI" 
        "gemini:@google/gemini-cli:Gemini CLI"
      )
      
      local install_jobs=()
      local needed_clis=()
      
      # Verificar quais CLIs precisam ser instalados
      for cli_info in "${ai_clis[@]}"; do
        local cmd_name=$(echo "$cli_info" | cut -d: -f1)
        local package_name=$(echo "$cli_info" | cut -d: -f2)
        local display_name=$(echo "$cli_info" | cut -d: -f3)
        
        if ! command -v "$cmd_name" >/dev/null 2>&1; then
          needed_clis+=("$cli_info")
          print_info "Programando instalação: $display_name"
        else
          print_info "$display_name já está instalado"
        fi
      done
      
      # Instalar CLIs em paralelo se necessário
      if [[ ${#needed_clis[@]} -gt 0 ]]; then
        print_info "Instalando ${#needed_clis[@]} CLIs em paralelo..."
        
        for cli_info in "${needed_clis[@]}"; do
          local cmd_name=$(echo "$cli_info" | cut -d: -f1)
          local package_name=$(echo "$cli_info" | cut -d: -f2)
          local display_name=$(echo "$cli_info" | cut -d: -f3)
          
          # Instalar em background
          (
            if npm install -g "$package_name" >/dev/null 2>&1; then
              echo "$display_name:success"
            else
              echo "$display_name:failed"
            fi
          ) &
          install_jobs+=($!)
        done
        
        # Aguardar conclusão de todas as instalações
        print_info "Aguardando conclusão das instalações paralelas..."
        for job in "${install_jobs[@]}"; do
          wait "$job"
        done
        
        # Verificar resultados
        print_info "Verificando instalações:"
        for cli_info in "${needed_clis[@]}"; do
          local cmd_name=$(echo "$cli_info" | cut -d: -f1)
          local display_name=$(echo "$cli_info" | cut -d: -f3)
          
          if command -v "$cmd_name" >/dev/null 2>&1; then
            print_info "$display_name instalado com sucesso"
          else
            print_warn "Falha ao instalar $display_name"
          fi
        done
      else
        print_info "Todos os CLIs de IA já estão instalados"
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
  command -v claude-code >/dev/null 2>&1 && print_info "Claude CLI: instalado"
  command -v gemini >/dev/null 2>&1 && print_info "Gemini CLI: instalado"
  
  return 0
}

install_zsh_starship_zoxide() {
  print_info "Instalando e configurando zsh, starship e zoxide..."
  
  # Instalar zsh
  print_info "Instalando zsh..."
  if ! command -v zsh >/dev/null 2>&1; then
    sudo apt install -y zsh
  else
    print_info "Zsh já está instalado"
  fi
  
  # Instalar starship
  print_info "Instalando starship..."
  if ! command -v starship >/dev/null 2>&1; then
    print_info "Baixando e instalando starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    
    if [[ $? -eq 0 ]] && command -v starship >/dev/null 2>&1; then
      print_info "Starship instalado com sucesso!"
    else
      print_warn "Falha ao instalar starship"
      return 1
    fi
  else
    print_info "Starship já está instalado"
  fi
  
  # Instalar zoxide
  print_info "Instalando zoxide..."
  if ! command -v zoxide >/dev/null 2>&1; then
    print_info "Baixando e instalando zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    
    if [[ $? -eq 0 ]]; then
      print_info "Zoxide instalado com sucesso!"
      # Adicionar zoxide ao PATH para a sessão atual
      if [[ -f "$HOME/.local/bin/zoxide" ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        print_info "PATH atualizado para a sessão atual"
      fi
    else
      print_warn "Falha ao instalar zoxide"
      return 1
    fi
  else
    print_info "Zoxide já está instalado"
  fi
  
  # Configurar zsh
  configure_zsh_config
  
  # Configurar zsh como shell padrão (sem prompt de senha)
  local current_shell=$(basename "$SHELL")
  if [[ "$current_shell" != "zsh" ]]; then
    print_info "Configurando zsh como shell padrão..."
    if command -v zsh >/dev/null 2>&1; then
      local zsh_path=$(which zsh)
      
      # Adicionar zsh aos shells válidos se não estiver
      if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        print_info "Zsh adicionado à lista de shells válidos"
      fi
      
      # Mudar shell padrão usando usermod (não pede senha)
      if sudo usermod -s "$zsh_path" "$USER" 2>/dev/null; then
        print_info "Shell padrão configurado para zsh"
        print_info "Zsh será ativado após o reinício recomendado"
      else
        # Fallback: mostrar instruções manuais
        print_warn "Não foi possível alterar shell automaticamente"
        print_info "Para alterar manualmente execute: chsh -s $zsh_path"
      fi
    fi
  else
    print_info "Zsh já é o shell padrão"
  fi
  
  return 0
}

configure_zsh_config() {
  print_info "Configurando arquivos de configuração do zsh..."
  
  local zshrc_file="$HOME/.zshrc"
  
  # Criar backup do .zshrc existente
  create_backup "$zshrc_file" "zsh-setup"
  
  # Configuração básica do zsh
  cat > "$zshrc_file" << 'EOF'
# Zsh configuration - Ubuntu Setup

# PATH configuration
export PATH="$HOME/.local/bin:$PATH"

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE

# Auto-completion
autoload -Uz compinit
compinit

# Case insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select

# Directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

# Zoxide aliases
alias cd='z'

EOF

  # Adicionar configuração do starship
  if command -v starship >/dev/null 2>&1; then
    echo '' >> "$zshrc_file"
    echo '# Starship prompt' >> "$zshrc_file"
    echo 'eval "$(starship init zsh)"' >> "$zshrc_file"
    print_info "Starship adicionado ao .zshrc"
  fi
  
  # Adicionar configuração do zoxide
  if command -v zoxide >/dev/null 2>&1 || [[ -f "$HOME/.local/bin/zoxide" ]]; then
    echo '' >> "$zshrc_file"
    echo '# Zoxide (better cd)' >> "$zshrc_file"
    echo 'eval "$(zoxide init zsh)"' >> "$zshrc_file"
    print_info "Zoxide adicionado ao .zshrc"
  fi
  
  # Adicionar configuração do mise se estiver instalado
  if command -v mise >/dev/null 2>&1; then
    echo '' >> "$zshrc_file"
    echo '# Mise (development tools manager)' >> "$zshrc_file"
    echo 'eval "$(mise activate zsh)"' >> "$zshrc_file"
    print_info "Mise adicionado ao .zshrc"
  fi
  
  # Criar configuração personalizada do starship
  create_starship_config
  
  print_info "Configuração do zsh criada em $zshrc_file"
}

create_starship_config() {
  if ! command -v starship >/dev/null 2>&1; then
    return 0
  fi
  
  print_info "Criando configuração personalizada do starship..."
  
  local starship_config="$HOME/.config/starship.toml"
  mkdir -p "$HOME/.config"
  
  # Criar backup da configuração existente
  create_backup "$starship_config" "starship-setup"
  
  cat > "$starship_config" << 'EOF'
# Starship configuration - Ubuntu Setup Professional Theme
format = """
[](#2E3440)\
$os\
$username\
[](bg:#3B4252 fg:#2E3440)\
$directory\
[](fg:#3B4252 bg:#434C5E)\
$git_branch\
$git_status\
[](fg:#434C5E bg:#4C566A)\
$c\
$elixir\
$elm\
$golang\
$gradle\
$haskell\
$java\
$julia\
$nodejs\
$nim\
$rust\
$scala\
$python\
$dotnet\
[](fg:#4C566A bg:#5E81AC)\
$docker_context\
[](fg:#5E81AC bg:#81A1C1)\
$time\
[ ](fg:#81A1C1)\
"""

# Disable the blank line at the start of the prompt
add_newline = false

# Username with professional styling
[username]
show_always = true
style_user = "bg:#2E3440 fg:#D8DEE9"
style_root = "bg:#BF616A fg:#D8DEE9"
format = '[ $user ]($style)'
disabled = false

# Alternative OS symbol configuration
# represents the current operating system
[os]
style = "bg:#2E3440 fg:#D8DEE9"
disabled = true # Disabled by default

[directory]
style = "bg:#3B4252 fg:#D8DEE9"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

# Here is how you can shorten some long paths by text replacement
# similar to mapped_locations in Oh My Posh:
[directory.substitutions]
"Documents" = "󰈙 "
"Downloads" = " "
"Music" = " "
"Pictures" = " "
# Keep in mind that the order matters. For example:
# "Important Documents" = " 󰈙 "
# will not be replaced, because "Documents" was already substituted before.
# So either put "Important Documents" before "Documents" or use the substituted version:
# "Important 󰈙 " = " 󰈙 "

[c]
symbol = " "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[docker_context]
symbol = " "
style = "bg:#5E81AC fg:#D8DEE9"
format = '[ $symbol $context ]($style) $path'

[elixir]
symbol = " "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[elm]
symbol = " "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[git_branch]
symbol = ""
style = "bg:#434C5E fg:#D8DEE9"
format = '[ $symbol $branch ]($style)'

[git_status]
style = "bg:#434C5E fg:#D8DEE9"
format = '[$all_status$ahead_behind ]($style)'

[golang]
symbol = " "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[gradle]
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[haskell]
symbol = " "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[java]
symbol = " "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[julia]
symbol = " "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[nodejs]
symbol = ""
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[nim]
symbol = "󰆥 "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[rust]
symbol = ""
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[scala]
symbol = " "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[python]
symbol = " "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[dotnet]
symbol = "󰪮 "
style = "bg:#4C566A fg:#D8DEE9"
format = '[ $symbol ($version) ]($style)'

[time]
disabled = false
time_format = "%H:%M" # Hour:Minute Format
style = "bg:#81A1C1 fg:#2E3440"
format = '[ 🕐 $time ]($style)'
EOF

  print_info "Configuração personalizada do starship criada em $starship_config"
}

install_localsend() {
  if command -v localsend >/dev/null 2>&1 || dpkg -s localsend &> /dev/null; then
    print_info "LocalSend já está instalado."
    return 0
  fi
  
  print_info "Instalando LocalSend..."
  
  # Detectar arquitetura
  local arch=$(dpkg --print-architecture)
  local localsend_arch=""
  
  case "$arch" in
    amd64)
      localsend_arch="x86-64"
      ;;
    arm64)
      localsend_arch="arm-64"
      ;;
    *)
      print_warn "Arquitetura $arch não suportada pelo LocalSend"
      return 1
      ;;
  esac
  
  # Instalar jq se necessário
  if ! command -v jq >/dev/null 2>&1; then
    sudo apt install -y jq
  fi
  
  local api_url="https://api.github.com/repos/localsend/localsend/releases/latest"
  local temp_deb="/tmp/localsend.deb"
  local max_retries=3
  
  for attempt in $(seq 1 $max_retries); do
    print_info "Tentativa $attempt/$max_retries para baixar LocalSend..."
    
    # Obter informações da versão mais recente
    print_info "Obtendo informações da versão mais recente..."
    local release_info=$(curl -sL "$api_url")
    
    if [[ -z "$release_info" ]]; then
      print_warn "Falha ao obter informações do release"
      if [[ $attempt -lt $max_retries ]]; then
        sleep 3
        continue
      else
        return 1
      fi
    fi
    
    # Extrair URL de download para a arquitetura correta
    local download_url=$(echo "$release_info" | jq -r ".assets[] | select(.name | contains(\"linux-${localsend_arch}.deb\")) | .browser_download_url")
    
    if [[ -z "$download_url" ]] || [[ "$download_url" == "null" ]]; then
      print_warn "Não foi possível encontrar arquivo .deb para arquitetura $localsend_arch"
      if [[ $attempt -lt $max_retries ]]; then
        sleep 3
        continue
      else
        return 1
      fi
    fi
    
    print_info "Baixando LocalSend de: $download_url"
    if wget -q --show-progress -O "$temp_deb" "$download_url"; then
      if [[ -f "$temp_deb" ]] && file "$temp_deb" | grep -q "Debian binary package"; then
        print_info "Download concluído, instalando LocalSend..."
        
        if sudo dpkg -i "$temp_deb" 2>/dev/null || sudo apt install -f -y; then
          print_info "LocalSend instalado com sucesso!"
          rm -f "$temp_deb"
          
          # Verificar instalação
          if command -v localsend >/dev/null 2>&1; then
            local version=$(dpkg -s localsend 2>/dev/null | grep "^Version:" | cut -d' ' -f2)
            print_info "LocalSend versão $version instalado"
          fi
          
          return 0
        else
          print_warn "Falha ao instalar pacote .deb do LocalSend"
          rm -f "$temp_deb"
        fi
      else
        print_warn "Arquivo baixado não é um .deb válido"
        rm -f "$temp_deb"
      fi
    else
      print_warn "Falha ao baixar LocalSend"
    fi
    
    if [[ $attempt -lt $max_retries ]]; then
      print_warn "Tentativa $attempt falhou, tentando novamente em 3s..."
      sleep 3
    fi
  done
  
  print_warn "Falha ao instalar LocalSend após $max_retries tentativas"
  print_info "Você pode tentar instalar manualmente em: https://github.com/localsend/localsend/releases/latest"
  return 1
}

# Placeholder para as demais funções
set_locale_ptbr() {
  print_step "Configurando locale (interface EN, formatação BR)"

  # Limpar locale.gen e garantir apenas os locales necessários
  print_info "Otimizando /etc/locale.gen para apenas EN_US e PT_BR..."
  
  # Criar backup do locale.gen atual (opcional)
  create_backup /etc/locale.gen locale || print_warn "Continuando sem backup do locale.gen"
  
  # Criar novo locale.gen otimizado com apenas os locales necessários
  sudo tee /etc/locale.gen > /dev/null << 'EOF'
# Locale configuration optimized by ubuntu-setup
# Only generate necessary locales to speed up locale-gen

# English (US)
en_US.UTF-8 UTF-8

# Portuguese (Brazil) 
pt_BR.UTF-8 UTF-8
EOF

  print_info "Locale configurado: en_US.UTF-8 UTF-8"
  print_info "Locale configurado: pt_BR.UTF-8 UTF-8"

  # Gera apenas os locales específicos que precisamos
  print_info "Gerando locales específicos (EN_US e PT_BR)..."
  sudo locale-gen en_US.UTF-8 pt_BR.UTF-8

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
  print_step "Configurando layout de teclado US International com cedilha"

  # Configurar apenas US International como padrão
  # Layout BR fica opcional (usuário pode adicionar manualmente)
  
  print_info "DEBUG: Obtendo configurações atuais de layout..."
  local current_sources=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null || echo "erro")
  local desired_sources="[('xkb', 'us+intl')]"
  print_info "DEBUG: Current sources: $current_sources"
  
  if [[ "$current_sources" != "$desired_sources" ]] && [[ "$current_sources" != "erro" ]]; then
    print_info "Configurando layout de teclado: US International"
    gsettings set org.gnome.desktop.input-sources sources "$desired_sources" || print_warn "Falha ao definir sources"
    gsettings set org.gnome.desktop.input-sources current 0 || print_warn "Falha ao definir current"
    print_info "Layout configurado: US International"
  else
    print_info "Layout de teclado já está configurado corretamente ou erro na verificação"
  fi
  
  print_info "DEBUG: Removendo atalho de alternância (não necessário com apenas um layout)..."
  # Limpar atalho de alternância já que temos apenas um layout
  gsettings set org.gnome.desktop.wm.keybindings switch-input-source "[]" 2>/dev/null || true

  print_info "DEBUG: Iniciando configuração de cedilha..."
  # Configurar .XCompose para cedilha correto
  configure_xcompose_cedilla || print_warn "Falha na configuração de cedilha"
  
  print_info "DEBUG: Finalizando configuração de teclado..."
  print_info "Layout de teclado configurado:"
  print_info "- Layout: US International"
  print_info "- Cedilha: ' + c = ç"
  print_info "- Para adicionar layout BR: Settings > Keyboard > Input Sources"
  print_info "DEBUG: configure_keyboard_layout concluída"
  print_info "DEBUG: ===== SAINDO DE configure_keyboard_layout ====="
}

configure_xcompose_cedilla() {
  print_info "DEBUG: Iniciando configure_xcompose_cedilla"
  local xcompose_file="$HOME/.XCompose"
  local needs_cedilla_config=true
  
  print_info "DEBUG: Verificando arquivo existente: $xcompose_file"
  print_info "DEBUG: Arquivo existe: $([ -f "$xcompose_file" ] && echo "SIM" || echo "NÃO")"
  
  # Verifica se já tem configuração de cedilha
  if [[ -f "$xcompose_file" ]] && grep -q "ccedilla" "$xcompose_file" 2>/dev/null; then
    needs_cedilla_config=false
    print_info ".XCompose já configurado para cedilha"
  fi
  
  print_info "DEBUG: Precisa configurar cedilha: $needs_cedilla_config"
  
  if [[ "$needs_cedilla_config" == true ]]; then
    print_info "DEBUG: Criando backup se necessário..."
    # Faz backup se o arquivo existe
    create_backup "$xcompose_file" "cedilla" || print_info "DEBUG: Backup não foi necessário ou falhou"
    
    print_info "DEBUG: Criando arquivo .XCompose..."
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
    print_info "DEBUG: Arquivo .XCompose criado com sucesso"
    print_info ".XCompose configurado para cedilha correto"
  fi
  
  print_info "DEBUG: Configurando GTK Compose..."
  # Configura GTK Compose file também
  local gtk_compose="$HOME/.config/gtk-3.0/Compose"
  print_info "DEBUG: GTK Compose path: $gtk_compose"
  
  if [[ ! -f "$gtk_compose" ]] || ! grep -q "ccedilla" "$gtk_compose" 2>/dev/null; then
    print_info "DEBUG: Criando diretório GTK3..."
    mkdir -p "$HOME/.config/gtk-3.0"
    print_info "DEBUG: Copiando arquivo para GTK3..."
    cp "$xcompose_file" "$gtk_compose" 2>/dev/null || true
    print_info "GTK3 Compose configurado para cedilha"
  fi
  
  print_info "DEBUG: configure_xcompose_cedilla concluída"
}

configure_system_settings() {
  print_info "DEBUG: ===== INICIANDO configure_system_settings ====="
  print_step "Configurando configurações do sistema"
  
  # Configurar Ghostty como terminal padrão do sistema
  if command -v ghostty >/dev/null 2>&1; then
    print_info "Configurando Ghostty como terminal padrão do sistema..."
    
    # Definir Ghostty como aplicação padrão para terminal
    gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty' || true
    gsettings set org.gnome.desktop.default-applications.terminal exec-arg '' || true
    
    # Configurar atalho de teclado Ctrl+Alt+T para abrir Ghostty
    print_info "Configurando atalho Ctrl+Alt+T para Ghostty..."
    
    # Remover atalho padrão do gnome-terminal se existir
    gsettings set org.gnome.settings-daemon.plugins.media-keys terminal '[]' || true
    
    # Configurar atalho customizado para Ghostty
    local custom_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['${custom_path}']" || true
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom_path}" name "Open Ghostty Terminal" || true
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom_path}" command "ghostty" || true
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom_path}" binding "<Primary><Alt>t" || true
    
    print_info "Ghostty configurado como terminal padrão com atalho Ctrl+Alt+T"
  else
    print_warn "Ghostty não encontrado, pulando configuração de terminal padrão"
  fi
  
  # Configurar atalhos customizados para aplicações
  print_info "Configurando atalhos de teclado customizados..."
  
  # Obter lista atual de custom keybindings
  local current_keybindings=($(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings | tr -d "[']" | tr ',' '\n' | tr -d ' '))
  local new_keybindings=()
  
  # Se já existe o atalho do Ghostty, incluir na lista
  if [[ " ${current_keybindings[@]} " =~ " /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ " ]]; then
    new_keybindings+=("/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/")
  fi
  
  # Super+F - Abrir File Manager
  local custom1_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
  new_keybindings+=("${custom1_path}")
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom1_path}" name "Open File Manager" || true
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom1_path}" command "nautilus" || true
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom1_path}" binding "<Super>f" || true
  
  # Super+Shift+F - Nova instância do File Manager
  local custom2_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
  new_keybindings+=("${custom2_path}")
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom2_path}" name "New File Manager Window" || true
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom2_path}" command "nautilus --new-window" || true
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom2_path}" binding "<Super><Shift>f" || true
  
  # Super+B - Abrir navegador padrão
  local custom3_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
  new_keybindings+=("${custom3_path}")
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom3_path}" name "Open Browser" || true
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom3_path}" command "xdg-open http://" || true
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom3_path}" binding "<Super>b" || true
  
  # Super+Shift+B - Nova instância do navegador
  local custom4_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
  new_keybindings+=("${custom4_path}")
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom4_path}" name "New Browser Window" || true
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom4_path}" command "google-chrome --new-window" || true
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom4_path}" binding "<Super><Shift>b" || true
  
  # Aplicar todos os keybindings customizados
  local keybindings_str="["
  for kb in "${new_keybindings[@]}"; do
    keybindings_str+="'${kb}',"
  done
  keybindings_str="${keybindings_str%,}]"  # Remove última vírgula e fecha array
  
  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "${keybindings_str}" || true
  
  print_info "Atalhos configurados:"
  print_info "  Super+F: Abrir File Manager"
  print_info "  Super+Shift+F: Nova janela File Manager"
  print_info "  Super+B: Abrir navegador padrão"
  print_info "  Super+Shift+B: Nova janela navegador"
  
  # Configurações adicionais do sistema
  print_info "Aplicando configurações gerais do sistema..."
  
  # Configurar comportamento do botão de energia (suspender)
  gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'suspend' || true
  
  # Configurar fuso horário para São Paulo
  if command -v timedatectl >/dev/null 2>&1; then
    print_info "Configurando fuso horário para America/Sao_Paulo..."
    sudo timedatectl set-timezone America/Sao_Paulo || true
  fi
  
  # Habilitar NTP para sincronização automática de horário
  if command -v timedatectl >/dev/null 2>&1; then
    sudo timedatectl set-ntp true || true
  fi
  
  print_info "Configurações do sistema aplicadas"
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
  
  # Configurações do dash-to-dock (se disponível)
  configure_dash_to_dock
  
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

configure_dash_to_dock() {
  print_info "Configurando dock do Ubuntu..."
  
  # Debug: listar schemas disponíveis
  print_info "Verificando extensões de dock disponíveis..."
  local available_schemas=$(gsettings list-schemas | grep -E "(ubuntu-dock|dash-to-dock)" || echo "nenhuma")
  print_info "Schemas encontrados: $available_schemas"
  
  # Primeiro, desabilitar ubuntu-dock se estiver ativa
  if command -v gnome-extensions >/dev/null 2>&1; then
    if gnome-extensions list --enabled | grep -q "ubuntu-dock@ubuntu.com"; then
      print_info "Desabilitando Ubuntu Dock nativo..."
      gnome-extensions disable "ubuntu-dock@ubuntu.com" 2>/dev/null || true
      print_info "Ubuntu Dock desabilitado"
    fi
  fi
  
  # Verificar se dash-to-dock está disponível
  if gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock"; then
    print_info "Configurando Dash-to-dock..."
    local dock_schema="org.gnome.shell.extensions.dash-to-dock"
    
    # Habilitar dash-to-dock se necessário
    if command -v gnome-extensions >/dev/null 2>&1; then
      if gnome-extensions list | grep -q "dash-to-dock@micxgx.gmail.com"; then
        gnome-extensions enable "dash-to-dock@micxgx.gmail.com" 2>/dev/null || true
        print_info "Dash-to-dock habilitado"
      fi
    fi
  elif gsettings list-schemas | grep -q "org.gnome.shell.extensions.ubuntu-dock"; then
    print_info "Dash-to-dock não disponível, usando Ubuntu Dock (nativo)..."
    local dock_schema="org.gnome.shell.extensions.ubuntu-dock"
    
    # Reabilitar ubuntu-dock se for o único disponível
    if command -v gnome-extensions >/dev/null 2>&1; then
      gnome-extensions enable "ubuntu-dock@ubuntu.com" 2>/dev/null || true
    fi
  else
    print_warn "Nenhuma extensão de dock encontrada"
    print_info "Extensões disponíveis:"
    if command -v gnome-extensions >/dev/null 2>&1; then
      gnome-extensions list | head -5 || echo "Nenhuma extensão listada"
    fi
    print_info "Pulando configuração do dock"
    return 0
  fi
  
  # Configurações básicas e seguras do dock
  print_info "Configurando dock básico..."
  
  # Configurações essenciais para o dock funcionar com mouse
  gsettings set "$dock_schema" dock-position 'BOTTOM' 2>/dev/null || true
  gsettings set "$dock_schema" autohide true 2>/dev/null || true
  gsettings set "$dock_schema" dock-fixed false 2>/dev/null || true
  
  # Configurações mínimas para hover funcionar (valores seguros)
  gsettings set "$dock_schema" intellihide false 2>/dev/null || true
  gsettings set "$dock_schema" require-pressure-to-show false 2>/dev/null || true
  
  print_info "Configurações básicas do dock aplicadas"
  print_warn "Configurações avançadas desabilitadas para evitar erros de compatibilidade"
  
  # Configurações de altura e tamanho - removido pois pode estar fora do range
  
  print_info "Dock configurado:"
  print_info "- Extensão: $(basename "$dock_schema")"
  print_info "- Posição: Parte inferior da tela"
  print_info "- Auto hide: Ativado - aparece com mouse na parte inferior"
  
  print_warn "Para aplicar as mudanças do dock:"
  print_warn "- Wayland: Faça logout/login ou reinicie o sistema"
  print_warn "- X11: Alt+F2, digite 'r', Enter (reinicia GNOME Shell)"
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
  local favorites="['org.gnome.Nautilus.desktop', 'google-chrome.desktop', 'code.desktop', 'org.gnome.Terminal.desktop', 'rider_rider.desktop', 'datagrip_datagrip.desktop', 'io.missioncenter.MissionCenter.desktop', 'com.getpostman.Postman.desktop', 'slack.desktop', 'discord.desktop', 'com.rtosta.zapzap.desktop', 'localsend_app.desktop']"
  gsettings set org.gnome.shell favorite-apps "$favorites"
  
  print_info "Autostart configurado para aplicações selecionadas."
}

main "$@"
