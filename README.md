# 🚀 Fedora Bootc — KDE Plasma Minimal com Nvidia + Kernel CachyOS

Imagem de sistema operacional imutável baseada em **Fedora 43 Bootc** com **KDE Plasma 6** minimal, **kernel CachyOS** e drivers **Nvidia** integrados.

## 🛠️ O que está incluído

* **Base:** Fedora Linux 43 (Bootc — sistema imutável)
* **Kernel:** CachyOS (via COPR `bieszczaders`) com sched_ext (`scx-scheds`)
* **Interface:** KDE Plasma 6 (minimal, sem dependências fracas)
* **Drivers Nvidia** (via Negativo17) — compilados contra o kernel CachyOS via multi-stage build
* **Codecs:** FFmpeg, GStreamer, Phonon VLC (via RPM Fusion)
* **Containers:** Podman, Distrobox, Flatpak
* **Energia:** TLP com integração Nvidia power management
* **GPU Híbrida:** switcheroo-control (AMD iGPU + Nvidia dGPU)
* **Navegador:** Google Chrome
* **Office:** LibreOffice
* **Localização:** pt_BR completa (locale, teclado, langpacks)
* **Automação:** GitHub Actions com build diário às **03:45 (Brasília)** + notificação Telegram

## 📁 Estrutura de Arquivos

| Arquivo | Função |
| --- | --- |
| `Containerfile` | Build multi-stage da imagem (CachyOS + Nvidia + KDE + sistema) |
| `pacotes_rpm` | Lista de pacotes RPM organizados por categoria |
| `10-nvidia-args.toml` | Argumentos do kernel (blacklist nouveau, modeset, power management) |
| `nvidia-power-management.conf` | Config modprobe para gerenciamento dinâmico de energia Nvidia |
| `vconsole.conf` | Layout de teclado BR para TTY |
| `locale.conf` | Localidade do sistema pt_BR |
| `config.toml` | Kickstart para gerar ISO de instalação com Btrfs |
| `.github/workflows` | GitHub Actions para build automático diário |

## ⚙️ Como Usar

### Atualizar o sistema
```bash
sudo bootc upgrade --check   # verifica atualizações
sudo bootc upgrade            # aplica
sudo reboot                   # reinicia com nova imagem
```

### Manutenção
```bash
bootc status                  # versão atual
sudo bootc rollback           # volta para versão anterior
```

### Mudar para esta imagem (primeira vez)
```bash
sudo bootc switch ghcr.io/SEU_USUARIO/bootc-plasma-minimal:latest
```

## 🤖 Criar ISO de instalação

```bash
git clone https://github.com/SEU_USUARIO/bootc-plasma-minimal.git
cd bootc-plasma-minimal
mkdir output
sudo podman build -t bootc-plasma-minimal -f Containerfile
```

```bash
sudo podman run \
    --rm -it --privileged --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./output:/output \
    -v ./config.toml:/config.toml:ro \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type anaconda-iso \
    --rootfs btrfs \
    localhost/bootc-plasma-minimal
```

A ISO será gerada em `output/bootiso/install.iso`.
