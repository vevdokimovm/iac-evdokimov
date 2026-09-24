#!/usr/bin/env bash
# Health of the stand for a human and for a CI runner: one line per check, exit code 0 = all passed, 1 = something failed.
set -uo pipefail

PREFIX="${PREFIX:-evdokimov-11}"
APP_PORT="${APP_PORT:-8033}"
GREETING="${GREETING:-devlab}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=15 -o BatchMode=yes)
fail=0
ok()  { echo "✓ $1"; }
bad() { echo "✗ $1"; fail=1; }

LB_IP=$(yc load-balancer network-load-balancer get --name "$PREFIX-lb" --format json 2>/dev/null | jq -r '.listeners[0].address // empty')
if [[ -z "$LB_IP" ]]; then
  bad "балансировщик $PREFIX-lb не найден"; bad "распределение не проверить"; bad "сервер приложения не проверить"; exit 1
fi

# проверка снаружи; если адрес недоступен из сети рабочего места — с сервера приложения: он не входит
# в целевую группу и выходит в интернет через NAT, то есть приходит на балансировщик как внешний клиент
APP_INT=$(yc compute instance get --name "$PREFIX-app" --format json 2>/dev/null | jq -r '.network_interfaces[0].primary_v4_address.address // empty')
WEB1_IP=$(yc compute instance get --name "$PREFIX-web-1" --format json 2>/dev/null | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address // empty')
VIA=""
lb_get() { curl -s -m 4 "$@" "http://$LB_IP"; }
if ! curl -s -o /dev/null -m 4 "http://$LB_IP"; then
  VIA=" (запрос с app через NAT)"
  lb_get() { ssh "${SSH_OPTS[@]}" -o "ProxyCommand=ssh ${SSH_OPTS[*]} -W %h:%p student@$WEB1_IP" \
               "student@$APP_INT" "curl -s -m 4 $* http://$LB_IP"; }
fi
code=$(lb_get -o /dev/null -w '%{http_code}' || true)
[[ "$code" == 200 ]] && ok "балансировщик отвечает: $code$VIA" || bad "балансировщик отвечает: ${code:-нет ответа}$VIA"

hosts=$(for _ in $(seq 1 12); do lb_get | grep -o "$GREETING on [a-z0-9-]*" | sed "s/$GREETING on $PREFIX-//"; done | sort -u | paste -sd, -)
n=$(tr ',' '\n' <<< "$hosts" | grep -c . || true)
(( n > 1 )) && ok "ответили машины: $hosts" || bad "ответили машины: ${hosts:-никто} — распределения нет"

APP_IP=$(yc compute instance get --name "$PREFIX-app" --format json 2>/dev/null | jq -r '.network_interfaces[0].primary_v4_address.address // empty')
reached=""
for web in $(yc compute instance list --format json | jq -r ".[] | select(.name | startswith(\"$PREFIX-web-\")) | .name" | sort); do
  ip=$(yc compute instance get --name "$web" --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address // empty')
  [[ -z "$ip" || -z "$APP_IP" ]] && continue
  if ssh "${SSH_OPTS[@]}" "student@$ip" "curl -s -m 5 http://$APP_IP:$APP_PORT" 2>/dev/null | grep -q "$GREETING on $PREFIX-app"; then
    reached="${web#$PREFIX-}"; break
  fi
done
[[ -n "$reached" ]] && ok "сервер приложения доступен с $reached по $APP_IP:$APP_PORT" || bad "сервер приложения недоступен с веб-серверов"

exit "$fail"
