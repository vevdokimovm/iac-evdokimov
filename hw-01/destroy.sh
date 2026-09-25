#!/usr/bin/env bash
# Удаляет всё, что создал create.sh: находит свои ресурсы по префиксу и удаляет их в обратном порядке.
set -euo pipefail
PREFIX="${PREFIX:-evdokimov-11}"

by_prefix() { "$@" --format json | jq -r --arg p "$PREFIX" '.[] | select((.name // "") | startswith($p)) | .name'; }

for n in $(by_prefix yc load-balancer network-load-balancer list); do echo "==> балансировщик $n"; yc load-balancer network-load-balancer delete --name "$n" >/dev/null; done
for n in $(by_prefix yc load-balancer target-group list);        do echo "==> целевая группа $n"; yc load-balancer target-group delete --name "$n" >/dev/null; done
for n in $(by_prefix yc compute instance list);                  do echo "==> машина $n"; yc compute instance delete --name "$n" >/dev/null; done
for n in $(by_prefix yc compute disk list);                      do echo "==> диск $n"; yc compute disk delete --name "$n" >/dev/null; done
for n in $(by_prefix yc vpc subnet list); do
  if [[ -n "$(yc vpc subnet get --name "$n" --format json | jq -r '.route_table_id // empty')" ]]; then
    echo "==> отвязка таблицы маршрутизации от $n"; yc vpc subnet update --name "$n" --disassociate-route-table >/dev/null
  fi
done
for n in $(by_prefix yc vpc route-table list); do echo "==> таблица маршрутизации $n"; yc vpc route-table delete --name "$n" >/dev/null; done
for n in $(by_prefix yc vpc gateway list);     do echo "==> NAT-шлюз $n"; yc vpc gateway delete --name "$n" >/dev/null; done
for n in $(by_prefix yc vpc subnet list);      do echo "==> подсеть $n"; yc vpc subnet delete --name "$n" >/dev/null; done
for n in $(by_prefix yc vpc network list);     do echo "==> сеть $n"; yc vpc network delete --name "$n" >/dev/null; done
for n in $(by_prefix yc vpc address list);     do echo "==> адрес $n"; yc vpc address delete --name "$n" >/dev/null; done
echo "==> готово"
