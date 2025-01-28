## Prerequisites

#### Installing Docker: Follow the installation instructions provided on the official Docker website for your operating system. Below are the installation commands for Ubuntu:

```
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
```

#### Installing Docker Compose: Install Docker Compose by following the relevant instructions. Below is how to install Docker Compose globally:

```
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

#### Installing htpasswd: You’ll need the htpasswd utility to create hashed passwords for basic authentication. Install it as follows for ubuntu

```
sudo apt update
sudo apt install -y apache2-utils
```

## Step 1: Configuring Domain Names
#### If you have a registered domain, you can configure DNS records to point to your server’s IP address. Ensure that DNS records are properly configured for the domains used in your composition files.

## Step 2: Project Structure Preparation
#### Create a directory for your project and navigate into it:

```
mkdir -p traefik-portainer-project/{traefik,portainer}
cd traefik-portainer-project
```

## Step 3: Configuring Traefik Proxy with Basic Authentication

```
cd traefik
mkdir ssl-certs
mkdir -p etc/traefik
```

### 1. Create a **traefik.yml** file for Traefik configuration in etc/traefik directory :

```
global:
  checkNewVersion: true
  sendAnonymousUsage: false  # true by default

# (Optional) Log information
# ---
log:
  level: ERROR  # DEBUG, INFO, WARNING, ERROR, CRITICAL
  format: common  # common, json, logfmt
  filePath: /etc/traefik/traefik.log

# (Optional) Accesslog
# ---
# accesslog:
  # format: common  # common, json, logfmt
  # filePath: /var/log/traefik/access.log

# (Optional) Enable API and Dashboard
# ---
api:
  dashboard: true  # true by default
  insecure: true  # Don't do this in production!

# Entry Points configuration
# ---
entryPoints:
  web:
    address: :80
    forwardedHeaders:
      insecure: true
    # (Optional) Redirect to HTTPS
    # ---
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https

  websecure:
    address: :443
    forwardedHeaders:
      insecure: true

# Configure your CertificateResolver here...
# ---
certificatesResolvers:
  staging:
    acme:
      email: your-email@yourdomain.me
      storage: /ssl-certs/acme.json
      caServer: "https://acme-staging-v02.api.letsencrypt.org/directory"
      httpChallenge:
        entryPoint: web
#
  production:
    acme:
      email: your-email@yourdomain.me
      storage: /ssl-certs/acme.json
      caServer: "https://acme-v02.api.letsencrypt.org/directory"
      httpChallenge:
        entryPoint: web

# (Optional) Overwrite Default Certificates
# tls:
#   stores:
#     default:
#       defaultCertificate:
#         certFile: /etc/traefik/certs/cert.pem
#         keyFile: /etc/traefik/certs/cert-key.pem
# (Optional) Disable TLS version 1.0 and 1.1
#   options:
#     default:
#       minVersion: VersionTLS12

providers:
  docker:
    exposedByDefault: false  # Default is true
  file:
    # watch for dynamic configuration changes
    directory: /etc/traefik
    watch: true
```

### 2. Create docker-compose.yml file for Traefik in traefik-portainer-project/traefik directory

```
---
version: '3'
services:
  traefik:
    image: traefik
    container_name: traefik
    ports:
      - 80:80
      - 443:443
    expose:
      - 8080 # expose the dashboard only in traefik network 
    volumes:
      - ./ssl-certs:/ssl-certs
      - ./etc/traefik:/etc/traefik
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
    labels:
      - "traefik.enable=true" # <== Enable traefik on itself to view dashboard and assign subdomain to view it
      - "traefik.http.routers.traefik_https.rule=Host(`traefik.yourdomain.me`)" # <== Setting the domain for the dashboard
      - "traefik.http.routers.traefik_https.entrypoints=web,websecure"
      - "traefik.http.routers.traefik_https.service=traefik-service"
      - "traefik.http.services.traefik-service.loadbalancer.server.port=8080"
      - "traefik.http.routers.traefik_https.tls=true"
      - "traefik.http.routers.traefik_https.tls.certresolver=production"
      - "traefik.http.routers.traefik_https.middlewares=basic-auth-global"
      - "traefik.http.middlewares.basic-auth-global.basicauth.usersfile=/etc/traefik/users"
```

##### 3. Generate the hashed password using the htpasswd utility:

```
htpasswd -c etc/traefik/users admin
```

#### You’ll be prompted to provide and confirm a password for this user.

### 4. Launch Traefik by running the following command in your Traefik project folder:

```
docker-compose up -d
```

## Step 4: Installing Portainer
### 1. Create a ***docker-compose.yml*** file for Portainer in traefik-portainer-project/portainer

```
version: '3.3'
services:
    portainer-ce:
        container_name: portainer
        expose:
          - 9000
        volumes:
            - '/var/run/docker.sock:/var/run/docker.sock'
            - 'portainer_data:/data'
        restart: unless-stopped
        image: portainer/portainer-ce:latest
        labels:
          - "traefik.enable=true" # <== Enable traefik on itself to view dashboard and assign subdomain to view it
          - "traefik.http.routers.portainer.entrypoints=web,websecure"
          - "traefik.http.routers.portainer.rule=Host(`portainer.yourdomain.me`)" # <== Setting the domain for the dashboard
          - "traefik.http.routers.portainer.service=portainer-service"
          - "traefik.http.services.portainer-service.loadbalancer.server.port=9000"
          - "traefik.http.routers.portainer.tls=true"
          - "traefik.http.routers.portainer.tls.certresolver=production"
 
volumes:
  portainer_data:

networks:
  default:
    external:
      name: traefik_default
```

#### ***traefik_default*** is the name given to the network created by traefik. Portainer must be part of this network.

### 2. Launch Portainer by running the following command in your Portainer project folder:

```
docker-compose up -d
```

## Accessing the Services
#### Now that everything is set up, you can access your services:

### Traefik Dashboard: Open a browser and go to https://taefik.yourdomain.me to access the secured Traefik dashboard.


### Portainer: Access https://portainer.yourdomain.me to reach the secure Portainer management interface. Follow the prompts to set up Portainer on your first use.
