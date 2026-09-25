#!/usr/bin/env bash
# Удаляет всё с префиксом: что есть, спрашивает у облака, а не берёт из списка в скрипте.
set -euo pipefail

PREFIX=evdokimov-11

for name in $(yc compute instance list --format json | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name"); do
  yc compute instance delete --name "$name"
done
for name in $(yc compute disk list --format json | jq -r ".[] | select(.name // \"\" | startswith(\"$PREFIX\")) | .name"); do
  yc compute disk delete --name "$name"
done
if yc vpc subnet get --name "$PREFIX-subnet" >/dev/null 2>&1; then
  yc vpc subnet delete --name "$PREFIX-subnet"
fi
if yc vpc network get --name "$PREFIX-net" >/dev/null 2>&1; then
  yc vpc network delete --name "$PREFIX-net"
fi

yc compute instance list
yc compute disk list
yc vpc network list
