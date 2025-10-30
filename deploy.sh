#!/bin/bash
set -e

echo "🚀 Starting Blue/Green Deployment Setup..."

# Load environment variables
if [ -f .env ]; then
  echo "📦 Loading environment from .env..."
  source .env
else
  echo "❌ .env file not found! Please create it or copy from .env.example."
  exit 1
fi

# Check Docker installation
if ! command -v docker &> /dev/null; then
  echo "🐳 Docker not found! Installing..."
  sudo apt update -y && sudo apt install -y docker.io
  sudo systemctl start docker
  sudo systemctl enable docker
fi

# Check Docker Compose installation
if ! command -v docker compose &> /dev/null; then
  echo "🧩 Installing Docker Compose plugin..."
  sudo apt update -y && sudo apt install -y docker-compose-plugin
fi

# Verify docker works
docker ps > /dev/null || { echo "❌ Docker daemon not running!"; exit 1; }

# Pull images
echo "⬇️  Pulling Blue and Green app images..."
docker pull "$BLUE_IMAGE"
docker pull "$GREEN_IMAGE"

# Build/refresh Nginx config
echo "🌀 Generating Nginx config for ACTIVE_POOL=$ACTIVE_POOL ..."
chmod +x nginx/entrypoint.sh
./nginx/entrypoint.sh

# Deploy containers
echo "🚢 Starting Docker Compose..."
docker compose up -d --force-recreate

# Wait a bit for services to come up
echo "⏳ Waiting for services..."
sleep 10

# Verify
echo "🔍 Checking deployed version:"
curl -I http://localhost:8080/version || true

echo "✅ Deployment complete!"
