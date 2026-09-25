#!/usr/bin/env bash
# ДЗ 1: стенд для показов (веб-серверы в двух зонах за балансировщиком, сервер приложения за NAT).
# Повторный запуск досоздаёт только то, чего не хватает.
# usage: ./create.sh [--web-count N] [--port P] [--env NAME]
set -euo pipefail
cd "$(dirname "$0")"

# ---- умолчания варианта 11; переменная окружения важнее умолчания, аргумент важнее переменной ----
PREFIX="${PREFIX:-evdokimov-11}"
ZONE_A="${ZONE_A:-ru-central1-b}"
ZONE_B="${ZONE_B:-ru-central1-d}"
CIDR_A="${CIDR_A:-10.21.1.0/24}"
CIDR_B="${CIDR_B:-10.21.2.0/24}"
APP_PORT="${APP_PORT:-8033}"
GREETING="${GREETING:-devlab}"
WEB_COUNT="${WEB_COUNT:-2}"
ENV_NAME="${ENV_NAME:-test}"
BOOT_SIZE="${BOOT_SIZE:-20}"
IMAGE_FAMILY=ubuntu-2404-lts

while [[ $# -gt 0 ]]; do
  case "$1" in
    --web-count) WEB_COUNT="$2"; shift 2 ;;
    --port)      APP_PORT="$2"; shift 2 ;;
    --env)       ENV_NAME="$2"; shift 2 ;;
    -h|--help)   sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "неизвестный аргумент: $1" >&2; exit 2 ;;
  esac
done
[[ "$WEB_COUNT" =~ ^[1-9][0-9]*$ ]] || { echo "--web-count: нужно целое > 0" >&2; exit 2; }
[[ "$APP_PORT" =~ ^[0-9]+$ ]] || { echo "--port: нужно число" >&2; exit 2; }
LABELS="env=$ENV_NAME,owner=$PREFIX"

exists() { yc "$@" >/dev/null 2>&1; }          # код возврата get: 0 — ресурс есть
skip()   { echo "    $1 уже есть, пропускаю"; }
ext_ip() { yc compute instance get --name "$1" --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address // empty'; }
int_ip() { yc compute instance get --name "$1" --format json | jq -r '.network_interfaces[0].primary_v4_address.address'; }

echo "==> сеть и подсети"
if exists vpc network get --name "$PREFIX-net"; then skip "$PREFIX-net"
else yc vpc network create --name "$PREFIX-net" --labels "$LABELS" >/dev/null; fi
for pair in "a $ZONE_A $CIDR_A" "b $ZONE_B $CIDR_B"; do
  read -r s zone cidr <<< "$pair"
  if exists vpc subnet get --name "$PREFIX-subnet-$s"; then skip "$PREFIX-subnet-$s"
  else yc vpc subnet create --name "$PREFIX-subnet-$s" --network-name "$PREFIX-net" \
         --zone "$zone" --range "$cidr" --labels "$LABELS" >/dev/null; fi
done

echo "==> NAT-шлюз и таблица маршрутизации"
if exists vpc gateway get --name "$PREFIX-nat"; then skip "$PREFIX-nat"
else yc vpc gateway create --name "$PREFIX-nat" --labels "$LABELS" >/dev/null; fi
GW_ID=$(yc vpc gateway get --name "$PREFIX-nat" --format json | jq -r .id)
if exists vpc route-table get --name "$PREFIX-rt"; then skip "$PREFIX-rt"
else yc vpc route-table create --name "$PREFIX-rt" --network-name "$PREFIX-net" \
       --route "destination=0.0.0.0/0,gateway-id=$GW_ID" --labels "$LABELS" >/dev/null; fi
RT_ID=$(yc vpc route-table get --name "$PREFIX-rt" --format json | jq -r .id)
if [[ "$(yc vpc subnet get --name "$PREFIX-subnet-a" --format json | jq -r '.route_table_id // empty')" == "$RT_ID" ]]; then
  skip "маршрут подсети $PREFIX-subnet-a"
else yc vpc subnet update --name "$PREFIX-subnet-a" --route-table-name "$PREFIX-rt" >/dev/null; fi

echo "==> файл настройки из шаблона"
SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export APP_PORT GREETING SSH_KEY
envsubst '${APP_PORT} ${GREETING} ${SSH_KEY}' < cloud-init.tpl.yaml > cloud-init.yaml

create_vm() {  # create_vm <name> <zone> <subnet> <public: yes|no>
  local nat=""
  [[ "$4" == yes ]] && nat=",nat-ip-version=ipv4"
  if exists compute instance get --name "$1"; then skip "$1"; return; fi
  yc compute instance create --name "$1" --hostname "$1" --zone "$2" \
    --platform standard-v3 --cores=2 --core-fraction=20 --memory=2 --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$BOOT_SIZE" \
    --network-interface subnet-name="$3""$nat" \
    --metadata-from-file user-data=cloud-init.yaml --labels "$LABELS" >/dev/null
  echo "    создана $1"
}

echo "==> веб-серверы"
ZONES=("$ZONE_A" "$ZONE_B"); SUBNETS=("$PREFIX-subnet-a" "$PREFIX-subnet-b")
for i in $(seq 1 "$WEB_COUNT"); do
  idx=$(( (i - 1) % 2 ))
  create_vm "$PREFIX-web-$i" "${ZONES[$idx]}" "${SUBNETS[$idx]}" yes
done

echo "==> сервер приложения (без публичного адреса)"
create_vm "$PREFIX-app" "$ZONE_A" "$PREFIX-subnet-a" no

echo "==> целевая группа"
if exists load-balancer target-group get --name "$PREFIX-tg"; then skip "$PREFIX-tg"
else
  TARGETS=()
  for i in $(seq 1 "$WEB_COUNT"); do
    idx=$(( (i - 1) % 2 ))
    TARGETS+=(--target "subnet-name=${SUBNETS[$idx]},address=$(int_ip "$PREFIX-web-$i")")
  done
  yc load-balancer target-group create --name "$PREFIX-tg" --labels "$LABELS" "${TARGETS[@]}" >/dev/null
fi

echo "==> балансировщик"
if exists load-balancer network-load-balancer get --name "$PREFIX-lb"; then skip "$PREFIX-lb"
else
  TG_ID=$(yc load-balancer target-group get --name "$PREFIX-tg" --format json | jq -r .id)
  yc load-balancer network-load-balancer create --name "$PREFIX-lb" --region-id ru-central1 --labels "$LABELS" \
    --listener name=http,port=80,target-port="$APP_PORT",external-ip-version=ipv4 \
    --target-group target-group-id="$TG_ID",healthcheck-name=http,healthcheck-interval=2s,healthcheck-timeout=1s,healthcheck-unhealthythreshold=2,healthcheck-healthythreshold=2,healthcheck-http-port="$APP_PORT",healthcheck-http-path=/ >/dev/null
fi

echo "==> ожидание готовности"
TG_ID=$(yc load-balancer target-group get --name "$PREFIX-tg" --format json | jq -r .id)
for _ in $(seq 1 90); do
  states=$(yc load-balancer network-load-balancer target-states --name "$PREFIX-lb" \
             --target-group-id "$TG_ID" --format json | jq -r '[.[].status] | unique | join(",")')
  [[ "$states" == "HEALTHY" ]] && break
  sleep 5
done
LB_IP=$(yc load-balancer network-load-balancer get --name "$PREFIX-lb" --format json | jq -r '.listeners[0].address')
echo "стенд готов: http://$LB_IP (цели: $states)"
