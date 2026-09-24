# Практика 1 — журнал ручных действий (веб-консоль)

Машина evdokimov-11-web-manual, создана мышкой в консоли Yandex Cloud.

1. Открыл console.yandex.cloud, облако cloud-gale-377, каталог default.
2. Compute Cloud → Виртуальные машины → «Создать виртуальную машину».
3. Имя ВМ: evdokimov-11-web-manual.
4. Метка: created-by = console.
5. Образ загрузочного диска: Marketplace → Ubuntu 24.04.
6. Зона доступности: ru-central1-b (мой вариант 11).
7. Загрузочный диск: тип HDD (network-hdd), размер 20 ГБ.
8. Вычислительные ресурсы: вкладка «Своя конфигурация».
9. Платформа Intel Ice Lake, vCPU 2.
10. Гарантированная доля vCPU 20 %.
11. RAM 2 ГБ.
12. Отметил «Прерываемая».
13. Сеть: подсеть default / default-ru-central1-b.
14. Публичный IP-адрес: автоматически.
15. Доступ: SSH-ключ, логин student.
16. «Добавить ключ»: имя evdokimov-11-mac, вставил содержимое ~/.ssh/id_ed25519.pub.
17. Резервное копирование выключил.
18. Проверил стоимость справа: 617,41 ₽/мес вместо ~3 000 ₽ по умолчанию.
19. «Создать ВМ», дождался статуса Running, скопировал публичный адрес.
20. ssh student@<IP>, sudo apt update, sudo apt install -y nginx, проверил systemctl status nginx.
21. Открыл http://<IP> в браузере — стартовая страница nginx.
22. set +H; sudo sed -i "s|Welcome to nginx!|devlab on $(hostname)|g" /var/www/html/index.nginx-debian.html.
23. Обновил страницу — «devlab on evdokimov-11-web-manual». exit.

Итого: 23 ручных шага. Та же машина командой — одна команда yc compute instance create из 13 строк (см. commands.sh).
