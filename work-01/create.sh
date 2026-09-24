#!/usr/bin/env bash
# Stand of practical work 1, independent part: network, subnet and two VMs on an empty folder.
set -euo pipefail

PREFIX=evdokimov-11
ZONE=ru-central1-b
CIDR=10.21.1.0/24
DISK_SIZE=20
IMAGE_FAMILY=debian-12
VM_NAMES=("$PREFIX-app-1" "$PREFIX-app-2")
SSH_KEY="$HOME/.ssh/id_ed25519.pub"

exists() { yc "$@" >/dev/null 2>&1; }

exists vpc network get --name "$PREFIX-net" || \
  yc vpc network create --name "$PREFIX-net" --labels created-by=script

exists vpc subnet get --name "$PREFIX-subnet" || \
  yc vpc subnet create --name "$PREFIX-subnet" --network-name "$PREFIX-net" \
    --zone "$ZONE" --range "$CIDR" --labels created-by=script

for name in "${VM_NAMES[@]}"; do
  exists compute instance get --name "$name" && { echo "$name already exists"; continue; }
  yc compute instance create \
    --name "$name" \
    --hostname "$name" \
    --zone "$ZONE" \
    --platform standard-v3 \
    --cores=2 --core-fraction=20 --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$DISK_SIZE" \
    --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
    --ssh-key "$SSH_KEY" \
    --labels created-by=script
done

yc compute instance list --format json | jq -r \
  ".[] | select(.name | startswith(\"$PREFIX\")) | \"\(.name)\t\(.status)\t\(.network_interfaces[0].primary_v4_address.one_to_one_nat.address // \"нет\")\""
