# Ferramenta de Suporte Técnico para Linux (Red Hat)

## Sobre

Script em Shell Script com menu interativo para diagnóstico e manutenção de sistemas **Red Hat Linux** (RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux).

> ⚠️ **Originalmente desenvolvido para Windows PowerShell**, esta versão foi completamente adaptada para o ecossistema Linux Red Hat.

## Requisitos

- **Distribuição**: RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux (ou qualquer derivado)
- **Permissão**: Recomendado executar como **root/sudo** para todas as funcionalidades
- **Dependências**: `bash`, `systemd`, `iproute2`, `util-linux` (pré-instalados na maioria das distribuições)

## Instalação

```bash
# Baixar ou criar o arquivo
chmod +x SupportToolRedHat.sh

# Executar
sudo ./SupportToolRedHat.sh
