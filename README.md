# 🚀 Meu Fedora Bootc Customizado

Este repositório contém a "receita" para o build automatizado da minha imagem de sistema operacional baseada em **Fedora 43**. O sistema é imutável, focado em performance com drivers **Nvidia** e interface **GNOME**.

## 🛠️ Arquitetura do Projeto

* **Base:** Fedora Linux Versão (43)
* **Interface:** GNOME Shell
* **Drivers:** Nvidia (via Negativo17) com compilação automática por `akmods`.
* **Automação:** GitHub Actions com build diário às **04:00 (Brasília)**.

## 📁 Estrutura de Arquivos

| Arquivo | Função |
| --- | --- |
| `Containerfile` | Instruções de build da imagem (instalação de pacotes e drivers). |
| `pacotes_rpm` | Lista de aplicativos e bibliotecas que o DNF deve instalar. |
| `post-install.sh` | Scripts de configuração pós-instalação (remover fedora flatpak, add flathub e instala os flatpaks). |
| `build-image.yml` | Configuração do GitHub Actions para o build automático. |
| `10-nvidia-args-.toml` | Configura os parâmetros para colocar nouveau no blacklist. |
| `post-install.service` | Configura um serviço do systemd para baixar os flatpaks no primeiro boot apos instalação |
| `vconsole.conf` | Configura o TTY para pt-BR
| `locale.conf` | Configura a localidade do sistema para pt-BR. | 
| `config.toml` | Configura um arquivo Fedora kickstart para criar um ISO com anaconda para instalar a versão da imagem personalizada. |

## ⚙️ Como Atualizar o Sistema

A imagem é reconstruída todos os dias. Para aplicar as atualizações no seu hardware:

1. Abra o terminal.
2. Verifique se há atualizações:
``` 
sudo bootc upgrade
```

3. Se houver mudanças, reinicie o computador:
```
sudo reboot
```
## 🛠️ Comandos de Manutenção

Se você precisar trocar de imagem ou verificar o estado atual:

* **Verificar versão atual:**
```
bootc status
```

* **Voltar para a versão anterior (Rollback):**
```
sudo bootc rollback
```

* **Mudar para esta imagem (Primeira vez):**
```
sudo bootc switch container-registry:tag
```

## 🤖 Fluxo de Build Automatizado

O processo de build utiliza cache inteligente via `type=gha`. Isso significa que:

1. O GitHub checa se houve mudança no Kernel ou na lista de pacotes.
2. Se não houver, ele reutiliza a compilação da Nvidia (economizando 20 minutos).
3. A imagem final é publicada no **GitHub Container Registry (GHCR)**.
---

