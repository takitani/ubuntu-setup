#!/bin/bash

# Script para limpar snaps desnecessários e liberar espaço

echo "=== Limpador de Snaps Ubuntu ==="
echo ""

# Mostrar estado atual
echo "Estado atual dos snaps:"
snap list
echo ""
df -h /var/lib/snapd
echo ""

# Snaps que podem ser removidos com segurança
UNNECESSARY_SNAPS=(
    "desktop-security-center"
    "prompting-client" 
    "firmware-updater"
)

# Perguntar sobre Firefox
read -p "Você usa Firefox? (s/n): " use_firefox
if [[ "$use_firefox" != "s" ]]; then
    UNNECESSARY_SNAPS+=("firefox")
fi

# Perguntar sobre Snap Store
read -p "Você usa a Snap Store? (s/n): " use_snapstore
if [[ "$use_snapstore" != "s" ]]; then
    UNNECESSARY_SNAPS+=("snap-store")
fi

echo ""
echo "Snaps que serão removidos:"
printf '%s\n' "${UNNECESSARY_SNAPS[@]}"
echo ""

read -p "Continuar com a remoção? (s/n): " confirm
if [[ "$confirm" != "s" ]]; then
    echo "Cancelado."
    exit 0
fi

# Remover snaps
for snap in "${UNNECESSARY_SNAPS[@]}"; do
    echo "Removendo $snap..."
    sudo snap remove --purge "$snap" 2>/dev/null || echo "  $snap não estava instalado"
done

# Limpar cache de snaps antigos
echo ""
echo "Limpando versões antigas de snaps..."
set -eu
snap list --all | awk '/disabled/{print $1, $3}' |
    while read snapname revision; do
        sudo snap remove "$snapname" --revision="$revision"
    done 2>/dev/null || true

# Limpar cache
echo "Limpando cache do snap..."
sudo rm -rf /var/lib/snapd/cache/*

echo ""
echo "=== Limpeza concluída! ==="
echo ""
echo "Novo estado:"
snap list
echo ""
df -h /var/lib/snapd
echo ""

# Opcional: desabilitar snap completamente
echo "Para DESABILITAR completamente o Snap (não recomendado no Ubuntu):"
echo "  sudo systemctl disable --now snapd.service"
echo "  sudo systemctl disable --now snapd.socket"
echo "  sudo systemctl disable --now snapd.seeded.service"
echo ""
echo "Para REMOVER snap completamente (CUIDADO!):"
echo "  sudo apt purge snapd"