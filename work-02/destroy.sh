#!/usr/bin/env bash
# Сносит стенд из любого состояния: спрашивает у облака, что есть с префиксом,
# и удаляет только найденное, в обратном порядке зависимостей.
set -euo pipefail

PREFIX=evdokimov-11

by_prefix() {  # by_prefix <команда yc ... list>: имена ресурсов, начинающихся с префикса
  "$@" --format json | jq -r --arg p "$PREFIX" '.[] | select((.name // "") | startswith($p)) | .name'
}

for name in $(by_prefix yc load-balancer network-load-balancer list); do
  echo "==> балансировщик $name"; yc load-balancer network-load-balancer delete --name "$name"
done
for name in $(by_prefix yc load-balancer target-group list); do
  echo "==> целевая группа $name"; yc load-balancer target-group delete --name "$name"
done
for name in $(by_prefix yc compute instance list); do
  echo "==> машина $name"; yc compute instance delete --name "$name"
done
for name in $(by_prefix yc compute disk list); do
  echo "==> диск $name"; yc compute disk delete --name "$name"
done
for name in $(by_prefix yc vpc subnet list); do
  echo "==> подсеть $name"; yc vpc subnet delete --name "$name"
done
for name in $(by_prefix yc vpc network list); do
  echo "==> сеть $name"; yc vpc network delete --name "$name"
done
echo "==> готово: ресурсов с префиксом $PREFIX не осталось"
