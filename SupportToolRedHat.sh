#!/bin/bash

# ============================================
# FERRAMENTA DE DIAGNOSTICO E SUPORTE TECNICO
# PARA RED HAT LINUX
# ============================================

# Variaveis globais
NOME_FERRAMENTA="Ferramenta de Suporte Tecnico v3.0 (Linux)"
VERMELHO='\033[0;31m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
CIANO='\033[0;36m'
MAGENTA='\033[0;35m'
CINZA='\033[0;37m'
RESET='\033[0m'

# ============================================
# BIBLIOTECA DE FUNCOES AUXILIARES
# ============================================

# Funcao para exibir mensagens coloridas
escrever_mensagem() {
    local texto="$1"
    local tipo="$2"
    
    case "$tipo" in
        "SUCESSO")
            echo -e "${VERDE}[OK] $texto${RESET}"
            ;;
        "ERRO")
            echo -e "${VERMELHO}[ERRO] $texto${RESET}"
            ;;
        "AVISO")
            echo -e "${AMARELO}[AVISO] $texto${RESET}"
            ;;
        "INFO")
            echo -e "${CIANO}[INFO] $texto${RESET}"
            ;;
        *)
            echo -e "  $texto"
            ;;
    esac
}

# Funcao para pausar a tela
aguardar_enter() {
    echo ""
    read -p "Pressione Enter para continuar..."
    mostrar_menu
}

# Verificar se o script esta sendo executado como root
verificar_root() {
    if [[ $EUID -ne 0 ]]; then
        escrever_mensagem "Algumas funcoes requerem privilegios de root" "AVISO"
        echo -e "${AMARELO}Recomendado executar como: sudo $0${RESET}"
        echo ""
    fi
}

# ============================================
# FUNCOES DE SISTEMA (LIMPEZA E INFORMACOES)
# ============================================

# 1. Limpar arquivos temporarios do sistema
limpar_temporarios() {
    escrever_mensagem "Iniciando limpeza de arquivos temporarios" "INFO"
    
    # Pastas temporarias comuns no Linux
    local pastas_temporarias=(
        "/tmp/*"
        "/var/tmp/*"
        "$HOME/.cache/*"
        "/var/log/*.old"
        "/var/log/*.gz"
    )
    
    for pasta in "${pastas_temporarias[@]}"; do
        rm -rf $pasta 2>/dev/null
        echo -e "${CINZA}  Limpo: $pasta${RESET}"
    done
    
    # Limpar logs antigos do journal (systemd)
    if command -v journalctl &> /dev/null; then
        journalctl --vacuum-time=7d 2>/dev/null
        echo -e "${CINZA}  Logs do journal limpos (mantendo 7 dias)${RESET}"
    fi
    
    escrever_mensagem "Limpeza de temporarios concluida" "SUCESSO"
}

# 2. Limpar cache DNS (systemd-resolved ou dnsmasq)
limpar_cache_dns() {
    escrever_mensagem "Limpando cache DNS" "INFO"
    
    if systemctl is-active --quiet systemd-resolved; then
        sudo systemd-resolve --flush-caches 2>/dev/null || sudo resolvectl flush-caches 2>/dev/null
        escrever_mensagem "Cache DNS (systemd-resolved) limpo" "SUCESSO"
    elif command -v dnsmasq &> /dev/null; then
        sudo systemctl restart dnsmasq 2>/dev/null
        escrever_mensagem "Cache DNS (dnsmasq) limpo" "SUCESSO"
    else
        escrever_mensagem "Nenhum servico de cache DNS detectado" "INFO"
        echo "  Para limpar: sudo systemctl restart systemd-resolved"
    fi
}

# 3. Exibir configuracoes de rede (IP, DNS, Gateway)
exibir_configuracao_ip() {
    escrever_mensagem "Exibindo configuracoes de rede" "INFO"
    echo -e "${VERDE}"
    ip addr show
    echo -e "${CIANO}\n--- Tabela de Roteamento ---${RESET}"
    ip route show
    echo -e "${CIANO}\n--- DNS Configurados ---${RESET}"
    cat /etc/resolv.conf 2>/dev/null | grep nameserver
    echo -e "${RESET}"
    escrever_mensagem "Configuracoes exibidas" "SUCESSO"
}

# 4. Exibir lista de processos em execucao
exibir_processos() {
    escrever_mensagem "Listando processos em execucao" "INFO"
    echo -e "${VERDE}"
    ps aux --sort=-%cpu | head -20
    echo -e "${RESET}"
    escrever_mensagem "Processos listados (top 20 por CPU)" "SUCESSO"
}

# 5. Exibir usuarios logados
exibir_usuarios_logados() {
    escrever_mensagem "Verificando usuarios logados" "INFO"
    echo -e "${VERDE}"
    who
    echo -e "${CIANO}\n--- Usuarios com sessoes ativas ---${RESET}"
    w
    echo -e "${RESET}"
    escrever_mensagem "Usuarios exibidos" "SUCESSO"
}

# 6. Exibir portas de rede abertas
exibir_portas_abertas() {
    escrever_mensagem "Verificando portas abertas" "INFO"
    echo -e "${VERDE}"
    if command -v ss &> /dev/null; then
        ss -tuln | grep LISTEN
    else
        netstat -tuln 2>/dev/null | grep LISTEN
    fi
    echo -e "${RESET}"
    escrever_mensagem "Portas abertas exibidas" "SUCESSO"
}

# ============================================
# FUNCOES DE REDE
# ============================================

# 7. Testar ping com opcoes interativas
testar_conexao() {
    local destino=""
    local quantidade=4
    
    # Se nenhum destino foi informado, mostra menu interativo
    if [[ -z "$1" ]]; then
        clear
        echo -e "${CIANO}========================================${RESET}"
        echo -e "         TESTE DE CONEXAO"
        echo -e "${CIANO}========================================${RESET}\n"
        
        # Detecta informacoes da rede atual
        local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
        local ip_local=$(ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)
        
        echo -e "${AMARELO}[INFORMACOES DA REDE ATUAL]${RESET}"
        if [[ -n "$gateway" ]]; then
            echo -e "  Gateway padrao: ${CINZA}$gateway${RESET}"
        else
            echo -e "  Gateway padrao: ${VERMELHO}NAO DETECTADO${RESET}"
        fi
        
        if [[ -n "$ip_local" ]]; then
            echo -e "  IP local: ${CINZA}$ip_local${RESET}"
        else
            echo -e "  IP local: ${VERMELHO}NAO DETECTADO${RESET}"
        fi
        
        echo -e "\n${AMARELO}[OPCOES DE TESTE]${RESET}"
        echo " 1. Internet (Google DNS - 8.8.8.8)"
        echo " 2. Rede local (Gateway: $gateway)"
        echo " 3. Placa de rede (Loopback - 127.0.0.1)"
        echo " 4. Digitar um IP manualmente"
        echo " 5. Pingar o proprio IP desta maquina"
        echo " 6. Diagnostico completo (testa tudo)"
        echo " 7. Voltar ao menu principal"
        
        read -p $'\nEscolha (1-7): ' escolha
        
        case $escolha in
            1) destino="8.8.8.8" ;;
            2) 
                if [[ -n "$gateway" ]]; then 
                    destino="$gateway"
                    echo -e "\nTestando gateway: $destino"
                else
                    escrever_mensagem "Gateway nao detectado!" "ERRO"
                    aguardar_enter
                    return
                fi
                ;;
            3) destino="127.0.0.1" ;;
            4)
                read -p "Digite o IP ou hostname: " destino
                if [[ -z "$destino" ]]; then
                    escrever_mensagem "IP invalido!" "ERRO"
                    return
                fi
                ;;
            5)
                if [[ -n "$ip_local" ]]; then
                    destino="$ip_local"
                    echo -e "\nTestando IP local: $destino"
                else
                    escrever_mensagem "Nao foi possivel detectar o IP local!" "ERRO"
                    aguardar_enter
                    return
                fi
                ;;
            6)
                diagnostico_completo_rede
                return
                ;;
            7) return ;;
            *)
                escrever_mensagem "Opcao invalida!" "ERRO"
                return
                ;;
        esac
    else
        destino="$1"
        quantidade="${2:-4}"
    fi
    
    # Executa o ping
    escrever_mensagem "Testando ping para $destino" "INFO"
    echo -e "${CIANO}>>> Testando conexao com $destino <<<${RESET}\n"
    
    if ping -c $quantidade "$destino" &> /dev/null; then
        local tempo_medio=$(ping -c $quantidade "$destino" 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
        echo -e "  ${VERDE}Pacotes recebidos: $quantidade de $quantidade${RESET}"
        if [[ -n "$tempo_medio" ]]; then
            printf "  Tempo medio de resposta: %.2fms\n" "$tempo_medio"
        fi
        escrever_mensagem "Ping para $destino realizado com sucesso" "SUCESSO"
    else
        echo -e "  ${VERMELHO}Falha no ping para $destino${RESET}"
        escrever_mensagem "Ping para $destino falhou" "ERRO"
        
        # Dicas baseadas no tipo de destino
        if [[ "$destino" == "8.8.8.8" ]]; then
            echo -e "\n  ${AMARELO}[DICA] Verifique sua conexao com a internet.${RESET}"
            echo -e "  ${AMARELO}[DICA] Tente: sudo systemctl restart NetworkManager${RESET}"
        elif [[ "$destino" == "127.0.0.1" ]]; then
            echo -e "\n  ${AMARELO}[DICA] Falha no loopback. Pode ser problema no driver.${RESET}"
        elif [[ "$destino" == "$gateway" ]]; then
            echo -e "\n  ${AMARELO}[DICA] Falha no gateway. Verifique o cabo de rede/Wi-Fi.${RESET}"
        fi
    fi
    echo ""
}

# 8. Reset completo da pilha de rede
resetar_rede() {
    escrever_mensagem "Iniciando reset completo de rede" "AVISO"
    echo -e "${AMARELO}Este processo vai reiniciar os servicos de rede${RESET}"
    
    if command -v nmcli &> /dev/null; then
        escrever_mensagem "Reiniciando NetworkManager..." "INFO"
        sudo systemctl restart NetworkManager
    fi
    
    escrever_mensagem "Liberando e renovando IP (DHCP)..." "INFO"
    if command -v dhclient &> /dev/null; then
        sudo dhclient -r && sudo dhclient
    else
        sudo systemctl restart NetworkManager
    fi
    
    limpar_cache_dns
    
    escrever_mensagem "Reset de rede concluido" "SUCESSO"
}

# Diagnostico completo de rede
diagnostico_completo_rede() {
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    
    echo -e "\n${MAGENTA}========== DIAGNOSTICO COMPLETO DE REDE ==========${RESET}"
    
    # Teste 1: Loopback
    echo -e "\n${AMARELO}[1/4] Testando placa de rede (127.0.0.1)...${RESET}"
    if ping -c 2 127.0.0.1 &> /dev/null; then
        echo -e "  ${VERDE}[OK] Placa de rede funcionando${RESET}"
    else
        echo -e "  ${VERMELHO}[FALHA] Problema na placa de rede!${RESET}"
    fi
    
    # Teste 2: Gateway
    echo -e "\n${AMARELO}[2/4] Testando gateway...${RESET}"
    if [[ -n "$gateway" ]]; then
        if ping -c 2 "$gateway" &> /dev/null; then
            echo -e "  ${VERDE}[OK] Gateway acessivel: $gateway${RESET}"
        else
            echo -e "  ${VERMELHO}[FALHA] Gateway inacessivel: $gateway${RESET}"
        fi
    else
        echo -e "  ${VERMELHO}[ERRO] Nenhum gateway detectado!${RESET}"
    fi
    
    # Teste 3: Internet
    echo -e "\n${AMARELO}[3/4] Testando conexao com internet (8.8.8.8)...${RESET}"
    if ping -c 2 8.8.8.8 &> /dev/null; then
        echo -e "  ${VERDE}[OK] Internet funcionando${RESET}"
    else
        echo -e "  ${VERMELHO}[FALHA] Sem conexao com internet!${RESET}"
    fi
    
    # Teste 4: DNS
    echo -e "\n${AMARELO}[4/4] Testando resolucao de DNS (google.com)...${RESET}"
    if host google.com &> /dev/null; then
        echo -e "  ${VERDE}[OK] DNS esta resolvendo nomes${RESET}"
    else
        echo -e "  ${VERMELHO}[FALHA] Problema na resolucao de DNS!${RESET}"
        echo -e "  ${AMARELO}[DICA] Verifique /etc/resolv.conf${RESET}"
    fi
    
    echo -e "\n${MAGENTA}================================================${RESET}"
    read -p "Pressione Enter para continuar..."
}

# ============================================
# FUNCOES DE DIAGNOSTICO E REPARO DO SISTEMA
# ============================================

# 9. Verificar sistema de arquivos (fsck)
executar_fsck() {
    escrever_mensagem "Verificacao de sistema de arquivos" "INFO"
    echo -e "${AMARELO}Verificando integridade do sistema de arquivos${RESET}"
    echo -e "${CINZA}Para verificar a particao raiz, o sistema pode precisar reiniciar${RESET}"
    echo ""
    
    df -h | grep -E '^/dev/'
    echo ""
    read -p "Digite a particao para verificar (ex: /dev/sda1) ou Enter para pular: " particao
    
    if [[ -n "$particao" ]]; then
        escrever_mensagem "Executando fsck em modo somente leitura..." "INFO"
        sudo fsck -n "$particao"
        escrever_mensagem "Verificacao fsck finalizada" "SUCESSO"
    fi
}

# 10. Exibir logs do sistema
exibir_logs() {
    escrever_mensagem "Exibindo logs do sistema (ultimas 20 linhas)" "INFO"
    echo -e "${VERDE}"
    journalctl -n 20 --no-pager 2>/dev/null || tail -20 /var/log/messages 2>/dev/null
    echo -e "${RESET}"
    escrever_mensagem "Logs exibidos" "SUCESSO"
}

# 11. Verificar servicos em execucao
verificar_servicos() {
    escrever_mensagem "Verificando servicos do sistema" "INFO"
    echo -e "${VERDE}"
    systemctl list-units --type=service --state=running | head -20
    echo -e "${RESET}"
    escrever_mensagem "Servicos listados (top 20)" "SUCESSO"
}

# 12. Limpar cache de pacotes (dnf/yum)
limpar_cache_pacotes() {
    escrever_mensagem "Limpando cache de pacotes" "INFO"
    
    if command -v dnf &> /dev/null; then
        sudo dnf clean all
        escrever_mensagem "Cache DNF limpo" "SUCESSO"
    elif command -v yum &> /dev/null; then
        sudo yum clean all
        escrever_mensagem "Cache YUM limpo" "SUCESSO"
    else
        escrever_mensagem "Gerenciador de pacotes nao identificado" "ERRO"
    fi
}

# ============================================
# FUNCOES EXTRAS (AUTOMATICAS)
# ============================================

# 13. Diagnostico completo do sistema
diagnostico_completo() {
    escrever_mensagem "INICIANDO DIAGNOSTICO COMPLETO DO SISTEMA" "INFO"
    echo -e "\n${MAGENTA}========== DIAGNOSTICO COMPLETO ==========${RESET}"
    
    echo -e "\n${CIANO}1. Informacoes do sistema:${RESET}"
    echo -e "${CINZA}   Kernel: $(uname -r)${RESET}"
    echo -e "${CINZA}   OS: $(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)${RESET}"
    echo -e "${CINZA}   Uptime: $(uptime -p)${RESET}"
    
    echo -e "\n${CIANO}2. Uso de memoria:${RESET}"
    free -h
    
    echo -e "\n${CIANO}3. Uso de disco:${RESET}"
    df -h | grep -E '^/dev/'
    
    echo -e "\n${CIANO}4. Carga do sistema:${RESET}"
    uptime
    
    echo -e "\n${CIANO}5. Processos com maior uso de CPU:${RESET}"
    ps aux --sort=-%cpu | head -6
    
    echo -e "\n${CIANO}6. Portas abertas:${RESET}"
    ss -tuln | grep LISTEN | head -10
    
    escrever_mensagem "DIAGNOSTICO COMPLETO FINALIZADO" "SUCESSO"
}

# 14. Limpeza completa do sistema
limpeza_completa() {
    escrever_mensagem "INICIANDO LIMPEZA COMPLETA DO SISTEMA" "INFO"
    echo -e "\n${MAGENTA}========== LIMPEZA COMPLETA ==========${RESET}"
    
    echo -e "\n${CIANO}1. Limpando arquivos temporarios...${RESET}"
    limpar_temporarios
    
    echo -e "\n${CIANO}2. Limpando cache DNS...${RESET}"
    limpar_cache_dns
    
    echo -e "\n${CIANO}3. Limpando cache de pacotes...${RESET}"
    limpar_cache_pacotes
    
    echo -e "\n${CIANO}4. Limpando logs antigos...${RESET}"
    sudo journalctl --vacuum-time=7d 2>/dev/null
    find /var/log -name "*.old" -delete 2>/dev/null
    find /var/log -name "*.gz" -delete 2>/dev/null
    echo -e "${CINZA}  Logs antigos removidos${RESET}"
    
    echo -e "\n${CIANO}5. Limpando cache do usuario...${RESET}"
    rm -rf $HOME/.cache/* 2>/dev/null
    rm -rf $HOME/.local/share/Trash/* 2>/dev/null
    
    escrever_mensagem "LIMPEZA COMPLETA FINALIZADA" "SUCESSO"
}

# ============================================
# INTERFACE DO MENU PRINCIPAL
# ============================================

mostrar_menu() {
    clear
    echo -e "${CIANO}========================================${RESET}"
    echo -e "    $NOME_FERRAMENTA"
    echo -e "${CIANO}========================================${RESET}"
    echo -e "${CIANO}========================================${RESET}\n"
    
    echo -e "${AMARELO}[ SISTEMA ]${RESET}"
    echo " 1. Limpar arquivos temporarios"
    echo " 2. Limpar cache DNS"
    echo " 3. Ver configuracao de IP"
    echo " 4. Ver processos em execucao"
    echo " 5. Ver usuarios logados"
    echo " 6. Ver portas abertas"
    echo ""
    
    echo -e "${AMARELO}[ REDE ]${RESET}"
    echo " 7. Testar ping (com opcoes)"
    echo " 8. Reset completo de rede"
    echo ""
    
    echo -e "${AMARELO}[ DIAGNOSTICO E REPARO ]${RESET}"
    echo " 9. Verificar sistema de arquivos (fsck)"
    echo "10. Exibir logs do sistema"
    echo "11. Ver servicos em execucao"
    echo "12. Limpar cache de pacotes (dnf/yum)"
    echo ""
    
    echo -e "${AMARELO}[ EXTRA ]${RESET}"
    echo "13. Diagnostico completo do sistema"
    echo "14. Limpeza completa do sistema"
    echo ""
    
    echo -e "${VERMELHO}[ SAIR ]${RESET}"
    echo " 0. Sair"
    echo ""
    echo -e "${CIANO}========================================${RESET}"
}

# ============================================
# PROGRAMA PRINCIPAL (INICIO)
# ============================================

# Verificar se esta rodando como root
verificar_root

# Limpa a tela e mostra banner inicial
clear
echo -e "${CIANO}========================================${RESET}"
echo -e "     FERRAMENTA DE SUPORTE TECNICO"
echo -e "          Inicializando..."
echo -e "${CIANO}========================================${RESET}"
echo ""
echo -e "${VERDE}Script pronto! Use o menu abaixo.${RESET}"
sleep 2

# Loop principal
while true; do
    mostrar_menu
    read -p $'\nDigite o numero da opcao desejada: ' opcao
    
    case $opcao in
        1) limpar_temporarios; aguardar_enter ;;
        2) limpar_cache_dns; aguardar_enter ;;
        3) exibir_configuracao_ip; aguardar_enter ;;
        4) exibir_processos; aguardar_enter ;;
        5) exibir_usuarios_logados; aguardar_enter ;;
        6) exibir_portas_abertas; aguardar_enter ;;
        7) testar_conexao; aguardar_enter ;;
        8) resetar_rede; aguardar_enter ;;
        9) executar_fsck; aguardar_enter ;;
        10) exibir_logs; aguardar_enter ;;
        11) verificar_servicos; aguardar_enter ;;
        12) limpar_cache_pacotes; aguardar_enter ;;
        13) diagnostico_completo; aguardar_enter ;;
        14) limpeza_completa; aguardar_enter ;;
        0)
            echo -e "\n${CIANO}========================================${RESET}"
            echo -e "${VERDE}Encerrando a ferramenta...${RESET}"
            echo -e "${VERDE}Obrigado por usar $NOME_FERRAMENTA!${RESET}"
            echo -e "${CIANO}========================================${RESET}"
            break
            ;;
        *)
            echo -e "${VERMELHO}Opcao invalida! Digite um numero de 0 a 14.${RESET}"
            sleep 1
            ;;
    esac
done