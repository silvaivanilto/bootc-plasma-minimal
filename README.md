<p align="center">
  <img src="https://img.shields.io/badge/Fedora-43-blue?style=for-the-badge&logo=fedora" alt="Fedora 43">
  <img src="https://img.shields.io/badge/KDE_Plasma-6-blue?style=for-the-badge&logo=kde" alt="KDE Plasma 6">
  <img src="https://img.shields.io/badge/Kernel-CachyOS-orange?style=for-the-badge" alt="CachyOS">
  <img src="https://img.shields.io/badge/Nvidia-Integrado-76b900?style=for-the-badge&logo=nvidia" alt="Nvidia">
  <img src="https://img.shields.io/badge/Bootc-Imut%C3%A1vel-purple?style=for-the-badge" alt="Bootc">
</p>

# Fedora Bootc — KDE Plasma Minimal

Sistema operacional **imutável** baseado em Fedora 43 Bootc com KDE Plasma 6, kernel CachyOS e drivers Nvidia — tudo integrado e atualizado automaticamente.

---

## ✨ Destaques

| | Componente | Descrição |
|---|---|---|
| 🐧 | **Fedora 43 Bootc** | Base imutável com atualizações atômicas |
| ⚡ | **Kernel CachyOS** | Otimizado para desktop, com `sched_ext` (scx-scheds) |
| 🖥️ | **KDE Plasma 6** | Interface minimal, sem dependências fracas |
| 🎮 | **Nvidia (Negativo17)** | Driver compilado contra o kernel CachyOS via multi-stage build |
| 🎬 | **Codecs completos** | FFmpeg, GStreamer, Phonon VLC (via RPM Fusion) |
| 📦 | **Containers** | Podman, Distrobox, Flatpak |
| 🔋 | **TLP** | Gerenciamento de energia com integração Nvidia |
| 🔀 | **GPU Híbrida** | switcheroo-control (AMD iGPU + Nvidia dGPU) |
| 🌐 | **Google Chrome** | Navegador pré-instalado |
| 📝 | **LibreOffice** | Suite office com integração KDE (kf6) |
| 📦 | **Flatpak + Discover** | Loja de apps com backend Flatpak |
| 🔧 | **CachyOS Addons** | sched_ext, ZRAM, ananicy-cpp |
| 🪟 | **Dual Boot** | Ferramenta gráfica para adicionar Windows ao GRUB |
| 🇧🇷 | **pt_BR** | Localização completa (idioma, teclado, langpacks) |

---

## 📥 Download da ISO

A ISO de instalação é publicada automaticamente na aba [**Releases**](../../releases), dividida em partes de ~1.9GB.

**Baixar e remontar:**

```bash
# 1. Baixe todas as partes .part e o SHA256SUMS.txt da Release mais recente

# 2. Remonte a ISO
cat install.iso.*.part > install.iso

# 3. Verifique a integridade
sha256sum -c SHA256SUMS.txt

# 4. Grave no pendrive (substitua /dev/sdX pelo dispositivo correto!)
sudo dd if=install.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

---

## ⚙️ Uso no dia a dia

```bash
# Verificar atualizações
sudo bootc upgrade --check

# Aplicar atualização
sudo bootc upgrade
sudo reboot

# Ver versão atual
bootc status

# Voltar para versão anterior
sudo bootc rollback
```

**Primeira instalação via container (sem ISO):**

```bash
sudo bootc switch ghcr.io/silvaivanilto/bootc-plasma-minimal:latest
```

---

## 📁 Estrutura do Projeto

```
├── Containerfile              # Build multi-stage (CachyOS + Nvidia + KDE)
├── config/
│   ├── locale.conf            # Localização pt_BR.UTF-8
│   ├── vconsole.conf          # Teclado ABNT2 para TTY
│   ├── 99-google-sans.conf    # Fontconfig (substituições MS Office)
│   ├── dualboot-windows.sh    # Ferramenta dual-boot (kdialog)
│   └── dualboot-windows.desktop
├── nvidia/
│   ├── 10-nvidia-args.toml    # Kernel args (blacklist nouveau, modeset)
│   └── nvidia-power-management.conf
├── packages/
│   └── pacotes_rpm            # Lista de pacotes RPM por categoria
├── fonts/
│   ├── google-fonts/          # Google Sans, Arimo, Tinos, Carlito, etc.
│   └── nerd-fonts/            # Nerd Fonts Symbols Only
├── iso/
│   └── config.toml            # Kickstart Anaconda (Btrfs + subvolumes)
└── .github/workflows/
    └── build-image.yml        # CI/CD: build diário + ISO → Releases
```

---

## 🔄 Automação

O GitHub Actions executa diariamente às **06:00 (Fortaleza)**:

1. **Build** da imagem container → push para GHCR
2. **Geração da ISO** → split em partes de 1.9GB → upload como Release

Também dispara automaticamente em cada push na branch `main`.
