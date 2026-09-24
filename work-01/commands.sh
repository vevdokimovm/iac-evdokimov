#!/usr/bin/env bash
# Практика 1 — журнал команд, которыми создавались и удалялись ресурсы.

# сервисный аккаунт и роль
yc iam service-account get --name evdokimov-11-sa >/dev/null 2>&1 || \
  yc iam service-account create --name evdokimov-11-sa
export FOLDER_ID=$(yc config get folder-id)
export SA_ID=$(yc iam service-account get --name evdokimov-11-sa --format json | jq -r .id)
yc resource-manager folder add-access-binding "$FOLDER_ID" --role editor --subject "serviceAccount:$SA_ID"
mkdir -p ~/.yc-keys
[ -s ~/.yc-keys/evdokimov-11-key.json ] || \
  yc iam key create --service-account-name evdokimov-11-sa --output ~/.yc-keys/evdokimov-11-key.json

# своя сеть и подсеть
export PREFIX=evdokimov-11
export ZONE=ru-central1-b
export CIDR=10.21.1.0/24
export DISK_SIZE=20
yc vpc network create --name "$PREFIX-net"
yc vpc subnet create --name "$PREFIX-subnet" --network-name "$PREFIX-net" --zone "$ZONE" --range "$CIDR"

# машина в своей сети
yc compute instance create \
  --name "$PREFIX-web-1" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2404-lts,type=network-hdd,size="$DISK_SIZE" \
  --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --labels created-by=cli

# остановленные прерываемые машины — какие поднять снова
yc compute instance list --format json | jq -r '.[] | select(.status != "RUNNING") | .name'

# уборка
yc compute instance delete "$PREFIX-web-1"
yc compute instance delete "$PREFIX-web-manual"
yc vpc subnet delete "$PREFIX-subnet"
yc vpc network delete "$PREFIX-net"
