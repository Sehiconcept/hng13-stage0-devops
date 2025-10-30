#!/bin/sh
set -e

# Substitute environment variables in nginx config
envsubst '${ACTIVE_POOL} ${BLUE_BACKEND} ${GREEN_BACKEND}' < \
    /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Start nginx in foreground
exec nginx -g 'daemon off;'
