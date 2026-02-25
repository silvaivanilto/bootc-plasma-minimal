# ============================================================================
# 🚀 Fedora Bootc — KDE Plasma Minimal + Nvidia + Kernel CachyOS
# ============================================================================
#
# Build multi-stage:
#   1. BUILDER  → Compila o módulo Nvidia contra o kernel CachyOS
#   2. FINAL    → Monta a imagem final com KDE Plasma, drivers e configurações
#
# ============================================================================


# ============================================================================
# ESTÁGIO 1: Builder — Compilação do módulo Nvidia
# ============================================================================
# Imagem temporária apenas para compilar o kmod-nvidia.
# Nada deste estágio vai para a imagem final, exceto o .rpm gerado.
# ============================================================================

FROM quay.io/fedora/fedora-bootc:43 AS builder

RUN <<ELL
set -e

# --- Repositórios COPR do kernel CachyOS ---
dnf5 -y install wget
FEDORA_VER="$(rpm -E %fedora)"
wget -O /etc/yum.repos.d/bieszczaders-kernel-cachyos.repo \
  "https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/repo/fedora-${FEDORA_VER}/bieszczaders-kernel-cachyos-fedora-${FEDORA_VER}.repo"
wget -O /etc/yum.repos.d/bieszczaders-kernel-cachyos-addons.repo \
  "https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos-addons/repo/fedora-${FEDORA_VER}/bieszczaders-kernel-cachyos-addons-fedora-${FEDORA_VER}.repo"

# --- Kernel CachyOS + headers para compilação ---
# noscripts: evita erro do dracut dentro do container
dnf5 -y install --setopt=tsflags=noscripts kernel-cachyos kernel-cachyos-devel-matched

# --- Remove kernel Fedora padrão (evita conflitos) ---
dnf5 -y remove --setopt=tsflags=noscripts \
  kernel-core kernel-modules kernel-modules-core kernel-modules-extra || true

# --- Prepara módulos do kernel ---
KERNEL_VERSION="$(rpm -q kernel-cachyos --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
echo ">>> Kernel CachyOS: $KERNEL_VERSION"
depmod -a "$KERNEL_VERSION"

# --- Repositório Negativo17 (Nvidia) ---
wget -O /etc/yum.repos.d/fedora-nvidia-580.repo \
  https://negativo17.org/repos/fedora-nvidia-580.repo

# --- Instala driver Nvidia + compila módulo ---
dnf5 install -y nvidia-driver nvidia-driver-cuda --refresh
akmods --force --kernels "$KERNEL_VERSION"
ELL


# ============================================================================
# ESTÁGIO 2: Imagem Final
# ============================================================================

FROM quay.io/fedora/fedora-bootc:43

# ----------------------------------------------------------------------------
# 2.1 — Copia arquivos de configuração e o kmod-nvidia
# ----------------------------------------------------------------------------
COPY --from=builder /var/cache/akmods/nvidia/kmod-nvidia*.rpm ./
COPY config/locale.conf config/vconsole.conf ./
COPY nvidia/10-nvidia-args.toml nvidia/nvidia-power-management.conf ./
COPY packages/pacotes_rpm ./

# ----------------------------------------------------------------------------
# 2.2 — Kernel CachyOS + Repositórios + Nvidia + Configurações do sistema
# ----------------------------------------------------------------------------
RUN <<EOF
set -e

# ┌─────────────────────────────────────────┐
# │  Diretórios base do sistema             │
# └─────────────────────────────────────────┘
mkdir -vp /var/roothome /data /var/home

# ┌─────────────────────────────────────────┐
# │  Kernel CachyOS                         │
# └─────────────────────────────────────────┘
dnf5 -y install wget
FEDORA_VER="$(rpm -E %fedora)"

# Repositórios COPR
wget -O /etc/yum.repos.d/bieszczaders-kernel-cachyos.repo \
  "https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/repo/fedora-${FEDORA_VER}/bieszczaders-kernel-cachyos-fedora-${FEDORA_VER}.repo"
wget -O /etc/yum.repos.d/bieszczaders-kernel-cachyos-addons.repo \
  "https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos-addons/repo/fedora-${FEDORA_VER}/bieszczaders-kernel-cachyos-addons-fedora-${FEDORA_VER}.repo"

# Instala kernel (noscripts: dracut não roda em container)
dnf5 -y install --setopt=tsflags=noscripts kernel-cachyos

# Remove kernel Fedora padrão
dnf5 -y remove --setopt=tsflags=noscripts \
  kernel-core kernel-modules kernel-modules-core kernel-modules-extra || true

# Gera modules.dep manualmente
KERNEL_VERSION="$(rpm -q kernel-cachyos --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
depmod -a "$KERNEL_VERSION"

# Dracut: garante que btrfs e virtio estejam no initramfs
# (necessário porque noscripts pula a geração automática)
mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/99-bootc-essential.conf << 'DRACUT'
filesystems+=" btrfs ext4 "
drivers+=" virtio_blk virtio_scsi virtio_pci nvme ahci sd_mod "
add_dracutmodules+=" btrfs "
DRACUT

# CachyOS Settings (ZRAM otimizado + sched_ext)
dnf5 -y swap zram-generator-defaults cachyos-settings \
  || dnf5 -y install cachyos-settings || true

# ┌─────────────────────────────────────────┐
# │  Repositórios extras                    │
# └─────────────────────────────────────────┘
# Negativo17 (libs Nvidia)
wget -O /etc/yum.repos.d/fedora-nvidia-580.repo \
  https://negativo17.org/repos/fedora-nvidia-580.repo

# RPM Fusion (codecs multimídia)
dnf5 -y install \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

# Google Chrome
dnf5 -y install fedora-workstation-repositories
sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/google-chrome.repo

# TLP (tlp-pd ainda não está nos repos oficiais)
dnf5 -y install \
  "https://repo.linrunner.de/fedora/tlp/repos/releases/tlp-release.fc${FEDORA_VER}.noarch.rpm" || true

# ┌─────────────────────────────────────────┐
# │  Nvidia — driver e módulo do kernel     │
# └─────────────────────────────────────────┘
# Instala dependências mínimas (sem ferramentas de build)
dnf5 download nvidia-kmod-common nvidia-driver-cuda
rpm -vi --nodeps nvidia-kmod-common*.rpm
rpm -vi --nodeps nvidia-driver-cuda*.rpm

# Instala o kmod-nvidia compilado no estágio 1
dnf5 -y install ./kmod-nvidia-*.rpm

# ┌─────────────────────────────────────────┐
# │  Configurações do sistema               │
# └─────────────────────────────────────────┘
# Dependências fracas desabilitadas (imagem minimal)
echo "install_weak_deps=False" >> /etc/dnf/dnf.conf

# SELinux: permite carregamento de módulos do kernel
setsebool -P domain_kernel_load_modules on || true

# /opt e /usr/local graváveis (bootc exige que estejam em /var)
rm -rvf /opt && mkdir -vp /var/opt && ln -vs /var/opt /opt
mkdir -vp /var/usrlocal && mv -v /usr/local/* /var/usrlocal/ 2>/dev/null || true
rm -rvf /usr/local && ln -vs /var/usrlocal /usr/local

# Localização pt_BR e teclado ABNT2
mv -v locale.conf /etc/locale.conf
mv -v vconsole.conf /etc/vconsole.conf

# Nvidia: argumentos do kernel (blacklist nouveau, modeset, power management)
# Docs: https://bit.ly/4qA7J73
mv -v 10-nvidia-args.toml /usr/lib/bootc/kargs.d/10-nvidia-args.toml
mv -v nvidia-power-management.conf /etc/modprobe.d/nvidia-power-management.conf

# ┌─────────────────────────────────────────┐
# │  Atualização geral do sistema           │
# └─────────────────────────────────────────┘
# Atualiza tudo exceto kernel/bootloader (evita conflitos)
# Docs: https://bit.ly/4aPjNvJ
dnf5 -y upgrade --refresh \
  -x 'kernel*' -x 'kernel-cachyos*' \
  -x 'grub2*' -x 'dracut*' -x 'shim*' -x 'fwupd*'

# ┌─────────────────────────────────────────┐
# │  Limpeza                                │
# └─────────────────────────────────────────┘
rm -rvf kmod-nvidia-*.rpm nvidia-kmod-common*.rpm nvidia-driver-cuda*.rpm
dnf5 clean all
EOF

# ----------------------------------------------------------------------------
# 2.3 — Pacotes RPM (KDE Plasma, codecs, apps, containers, etc.)
# ----------------------------------------------------------------------------
RUN <<EOR
set -e

# Instala todos os pacotes listados em packages/pacotes_rpm
grep -v '^#' pacotes_rpm | grep -v '^$' | sed 's/#.*//' | tr '\n' ' ' | \
  xargs dnf5 install -y --skip-unavailable \
    --exclude=power-profiles-daemon \
    --exclude=toolbox

# ┌─────────────────────────────────────────┐
# │  Serviços do sistema                    │
# └─────────────────────────────────────────┘
# Display Manager (KDE Plasma Login)
systemctl enable plasmalogin.service
systemctl set-default graphical.target

# Energia (TLP)
systemctl enable tlp.service
systemctl enable tlp-pd.service || true
systemctl mask systemd-rfkill.service systemd-rfkill.socket

# Nvidia (persistenced; suspend/hibernate/resume habilitados pelo %post do driver)
systemctl enable nvidia-persistenced.service || true

# Workaround bootc: mascarar remount-fs
systemctl mask systemd-remount-fs.service

# ┌─────────────────────────────────────────┐
# │  Limpeza                                │
# └─────────────────────────────────────────┘
rm -rvf pacotes_rpm
dnf5 clean all
EOR

# ----------------------------------------------------------------------------
# 2.4 — Fontes locais (Google Sans + Nerd Fonts Symbols Only)
# ----------------------------------------------------------------------------
COPY fonts/google-sans/ /usr/share/fonts/google-sans/
COPY fonts/nerd-fonts/ /usr/share/fonts/nerd-fonts-symbols/
RUN fc-cache -fv

# ----------------------------------------------------------------------------
# 2.5 — Validação final da imagem
# ----------------------------------------------------------------------------
RUN bootc container lint
