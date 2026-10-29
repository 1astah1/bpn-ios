# Umbra (рабочее название)

iOS-клиент для подписок VLESS (Remnawave / 3x-ui): SwiftUI + Network Extension (packet tunnel) + ядро Xray-core через [libXray](https://github.com/XTLS/libXray).

## Устройство

| Папка | Что внутри |
|---|---|
| `App/` | Приложение: экраны, загрузка подписки, управление VPN-профилем |
| `PacketTunnel/` | VPN-расширение: поднимает интерфейс и запускает Xray на его fd |
| `Shared/` | Общее для обоих: модели, сборка конфига Xray, обёртка над libXray |
| `Config/` | Название, bundle id, App Group, версия |
| `scripts/` | Сборка ядра и генерация проекта |

Как работает:
1. Приложение скачивает подписку (с заголовками устройства `x-hwid` и т.п.), libXray превращает ссылки в outbounds.
2. Приложение собирает полный конфиг Xray (`XrayConfigBuilder`) и кладёт его в общую папку App Group.
3. Расширение задаёт сеть (`NEPacketTunnelNetworkSettings`), находит fd интерфейса utun и запускает Xray с tun-inbound на этом fd (`env.xray.tun.fd`).

Маршрутизация:
- запросы DNS к ядру → свой DNS-модуль, зарубежные имена резолвятся через прокси;
- российские домены и их DNS (77.88.8.8) — напрямую (переключатель в настройках);
- локальные сети — мимо туннеля;
- остальное — выбранный сервер или балансировщик `leastPing` по всем серверам подписки.

Ограничение iOS: расширению дают около 50 МБ памяти. Поэтому без geoip/geosite — правила списком в `Shared/DomesticRules.swift`.

## Сборка (на маке)

```bash
brew install go xcodegen
./scripts/bootstrap.sh          # соберёт Vendor/LibXray.xcframework и Umbra.xcodeproj
```

Подпись: создать `Config/Local.xcconfig` с `DEVELOPMENT_TEAM = <Team ID>`. VPN на устройстве работает только с платным аккаунтом разработчика: бесплатная команда не даёт права Network Extension. В симуляторе запускается интерфейс, но не туннель.

Диплинк импорта: `umbra://import?url=<urlencoded ссылка подписки>`.
