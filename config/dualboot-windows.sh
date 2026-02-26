#!/usr/bin/env bash
# Configurar Windows no menu GRUB (dual-boot)
# Usa kdialog para interface gráfica no KDE Plasma

set -e

TITLE="Dual Boot — Windows"
ICON="yast-kernel"

# Verifica se é root, senão pede senha via pkexec
if [ "$EUID" -ne 0 ]; then
    exec pkexec "$0" "$@"
fi

# Verifica dependências
if ! command -v os-prober &>/dev/null; then
    kdialog --icon "$ICON" --title "$TITLE" \
        --error "os-prober não encontrado.\n\nInstale com: sudo dnf5 install os-prober"
    exit 1
fi

# Detecta Windows
kdialog --icon "$ICON" --title "$TITLE" \
    --passivepopup "Procurando instalação do Windows..." 3

WIN_PART=$(os-prober 2>/dev/null | head -n 1 | cut -d: -f1 | cut -d@ -f1)

if [ -z "$WIN_PART" ]; then
    kdialog --icon "$ICON" --title "$TITLE" \
        --error "Nenhuma instalação do Windows foi detectada.\n\nVerifique se a partição EFI do Windows está acessível."
    exit 1
fi

WIN_UUID=$(lsblk -no UUID "$WIN_PART")

if [ -z "$WIN_UUID" ]; then
    kdialog --icon "$ICON" --title "$TITLE" \
        --error "Não foi possível obter o UUID da partição:\n$WIN_PART"
    exit 1
fi

# Confirma com o usuário
kdialog --icon "$ICON" --title "$TITLE" \
    --yesno "Windows detectado!\n\nPartição: $WIN_PART\nUUID: $WIN_UUID\n\nAdicionar ao menu GRUB?" \
    || exit 0

# Cria entrada no GRUB
cat > /boot/grub2/windows.cfg << GRUB
menuentry "Windows" --class windows --class os {
    insmod part_gpt
    insmod fat
    insmod chain
    search --no-floppy --fs-uuid --set=root $WIN_UUID
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
GRUB

# Timeout de 30s para escolher o SO
grub2-editenv - set timeout=30

# Adiciona source no grub.cfg se necessário
if [ -f /boot/grub2/grub.cfg ]; then
    if ! grep -q "windows.cfg" /boot/grub2/grub.cfg; then
        echo 'source $prefix/windows.cfg' >> /boot/grub2/grub.cfg
    fi
fi

kdialog --icon "$ICON" --title "$TITLE" \
    --msgbox "Windows adicionado ao GRUB com sucesso!\n\nNo próximo boot, você terá 30 segundos para escolher o sistema."
