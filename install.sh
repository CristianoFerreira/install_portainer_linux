#!/bin/bash

# Cores
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
BLUE='\e[34m'
NC='\e[0m'

# Função para mostrar spinner de carregamento
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Função para verificar requisitos do sistema
check_system_requirements() {
    echo -e "${BLUE}Verificando requisitos do sistema...${NC}"
    
    # Verificar espaço em disco (em GB, removendo a unidade 'G')
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$free_space" -lt 10 ]; then
        echo -e "${RED}❌ Erro: Espaço em disco insuficiente. Mínimo requerido: 10GB${NC}"
        return 1
    fi
    
    # Verificar memória RAM
    local total_mem=$(free -g | awk 'NR==2 {print $2}')
    if [ $total_mem -lt 2 ]; then
        echo -e "${RED}❌ Erro: Memória RAM insuficiente. Mínimo requerido: 2GB${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Requisitos do sistema atendidos${NC}"
    return 0
}

# Logo animado
show_animated_logo() {
    clear
    echo -e "${GREEN}"
    echo -e "  _____        _____ _  __  _________     _______  ______ ____   ____ _______ "
    echo -e " |  __ \ /\   / ____| |/ / |__   __\ \   / /  __ \|  ____|  _ \ / __ \__   __|"
    echo -e " | |__) /  \ | |    | ' /     | |   \ \_/ /| |__) | |__  | |_) | |  | | | |   "
    echo -e " |  ___/ /\ \| |    |  <      | |    \   / |  ___/|  __| |  _ <| |  | | | |   "
    echo -e " | |  / ____ \ |____| . \     | |     | |  | |    | |____| |_) | |__| | | |   "
    echo -e " |_| /_/    \_\_____|_|\_\    |_|     |_|  |_|    |______|____/ \____/  |_|   "
    echo -e "${NC}"
    sleep 1
}

# Função para mostrar um banner colorido
function show_banner() {
    echo -e "${GREEN}=============================================================================="
    echo -e "=                                                                            ="
    echo -e "=                 ${YELLOW}Preencha as informações solicitadas abaixo${GREEN}                 ="
    echo -e "=                                                                            ="
    echo -e "==============================================================================${NC}"
}

# Função para mostrar uma mensagem de etapa com barra de progresso
function show_step() {
    local current=$1
    local total=5
    local percent=$((current * 100 / total))
    local completed=$((percent / 2))
    
    echo -ne "${GREEN}Passo ${YELLOW}$current/$total ${GREEN}["
    for ((i=0; i<50; i++)); do
        if [ $i -lt $completed ]; then
            echo -ne "="
        else
            echo -ne " "
        fi
    done
    echo -e "] ${percent}%${NC}"
}

# Mostrar banner inicial
clear
show_animated_logo
show_banner
echo ""

# Solicitar informações do usuário
show_step 1
read -p "📧 Endereço de e-mail: " email
echo ""
show_step 2
read -p "🌐 Dominio do Traefik (ex: traefik.seudominio.com): " traefik
echo ""
show_step 3
read -s -p "🔑 Senha do Traefik: " senha
echo ""
echo ""
show_step 4
read -p "🌐 Dominio do Portainer (ex: portainer.seudominio.com): " portainer
echo ""
show_step 5
read -p "🌐 Dominio do Edge (ex: edge.seudominio.com): " edge
echo ""

# Verificação de dados
clear
echo -e "${BLUE}📋 Resumo das Informações${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "📧 Seu E-mail: ${YELLOW}$email${NC}"
echo -e "🌐 Dominio do Traefik: ${YELLOW}$traefik${NC}"
echo -e "🔑 Senha do Traefik: ${YELLOW}$senha${NC}"
echo -e "🌐 Dominio do Portainer: ${YELLOW}$portainer${NC}"
echo -e "🌐 Dominio do Edge: ${YELLOW}$edge${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

read -p "As informações estão certas? (y/n): " confirma1
if [ "$confirma1" == "y" ]; then
    clear
    
    # Verificar requisitos do sistema
    check_system_requirements || exit 1
    
    echo -e "${BLUE}🚀 Iniciando instalação...${NC}"
    
    #########################################################
    # INSTALANDO DEPENDENCIAS
    #########################################################
    echo -e "${YELLOW}📦 Atualizando sistema e instalando dependências...${NC}"
    (sudo apt update -y && sudo apt upgrade -y) > /dev/null 2>&1 &
    spinner $!
    
    echo -e "${YELLOW}🐳 Instalando Docker...${NC}"
    (sudo apt install -y curl && \
    curl -fsSL https://get.docker.com -o get-docker.sh && \
    sudo sh get-docker.sh) > /dev/null 2>&1 &
    spinner $!
    
    mkdir -p ~/Portainer && cd ~/Portainer
    echo -e "${GREEN}✅ Dependências instaladas com sucesso${NC}"
    sleep 2
    clear

    #########################################################
    # CRIANDO DOCKER-COMPOSE.YML
    #########################################################
    cat > docker-compose.yml <<EOL
services:
  traefik:
    image: traefik:latest
    container_name: traefik
    ports:
      - 80:80
      - 443:443
    expose:
      - 8080  # expose the dashboard only in traefik network 
    volumes:
      - ./ssl-certs:/ssl-certs
      - ./etc/traefik:/etc/traefik
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
    command:
      - --global.checkNewVersion=true
      - --global.sendAnonymousUsage=false
      - --log.level=ERROR  # DEBUG, INFO, WARNING, ERROR, CRITICAL
      - --log.format=common  # common, json, logfmt
      - --log.filePath=/etc/traefik/traefik.log
      - --log.accesslog.format=common
      - --log.accesslog.filePath=/var/log/traefik/access.log
      - --api.insecure=true
      - --api.dashboard=true
      - --entrypoints.web.address=:80
      - --entrypoints.web.forwardedHeaders.insecure=true
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entryPoints.web.http.redirections.entrypoint.scheme=https
      - --entrypoints.websecure.address=:443
      - --entrypoints.websecure.forwardedHeaders.insecure=true
      - --certificatesResolvers.staging.acme.email=$email
      - --certificatesResolvers.staging.acme.storage=/ssl-certs/acme.json
      - --certificatesResolvers.staging.acme.caServer="https://acme-staging-v02.api.letsencrypt.org/directory"
      - --certificatesResolvers.staging.acme.httpChallenge.entryPoint=web
      - --certificatesResolvers.production.acme.email=$email
      - --certificatesResolvers.production.acme.storage=/ssl-certs/acme.json
      - --certificatesResolvers.production.acme.caServer="https://acme-staging-v02.api.letsencrypt.org/directory"
      - --certificatesResolvers.production.acme.httpChallenge.entryPoint=web
      - --providers.docker.exposedByDefault=false  # Default is true
      - --providers.file.directory=./etc/traefik  # watch for dynamic configuration changes
      - --providers.file.watch=true
    labels:
      - "traefik.http.routers.http-catchall.rule=hostregexp(\`{host:.+}\`)"
      - "traefik.http.routers.http-catchall.entrypoints=web"
      - "traefik.http.routers.http-catchall.middlewares=redirect-to-https"
      - "traefik.enable=true"  # <== Enable traefik on itself to view dashboard and assign subdomain to view it
      - "traefik.http.routers.traefik_https.rule=Host(\`$traefik\`)" # <== Setting the domain for the dashboard
      - "traefik.http.routers.traefik_https.entrypoints=web,websecure"
      - "traefik.http.routers.traefik_https.service=traefik-service"
      - "traefik.http.services.traefik-service.loadbalancer.server.port=8080"
      - "traefik.http.routers.traefik_https.tls=true"
      - "traefik.http.routers.traefik_https.tls.certresolver=production"
      - "traefik.http.routers.traefik_https.middlewares=basic-auth-global"
      - "traefik.http.middlewares.basic-auth-global.basicauth.users=$senha"
  portainer:
    container_name: portainer
    expose:
      - 9000
      - 8000
    volumes:
        - '/var/run/docker.sock:/var/run/docker.sock'
        - 'portainer_data:/data'
    restart: unless-stopped
    image: portainer/portainer-ce:latest
    command: -H unix:///var/run/docker.sock
    restart: always
    labels:
      - "traefik.enable=true" # <== Enable traefik on itself to view dashboard and assign subdomain to view it
      - "traefik.http.routers.portainer.entrypoints=web,websecure"
      - "traefik.http.routers.portainer.rule=Host(\`$portainer\`)" # <== Setting the domain for the dashboard
      - "traefik.http.routers.portainer.service=portainer-service"
      - "traefik.http.services.portainer-service.loadbalancer.server.port=9000"
      - "traefik.http.routers.portainer.tls=true"
      - "traefik.http.routers.portainer.tls.certresolver=production"
      - "traefik.http.routers.edge.entrypoints=web,websecure"
      - "traefik.http.routers.edge.rule=Host(\`$edge\`)" # <== Setting the domain for the dashboard
      - "traefik.http.routers.edge.service=edge-service"
      - "traefik.http.services.edge-service.loadbalancer.server.port=8000"
      - "traefik.http.routers.edge.tls=true"
      - "traefik.http.routers.edge.tls.certresolver=production"
volumes:
  portainer_data:
EOL

    #########################################################
    # CERTIFICADOS LETSENCRYPT
    #########################################################
    echo -e "${YELLOW}📝 Gerando certificado LetsEncrypt...${NC}"
    touch acme.json
    sudo chmod 600 acme.json
    
    #########################################################
    # INICIANDO CONTAINER
    #########################################################
    echo -e "${YELLOW}🚀 Iniciando containers...${NC}"
    (sudo docker compose up -d) > /dev/null 2>&1 &
    spinner $!
    
    clear
    show_animated_logo
    
    echo -e "${GREEN}🎉 Instalação concluída com sucesso!${NC}"
    echo -e "${BLUE}📝 Informações de Acesso:${NC}"
    echo -e "${GREEN}================================${NC}"
    echo -e "🔗 Portainer: ${YELLOW}https://$portainer${NC}"
    echo -e "🔗 Traefik: ${YELLOW}https://$traefik${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${BLUE}💡 Dica: Aguarde alguns minutos para que os certificados SSL sejam gerados${NC}"
    echo -e "${GREEN}🌟 Visite: https://packtypebot.com.br${NC}"
else
    echo -e "${RED}❌ Instalação cancelada. Por favor, inicie novamente.${NC}"
    exit 0
fi
