#!/bin/bash
# 🚀 HNG Stage 1 DevOps Deploy Script
# Author: Sehihub
# Bash script to deploy a Dockerized application on a remote server with Nginx reverse proxy

set -e
set -o pipefail

LOGFILE="deploy_$(date +%Y%m%d%H%M%S).log"

echo "🚀 Starting Deployment..." | tee -a "$LOGFILE"

# --- Collect User Inputs ---
read -rp "Enter Git Repository URL: " GIT_REPO
read -rp "Enter Personal Access Token (PAT): " GIT_PAT
read -rp "Enter Branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -rp "Enter Remote Server Username: " REMOTE_USER
read -rp "Enter Remote Server IP Address: " REMOTE_IP
read -rp "Enter Path to SSH Key: " SSH_KEY
read -rp "Enter Application Port (container internal port): " APP_PORT

echo "📦 Repo exists? Checking locally..."
REPO_NAME=$(basename -s .git "$GIT_REPO")

if [ -d "$REPO_NAME" ]; then
    echo "📦 Repo exists. Pulling latest changes..." | tee -a "$LOGFILE"
    cd "$REPO_NAME"
    git fetch origin "$BRANCH"
    git reset --hard "origin/$BRANCH"
else
    echo "📦 Cloning repository..." | tee -a "$LOGFILE"
    git clone -b "$BRANCH" "https://$GIT_PAT@${GIT_REPO#https://}" "$REPO_NAME"
    cd "$REPO_NAME"
fi

# --- Verify Dockerfile or docker-compose.yml ---
if [[ ! -f Dockerfile && ! -f docker-compose.yml ]]; then
    echo "❌ No Dockerfile or docker-compose.yml found. Aborting." | tee -a "$LOGFILE"
    exit 1
fi

# --- Test SSH connection ---
echo "🔑 Testing SSH connection..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "echo 'SSH connection successful ✅'" | tee -a "$LOGFILE"

# --- Prepare remote environment ---
echo "⚙️  Setting up remote environment..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" bash << EOF
if command -v apt-get &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y docker.io docker-compose nginx
elif command -v dnf &> /dev/null; then
    sudo dnf update -y
    sudo dnf install -y docker nginx
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.22.0/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "❌ No supported package manager found."
    exit 1
fi

sudo systemctl enable --now docker
sudo systemctl enable --now nginx
sudo usermod -aG docker $REMOTE_USER || true
EOF

# --- Deploy the Dockerized application ---
echo "🚢 Deploying Dockerized application..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" bash << EOF
cd ~
mkdir -p $REPO_NAME
rsync -av --exclude='.git' ./ $REMOTE_USER@$REMOTE_IP:~/$REPO_NAME/
cd $REPO_NAME

if [ -f docker-compose.yml ]; then
    docker-compose down || true
    docker-compose up -d --build
else
    docker stop $REPO_NAME || true
    docker rm $REPO_NAME || true
    docker build -t $REPO_NAME .
    docker run -d --name $REPO_NAME -p $APP_PORT:$APP_PORT $REPO_NAME
fi
EOF

# --- Configure Nginx ---
echo "🌐 Configuring Nginx reverse proxy..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" bash << EOF
NGINX_CONF="/etc/nginx/conf.d/$REPO_NAME.conf"
sudo tee \$NGINX_CONF > /dev/null << NGINX
server {
    listen 80;
    server_name $REMOTE_IP;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

sudo nginx -t
sudo systemctl reload nginx
EOF

# --- Validate Deployment ---
echo "✅ Deployment finished. Validating..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" "curl -I http://127.0.0.1:$APP_PORT"

echo "🎉 Deployment complete! Check http://$REMOTE_IP in your browser."

