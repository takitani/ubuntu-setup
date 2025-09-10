#!/bin/bash

# Script para atualizar Cursor IDE
# Baseado no ubuntu-setup project

# Cores para logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

update_cursor() {
  print_info "🔄 Verificando atualização do Cursor IDE..."
  
  # Verificar se Cursor está instalado
  if [[ ! -f "/opt/cursor/cursor.AppImage" ]]; then
    print_error "❌ Cursor não está instalado."
    print_info "Para instalar: curl -fsSL https://raw.githubusercontent.com/takitani/ubuntu-setup/main/post-install.sh | bash"
    exit 1
  fi
  
  # Instalar dependências se necessário
  if ! command -v jq >/dev/null 2>&1; then
    print_info "📦 Instalando jq..."
    sudo apt update && sudo apt install -y jq
  fi
  
  # Obter informações da API
  local api_url="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
  local user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
  local temp_appimage="/tmp/cursor-update.AppImage"
  
  print_info "🌐 Consultando API do Cursor..."
  local download_url=$(curl -sL -A "$user_agent" "$api_url" | jq -r '.url // .downloadUrl')
  
  if [[ -z "$download_url" ]] || [[ "$download_url" == "null" ]]; then
    print_error "❌ Não foi possível obter URL da API do Cursor"
    exit 1
  fi
  
  print_info "⬇️  Baixando nova versão do Cursor..."
  if wget -q --show-progress -O "$temp_appimage" "$download_url"; then
    if [[ -f "$temp_appimage" ]] && file "$temp_appimage" | grep -q "ELF"; then
      print_info "📦 Download concluído, atualizando..."
      
      # Backup da versão atual
      print_info "💾 Criando backup da versão atual..."
      sudo cp "/opt/cursor/cursor.AppImage" "/opt/cursor/cursor.AppImage.backup" 2>/dev/null || true
      
      # Substituir AppImage
      sudo mv "$temp_appimage" "/opt/cursor/cursor.AppImage"
      sudo chmod +x "/opt/cursor/cursor.AppImage"
      
      print_success "✅ Cursor atualizado com sucesso!"
      print_info "📝 Feche e reabra o Cursor para usar a nova versão"
      print_info "🔄 Backup anterior salvo em: /opt/cursor/cursor.AppImage.backup"
      
      # Verificar se wrapper está correto
      if [[ -f "/usr/local/bin/cursor" ]] && grep -q "\-\-no-sandbox" /usr/local/bin/cursor; then
        print_info "✅ Wrapper do terminal está correto"
      else
        print_warn "⚠️  Wrapper do terminal pode precisar ser corrigido"
        print_info "Execute o script de instalação para corrigir: https://raw.githubusercontent.com/takitani/ubuntu-setup/main/post-install.sh"
      fi
      
      return 0
    else
      print_error "❌ Arquivo baixado não é um AppImage válido"
      rm -f "$temp_appimage"
      exit 1
    fi
  else
    print_error "❌ Falha ao baixar atualização do Cursor"
    exit 1
  fi
}

# Verificar se está sendo executado como root
if [[ $EUID -eq 0 ]]; then
   print_error "❌ Este script não deve ser executado como root"
   print_info "Execute como usuário normal. O sudo será solicitado quando necessário."
   exit 1
fi

# Mostrar header
echo "🚀 Cursor IDE Updater"
echo "===================="
echo ""

# Executar atualização
update_cursor

echo ""
echo "✨ Atualização concluída!"