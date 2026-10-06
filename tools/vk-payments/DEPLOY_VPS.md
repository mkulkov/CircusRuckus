# Развёртывание сервера покупок VK на действующем VPS

Домен: **vk-games-shop.mkulkov.ru**. Приложение VK: **54768735**.
Товар: **remove_ads**, цена **299 голосов VK**, первоначальный режим **test**.
Исходники сервера: папка `tools/vk-payments` проекта ClownSmash.

На VPS уже работают VPN и другие службы. Их доступность — обязательное условие.
Не останавливать VPN, не менять его порты, конфигурацию, маршруты, forwarding,
NAT, firewall, SSH, DNS других доменов и существующие сайты. Не перезагружать VPS.
Не выполнять полное обновление ОС, `ufw reset`, `iptables -F`, замену общих
nginx-конфигов или установку второго proxy поверх работающего.

ОС сервера по сообщению пользователя: **Debian 13 (trixie)** с systemd.
При входе подтвердить версию и архитектуру. Это инструкция: VPS по ней ещё не изменён.

## 1. Что потребуется перед подключением

- IP/имя VPS, SSH-порт, пользователь с sudo и доступ через SSH-ключ.
- Путь к уже настроенному локальному SSH-ключу или SSH-agent. Закрытый ключ
  и пароли не вставлять в переписку, команды или отчёт.
- Возможность изменить DNS поддомена `vk-games-shop.mkulkov.ru`.
- Email для регистрации Let’s Encrypt.
- Защищённый ключ приложения VK: внести непосредственно на VPS в закрытый файл.
- Точный HTTPS origin Web-игры VK для CORS. Это origin самой игры/iframe,
  а не родительской страницы `vk.ru`. Его можно получить в консоли iframe:
  `window.location.origin`. При изменении origin после деплоя обновить разрешённый список.
- Способ проверки VPN с клиентского устройства до и после работ.

## 2. Сначала обследовать сервер без изменений

После входа выполнить отдельно:

```bash
cat /etc/os-release
uname -m
systemctl --failed
systemctl list-units --type=service --state=running --no-pager
sudo ss -lntup
df -h
free -h
timedatectl status
sudo ufw status verbose
```

Если `ufw` отсутствует, не устанавливать его только ради этой инструкции.
Определить существующий firewall и сетевой стек. При использовании nftables
сохранить его правила, при использовании iptables — соответствующие IPv4/IPv6
правила. Не менять и не переключать один механизм на другой.
Проверить, кто слушает TCP 80, 443 и 8787, а также UDP 443 и порты VPN.
Учитывать службы в Docker/контейнерах, пробросы портов и firewall провайдера.
Не выводить приватные ключи VPN, защищённый ключ VK, переменные окружения процессов
или полные конфиги с секретами в чат/лог.

Зафиксировать состояние действующих служб и проверить подключение VPN извне.
Сделать локальную защищённую резервную копию только тех конфигов, которые
предстоит менять. Например для nginx, если он установлен:

```bash
sudo install -d -m 0700 /root/vk-shop-backup
sudo cp -a /etc/nginx /root/vk-shop-backup/nginx-before-vk-shop
sudo nginx -t
```

Если каталог резервной копии уже существует, выбрать новое имя с датой;
не перезаписывать предыдущую копию.

### Решение по портам

| Состояние | Действие |
|---|---|
| TCP 80/443 свободны | Можно установить nginx и добавить новый сайт. |
| 80/443 заняты существующим nginx | Использовать этот nginx, добавить отдельный virtual host; сохранить остальные сайты. |
| 80/443 заняты другим HTTP proxy | Использовать действующий proxy либо согласовать nginx за ним; не заменять proxy. |
| TCP 443 занят VPN или другим не-HTTP сервисом | Остановить настройку публичного HTTPS и согласовать отдельный IP/другой сервер или архитектуру совместного использования. VPN не отключать. |
| 8787 занят | Выбрать свободный loopback-порт и одновременно изменить EnvironmentFile и upstream nginx. |

Разные DNS-имена на одном IP сами по себе не позволяют nginx и VPN независимо
занять один TCP-порт 443. DNS-01 может помочь получить сертификат, но не решает
конфликт слушателей. Не переносить службы и не настраивать SNI-мультиплексирование
без отдельного согласования. Независимые работы, например подготовку файлов
сервера и локальные тесты, можно продолжить.

## 3. DNS и сетевой доступ

Создать A-запись:

```text
vk-games-shop.mkulkov.ru -> публичный IPv4 VPS
```

AAAA добавлять только при действительно работающем IPv6 на этом VPS.
Устаревшая AAAA может мешать проверке Let’s Encrypt. Если есть CAA-записи,
убедиться, что они разрешают выпуск сертификата Let's Encrypt.

Проверить снаружи и на VPS:

```bash
dig +short A vk-games-shop.mkulkov.ru
dig +short AAAA vk-games-shop.mkulkov.ru
dig CAA mkulkov.ru
```

Для описанного HTTP-01 сценария должны быть доступны TCP 80 и 443.
Если действующий firewall их закрывает, добавить только разрешения этих портов
в существующий механизм и в firewall провайдера. Не включать новый firewall,
не менять default policy и не удалять существующие правила. Сохранить SSH и все
порты VPN/других служб. Порт Node.js не открывать наружу.

## 4. Системные пакеты и Node.js

Только после проверки конфликтов портов, для Debian 13:

```bash
sudo apt-get update
sudo apt-get install -y nginx ca-certificates curl xz-utils python3 sqlite3 dnsutils
```

Не запускать общий `apt upgrade`. Если nginx уже есть, использовать его.
Если установщик предлагает перезапустить действующие службы, не выбирать VPN,
SSH и другие службы, не относящиеся к задаче. Проверять их состояние после установки.

Для сервера нужен Node.js 24+. Не заменять Node.js других приложений.
Установить отдельный официальный runtime в `/opt/vk-payments-node`.
Ниже — команды Bash на VPS, не PowerShell:

```bash
set -e
case "$(uname -m)" in
  x86_64) node_arch=x64 ;;
  aarch64) node_arch=arm64 ;;
  *) echo 'Нужна отдельная проверка архитектуры'; exit 1 ;;
esac
node_work_dir=$(mktemp -d)
cd "$node_work_dir"
curl -fsSLO https://nodejs.org/dist/index.json
node_version=$(python3 -c 'import json; print(next(v["version"] for v in json.load(open("index.json")) if v["version"].startswith("v24.") and v["lts"]))')
node_archive="node-${node_version}-linux-${node_arch}.tar.xz"
curl -fsSLO "https://nodejs.org/dist/${node_version}/${node_archive}"
curl -fsSLO "https://nodejs.org/dist/${node_version}/SHASUMS256.txt"
awk -v name="$node_archive" '$2 == name {print}' SHASUMS256.txt > selected.sha256
test -s selected.sha256
sha256sum -c selected.sha256
sudo install -d -m 0755 /opt/vk-payments-node
sudo tar -xJf "$node_archive" -C /opt/vk-payments-node --strip-components=1
/opt/vk-payments-node/bin/node --version
/opt/vk-payments-node/bin/node -e "require('node:sqlite')"
```

Если `/opt/vk-payments-node` уже используется, сначала проверить версию и владельца
установки; не распаковывать поверх работающего runtime. Зафиксировать выбранную
версию и SHA-256 в отчёте. npm-зависимостей у сервера нет.

## 5. Загрузка файлов и отдельный пользователь

С Windows передать только исходники сервера и тесты в домашний каталог SSH-пользователя.
Заменить `SSH_USER`, `VPS_IP` и `SSH_PORT` реальными значениями; это не секреты:

```powershell
scp -P SSH_PORT "C:/dev/Godot/games/ClownSmash/tools/vk-payments/server.mjs" "C:/dev/Godot/games/ClownSmash/tools/vk-payments/server.test.mjs" SSH_USER@VPS_IP:~/
```

На VPS:

```bash
id vk-shop
```

Если пользователя нет, создать:

```bash
sudo useradd --system --home-dir /var/lib/vk-shop --shell /usr/sbin/nologin vk-shop
```

Если уже есть, убедиться, что это пользователь данного приложения.

```bash
sudo install -d -o root -g root -m 0755 /opt/vk-shop
sudo install -d -o vk-shop -g vk-shop -m 0700 /var/lib/vk-shop
sudo install -d -o root -g root -m 0700 /etc/vk-shop
sudo install -o root -g root -m 0644 ~/server.mjs /opt/vk-shop/server.mjs
sudo install -o root -g root -m 0644 ~/server.test.mjs /opt/vk-shop/server.test.mjs
sudo -u vk-shop /opt/vk-payments-node/bin/node --test /opt/vk-shop/server.test.mjs
```

При повторном размещении сохранить старый код для отката, остановить только
`vk-shop.service` на время замены файлов и не затрагивать другие службы.

## 6. Закрытая конфигурация сервера

Создать `/etc/vk-shop/vk-shop.env` редактором на VPS:

```bash
sudo touch /etc/vk-shop/vk-shop.env
sudo chmod 0600 /etc/vk-shop/vk-shop.env
sudoedit /etc/vk-shop/vk-shop.env
```

Содержимое:

```dotenv
VK_APP_ID=54768735
VK_APP_SECRET=ВНЕСТИ_ЗАЩИЩЕННЫЙ_КЛЮЧ_НА_СЕРВЕРЕ
VK_PAYMENT_MODE=test
VK_REMOVE_ADS_PRICE=299
VK_ALLOWED_ORIGINS=https://ТОЧНЫЙ-ORIGIN-ИГРЫ
VK_DATABASE_PATH=/var/lib/vk-shop/payments.sqlite
HOST=127.0.0.1
PORT=8787
```

Заменить оба заполнителя реальными значениями. Не выводить файл через `cat`
в протокол работ. Секрет не копировать в игру или git. Ключ читает systemd;
веб-сервер nginx к нему доступа не получает.

## 7. systemd: запуск и автоматическое восстановление процесса

Создать `/etc/systemd/system/vk-shop.service`:

```ini
[Unit]
Description=VK Games Shop payment callbacks and entitlements
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=vk-shop
Group=vk-shop
WorkingDirectory=/opt/vk-shop
EnvironmentFile=/etc/vk-shop/vk-shop.env
ExecStart=/opt/vk-payments-node/bin/node /opt/vk-shop/server.mjs
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/vk-shop
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6

[Install]
WantedBy=multi-user.target
```

Запустить:

```bash
sudo systemd-analyze verify /etc/systemd/system/vk-shop.service
sudo systemctl daemon-reload
sudo systemctl enable --now vk-shop.service
sudo systemctl status vk-shop.service --no-pager
sudo ss -lntp '( sport = :8787 )'
curl -i http://127.0.0.1:8787/vk/payments/catalog
```

Ожидается listener только на `127.0.0.1:8787`, не `0.0.0.0`/`[::]`.
Запрос без подписанных параметров и Origin вернёт 403: это нормально и подтверждает
ответ приложения, но не работу настоящей покупки. В текущем сервере нет `/health`;
не выдавать 404 корня за ошибку запуска.

## 8. nginx: отдельный HTTP virtual host

Создать `/etc/nginx/sites-available/vk-games-shop.mkulkov.ru`.
Другие файлы, default-сайт и общий `nginx.conf` не заменять.

```nginx
server {
    listen 80;
    server_name vk-games-shop.mkulkov.ru;

    client_max_body_size 16k;
    server_tokens off;

    location ^~ /vk/payments/ {
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        proxy_connect_timeout 5s;
        proxy_read_timeout 20s;
        proxy_send_timeout 20s;
        access_log off;
    }

    location / {
        return 404;
    }
}
```

Для работающего IPv6 дополнительно добавить `listen [::]:80;`.
Если на сервере другой layout nginx, адаптировать подключение отдельного файла
к нему. Не создавать второй конфликтующий `server_name`.

```bash
sudo ln -s /etc/nginx/sites-available/vk-games-shop.mkulkov.ru /etc/nginx/sites-enabled/vk-games-shop.mkulkov.ru
sudo nginx -t
sudo systemctl reload nginx
curl -i --resolve vk-games-shop.mkulkov.ru:80:127.0.0.1 http://vk-games-shop.mkulkov.ru/vk/payments/catalog
```

Создавать symlink только если его ещё нет. Если nginx до этого не был запущен
и порты свободны, вместо reload выполнить `sudo systemctl enable --now nginx`.
После reload проверить прежние сайты и VPN. Reload допустим только после
успешного `nginx -t`. Не пользоваться restart для изменения virtual host.

## 9. Let’s Encrypt и HTTPS

Если Certbot уже установлен, проверить его способ установки и использовать его;
не устанавливать одновременно apt- и snap-версии, не менять существующие
сертификаты и renewal jobs. На Debian 13 использовать штатные пакеты Debian:

```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo /usr/bin/certbot --version
```

Когда DNS указывает на VPS и TCP 80 доступен снаружи, выполнить:

```bash
sudo /usr/bin/certbot --nginx \
  --cert-name vk-games-shop.mkulkov.ru \
  -d vk-games-shop.mkulkov.ru \
  --redirect \
  --agree-tos \
  --email YOUR_LETS_ENCRYPT_EMAIL
sudo nginx -t
```

Вместо `YOUR_LETS_ENCRYPT_EMAIL` указать предоставленный email.
Certbot добавит SSL к новому virtual host и перенаправление HTTP на HTTPS.
Если на VPS уже используется другой способ установки Certbot, сохранить его,
адаптировать путь и не создавать вторую установку.

Проверить с внешнего компьютера:

```bash
curl -I http://vk-games-shop.mkulkov.ru/
curl -i https://vk-games-shop.mkulkov.ru/vk/payments/catalog
openssl s_client -connect vk-games-shop.mkulkov.ru:443 -servername vk-games-shop.mkulkov.ru </dev/null
```

HTTP должен перенаправлять на HTTPS. HTTPS должен проходить проверку сертификата
без `-k`; запрос без авторизации должен быть отклонён приложением, а не nginx
с кодом 502. Проверить имя домена, цепочку и срок сертификата. Не закрывать TCP 80:
он нужен для следующих проверок HTTP-01. Если порт 80 нельзя использовать,
сначала согласовать DNS-01 и автоматизацию DNS-провайдера.

## 10. Автообновление сертификатов

Пакет Debian содержит `certbot.timer`. Проверить, что он включён:

```bash
sudo systemctl enable --now certbot.timer
sudo systemctl status certbot.timer --no-pager
sudo systemctl list-timers --all --no-pager
sudo /usr/bin/certbot renew --cert-name vk-games-shop.mkulkov.ru --dry-run
```

Если на VPS есть собственное расписание renewal, сначала определить его и
не создавать дублирующий timer. Не добавлять параллельный cron, если auto-renew
уже работает. Штатный Debian cron не запускает renewal при наличии systemd.

nginx plugin Certbot обеспечивает reload после успешного обновления.
Проверить сохранённую renewal-конфигурацию данного сертификата и результат
dry-run. Если нужна отдельная reload-hook, добавить её только для этого домена:

```bash
sudo install -d -m 0755 /etc/letsencrypt/renewal-hooks/deploy
sudo tee /etc/letsencrypt/renewal-hooks/deploy/50-vk-shop-nginx >/dev/null <<'EOF'
#!/bin/sh
set -eu
case " ${RENEWED_DOMAINS:-} " in
  *" vk-games-shop.mkulkov.ru "*) /usr/sbin/nginx -t && /usr/bin/systemctl reload nginx ;;
esac
EOF
sudo chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/50-vk-shop-nginx
sudo /usr/bin/certbot renew --cert-name vk-games-shop.mkulkov.ru --dry-run --run-deploy-hooks
```

При нестандартной установке заменить путь Certbot. Не менять renewal-config других доменов.
Отчёт должен содержать состояние timer, ближайший запуск и результат dry-run;
наличие сертификата без проверки обновления не завершает задачу.

## 11. Подключение игры и кабинета VK

В проекте установить:

```ini
monetization/vk/payments_base_url="https://vk-games-shop.mkulkov.ru"
```

В `project.godot`, внутри секции `[monetization]`, это строка
`vk/payments_base_url="https://vk-games-shop.mkulkov.ru"`.

В кабинете приложения `54768735`, **Платежи → Подключение**:

- Callback: `https://vk-games-shop.mkulkov.ru/vk/payments/callback`.
- Версия уведомлений: `5.132`.
- Выбрать администратора в списке тестировщиков платежей.

Изменение кабинета/загрузку билда выполнять только если пользователь отдельно
поручил эти действия. Сама подготовка VPS не означает публикацию игры.

Пересобрать `Web - VK Mini Apps`, развернуть Dev-билд и проверить покупку внутри VK.
Если origin новой сборки изменился, обновить только `VK_ALLOWED_ORIGINS`
и перезапустить только `vk-shop.service`.

Проверки покупки: цена 299 голосов, отмена без выдачи права, успешная тестовая
оплата, исчезновение баннера, отсутствие рекламы перед вторым уровнем,
восстановление после перезапуска/на другом устройстве того же аккаунта,
отсутствие права у другого аккаунта. Тесты сервера не заменяют эти проверки.

## 12. База, резервная копия и обслуживание

Данные находятся в `/var/lib/vk-shop/payments.sqlite`. Каталог приложения
и каталог базы разделены; обновление кода не удаляет покупки.
Для согласованной копии работающей SQLite использовать backup API:

```bash
sudo install -d -o root -g root -m 0700 /var/backups/vk-shop
backup_file="/var/backups/vk-shop/payments-$(date -u +%Y%m%dT%H%M%SZ).sqlite"
sudo sqlite3 /var/lib/vk-shop/payments.sqlite ".backup '$backup_file'"
sudo chmod 0600 "$backup_file"
sudo sqlite3 "$backup_file" 'PRAGMA integrity_check;'
```

Настроить ежедневную копию по этим командам через отдельный systemd timer,
проверить копию и предусмотреть защищённое хранение вне VPS.
Не копировать отдельно активный `.sqlite` без WAL/backup API.
Не удалять историю заказов для «сброса теста» и не заменять live-базу test-базой.

Полезные команды:

```bash
sudo journalctl -u vk-shop.service -n 50 --no-pager
sudo systemctl status vk-shop.service nginx --no-pager
sudo nginx -t
```

Перед переходом в `live` отдельно согласовать запуск реальных платежей.
Меняется только `VK_PAYMENT_MODE` и перезапускается `vk-shop.service`.
Тестовые права не станут реальными. Тестировщики VK после публикации продолжают
отправлять `*_test`; текущий live-сервер их отклоняет. Для тестирования после
публикации нужен отдельный test endpoint/Dev-билд.

## 13. Приёмка и откат

Работы завершены, когда:

- VPN подключается извне, его маршрутизация и доступ к ресурсам работают как раньше.
- Остальные службы и прежние сайты доступны; новых failed units не появилось.
- Новый backend слушает только loopback, запущен от отдельного пользователя
  и имеет автозапуск. Выполнен контрольный restart только `vk-shop.service`.
- HTTPS домена работает с доверенным сертификатом; HTTP перенаправляется.
- Certbot timer активен и renewal dry-run успешен.
- Серверные тесты проходят, база и секрет доступны только нужным пользователям.
- Проверена согласованная резервная копия базы.
- Реальная тестовая покупка отмечена Pass либо конкретно указано,
  что она ещё не проверена из-за ненастроенного кабинета/неразмещённого Dev-билда.

Если новая конфигурация не проходит `nginx -t`, не делать reload.
Если после reload возникла регрессия, отключить только новый virtual host
и восстановить только изменённые файлы из копии, затем проверить конфигурацию
и выполнить reload. Можно остановить `vk-shop.service`; VPN и другие службы
не останавливать. Не откатывать весь сервер и не восстанавливать устаревшую
платёжную базу без отдельного решения — это может потерять новые покупки.

## 14. Готовое задание для выполнения по SSH

> Полностью подготовь сервер покупок VK для приложения 54768735 на предоставленном
> VPS, домен vk-games-shop.mkulkov.ru, товар remove_ads, цена 299 голосов, режим test.
> ОС сервера — Debian 13. Используй текущие исходники tools/vk-payments и эту инструкцию. Сначала обследуй
> ОС, порты, proxy, firewall и работающие службы. На VPS уже есть VPN и другие
> службы: они должны оставаться доступны и работать; их настройки, порты, NAT,
> маршрутизацию и SSH не менять. При конфликте TCP 80/443 не останавливай владельца
> порта и согласуй способ совместного размещения. Установи отдельный Node.js 24+
> без замены runtime других приложений; размести backend, отдельного пользователя,
> закрытый EnvironmentFile, постоянную SQLite-базу и systemd-службу с автозапуском.
> Добавь отдельный virtual host к существующему nginx либо установи nginx, если
> порты свободны. Настрой HTTP, выпусти Let's Encrypt для указанного домена,
> перенаправь HTTP на HTTPS, проверь автообновление сертификата и reload nginx.
> Настрой и проверь резервную копию базы. Не перезагружай VPS, не делай полное
> обновление ОС, не сбрасывай firewall и не заменяй конфигурацию других сайтов.
> Ключи и пароли не выводи в отчёт. Проверь внешнюю доступность VPN/старых служб
> до и после работ, серверные тесты, HTTPS, systemd и certbot renew --dry-run.
> Не включай реальные платежи, не меняй кабинет VK и не публикуй игру без отдельного
> поручения. Дай отчёт с адресами API, результатами проверок, состоянием автозапуска
> и renewal, путями конфигов/базы/backup и оставшимися шагами для тестовой покупки.

## Источники, проверенные 2026-10-01

- [Официальные бинарные архивы Node.js 24](https://nodejs.org/download/release/latest-v24.x/)
- [nginx reverse proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Certbot в Debian 13](https://packages.debian.org/trixie/certbot)
- [nginx plugin в Debian 13](https://packages.debian.org/trixie/python3-certbot-nginx)
- [Certbot: параметры CLI в Debian 13](https://manpages.debian.org/trixie/certbot/certbot.1.en.html)
- [Debian: расписание renewal](https://sources.debian.org/src/python-certbot/4.0.0-2%2Bdeb13u1/debian/certbot.cron.d)
- [VK: уведомления платежей](https://dev.vk.ru/ru/api/payments/notifications/vk)
- [VK: тестирование платежей](https://dev.vk.ru/ru/api/payments/testing)
