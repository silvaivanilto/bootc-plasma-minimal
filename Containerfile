# Fedora Bootc — KDE Plasma Minimal + Nvidia + Kernel CachyOS

# === ESTÁGIO 1: Builder — Compilação do módulo Nvidia ===

FROM quay.io/fedora/fedora-bootc:43 AS builder

RUN <<ELL
set -eu

FEDORA_VER="$(rpm -E %fedora)"
dnf5 -y install wget

# Repositórios CachyOS + Negativo17
wget -O /etc/yum.repos.d/bieszczaders-kernel-cachyos.repo \
  "https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/repo/fedora-${FEDORA_VER}/bieszczaders-kernel-cachyos-fedora-${FEDORA_VER}.repo"
wget -O /etc/yum.repos.d/bieszczaders-kernel-cachyos-addons.repo \
  "https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos-addons/repo/fedora-${FEDORA_VER}/bieszczaders-kernel-cachyos-addons-fedora-${FEDORA_VER}.repo"
wget -O /etc/yum.repos.d/fedora-nvidia-580.repo \
  https://negativo17.org/repos/fedora-nvidia-580.repo

# Kernel CachyOS (noscripts: dracut não roda em container)
dnf5 -y install --setopt=tsflags=noscripts kernel-cachyos kernel-cachyos-devel-matched
dnf5 -y remove --setopt=tsflags=noscripts \
  kernel-core kernel-modules kernel-modules-core kernel-modules-extra || true

KERNEL_VERSION="$(rpm -q kernel-cachyos --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
echo ">>> Kernel CachyOS: $KERNEL_VERSION"
depmod -a "$KERNEL_VERSION"

# Nvidia: driver + compilação do módulo
dnf5 -y install --refresh nvidia-driver nvidia-driver-cuda
akmods --force --kernels "$KERNEL_VERSION"

dnf5 clean all
ELL


# === ESTÁGIO 2: Imagem Final ===

FROM quay.io/fedora/fedora-bootc:43

COPY --from=builder /var/cache/akmods/nvidia/kmod-nvidia*.rpm ./
COPY config/locale.conf config/vconsole.conf ./
COPY nvidia/10-nvidia-args.toml nvidia/nvidia-power-management.conf ./
COPY packages/pacotes_rpm ./

# --- 2.1 Kernel + Repositórios + Nvidia + Sistema ---
RUN <<EOF
set -eu

FEDORA_VER="$(rpm -E %fedora)"
dnf5 -y install wget

# Desabilita dependências fracas (antes de qualquer install)
echo "install_weak_deps=False" >> /etc/dnf/dnf.conf

# Diretórios base
mkdir -p /var/roothome /data /var/home

# --- Kernel CachyOS ---
wget -O /etc/yum.repos.d/bieszczaders-kernel-cachyos.repo \
  "https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/repo/fedora-${FEDORA_VER}/bieszczaders-kernel-cachyos-fedora-${FEDORA_VER}.repo"
wget -O /etc/yum.repos.d/bieszczaders-kernel-cachyos-addons.repo \
  "https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos-addons/repo/fedora-${FEDORA_VER}/bieszczaders-kernel-cachyos-addons-fedora-${FEDORA_VER}.repo"

dnf5 -y install --setopt=tsflags=noscripts kernel-cachyos
dnf5 -y remove --setopt=tsflags=noscripts \
  kernel-core kernel-modules kernel-modules-core kernel-modules-extra || true

KERNEL_VERSION="$(rpm -q kernel-cachyos --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
echo ">>> Kernel CachyOS: $KERNEL_VERSION"
depmod -a "$KERNEL_VERSION"

# Dracut: btrfs + virtio no initramfs
mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/99-bootc-essential.conf << 'DRACUT'
filesystems+=" btrfs ext4 "
drivers+=" virtio_blk virtio_scsi virtio_pci nvme ahci sd_mod "
add_dracutmodules+=" btrfs "
DRACUT

# CachyOS Settings (ZRAM + sched_ext)
dnf5 -y swap zram-generator-defaults cachyos-settings \
  || dnf5 -y install cachyos-settings || true

# --- Repositórios extras ---
wget -O /etc/yum.repos.d/fedora-nvidia-580.repo \
  https://negativo17.org/repos/fedora-nvidia-580.repo

dnf5 -y install --refresh \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

dnf5 -y install fedora-workstation-repositories
sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/google-chrome.repo

cat > /etc/yum.repos.d/antigravity.repo << 'REPO'
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
REPO
dnf5 -y install antigravity

dnf5 -y install \
  "https://repo.linrunner.de/fedora/tlp/repos/releases/tlp-release.fc${FEDORA_VER}.noarch.rpm" || true

# --- Nvidia: driver + módulo pré-compilado ---
dnf5 download nvidia-kmod-common nvidia-driver-cuda
rpm -i --nodeps nvidia-kmod-common*.rpm
rpm -i --nodeps nvidia-driver-cuda*.rpm
dnf5 -y install ./kmod-nvidia-*.rpm

# --- Configurações do sistema ---
setsebool -P domain_kernel_load_modules on || true

# /opt e /usr/local graváveis (bootc exige /var)
rm -rf /opt && mkdir -p /var/opt && ln -s /var/opt /opt
mkdir -p /var/usrlocal && mv /usr/local/* /var/usrlocal/ 2>/dev/null || true
rm -rf /usr/local && ln -s /var/usrlocal /usr/local

# Locale e Nvidia configs
mv locale.conf /etc/locale.conf
mv vconsole.conf /etc/vconsole.conf
mv 10-nvidia-args.toml /usr/lib/bootc/kargs.d/10-nvidia-args.toml
mv nvidia-power-management.conf /etc/modprobe.d/nvidia-power-management.conf

# --- Atualização geral ---
dnf5 -y upgrade --refresh \
  -x 'kernel*' -x 'kernel-cachyos*' \
  -x 'grub2*' -x 'dracut*' -x 'shim*' -x 'fwupd*'

rm -f kmod-nvidia-*.rpm nvidia-kmod-common*.rpm nvidia-driver-cuda*.rpm
dnf5 clean all
EOF

# --- 2.2 Pacotes RPM ---
RUN <<EOR
set -eu

grep -v '^#' pacotes_rpm | grep -v '^$' | sed 's/#.*//' | tr '\n' ' ' | \
  xargs dnf5 install -y --skip-unavailable \
    --exclude=power-profiles-daemon \
    --exclude=toolbox

# Serviços
systemctl enable plasmalogin.service
systemctl set-default graphical.target
systemctl enable tlp.service
systemctl enable tlp-pd.service || true
systemctl mask systemd-rfkill.service systemd-rfkill.socket
systemctl enable nvidia-persistenced.service || true
systemctl enable ananicy-cpp.service || true
systemctl mask systemd-remount-fs.service

# Padrões KDE (Breeze + Google Sans)
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/kdeglobals << 'KDE'
[KDE]
LookAndFeelPackage=org.kde.breeze.desktop

[General]
font=Google Sans Flex,10,-1,5,50,0,0,0,0,0
fixed=Google Sans Code,10,-1,5,50,0,0,0,0,0
smallestReadableFont=Google Sans Text,8,-1,5,50,0,0,0,0,0
toolBarFont=Google Sans Flex,10,-1,5,50,0,0,0,0,0
menuFont=Google Sans Flex,10,-1,5,50,0,0,0,0,0
titleFont=Google Sans Flex,10,-1,5,75,0,0,0,0,0
KDE

rm -f pacotes_rpm
dnf5 clean all
EOR

# --- 2.3 Fontes + ferramenta dual-boot ---
COPY fonts/google-fonts/ /usr/share/fonts/google-fonts/
COPY fonts/nerd-fonts/ /usr/share/fonts/nerd-fonts-symbols/
COPY config/99-google-sans.conf /etc/fonts/conf.d/99-google-sans.conf
COPY config/dualboot-windows.sh /usr/local/bin/dualboot-windows
COPY config/dualboot-windows.desktop /usr/share/applications/dualboot-windows.desktop
RUN fc-cache -f

# --- 2.4 Validação ---
RUN bootc container lint
