# hw-02 — стенд в манифесте Terraform

Вариант 11: префикс `evdokimov-11`, слово `devlab`, порт `8033`, два веб-сервера Debian 12
в двух зонах за сетевым балансировщиком. Тот же стенд, что в `hw-01`, без сервера приложения
и NAT-шлюза.

## Что нужно

- Terraform ≥ 1.8, `yc`, ключ SSH `~/.ssh/id_ed25519.pub` (его открытая часть вписана в `main.tf`);
- ключ сервисного аккаунта вне репозитория, например `~/.yc-keys/evdokimov-11-key.json`.

В облаке не должно быть лишних сетей: квота — две сети на облако, стенд занимает вторую.

## Как поднять

```bash
export YC_SERVICE_ACCOUNT_KEY_FILE=$HOME/.yc-keys/evdokimov-11-key.json
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
export YC_ZONE=ru-central1-d     # любая зона из main.tf
cd hw-02
terraform init
terraform apply
LB=$(terraform output -raw lb_url)
for i in $(seq 1 40); do curl -s "$LB/"; done | sort | uniq -c
```

Nginx ставится при первой загрузке: проверять через 1–2 минуты после `apply`.
Ответов должно быть две строки (`devlab on evdokimov-11-hw2-web-1` и `-2`), доли неравные — это нормально.

## Как снести

```bash
terraform destroy
yc compute instance list; yc compute disk list; yc vpc address list
yc load-balancer network-load-balancer list; yc vpc network list   # осталась только default
```

## Что менять под себя

- число серверов — `count` в ресурсе `yandex_compute_instance.web`;
- зоны и диапазоны подсетей — ресурсы `yandex_vpc_subnet` и выбор зоны через `count.index % 2`;
- порт и слово на странице — `app_port` и `greeting` в `templatefile`, `target_port` и `port` проверки в балансировщике;
- открытая часть ключа SSH — `ssh_key`.

В `main.tf` зона A — `ru-central1-e`: по варианту это `b`, но машины в ней не создавались
(`Zone ru-central1-b is not available`), в `a` — `Service is overloaded`.

## Если страница не открылась

- цели `UNHEALTHY` — проверка смотрит не на тот порт или в целевую группу попал публичный адрес вместо `ip_address`;
- одна строка в выборке — остальные машины ещё ставят nginx, повторить через минуту;
- `Quota ... exceeded` — остатки прошлых работ: удалить через `yc` и повторить `apply`;
- в новом окне терминала переменные `YC_*` пусты — задать заново.

Пайплайн только проверяет манифест (`terraform fmt`, `validate`); в облако он ничего не применяет.
Состояние `*.tfstate` в репозиторий не попадает.
