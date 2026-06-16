# TG WS Proxy на Keenetic (без USB-флешки)

Полная инструкция: MTProto-прокси на роутере Keenetic для всех устройств в домашней сети.  
Entware ставится на **встроенное хранилище** — USB-флешка **не нужна**.

Подходит для моделей с архитектурой **mipsel** (Hero 4G, Hero 4G+, Giga, Ultra и др.).

---

## Что получится

```
Телефон / ПК (Telegram с включённым прокси)
        ↓  MTProto
Роутер 192.168.1.1:1443  (tg-ws-proxy)
        ↓  WebSocket
Telegram

Остальной интернет (браузер, YouTube…) → как обычно, без прокси
```

- Прокси работает на роутере 24/7
- На **каждом** устройстве прокси включается **вручную** в Telegram
- USB-флешка **не требуется** (Entware на встроенной памяти)

---

## Требования

| Что | Зачем |
|-----|--------|
| Keenetic с mipsel (MT7621 и др.) | Архитектура Entware |
| KeeneticOS 3.7+ | Entware на встроенном хранилище |
| 128+ МБ flash, 256 МБ RAM | Hero 4G / Hero 4G+ и старше |
| Интернет на роутере | Установка пакетов и работа прокси |
| ПК в той же сети | Подготовка и загрузка архива |

**Проверенные модели:** Hero 4G (KN-2310), Hero 4G+ (KN-2311) и аналоги.

---

## Установка одной командой (рекомендуется)

С **ПК** в той же сети, что роутер. Установщик по SSH:
- проверит подключение;
- при необходимости поставит **Entware** на встроенное хранилище;
- скачает и установит **TG WS Proxy**;
- спросит порт и параметры;
- выведет ссылку `tg://proxy` с **LAN-IP**.

### Linux / macOS / Git Bash

```bash
curl -sL https://raw.githubusercontent.com/Flowseal/tg-ws-proxy/main/packaging/keenetic/install-keenetic.sh | bash
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File packaging\keenetic\install-keenetic.sh
```

или в **Git Bash**:

```bash
curl -sL https://raw.githubusercontent.com/Flowseal/tg-ws-proxy/main/packaging/keenetic/install-keenetic.sh | bash
```

### Без вопросов (автоматически)

```bash
TGWS_NONINTERACTIVE=1 TGWS_ROUTER_IP=192.168.1.1 TGWS_ROUTER_PASS=пароль \
  curl -sL https://raw.githubusercontent.com/Flowseal/tg-ws-proxy/main/packaging/keenetic/install-keenetic.sh | bash
```

(для пароля нужен `sshpass`, иначе введёте пароль SSH вручную)

### Только прокси (Entware уже есть)

На роутере в `exec sh`:

```sh
wget -qO- https://raw.githubusercontent.com/Flowseal/tg-ws-proxy/main/packaging/keenetic/install-remote.sh | sh
```

### Перед установкой в веб-интерфейсе

1. **Поддержка открытых пакетов OPKG** — включена
2. **Сервер SSH** — включён, доступ для `admin`
3. **Приложения → OPKG** → **Встроенное хранилище** → **Доступ** ✓

### Переменные установщика

| Переменная | Описание |
|------------|----------|
| `TGWS_ROUTER_IP` | IP роутера (192.168.1.1) |
| `TGWS_ROUTER_USER` | Логин SSH (admin) |
| `TGWS_ROUTER_PASS` | Пароль (опционально) |
| `TGWS_STORAGE` | `storage:/` или метка USB |
| `TGWS_ENTWARE_ARCH` | `mipsel` или `aarch64` |
| `TGWS_PORT` | Порт прокси (1443) |
| `TGWS_TARBALL_URL` | Свой URL архива .tar.gz |
| `TGWS_NONINTERACTIVE` | `1` — без вопросов |

> **Примечание:** архив с GitHub Releases появится после публикации релиза.  
> До этого запускайте установщик **из папки проекта** — он скопирует локальный `dist/*.tar.gz` на роутер.

---

## Ручная установка (пошагово)

### Часть 1. Подготовка на ПК

PowerShell в папке проекта:

```powershell
cd "C:\путь\к\tg-ws-proxy-main"
powershell -ExecutionPolicy Bypass -File packaging\keenetic\build-package.ps1
```

Файл для роутера:

```
dist\tg-ws-proxy-keenetic-mipsel-<версия>.tar.gz
```

Скопируйте его на рабочий стол — понадобится один раз при установке.

### 1.2. Запишите данные роутера

- IP: обычно `192.168.1.1` (проверьте в веб-интерфейсе)
- Логин: `admin`
- Пароль: ваш от веб-интерфейса

---

## Часть 2. Включите компоненты KeeneticOS

1. Откройте `http://192.168.1.1`
2. **Управление** → **Общие настройки** → **Изменить набор компонентов**
3. Включите:
   - **Поддержка открытых пакетов OPKG**
   - **Сервер SSH** (рекомендуется)
4. **Сохранить**

---

## Часть 3. Установка Entware на встроенное хранилище

USB-флешка **не нужна**.

### 3.1. Привязка хранилища

1. **Приложения** → **OPKG**
2. Накопитель: **Встроенное хранилище**
3. **Доступ** — включён
4. **Сохранить**

### 3.2. Установка одной командой

Откройте CLI в браузере: **`http://192.168.1.1/a`**

> В поле **Command** (вкладка Parse) вводите **только команды**, не URL.  
> Ответ всегда в JSON — это нормально.

Если Entware ещё не установлен:

```
no opkg disk
opkg disk storage:/ https://bin.entware.net/mipselsf-k3.4/installer/mipsel-installer.tar.gz
```

Ожидаемый ответ: **`Disk is set to: storage:/.`**

Если пишет `Disk is unchanged` — диск уже выбран, смотрите журнал.

### 3.3. Дождитесь установки

**Управление** → **Диагностика** → **Системный журнал**

Ищите:

```
doinstall: [1/5] Starting "Entware" deployment...
...
doinstall: [5/5] "Entware" installed!
```

Подождите 5–15 минут. Роутер не перезагружайте.

### 3.4. Ручная установка (если автоматическая не стартовала)

1. Скачайте: https://bin.entware.net/mipselsf-k3.4/installer/mipsel-installer.tar.gz
2. **Приложения** → **Встроенное хранилище** → папка **`install`**
3. **Импортировать** → загрузите `mipsel-installer.tar.gz`
4. **Приложения** → **OPKG** → снимите накопитель → **Сохранить**
5. Снова выберите **Встроенное хранилище** → **Сохранить**

### 3.5. Проверка Entware

Подключитесь по **SSH** (удобнее, чем Web CLI):

```powershell
ssh admin@192.168.1.1
```

Введите пароль. Появится `(config)>`. Перейдите в shell:

```
exec sh
```

Проверьте:

```sh
ls /opt/bin/opkg
/opt/bin/opkg update
passwd root
```

Смените пароль `root` (по умолчанию `keenetic`).

| Способ доступа | Адрес |
|----------------|--------|
| Веб-интерфейс | `http://192.168.1.1` |
| Web CLI (JSON) | `http://192.168.1.1/a` |
| SSH админ | `ssh admin@192.168.1.1` (порт 22) |
| SSH Entware | `ssh -p 222 root@192.168.1.1` |

Для установки прокси достаточно: **SSH admin** → `exec sh`.

---

## Часть 4. Загрузка TG WS Proxy на роутер

1. `http://192.168.1.1` → **Приложения** → **Встроенное хранилище**
2. Создайте папку **`tmp`**
3. **Импортировать** → выберите `tg-ws-proxy-keenetic-mipsel-*.tar.gz` с ПК
4. Дождитесь окончания загрузки

---

## Часть 5. Установка TG WS Proxy

В SSH:

```
exec sh
```

Команды:

```sh
cd /storage/tmp
tar -xzf tg-ws-proxy-keenetic-mipsel-*.tar.gz
sh tg-ws-proxy-keenetic-mipsel-*/install.sh
```

Установщик автоматически поставит:

- Python и все нужные модули (`asyncio`, `urllib`, `idna`, `ssl`, `ctypes`…)
- Прокси в `/opt/share/tg-ws-proxy/`
- Конфиг в `/opt/etc/tg-ws-proxy/`
- Автозапуск `/opt/etc/init.d/S99tgwproxy`

В конце: **`=== TG WS Proxy installed ===`**

---

## Часть 6. Запуск и проверка

```sh
/opt/etc/init.d/S99tgwproxy start
/opt/etc/init.d/S99tgwproxy status
```

Ожидается: **`tg-ws-proxy is running (pid ...)`**

Проверьте порт:

```sh
netstat -tln | grep 1443
```

Должно быть: `0.0.0.0:1443 ... LISTEN`

Secret и LAN-IP:

```sh
cat /opt/etc/tg-ws-proxy/secret
ip -4 addr show br0
```

LAN-IP обычно **`192.168.1.1`**.

> В логе ссылка `tg://proxy?server=100.x.x.x` — это **не** LAN-адрес.  
> Для устройств используйте **`192.168.1.1`**.

Ссылка для Telegram (подставьте свой secret):

```
tg://proxy?server=192.168.1.1&port=1443&secret=dd<ВАШ_SECRET>
```

Пример: secret `a0d40d0e...` → в ссылке `secret=dda0d40d0e...`

---

## Часть 7. Настройка Telegram

На **каждом** телефоне и ПК.

### Способ 1 — по ссылке

1. Соберите ссылку (см. выше)
2. Отправьте в **Избранное**
3. Нажмите → **Подключить**

### Способ 2 — вручную

**Telegram Desktop:** Настройки → Продвинутые → Тип подключения → Прокси → MTProto

**Telegram Mobile:** Настройки → Данные и память → Прокси → MTProto

| Поле | Значение |
|------|----------|
| Сервер | `192.168.1.1` (LAN-IP роутера) |
| Порт | `1443` |
| Secret | 32 hex-символа **без** `dd` (из `/opt/etc/tg-ws-proxy/secret`) |

Пример secret: `a0d40d0e054aa12e773b28bcab128f1d`

### Важно

- Wi‑Fi: **домашняя сеть**, не гостевая
- **VPN на телефоне выключен**
- Прокси **включён** (переключатель активен)
- Удалите старые прокси перед добавлением нового

---

## Часть 8. Управление

| Действие | Команда |
|----------|---------|
| Статус | `/opt/etc/init.d/S99tgwproxy status` |
| Запуск | `/opt/etc/init.d/S99tgwproxy start` |
| Остановка | `/opt/etc/init.d/S99tgwproxy stop` |
| Перезапуск | `/opt/etc/init.d/S99tgwproxy restart` |
| Логи | `tail -f /opt/var/log/tg-ws-proxy.log` |
| Secret | `cat /opt/etc/tg-ws-proxy/secret` |
| Конфиг | `cat /opt/etc/tg-ws-proxy/tgwproxy.conf` |

После перезагрузки роутера прокси стартует автоматически.

---

## Часть 9. Конфигурация

Файл: `/opt/etc/tg-ws-proxy/tgwproxy.conf`

```sh
HOST=0.0.0.0
PORT=1443
DC_IPS="1:149.154.175.50 2:149.154.167.220 4:149.154.167.220 5:149.154.171.5"
POOL_SIZE=2
BUF_KB=128
NO_CFPROXY=0
# VERBOSE=1
```

После правок: `/opt/etc/init.d/S99tgwproxy restart`

| Параметр | Описание |
|----------|----------|
| `HOST=0.0.0.0` | Слушать всю LAN |
| `PORT` | Порт прокси (по умолчанию 1443) |
| `DC_IPS` | IP дата-центров Telegram |
| `POOL_SIZE` | 1–2 для слабых роутеров, 2–4 для мощных |
| `NO_CFPROXY=1` | Отключить Cloudflare fallback (экономия RAM) |
| `VERBOSE=1` | Подробные логи |

---

## Часть 10. Проверка с ПК

PowerShell (ПК в той же сети):

```powershell
Test-NetConnection 192.168.1.1 -Port 1443
```

`TcpTestSucceeded : True` — порт доступен.

При подключении Telegram в логе роутера должны появиться строки:

```
[192.168.1.x:...] DC2 -> wss://kws2.web.telegram.org/apiws via 149.154.167.220
```

---

## Часть 11. Устранение неполадок

### Entware

| Проблема | Решение |
|----------|---------|
| `Disk is unchanged` | Диск уже выбран — смотрите журнал или ручная установка |
| `/opt/bin/opkg` нет | Дождитесь `"Entware" installed!` в журнале |

### Python-модули (если установка старая)

```sh
/opt/bin/opkg install \
  python3-light python3-asyncio python3-logging \
  python3-urllib python3-email python3-idna python3-codecs \
  python3-ctypes python3-openssl libopenssl
```

Проверка:

```sh
/opt/bin/python3 -c "
import asyncio, ssl, urllib.request, ctypes
print('telegram.org'.encode('idna'))
from proxy._aes import Cipher
print('OK')
"
```

(выполнять из `/opt/share/tg-ws-proxy`)

### Прокси не стартует

```sh
cat /opt/var/log/tg-ws-proxy.log
/opt/etc/init.d/S99tgwproxy restart
```

Ручной запуск:

```sh
/opt/etc/init.d/S99tgwproxy stop
/opt/bin/tgwproxy
```

### Telegram не подключается, лог пустой

- Проверьте гостевую Wi‑Fi (нельзя)
- Отключите VPN на телефоне
- Проверьте брандмауэр Windows для `Telegram.exe`
- Убедитесь, что прокси **включён** в настройках Telegram

### Ошибка `unknown encoding: idna`

```sh
/opt/bin/opkg install python3-idna python3-codecs
/opt/etc/init.d/S99tgwproxy restart
```

### Ошибка `No module named 'asyncio'`

```sh
/opt/bin/opkg install python3-asyncio
```

### Не грузятся фото/видео

В настройках прокси Telegram в поле **DC → IP** оставьте только:

```
4:149.154.167.220
```

Или очистите поле. Подробнее в [основном README](./README.md).

### Полная переустановка прокси

```sh
/opt/etc/init.d/S99tgwproxy stop
rm -f /opt/bin/tgwproxy /opt/etc/init.d/S99tgwproxy
rm -rf /opt/share/tg-ws-proxy /opt/etc/tg-ws-proxy
```

Затем повторите Части 4–6. Entware не трогайте.

---

## Часть 12. Безопасность

- Прокси только для домашней сети (LAN)
- **Не пробрасывайте порт 1443 в интернет** (WAN)
- Secret: `/opt/etc/tg-ws-proxy/secret` (права 600)
- Смените пароль `root` Entware: `passwd root`

---

## Краткая шпаргалка

```
1. OPKG + Entware на storage:/
2. Загрузить .tar.gz во встроенное хранилище → tmp/
3. exec sh → cd /storage/tmp → tar → install.sh
4. /opt/etc/init.d/S99tgwproxy start
5. Telegram: 192.168.1.1:1443 + secret
```

---

## Файлы на роутере

| Путь | Назначение |
|------|------------|
| `/opt/share/tg-ws-proxy/` | Код прокси |
| `/opt/bin/tgwproxy` | Запускатель |
| `/opt/etc/tg-ws-proxy/tgwproxy.conf` | Настройки |
| `/opt/etc/tg-ws-proxy/secret` | Ключ для Telegram |
| `/opt/etc/init.d/S99tgwproxy` | Автозапуск |
| `/opt/var/log/tg-ws-proxy.log` | Логи |

---

## Альтернатива

Если роутер не справляется — [Docker-версия](./README.docker.md) на NAS/мини-ПК в той же сети.
