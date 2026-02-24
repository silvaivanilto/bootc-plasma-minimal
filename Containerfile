# Estágio de build do módulo da nvidia numa imagem separada
# Para evitar poluir a imagem final com os pacotes de desenvolvimento do kernel e ferramentas de construção
FROM quay.io/fedora/fedora-bootc:43 AS builder

RUN <<ELL
set -e

echo "Habilita repositórios COPR do kernel CachyOS"
dnf5 -y install 'dnf5-command(copr)'
dnf5 copr enable -y bieszczaders/kernel-cachyos
dnf5 copr enable -y bieszczaders/kernel-cachyos-addons

echo "Instala o kernel CachyOS e o devel correspondente"
dnf5 -y install kernel-cachyos kernel-cachyos-devel-matched

echo "Remove o kernel Fedora padrão para evitar conflitos"
dnf5 -y remove kernel-core kernel-modules kernel-modules-core kernel-modules-extra || true

echo "Identifica a versão do kernel CachyOS instalada"
KERNEL_VERSION="$(rpm -q kernel-cachyos --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
echo "Kernel CachyOS: $KERNEL_VERSION"

echo "wget necessário para baixar repositórios"
dnf5 -y install wget

echo "Configura repositório negativo17 para drivers nvidia"
wget -O /etc/yum.repos.d/fedora-nvidia-580.repo \
https://negativo17.org/repos/fedora-nvidia-580.repo

echo "Instala o driver da nvidia"
dnf5 install -y nvidia-driver nvidia-driver-cuda --refresh

echo "Build nvidia kernel module para o kernel CachyOS: $KERNEL_VERSION"
akmods --force --kernels "$KERNEL_VERSION"
ELL

# Imagem final do container
FROM quay.io/fedora/fedora-bootc:43

# Copia o módulo da nvidia construído no estágio anterior
COPY --from=builder /var/cache/akmods/nvidia/kmod-nvidia*.rpm ./

# Copia os arquivos necessários para o container
COPY 10-nvidia-args.toml locale.conf pacotes_rpm vconsole.conf nvidia-power-management.conf ./

# Bloco com a configuração base do sistema, kernel CachyOS, Nvidia e repositórios extras
RUN <<EOF
set -e

echo "Cria diretórios necessários"
mkdir -vp /var/roothome /data /var/home

echo "Habilita repositórios COPR do kernel CachyOS"
dnf5 -y install 'dnf5-command(copr)'
dnf5 copr enable -y bieszczaders/kernel-cachyos
dnf5 copr enable -y bieszczaders/kernel-cachyos-addons

echo "Instala o kernel CachyOS"
dnf5 -y install kernel-cachyos

echo "Remove o kernel Fedora padrão"
dnf5 -y remove kernel-core kernel-modules kernel-modules-core kernel-modules-extra || true

echo "Troca zram padrão pelo cachyos-settings (ZRAM otimizado)"
dnf5 -y swap zram-generator-defaults cachyos-settings || dnf5 -y install cachyos-settings || true

echo "Configura SELinux para permitir carregamento de módulos do kernel"
setsebool -P domain_kernel_load_modules on

echo "wget necessário para baixar repositórios"
dnf5 -y install wget

echo "Configura repositório negativo17 para libs da nvidia necessárias"
wget -O /etc/yum.repos.d/fedora-nvidia-580.repo \
https://negativo17.org/repos/fedora-nvidia-580.repo

echo "Configura repositórios RPM Fusion (free + nonfree) para codecs"
FEDORA_VER="$(rpm -E %fedora)"
dnf5 -y install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

echo "Configura repositório do Google Chrome"
dnf5 -y install fedora-workstation-repositories
dnf5 config-manager setopt google-chrome.enabled=1

echo "Desabilita dependências fracas para manter a imagem minimal"
echo "install_weak_deps=False" >> /etc/dnf/dnf.conf

echo "instalar o pacote do nvidia-kmod-common e nvidia-driver-cuda necessários, mas sem toda as dependências para construção do módulo"
dnf5 download nvidia-kmod-common nvidia-driver-cuda
rpm -vi --nodeps nvidia-kmod-common*.rpm
rpm -vi --nodeps nvidia-driver-cuda*.rpm

echo "instalar o kmod-nvidia previamente construído na imagem anterior"
dnf5 -y install ./kmod-nvidia-*.rpm

echo "Para /opt gravavel"
rm -rvf /opt && mkdir -vp /var/opt && ln -vs /var/opt /opt

echo "Para /usr/local gravavel"
mkdir -vp /var/usrlocal && mv -v /usr/local/* /var/usrlocal/ 2>/dev/null || true
rm -rvf /usr/local && ln -vs /var/usrlocal /usr/local

echo "Configura o TTY para o layout de teclado BR, bem como o sistema de locale PT-BR"
mv -v vconsole.conf /etc/vconsole.conf
mv -v locale.conf /etc/locale.conf

echo "Configura os argumentos do kernel para nvidia"
echo "veja a doc https://bit.ly/4qA7J73"
mv -v 10-nvidia-args.toml /usr/lib/bootc/kargs.d/10-nvidia-args.toml

echo "Configura gerenciamento dinâmico de energia da Nvidia"
mv -v nvidia-power-management.conf /etc/modprobe.d/nvidia-power-management.conf

echo "Atualiza todo o container para os pacotes mais recentes, mas não mexe no kernel nem no bootloader"
echo "Veja a doc https://bit.ly/4aPjNvJ"
dnf5 -y upgrade --refresh -x 'kernel*' -x 'kernel-cachyos*' -x 'grub2*' -x 'dracut*' -x 'shim*' -x 'fwupd*'

echo "Limpeza de residuos desse bloco de construção, para reduzir o tamanho da imagem final"
rm -rvf kmod-nvidia-*.rpm nvidia-kmod-common*.rpm nvidia-driver-cuda*.rpm
dnf5 clean all
EOF

# Bloco para instalar os pacotes rpm listados no arquivo pacotes_rpm
# Inclui KDE Plasma, codecs, TLP, Chrome, containers, scx-scheds e libs Nvidia
RUN <<EOR
set -e

echo "instala os pacotes rpm listados no arquivo pacotes_rpm"
grep -v '^#' pacotes_rpm | grep -v '^$' | tr '\n' ' ' | xargs dnf5 install -y --skip-unavailable --exclude=power-profiles-daemon --exclude=toolbox

echo "Habilita serviços necessários"
systemctl mask systemd-remount-fs.service

echo "Habilita o Plasma Login Manager como display manager"
systemctl enable plasmalogin.service
systemctl set-default graphical.target

echo "Habilita TLP para gerenciamento de energia"
systemctl enable tlp.service
systemctl mask systemd-rfkill.service systemd-rfkill.socket

echo "Habilita serviços Nvidia de suspend/hibernate/resume"
systemctl enable nvidia-suspend.service || true
systemctl enable nvidia-hibernate.service || true
systemctl enable nvidia-resume.service || true
systemctl enable nvidia-persistenced.service || true

echo "Limpeza de resíduos de construção" 
rm -rvf pacotes_rpm 
dnf5 clean all
EOR

# Instala fontes locais (Google Sans + Nerd Fonts Symbols Only)
COPY fonts/google-sans/ /usr/share/fonts/google-sans/
COPY fonts/nerd-fonts/ /usr/share/fonts/nerd-fonts-symbols/
RUN fc-cache -fv

# Verificar por erros na imagem 
RUN bootc container lint
