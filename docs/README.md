
# keenetic-tg-ws

Локальный MTProto-прокси для Telegram на роутерах Keenetic (Entware), с установкой на встроенное хранилище без USB-флешки.

## Быстрый старт

```bash
bash <(curl -sL https://raw.githubusercontent.com/mrzvSSL/keenetic-tg-ws/main/packaging/keenetic/install-keenetic.sh)
```

Установщик:
- подключится к роутеру по SSH;
- при необходимости установит Entware;
- установит TG WS Proxy и зависимости;
- настроит и запустит сервис.

## Полная инструкция

Смотрите подробный гайд: `docs/README.keenetic.md`

## Только установка прокси (Entware уже есть)

```sh
wget -qO- https://raw.githubusercontent.com/mrzvSSL/keenetic-tg-ws/main/packaging/keenetic/install-remote.sh | sh
```
