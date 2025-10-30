#!/bin/sh
set -e

echo "🌀 Generating Nginx config for ACTIVE_POOL=$ACTIVE_POOL ..."

# Create temporary nginx.conf from template
envsubst '$ACTIVE_POOL' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

echo "✅ Nginx config generated."
echo "▶️ Starting Nginx..."

nginx -g 'daemon off;'
