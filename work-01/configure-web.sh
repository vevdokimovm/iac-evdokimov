#!/usr/bin/env bash
# Запускается на машине по SSH: nginx на своём порту, со словом варианта и именем хоста.
set -euo pipefail

PORT=8033
WORD=devlab

sudo apt-get update -qq
sudo apt-get install -y -qq nginx
sudo sed -i "s/listen 80 default_server;/listen $PORT default_server;/; s/listen \[::\]:80 default_server;/listen [::]:$PORT default_server;/" \
  /etc/nginx/sites-enabled/default
sudo sed -i "s|Welcome to nginx!|$WORD on $(hostname)|g" /var/www/html/index.nginx-debian.html
sudo nginx -t
sudo systemctl reload nginx
curl -s "localhost:$PORT" | grep -o "$WORD on [a-z0-9-]*" | head -1
