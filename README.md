# 🚀 Ubuntu Setup - Ubuntu 25 + GNOME Post-Install Script

[![Ubuntu](https://img.shields.io/badge/Ubuntu-25.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![GNOME](https://img.shields.io/badge/GNOME-47+-4A86CF?style=for-the-badge&logo=gnome&logoColor=white)](https://www.gnome.org)
[![Bash](https://img.shields.io/badge/Bash-5.0+-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

Script de pós-instalação automatizado para Ubuntu 25 com GNOME, otimizado para configuração brasileira com interface em inglês.

## ⚡ Execução Rápida (Remota)

Execute o script diretamente do GitHub sem clonar o repositório:

```bash
# Via curl (recomendado)
bash <(curl -fsSL https://raw.githubusercontent.com/takitani/ubuntu-setup/main/post-install.sh)

# Via wget
bash <(wget -qO- https://raw.githubusercontent.com/takitani/ubuntu-setup/main/post-install.sh)

# Com opções (exemplo: sem Flatpak)
bash <(curl -fsSL https://raw.githubusercontent.com/takitani/ubuntu-setup/main/post-install.sh) --no-flatpak
```

## 📦 O que o script faz

### Sistema e Pacotes
- ✅ Atualiza todo o sistema via `apt update && apt upgrade`
- ✅ Configura repositórios essenciais (universe, multiverse)
- ✅ Instala **Flatpak** e **Snap** (se habilitados)
- ✅ Instala aplicativos desktop essenciais:
  - Google Chrome
  - Discord
  - Visual Studio Code  
  - Slack Desktop
  - JetBrains IDEs (Rider, DataGrip)
  - Cursor IDE
  - LocalSend (transferência de arquivos)
  - ZapZap (WhatsApp Web)
  - Mission Center (monitor do sistema)
  - Postman (API testing)
  - HardInfo (informações de hardware)
  - GNOME Tweaks e Extensions

### Configurações de Localização
- ✅ **Interface em inglês** com **formatação brasileira**
  - `LANG=en_US.UTF-8` (interface)
  - `LC_CTYPE=pt_BR.UTF-8` (suporte a caracteres brasileiros)
- ✅ **Timezone**: America/Sao_Paulo
- ✅ **Teclado US Internacional** com cedilha (ç) funcionando corretamente
  - Layout principal: US International  
  - Layout secundário: BR
  - Alternância: Super + Space
  - Compose key para cedilha

### Configurações do GNOME
- ✅ **Tema escuro** habilitado por padrão
- ✅ **Fontes** otimizadas (Cantarell + Source Code Pro)
- ✅ **Comportamento das janelas** configurado
- ✅ **Touchpad** com tap-to-click e scroll natural
- ✅ **Nautilus** com thumbnails e tree view
- ✅ **Extensões** essenciais instaladas e configuradas:
  - Dash to Dock (parte inferior, auto hide com pressão)
  - Clipboard Indicator
  - System Monitor  
  - User Themes

### Ferramentas de Desenvolvimento
- ✅ **Mise** para gerenciamento de versões
- ✅ **Node.js LTS** instalado via Mise
- ✅ **.NET 9** instalado via Mise
- ✅ **CLIs de IA** instalados:
  - Codex CLI (`@openai/codex`)
  - Claude CLI (`@anthropic-ai/claude-code`)
  - Gemini CLI (`@google/gemini-cli`)
- ✅ **Ghostty Terminal** configurado como padrão
- ✅ **Zsh** com Starship prompt e Zoxide
  - Configuração personalizada do Starship
  - Aliases úteis para Git e desenvolvimento
  - Navegação inteligente com Zoxide (`z` command)
  - Histórico compartilhado e auto-complete

### Autostart e Favoritos
- ✅ **Autostart** de aplicações configurado
- ✅ **Aplicações favoritas** no dock configuradas
- ✅ **Delays** inteligentes para evitar sobrecarga no boot

## 💾 Instalação Local

```bash
# Clone o repositório
git clone https://github.com/takitani/ubuntu-setup.git
cd ubuntu-setup

# Torne o script executável
chmod +x post-install.sh

# Execute
./post-install.sh
```

## 🔧 Opções de Execução

```bash
# Execução padrão (instala Flatpak e Snap)
./post-install.sh

# Sem Flatpak
./post-install.sh --no-flatpak

# Sem Snap  
./post-install.sh --no-snap

# Sem ambos
./post-install.sh --no-flatpak --no-snap

# Ver ajuda
./post-install.sh --help
```

## 🔒 Características de Segurança

- **Backups automáticos**: Cria backup com timestamp de todos os arquivos antes de modificar
- **Idempotente**: Pode ser executado múltiplas vezes sem causar problemas
- **Verificações**: Checa se configurações já existem antes de aplicar
- **Não destrutivo**: Preserva configurações existentes do usuário
- **Tratamento de erros**: Continua execução mesmo se algumas partes falharem

## 📁 Arquivos Modificados

O script modifica os seguintes arquivos (sempre criando backups):

- `/etc/locale.gen` - Configuração de locales
- `~/.XCompose` - Configuração de cedilha
- `~/.config/gtk-3.0/Compose` - Configuração GTK de cedilha
- `~/.config/autostart/` - Aplicações no autostart
- `~/.zshrc` - Configuração do Zsh com Starship e Zoxide
- `~/.config/starship.toml` - Configuração personalizada do Starship
- GNOME Settings via `gsettings` (temas, layouts, comportamento, dash-to-dock)

## 🎨 Aplicativos Instalados

### Via APT/DEB
- Google Chrome (repositório oficial)
- Visual Studio Code (repositório oficial Microsoft)
- LocalSend (GitHub releases - .deb)
- HardInfo
- GNOME Tweaks e Extensions
- Ferramentas base (curl, wget, git, vim, htop, etc.)

### Via Flatpak (se habilitado)
- Discord

### Via Snap (se habilitado)  
- Slack

### Download Direto
- Cursor IDE (AppImage com auto-update)
- Ghostty Terminal (via script)
- Starship prompt (cross-shell prompt)
- Zoxide (smarter cd command)

## 🧹 Script de Limpeza de Snaps

Inclui script adicional para limpar snaps desnecessários:

```bash
# Execute para limpar loops do snap
./clean-snaps.sh
```

## 🐛 Solução de Problemas

### Cedilha não funciona
Certifique-se de:
1. Reiniciar após executar o script
2. Usar `'` + `c` para obter ç
3. Verificar se `LC_CTYPE=pt_BR.UTF-8` está configurado com `locale`

### Extensões não aparecem
1. Faça logout e login novamente
2. Pressione Alt+F2, digite `r` e pressione Enter para reiniciar o GNOME Shell
3. Verifique se as extensões estão habilitadas em `gnome-extensions`

### Aplicativos não iniciam no boot
1. Verifique se os delays estão adequados para seu sistema
2. Confira os arquivos em `~/.config/autostart/`
3. Use `gnome-session-properties` para gerenciar autostart

### Zsh não é o shell padrão após instalação
1. Execute `chsh -s $(which zsh)` manualmente
2. Faça logout e login novamente
3. Verifique com `echo $SHELL` se mudou para zsh

### Starship não aparece
1. Reinicie o terminal ou execute `source ~/.zshrc`
2. Verifique se o comando `starship` está disponível
3. Verifique se o arquivo `~/.config/starship.toml` foi criado

## 📝 Logs e Backups

O script cria backups com sufixos descritivos:
- `arquivo.bak.YYYYMMDDHHMMSS` - Backups com data/hora
- `arquivo.bak.cedilla` - Backups específicos da configuração de cedilha

## ⚙️ Requisitos

- **Ubuntu 25** (pode funcionar em versões anteriores)
- **GNOME Desktop** 
- **Conexão com internet** para downloads
- **Usuário com sudo** (não execute como root)

## 🤝 Contribuindo

Sinta-se à vontade para abrir issues ou pull requests!

### Adicionando novos aplicativos
1. Adicione a função `install_<nome>()` no script
2. Chame a função em `install_desktop_apps()`
3. Teste a instalação e verifique se é idempotente

### Adicionando configurações GNOME
1. Use `gsettings` para configurações
2. Sempre verifique o valor atual antes de alterar
3. Documente o que cada configuração faz

## 📄 Licença

MIT License - veja o arquivo LICENSE para detalhes.

## ⚠️ Avisos

- Execute como **usuário normal**, não como root
- Recomendado para instalações limpas do Ubuntu 25 com GNOME
- Testado com GNOME 47+ 
- Algumas configurações podem requerer logout/login para efeito completo
- O script é voltado para o layout de teclado ABNT2 físico com US International no sistema

## 🔄 Diferenças do Script Arch Original

Este script é baseado no [exarch-setup](https://github.com/takitani/exarch-setup) mas adaptado para Ubuntu:

### Mudanças principais:
- `yay` → `apt` + `flatpak` + `snap`
- Configurações Hyprland → Configurações GNOME
- `localectl` mantido para locale (funciona no Ubuntu também)
- Waybar → GNOME Extensions
- Bindings Hyprland → Atalhos GNOME
- Omarchy → Configurações nativas de logout/shutdown

### Mantido do original:
- Estrutura de logs coloridos
- Sistema de backups
- Configuração de cedilha
- Filosofia idempotente
- Locale BR com interface EN