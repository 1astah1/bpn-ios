# Отправка на App Review

Сверено с App Review Guidelines от 16.10.2026 и форумами разработчиков (29.10.2026).

## Сделано в приложении

| Правило | Что сделано |
|---|---|
| 5.4 VPN | NEPacketTunnelProvider через NETunnelProviderManager. Экран «Что приложение передаёт» до любого использования. Пояснение перед системным запросом VPN |
| 5.4 данные третьим лицам | Идентификатор устройства, модель и iOS уходят только серверу, который сам требует их для лимита устройств (`x-hwid-active`) |
| 3.1.1 / 3.1.3 покупки | Ни цен, ни ссылок на оплату, ни «продлить». Объявление панели и ссылка на кабинет не показываются. Клиент универсальный: https-списки серверов и конфиги vless/vmess/trojan/ss/hysteria2 |
| 5.1.1 политика | Ссылка в приложении: экран данных и «Настройки → Конфиденциальность». URL в `Config/Base.xcconfig` (`PRIVACY_POLICY_URL`) |
| Privacy Manifest | `App/PrivacyInfo.xcprivacy` и `PacketTunnel/PrivacyInfo.xcprivacy`. SystemBootTime 35F9.1 и FileTimestamp C617.1 (Go-рантайм: `mach_absolute_time`, `stat`) |
| IPv6-only (NAT64) | IPv4-адреса серверов синтезируются через getaddrinfo до запуска ядра (`PacketTunnel/NAT64.swift`), IPv6-маршрут в туннеле |
| 2.1 полнота | Понятные тексты ошибок, без падений без App Group, отладочные флаги только в DEBUG |
| 2.4.1 iPad | Только iPhone (`TARGETED_DEVICE_FAMILY = 1`). На iPad проверяется UI-тестом в режиме совместимости |

## Перед отправкой — сделать

- [ ] Аккаунт разработчика **на организацию** с первого дня. Перенос с аккаунта физлица даёт отказ 4.3(a).
- [ ] Своя политика конфиденциальности приложения на постоянном адресе. В ней:
  - идентификатор устройства, модель и iOS — только серверу, который ведёт лимит устройств;
  - трафик и история не логируются;
  - данные не продаются и не передаются (это требование 5.4).
- [ ] Демо-доступ для проверяющего:
  - отдельный пользователь или просто `vless://`-ссылка на тестовый сервер;
  - нейтральные имена, без «Обход»;
  - без срока и лимита на экране;
  - доступ из США, проверить в IPv6-only сети: Mac → «Общий интернет» → NAT64.
- [ ] Сборка Xcode 26+, SDK iOS 26, Release, архив через Xcode Organizer.
- [ ] Перед первой отправкой проверить на iPhone: подключение, переключение серверов, сеть NAT64.

## App Store Connect

- **Privacy Policy URL** — тот же адрес, что в приложении.
- **App Privacy:**
  - собираются Device ID и Other Diagnostic Data (модель и версия iOS);
  - цель — App Functionality;
  - Linked to user: Yes;
  - Tracking: No.
- **Шифрование:**
  - отвечать «Yes, uses encryption» — стандартные алгоритмы не из iOS;
  - Францию исключить из стран или загрузить французскую декларацию;
  - REALITY и VLESS Encryption — нестандартные протоколы: вопрос CCATS решать с юристом.
- **Доступность:** исключить материковый Китай (нужна лицензия MIIT). Другие страны — по решению.
- **Возрастной рейтинг:** на всё «No», встроенного браузера нет. У похожих клиентов в американском App Store стоит 4+.
- **Описание и ключевые слова:** без «обход блокировок», «bypass», «firewall», «без цензуры». Это сетевой клиент для своих серверов.
- **Скриншоты:** `scripts/ui-shots.sh` на iPhone 17 Pro Max, демо-доступ без «Обход».

## App Review Notes (вставить как есть, подставив ссылку)

```
This is a free network client for user-provided proxy/VPN configurations (VLESS, VMess, Trojan, Shadowsocks, Hysteria2). It does not sell anything: there are no in-app purchases, prices, or links to purchase anything inside the app. Users add a server list URL or a configuration link they already have (self-hosted or from any provider).

How to test:
1. Launch the app, read the data disclosure screen, tap "Понятно, продолжить" (Continue).
2. Tap the text field, paste the demo configuration below, tap "Добавить" (Add).
3. Tap the toggle in the center (or drag the knob up), read the explanation, tap "Продолжить", allow the VPN configuration.
4. The status turns to "ПОДКЛЮЧЕНО" (Connected); browse any website.

Demo configuration (no account needed): <ВСТАВИТЬ ССЫЛКУ>
The demo server is reachable from the US and works on IPv6-only (NAT64) networks.

Data: the app shows a disclosure screen before use. It sends the device identifier, device model and iOS version only to the server from the user's link, and only when that server enforces a per-device limit. The app does not log traffic or browsing history and does not sell, use or disclose data to third parties (see Privacy Policy).

VPN implementation: NEPacketTunnelProvider via NETunnelProviderManager; the app is published by an organization account. The app is not distributed in territories that require a VPN license (China mainland excluded).
```

## Если отклонили

- **4.3(a) spam / похожий бинарник.** Ответить в Resolution Center:
  - интерфейс и код свои;
  - перечислить отличия: тумблер с перетаскиванием, выбор сервера с пингом, синтез адресов NAT64, данные устройства только по требованию сервера;
  - ядро Xray — открытая библиотека, как WebKit у браузеров.
- **3.1.1 «paid key unlocks content».** Показать, что приложение работает с любым конфигом, включая свой сервер. Внутри ничего не продаётся, ссылок на покупку нет.
- **5.4 данные.** Сослаться на экран раскрытия, политику и на то, что данные устройства уходят только серверу из ссылки пользователя.
