# PROGRESS.md — Цирковой переполох

## 2026-10-06 — Платформенные сборки и отправка на GitHub

- Исходники отправлены в `origin/main` коммитом `0c7ff68` перед экспортами.
- RuStore: подписанный AAB `builds/clown-smash-rustore-1.0.3-release-0c7ff68.aab`, версия `1.0.3` (`versionCode=4`), 56 681 643 байта. Экспортная подпись совпала с предыдущим RuStore AAB.
- VK Mini Apps: Web-пакет из 9 runtime-файлов и ZIP `builds/clown-smash-vk-mini-apps-0c7ff68.zip`, 31 093 629 байт; `Deploy-VK.ps1 -ValidateOnly` прошёл.
- Яндекс Игры: ZIP `builds/clown-smash-yandex-games-0c7ff68.zip`, 9 файлов, `index.html` в корне, 60 729 192 байта до сжатия и 31 093 577 байт в ZIP.
- SHA-256 RuStore AAB: `334D674BDD4DB2A54FCCCBCA53102F4557C37633273B4305B5BC0A6A20662294`; VK ZIP: `6AD8BECA6673CA34F45958C76040519FCC5F72B6A6B13C6954A65C458F7735B3`; Yandex ZIP: `786587331464E396BE59D3C9DC8664FCD8F0BCAD8539A6CADB48B76BC334DDBE`.
- Godot full runner и smoke test прошли; VK/OK/Yandex bridge и VK payment server suites: 17 тестов прошли. Файлы сборок локальные; загрузка в кабинеты, hosted-runtime, sandbox-покупка и публикация не выполнялись.

## 2026-10-06 — Предложение отключить рекламу перенесено в настройки

- Кнопка «Отключить рекламу» теперь находится в меню настроек, отображается только при доступном товаре и скрывается после покупки.
- Кнопки из главного меню и игровых экранов убраны; сценарии покупки из самого окна блокировки рекламы сохранены.
- Godot 4.7.2: `tests/run_tests.gd`, `tests/smoke_test.gd` и headless editor/import завершились с кодом 0.

## 2026-10-02 — VK Hosting origins use app-bound templates

- The payment API now accepts an empty explicit origin list while still allowing only the generated stage/prod VK Hosting host patterns for the configured app ID. Exact HTTPS origins remain required for external hosts.
- Regression coverage confirms rotating hashes for VK Hosting app IDs are accepted and unrelated origins remain denied; all 13 payment server tests pass.

## 2026-10-01 — Подготовлен VK Mini Apps Prod deploy package

- Создан `builds/vk-mini-apps-prod-deploy-2026-10-01/` на основе текущего Release Web-экспорта; ZIP и `deploy-release` содержат одинаковые 9 runtime-файлов.
- Hosting config приложения `54768735` направлен только в Prod (`update_prod=true`, `update_dev=false`). `Deploy-VK.ps1 -Target Prod -ValidateOnly`, состав ZIP и 10 SHA-256 записей прошли.
- Пакет подготовлен локально; production hosting не обновлялся, публикация и runtime в VK не проверялись.

## 2026-10-01 — Новый локальный VK Mini Apps release candidate

- Пересобран Godot 4.7.2 preset `Web - VK Mini Apps` из текущего дерева в `builds/vk-mini-apps-release-2026-10-01/`; архив содержит ровно 9 runtime-файлов.
- Импорт, полный Godot runner, smoke, VK/OK/Yandex bridge tests, 12 платёжных серверных тестов и `Deploy-VK.ps1 -ValidateOnly` прошли. SHA-256 ZIP: `D333FDDCDB3C9EE1E389F4109893D36254D8AA54E493A7D87ACF6C0D9D4E0D8C`.
- Hosting config подготовлен только для Dev. Кабинет/размещение VK заблокированы политикой браузера; экспорт остаётся локальным, загрузка и production-публикация не выполнялись.

## 2026-10-01 — Совместимость запроса товара VK

- Реальный журнал VPS содержит get_item с корректной подписью при отображении get_item_test в кабинете. В test-режиме обработчик ранее возвращал Invalid order, поскольку принимал только get_item_test.
- Информация о товаре теперь выдаётся для обоих подписанных get_item/get_item_test: этот запрос не создаёт заказ и не выдаёт право. Режим order_status_change остаётся строгим; тест подтверждает, что обычная оплата не выдаёт тестовое право.
- Локальные 6 тестов прошли; изменение применено с резервной копией на VPS, синтаксис и серверные/multi-game тесты прошли. Перезапущен только vk-shop@circusrucus.service. Успешная покупка VK остаётся непроверенной.

## 2026-10-01 — Диагностика платёжного callback VK

- На VPS и в локальном сервере добавлен безопасный журнал callback: распознанный тип, проверка подписи/идентичности приложения, наличие обязательных полей и код ответа. Ключ, подписи, полные запросы и данные пользователей не логируются.
- Сохранена резервная копия VPS; синтаксис, локальные 6 тестов и 6 серверных/multi-game тестов прошли. Перезапущен только vk-shop@circusrucus.service.
- Синтетический подписанный get_item_test через публичный HTTPS URL вернул HTTP 200 и товар remove_ads по текущей цене 14 голосов; запись заказа не создавалась, в базе 0 заказов. Это не проверка запроса со стороны VK.
- Браузерное подключение возвращает timeout. Для определения причины ошибки окна нужна новая попытка пользователя и сопоставление с безопасным журналом.

## 2026-10-01 — CORS для новых сборок VK

- Платёжный сервер дополнительно разрешает HTTPS origins stage-app<VK_APP_ID>-<12 hex>.pages.vk-apps.ru и prod-app<VK_APP_ID>-<12 hex>.pages-ac.vk-apps.ru. Список точных адресов сохранён, подпись запуска VK обязательна. Чужие app_id, порты, userinfo и домены с посторонними суффиксами не разрешаются.
- Добавлены позитивные/негативные тесты шаблонов; локальные 6 серверных тестов прошли. На VPS сохранена резервная копия, синтаксис и 6 серверных/multi-game тестов прошли; перезапущен только vk-shop@circusrucus.service. Внешняя проверка: свой Dev/Prod origin — HTTP 204 с конкретным CORS origin, чужой app_id — HTTP 403.

## 2026-10-01 — Проверка рекламы и окно покупки перед уровнями VK

- По запросу пользователя перед входом в каждый уровень VK проверяется доступность interstitial, если право remove_ads не подтверждено. Первый уровень остаётся без показа interstitial, но проверка доступности выполняется.
- Недоступность, ошибка или timeout останавливают переход и открывают окно: возможный блокировщик/сбой сети, «Отключить рекламу» с серверной ценой и «Выход» в главное меню. Подтверждённая покупка продолжает ожидающий уровень один раз; отмена/ошибка позволяет повторить покупку или выйти.
- VK banner/native ads учитывают data.result === true; result:false больше не считается показом. Проверка SDK ограничена 10 секундами, показ interstitial — 30 секундами, поздний ответ не вызывает повторное завершение.
- Проверка распространяется на VK; остальные платформы сохраняют прежний сценарий. Добавлены проверки JS результатов и Godot переходов/прав/состояний кнопок.
- Локальные JS-тесты, полный Godot runner, import и smoke проверены; отдельная Dev-сборка: builds/vk-dev-ad-gate-2026-10-01. Размещение новой сборки и реальная успешная покупка VK не выполнялись.
- 2026-10-01 Web export повторно собран из актуального дерева. Dev-папка и ZIP синхронизированы, 9 runtime SHA-256 сверены; Deploy-VK.ps1 -ValidateOnly прошёл. ZIP SHA-256: `3DD61960F32A856F2E0D7A7D612E85E081B95EDB82DF2B7CED07506D6A7420D6`. На VK не загружено.
## 2026-10-01 — Dev-сборка VK с новым сервером покупок

- В project.godot задан payments_base_url=https://vk-games-shop.mkulkov.ru/games/circusrucus; клиент использует каталог и права этого сервера. Callback: /games/circusrucus/vk/payments/callback.
- Собран реальный preset Web - VK Mini Apps (без monetization_demo) в builds/vk-dev-payments-2026-10-01/deploy-release. ZIP содержит 9 runtime-файлов; hosting config обновляет только Dev, рядом README и SHA-256.
- Импорт, полный Godot tests/run_tests.gd, smoke_test.gd, VK/Yandex JS bridge и 5 серверных тестов прошли. Экспорт и Deploy-VK.ps1 -ValidateOnly прошли; адрес сервера в PCK и платёжный bridge в HTML проверены.
- Загрузка в VK не выполнялась. Реальная покупка/отмена в окне VK остаются непроверенными до размещения нового Dev runtime. При предыдущей проверке кабинета API callback был 5.131; для проверки возвратов нужна 5.132.

## 2026-10-01 — Инструкция размещения платёжного сервера на VPS

- Добавлен `tools/vk-payments/DEPLOY_VPS.md` для Debian 13 и домена `vk-games-shop.mkulkov.ru`: отдельный Node.js, systemd, nginx HTTP/HTTPS, Let's Encrypt через Debian Certbot, certbot.timer/dry-run, база/backup, настройка VK и готовое задание для SSH-развёртывания.
- Обязательное условие пользователя: сохранить работающий VPN и остальные службы. Инструкция требует проверки портов/сетевых правил до изменений, сохранения существующего proxy и согласования конфликтов 80/443 без остановки VPN; не предусматривает сброс firewall, смену маршрутизации или перезагрузку VPS.
- VPS ещё не обследован; Debian 13 указан пользователем, SSH-доступ, фактическая конфигурация ОС, DNS, сертификат и внешняя доступность служб не проверены. Изменена только документация.

## 2026-10-01 — Реализована покупка отключения рекламы через VK

- Товар `remove_ads`, цена 299 голосов VK по указанию пользователя. Клиент вызывает `VKWebAppShowOrderBox`, приостанавливает игру/звук на время окна и выдаёт право только после подтверждения серверного реестра; отмена, ошибка, timeout и неподтверждённая оплата не выдают право.
- Добавлен сервер `tools/vk-payments` на Node.js 24+ без сторонних зависимостей: каталог, проверка MD5-подписи уведомлений и HMAC-SHA256 параметров запуска, постоянная SQLite-база, идемпотентная обработка заказов/возвратов, раздельные test/live права. Восстановление по VK-аккаунту работает при запуске и возврате фокуса; устаревший ответ восстановления не отменяет новую покупку.
- Добавлен `monetization/vk/payments_base_url`. Пока HTTPS-сервер не размещён и адрес не настроен, кнопка покупки скрыта. Инструкции размещения и настройки callback/тестировщиков: `tools/vk-payments/README.md`.
- Проверены официальные инструкции VK по товарам, get_item, order_status_change, подписи и тестовым платежам 2026-10-01. Тестовые платежи не требуют наличия 299 голосов и не списывают баланс.
- Проверки: 5 серверных тестов, `tests/vk_bridge_test.mjs`, регрессия `tests/yandex_bridge_test.mjs`, импорт Godot, полный `tests/run_tests.gd` и smoke — PASS; без ошибок/утечек. Релиз VK пересобран локально; пакет `builds/vk-mini-apps-payments-delivery-2026-10-01/`.
- Сервер ещё не размещён, защищённый ключ не получен, кабинет не изменён, сборка не загружена. Настоящая тестовая покупка VK и восстановление на другом устройстве пока не проверены. Ошибки рекламы из предыдущего аудита остаются вне этой доработки.

## 2026-10-01 — Устранены утечки тестов и пересобран релиз VK Mini Apps

- В трёх сценариях `tests/run_tests.gd` добавлено освобождение пяти созданных узлов: двух MonetizationService, двух SaveManager и SpawnDirector. Они удерживали связанные адаптеры, скрипты и LevelConfig после завершения тестов.
- Полный verbose-запуск тестов: PASS, exit 0, без ObjectDB leaks и ресурсов, остающихся в использовании. Импорт проекта и smoke-проверка: exit 0, без диагностик.
- Релизный preset `Web - VK Mini Apps` пересобран в Godot 4.7.2 в `builds/vk/`; подготовлен пакет `builds/vk-mini-apps-delivery-2026-10-01/` с ZIP из девяти runtime-файлов, hosting config, README и SHA-256 manifest.
- Загрузка на VK не выполнялась. Обнаруженные при аудите ошибки обработки результата рекламы и отсутствие ограничения ожидания не входили в эту доработку; реальная реклама и платежи в размещённой игре остаются непроверенными.

## 2026-09-29 — Добавлен локальный запуск деплоя VK Mini Apps

- Добавлен `tools/vk-deploy/Deploy-VK.ps1`: проверка набора девяти runtime-файлов, вывод SHA-256, выбор dev/prod/both с отдельным текстовым подтверждением и запуск закреплённого VK CLI.
- Скрипт восстанавливает исходный `vk-hosting-config.json` после выполнения CLI; `-ValidateOnly` проверяет пакет без установки зависимостей и загрузки.
- Реальную загрузку не запускали: токен и авторизация остаются на стороне пользователя при запуске скрипта.

## 2026-09-29 — VK Mini Apps Web-сборка обновлена локально

- Пересобран preset `Web - VK Mini Apps` в Godot 4.7.2 для приложения `54768735`; подготовлен пакет `builds/vk-mini-apps-delivery-2026-09-29/`.
- ZIP `clown-smash-vk-mini-apps-web-2026-09-29.zip` содержит девять Web runtime-файлов в корне; рядом сохранены hosting config, README и SHA-256 manifest.
- Импорт проекта, полный `tests/run_tests.gd`, `tests/smoke_test.gd` и Web export прошли. При завершении полного тестового раннера остаются предупреждения Godot об утёкших ObjectDB instances и используемых ресурсах.
- Обновление кабинета/хостинга VK не выполнено: браузерная политика заблокировала доступ к странице кабинета. Загрузка, размещённый runtime, production ads и модерация не проверены.

## 2026-09-29 — Очистка Android-экспорта

- Во всех Android-пресетах исключены тесты, инструменты, промо, проверки и исходные заготовки графики; обычные игровые APK и релизный AAB не включают демо-видео. В QA-профиле монетизации демо-ролик сохранён как функциональный ресурс.
- Release RuStore продолжает собираться как AAB только для arm64-v8a; APK-профили оставлены для QA и эмулятора.
- Проверка экспорта выполняется отдельно; фактический размер нового артефакта ещё не измерен.

## 2026-09-28 — Очистка проекта

- Папка `promotion/` оставлена на диске, но исключена из Git: она содержит материалы для магазинов и рекламы, не требуемые для сборки игры. Ранее удалённые `artifacts/`, резервная Android-копия и черновые листы генерации также исключены из индекса.
- Удалены локальные сборки, кеши Godot/Gradle/браузера, проверочные скриншоты и видео, промежуточные материалы в `artifacts/`, резервная копия Android-ассетов и неиспользуемые исходные листы генерации в `assets/generated/`.
- По решению пользователя готовые материалы в `promotion/` сохранены. Игровые ресурсы, эталонное изображение для визуального сравнения, демо-ролик и Android-шаблон сохранены.
- `.gitignore` дополнен для удалённых временных каталогов и результатов генерации.
- После очистки импорт Godot завершился с кодом 0, полный `tests/run_tests.gd` и `tests/smoke_test.gd` прошли. Первый запуск тестов в песочнице не смог записать `user://`; повторный запуск с доступом к каталогу пользователя прошёл. У тестового раннера остались известные предупреждения ObjectDB/ресурсов при выходе.

## 2026-09-23 — Android-реклама РСЯ + VK (подготовлено, не опубликовано)

- Включён существующий Godot-плагин Yandex Mobile Ads в RuStore-экспорт. Зависимости обновлены до совместимой пары SDK 7.18.7 и адаптера VK Реклама (ex. myTarget) 5.27.4.1 по официальной документации; идентификаторы действующих блоков РСЯ добавлены в настройки проекта.
- В VK Рекламе приложение «Цирковой переполох» `3516015` и два блока восстановлены из архива в тестовый режим. В РСЯ к баннеру `R-M-20038632-1` привязан VK-блок `2065554`, к межстраничному блоку `R-M-20038632-2` — VK-блок `2065557`; обе связи In-App Bidding сохранены и повторно прочитаны в кабинете.
- Проверочная debug AAB собрана вне `builds/`, существующая release AAB и версии в RuStore не заменялись. Импорт проекта и полный тестовый скрипт прошли; известные предупреждения ObjectDB/ресурсов при выходе тестов остались.
- До релиза: ссылка на магазин и выход из тестового режима в обоих рекламных кабинетах, проверка согласия/политики конфиденциальности и маркировки данных, тест баннера и interstitial на Android-устройстве, затем отдельная release-сборка с увеличенным `versionCode` и публикация через RuStore.

## 2026-09-23 — RuStore release-candidate preparation

- Added `promotion/rustore_2026-09-23/` with a filled 512×512 RGB icon, three visually reviewed current Russian 9:16 gameplay screenshots, verified dimensions/file sizes, Russian store-card copy and SHA-256 checksums.
- Added `docs/rustore_release_checklist.md`, refreshed against the current official RuStore publication, AAB-signing, Pay SDK and sandbox-test documentation.
- Built and uploaded the signed final candidate `builds/clown-smash-rustore.aab` (48,307,799 bytes, SHA-256 `6F5ABACB17E20A1FFD25F231A7290DC33BD752DE8F793622A64C224D393C7E32`). JAR verification passed with the expected RSA-4096 upload certificate; archive filtering confirmed RuStore Pay is present and Yandex Ads, tests, tools, promotion, verification, references and demo video are absent.
- Verified merged Android metadata: package `ru.mkulkov.circusruckus`, version `1.0` (`versionCode=1`), min SDK 24, target SDK 36, and declared permissions.
- Full Godot tests and smoke test passed. The test runner still reports its known ObjectDB/resource-use warnings at exit.
- Configured RuStore application ID `2063757594`, then used the Public API to upload the AAB, 512x512 icon and three portrait screenshots to draft `2064828374`. API verification reports version `1.0` (`versionCode=1`), status `DRAFT`, publication type `MANUAL`, and three active phone screenshots. No moderation or publication endpoint was called.
- Refilled draft `2064828374`: saved Russian short/full descriptions, public support email, Arcade/Casual categories, age 6+, search tags, content labels and RuStore Pay integration through the Console. Because saving the web form clears API-only attachments, the AAB, icon and three screenshots were uploaded again through the Public API after the final browser save. Final API verification reports version `1.0` (`versionCode=1`), `DRAFT`, `MANUAL`, three screenshots and no moderation date; no moderation endpoint was called.
- Product `remove_ads` is published as a non-consumable purchase priced at 299 RUB. After refreshing the Console, draft `2064828374` shows `Встроенные покупки -> Товары`; Pay sandbox purchase/decline/restart-restore verification remains pending.

## 2026-09-16 — Bilingual horizontal gameplay videos

- Added `promotion/gameplay_videos_bilingual_2026-09-16/` with new Russian and English 1920x1080 (16:9) H.264/AAC videos at 60 FPS. Each opens with its matching localized startup splash and then shows continuous gameplay from the matching localized runtime recording.
- The portrait playfield remains complete, centered and uniformly scaled over a blurred, darkened frame-derived background. FFprobe metadata, full FFmpeg decode and visual review of title-card and gameplay contact sheets passed; no game asset or runtime UI was modified.

## 2026-09-16 — Yandex archive with graphical countdown

- Re-exported `Web - Yandex Games` after adding the localized `НАЧАЛИ!` / `GO!` raster countdown and circus-confetti burst.
- Built `builds/clown-smash-yandex-countdown-confetti-2026-09-16.zip`: 9 root runtime files, 31,100,184 bytes, SHA-256 `FDF4050D0E28E18AA9B236954470152A323074AD1F54FB8D81C6EF4687A93B91`.
- Editor/import, full tests, smoke test, Yandex Bridge contract, Web export and archive-content inspection passed; live cabinet upload and hosted SDK behavior were not performed.

## 2026-09-16 — Графический старт и цирковое конфетти

- Финальный кадр отсчёта заменён на локализованные прозрачные растровые надписи `НАЧАЛИ!` / `GO!` без круглой подложки.
- Надпись появляется с коротким pop-эффектом и взрывается яркими блестящими цирковыми конфетти; цифры `3–2–1` и игровая логика отсчёта не изменены.
- Godot 4.7.2: импорт, полный `tests/run_tests.gd`, smoke-тест и видимые Compatibility-renderer кадры обеих локалей прошли; PNG подтверждены как RGBA.

## 2026-09-16 — Yandex production build refreshed after UI correction

- Re-exported `Web - Yandex Games` after hiding the Remove Ads currency icon and rebuilt `builds/clown-smash-yandex-remove-ads-2026-09-16.zip` with only the nine upload files.
- Final archive: 28,682,246 bytes, SHA-256 `B8748D17BE2EB0E90303FE8AC1F8A3629915575F23C5417AAD9F9DFA340282F2`. Import, full tests, smoke test, Web export and ZIP inspection passed.

## 2026-09-16 — Bilingual horizontal gameplay collages

- Added `promotion/gameplay_collages_bilingual_2026-09-16/` with three Russian and three English 2560x1440 (16:9) JPEG collages. The first Russian and English collages contain their matching localized startup splashes; all remaining panels are unique frames from the localized gameplay recordings, with no source-image reuse across the six collages.
- Used existing visible Compatibility-renderer captures and localized runtime recordings without changing game assets or UI. FFprobe confirmed every deliverable as 2560x1440 `yuvj420p`; the bilingual contact sheet was visually reviewed.

## 2026-09-16 — English Yandex moderation videos refreshed

- Added `promotion/yandex_games_en_2026-09-16/` as the English equivalent of the current Russian moderation-video package: fresh vertical 1080x1920 and horizontal 1920x1080 H.264/AAC gameplay videos at 60 FPS and 26.27 seconds.
- Both outputs come from one deterministic English Godot Movie Maker capture. The horizontal version keeps the full portrait frame over a blurred background from the same stream; full FFmpeg decode and visual contact-sheet review passed.

## 2026-09-16 — Remove Ads button icon hidden

- Removed the graphical currency icon from the Remove Ads buttons in the main menu and session overlay at the user's request. The SDK catalog, dynamic price/currency text, purchase and restore flows remain unchanged.

## 2026-09-16 — Yandex `remove_ads` purchase restored

- Re-enabled purchases in the production `Web - Yandex Games` preset after the `remove_ads` product was added in the platform console.
- Added `payments.getCatalog()` integration. The Remove Ads buttons display the SDK-provided price/currency text and remain hidden in the Yandex build until the catalog returns the declared product.
- Kept the permanent entitlement flow through `payments.purchase()` and startup `payments.getPurchases()` restoration; a successful/restored purchase persists `ads_removed` and disables in-game banner/interstitial requests.
- Built `builds/clown-smash-yandex-remove-ads-2026-09-16.zip`: 9 root files, 28,682,248 bytes, SHA-256 `A2AE412B7824230B0C5C10FCEE5E8CE37267245609236FF1F4223FBBE8760D64`. Editor/import, JavaScript bridge contract, full Godot tests, smoke test, visible Compatibility-renderer offer capture, Web export and ZIP inspection passed; live sandbox purchase/restore still requires the uploaded Yandex draft.

## 2026-09-16 — Yandex moderation corrections

- Localized the final countdown cue as `GO!` / `ВПЕРЁД!` and made the already-instantiated Settings overlay refresh all labels after the platform SDK selects a locale, eliminating mixed Russian/English UI.
- Removed the unsupported check-mark glyph from completed level buttons; fresh Russian and English Compatibility-renderer captures show readable text without missing-glyph boxes.
- Added `no_purchases` to the production `Web - Yandex Games` preset. The undeclared `remove_ads` button is hidden in this release while advertising remains available; RuStore, VK and explicit monetization-demo presets are unchanged.
- Added fresh Russian vertical and horizontal gameplay videos under `promotion/yandex_games_ru_2026-09-16/`. Both are H.264/AAC, 26.27 seconds, fully decoded and visually reviewed from contact sheets.
- Built `builds/clown-smash-yandex-release-fix-2026-09-16.zip`: 12 root files, 28,681,250 bytes, SHA-256 `9518FF34F76A17FBA82B89C5FA5163EBE28CC7B5E0B62DC4B824CA0D563F15D0`.
- Godot editor/import check, full `tests/run_tests.gd`, smoke test, production Web export, archive inspection and visible renderer checks passed. Cabinet upload, draft-language field replacement and repeat moderation remain external manual steps.

## 2026-09-15 — RuStore AAB release packaging

- Configured the production RuStore preset as an arm64 AAB and narrowed its export filter to omit tests, tooling, promotion/verification material, source-processing assets, the demo ad video, and the optional Android Yandex Ads plugin.
- Kept RuStore Pay initialization independent of the optional ads singleton, so the signed store build can retain purchases without bundling Yandex Mobile Ads.
- Built and verified `builds/clown-smash-rustore.aab` (45,885,611 bytes, SHA-256 `EC806CF3FFC94C0958A0EB1ECEE016C5A8BA972DED21F57D96777095864CE9FC`) with the universal release certificate; archive inspection found no Yandex/AppMetrica, Adugo, test, tooling, promotion, verification, reference, or demo-ad paths.
- Built the matching signed device APK, installed it on Infinix X663, and visually checked the 1080x2400 main menu, countdown, gameplay board and a real empty-box tap. Runtime logs showed only RuStore Core/Pay plugins, no crash or GDScript error, and roughly 60 FPS frame delivery after startup.
- Full automated tests and the smoke test passed. Store purchase/restore is still blocked from production verification until `rustore_PayClientSettings_consoleApplicationId` is replaced from `0` with the actual RuStore Console application ID and the `remove_ads` product is configured.

## 2026-09-15 — RuStore production monetization components

- Added the official RuStore Godot Pay/Core 11.1.0 plugins and the current Pay SDK Maven repository; BillingClient is not used.
- Added the Android Yandex Mobile Ads 7.18.3 plugin and connected the RuStore adapter to a bottom adaptive banner and level-start interstitial callbacks.
- Implemented non-consumable `remove_ads` purchase and startup restoration. A confirmed purchase uses the existing durable `ads_removed` save path, hides the banner and bypasses later interstitials.
- Added the `Android - RuStore` Gradle export preset, Android network permissions, Pay SDK manifest metadata, and documented public configuration keys.
- Local/static verification can prove parsing, tests and Gradle dependency resolution only. RuStore Console app/product IDs, Yandex ad-unit IDs, release signing, sandbox purchase/restore, real ad inventory, consent/privacy setup and device behavior still require owner/device verification.

## 2026-09-13 — Yandex lifecycle, cloud saves and advertising gates

- Centralized Yandex SDK initialization in the web platform bridge; localization, Game Ready, Gameplay API, lifecycle, cloud saves and advertising now reuse one `ysdk` promise.
- Added `GameplayAPI.start()/stop()` state mapping and `game_api_pause` / `game_api_resume` handling that pauses an active round and Music/SFX without auto-resuming a user-paused round.
- Added guest/authorized cloud progress through `ysdk.getPlayer()` and `player.getData()/setData(..., true)` with a five-second local fallback. Valid local/cloud saves merge unlocked/completed levels and best results without losing progress.
- Fixed JavaScriptBridge callback decoding and callback lifetime in `WebMonetizationAdapter`; this previously prevented successful adapter initialization and therefore could suppress the sticky-banner request.
- Level 1 is now unconditionally free of game-requested interstitials, including demo builds. Yandex's separate automatic startup ad remains platform-controlled and is handled through lifecycle events.
- Sticky status and reason are reported as `[ClownSmash][Ads]`; the cabinet must enable the bottom portrait sticky placement plus **Use API to show sticky banner** before live display can be confirmed.
- Verification: Godot editor parse/import passed; full `tests/run_tests.gd` passed; `node tests/yandex_bridge_test.mjs` passed with one SDK initialization, lifecycle, Gameplay API, sticky show and cloud round-trip mocks.
- Exported `builds/clown-smash-yandex-release-2026-09-13-1737.zip`: nine runtime files at archive root, 58,241,071 bytes unpacked, 28,632,374 bytes compressed, SHA-256 `7FECD2E7CE626371BCB4107C4B0D5902313FC7E1A99F1C86E4CA3BF2C26CAD96`.

## 2026-09-13 — обновлены скриншоты страницы VK

- Подготовлена новая галерея `promotion/vk_games_2026-09-13/screenshots_v2/`: пять PNG 600×1200 в единой портретной ориентации.
- Убрана сильная JPEG-компрессия; первые позиции заменены на выразительные кадры реального игрового рендера: удар молотком, специальные клоуны и основной игровой процесс.
- Проверены декодирование, точные пиксельные размеры, соотношение 1:2 и вес менее 1 МБ для каждого файла.
- Порядок загрузки и назначение файлов описаны в `promotion/vk_games_2026-09-13/README.md`.
- Из заставки `verification/startup_splash_circus_1080x1920.png` подготовлен отдельный `screenshots_v2/03_startup_splash_600x1200.png`: 600×1200, PNG, без искажения пропорций; он отмечен как дополнительный презентационный кадр, а не геймплей.
- Автоматически заменить уже опубликованные файлы в кабинете VK не удалось: официальная страница `dev.vk.ru` заблокирована политикой браузерного доступа в текущем окружении. Готовые файлы требуют ручной загрузки в кабинет.

## 2026-09-13 — Yandex Games release after feedback fixes

- Exported the current `Web - Yandex Games` release after the gameplay-feedback deduplication and sticky-banner diagnostics changes.
- Prepared `builds/clown-smash-yandex-release-2026-09-13-1643.zip`: nine runtime files at the archive root, 58,230,460 bytes unpacked and 28,625,659 bytes compressed.
- Archive paths contain no directories, spaces or non-ASCII characters. SHA-256: `AB0384CC11AB6DBA4CF498BF4324D4F714B79B4AEBA82F814BE50A7B55359646`.

## 2026-09-13 — Gameplay feedback deduplication and Yandex banner diagnostics

- Removed the static HUD `+10` and life-loss messages; both now use only the localized rising/fading impact label at the struck box.
- A bonus miss now suppresses the later duplicate escape label for that same active Clock or Glutton.
- The Yandex web bridge now checks `getBannerAdvStatus()` before requesting a sticky banner and logs the status, show result, rejection, or platform reason in the browser console instead of silently swallowing every outcome.

## 2026-09-13 — Fresh Yandex Games release build

- Re-ran the full automated suite and smoke test, then exported the current `Web - Yandex Games` release with Godot 4.7.2 stable.
- Prepared `builds/clown-smash-yandex-release-2026-09-13-1514.zip` with nine runtime files at the archive root, including `index.html`; paths contain no spaces, Cyrillic characters, or nested directories.
- Verified the `/sdk.js` bootstrap, 58,229,230-byte unpacked payload, 28,624,977-byte ZIP, and SHA-256 `24126B8BE673377B60BC875D5175D75067F39EE80284EA59BFAA65B4DC02C41D`.
- Hosted Yandex SDK callbacks, advertising, purchases, Developer Console validation, and moderation remain external checks.

## 2026-09-13 — Yandex production export banner startup fix

- Fixed the production web export compile failure caused by the monetization demo presenter preloading a demo-only video that the Yandex preset intentionally excludes.
- The demo video is now loaded lazily only when the opt-in demo presenter runs, so the production `MonetizationService` can initialize, restore entitlements, request the sticky banner and later send `LoadingAPI.ready()`.
- Live draft diagnosis before the fix showed the missing-resource parse error and no game-side banner request; a corrected archive must be uploaded to the Yandex Games draft before hosted behavior can be rechecked.

## 2026-09-13 — Browser gameplay layout

- Raised the browser HUD to the top of the portrait canvas and moved the 3×3 playfield up by the same 112 design pixels.
- Kept the existing native/mobile HUD and playfield offsets unchanged.
- Rebuilt the `Web - Yandex Games` release package after automated and rendered browser verification.

## 2026-09-13 — Yandex Games monetized release candidate

- Added the required one-shot `LoadingAPI.ready()` call when the player-facing Main Menu becomes available.
- Fullscreen Yandex advertising now mutes the Music/SFX buses from the SDK `onOpen` callback and restores their prior mute state on close/error; duplicate terminal callbacks are ignored.
- Rebuilt the `Web - Yandex Games` release archive with production SDK advertising and the durable `remove_ads` purchase/restore flow.
- Store-console contracts, the `remove_ads` catalog item, real ad inventory, live purchase callbacks and moderation still require the owner's Yandex account and cannot be proven by local tests.

## 2026-09-13 — Cross-platform monetization demo QA

- Added the opt-in `monetization_demo` export feature with a bottom-slot test banner, a labelled four-second Theora video interstitial before level start, and a successful virtual `remove_ads` purchase.
- The demo uses the production `MonetizationService` and `SaveManager` entitlement path: purchase hides banner/button immediately, skips later interstitials, and persists `ads_removed` across restart.
- Added separate Android/RuStore, Yandex Games Web and VK Mini Apps Web demo export presets under `builds/monetization-demo/`; no real SDK purchase or ad inventory is simulated in production adapters.
- Added automated coverage for virtual purchase, disk persistence, restart restore, ad bypass, bottom banner placement/hide, and video resource loading.
- Verification: full `tests/run_tests.gd` and `tests/smoke_test.gd` passed; all three demo exports completed. Physical Infinix X663 inspection confirmed the bottom banner and video interstitial. A restart check exposed and fixed the demo presenter's default-visible banner state; final recheck is recorded in `verification/monetization_demo_after_restart_android.png`.
- Still unverified: hosted Yandex/VK containers and their real SDK callbacks; RuStore Pay SDK/sandbox and a selected Android ad network; store-console catalog/placement setup, real payment restoration across accounts/devices, and moderation.

## 2026-09-12 — Countdown purchase visibility

- Kept `REMOVE_ADS` hidden during the pre-level countdown; it is shown only on eligible pause or result panels.

## 2026-09-12 — Phone menu and result panel fit

- Removed the enclosing frame from Main Menu while keeping a non-overlapping adaptive action layout.
- Made SessionOverlay panels grow for every visible action, so `REMOVE_ADS` remains inside pause and result panels.
- Changed StartupSplash from aspect-covered scaling to screen-fill scaling, preventing the localized title art from being horizontally cropped on 1080×2400 phones.

## 2026-09-12 — Startup and Main Menu mobile layout

- Reduced the embedded Russian and English startup-title art to add reliable horizontal safe margins on phone screens.
- Main Menu now uses the localized startup art as its background and no longer draws a duplicate text title.
- Added an adaptive menu panel: its height follows the visible actions, including the optional `REMOVE_ADS` button, and actions use consistent non-overlapping vertical gaps.

## 2026-09-12 — Boot splash hammer angle refinement

- Replaced `assets/generated/boot_splash_clown_chase.png` with the approved preview: the hammer head keeps its side-view perspective with a reduced diagonal tilt, while the handle remains perpendicular to the head axis.
- Preserved the hidden striking/top surfaces and the rest of the splash composition.

## 2026-09-12 — Boot splash hammer replacement

- Replaced the hammer in `assets/generated/boot_splash_clown_chase.png` with the authored gameplay hammer from `assets/generated/toy_hammer.png` as the visual reference.
- Corrected the hammer construction in the splash: centered perpendicular handle, hidden striking/top surfaces, and a slight turn around the handle's vertical axis.
- Preserved the circus background, clowns, composition and engine-level splash path.

## 2026-09-12 — Results popup bottom padding

- Increased the Results popup height so the lower Menu button has a 40-pixel inner bottom gap instead of touching the panel edge.

## 2026-09-12 — Web viewport fit

- Added a reusable portrait web shell for Yandex Games and VK Mini Apps exports.
- The 9:16 canvas now scales against both browser width and real viewport height, stays centered, and no longer overflows a wide external browser window.

## 2026-09-12 — Branded boot splash

- Replaced the default Godot boot image with a text-free circus chase composition: one clown with the toy hammer runs after another clown.
- Corrected the chasing clown's hammer construction and grip: centered perpendicular handle, closed hand around the shaft, and end knob below the fist.
- Kept this engine-level splash language-neutral; the localized Russian/English title splash still follows after startup.

## 2026-09-12 — Game rename

- Renamed the player-facing game title to `Цирковой переполох` in project metadata, export metadata, Main Menu and About text.
- Reworked the startup splash title while preserving the approved circus composition, clown and hammer artwork.
- Added visible Compatibility-renderer captures for the renamed startup splash and Main Menu at 1080×1920.
- Added the English `Circus Ruckus` splash and localized Main Menu/About titles; English startup now selects its own title art automatically.

## 2026-09-12 — Yandex Games release build

- Exported the `Web - Yandex Games` release build to `builds/yandex` with Godot 4.7.2 stable.
- Prepared `builds/clown-smash-yandex.zip` for Developer Console upload: one root `index.html`, no spaces or Cyrillic characters in paths, 48.62 MiB unpacked.
- Verified the Yandex Games SDK bootstrap uses the required relative `/sdk.js` path for archive hosting.
- Launched the official Yandex Games SDK dev proxy in mock mode and verified its HTTPS response; the visible browser run uses a separate local HTTP server because the embedded browser rejects the proxy's self-signed certificate. Developer Console moderation and production SDK behavior remain pending.

## 2026-09-12 — Android test build without purchases and updated Yandex materials

- Added the Android-only `no_purchases` export feature: the purchase action is hidden and `MonetizationService` declines purchase requests in this test build.
- Exported `builds/clown-smash-test-no-purchases.apk` and installed it on the physical Infinix X663.
- Captured and visually reviewed the test-build menu (no purchase action) and active gameplay; recorded a 28-second real-device gameplay video.
- Prepared the separate package `promotion/yandex_games_test_no_purchases_2026-09-12/` with icons, covers, mobile screenshots, the new phone recording, device evidence and an upload checklist tied to current Yandex Games requirements.

## 2026-09-12 — Yandex Games cover

- Added `promotion/yandex_games_test_no_purchases_2026-09-12/covers/cover_800x472_clownsmash.png`: a text-free 800x470 cover with the Normal, Bomb and Clock clowns, circus setting and the authored red/gold side-handle hammer silhouette.
- Visually reviewed the final PNG at its exact upload resolution; it has no UI, border or rounded corners.

## 2026-09-12 — Russian/English localization

- Added English translations for the current player-facing UI and gameplay feedback.
- Added startup language detection for Yandex Games (`environment.i18n.lang`), VK Mini Apps (`vk_language`), and Android/RuStore device locale.
- Unsupported languages fall back to Russian; locale selection finishes before the first game screen is created.
- Live platform verification in the Yandex/VK developer environments and a RuStore-installed Android build remains pending.

## Current status

Milestones 0–8 are complete and verified with Godot 4.7.2 stable.

Milestone 9 is complete for automated Android validation on desktop, the `Medium_Phone` emulator, and the physical Infinix X663 phone. The physical-device run confirmed stable 60 FPS and successful haptic API delivery; a person holding the phone must still make the subjective tactile-quality judgement.

---

## Done

- [x] MVP concept defined.
- [x] One world selected: Circus Tent.
- [x] 3×3 box playfield fixed.
- [x] Seven gameplay clown types defined.
- [x] Score rules fixed.
- [x] Combo rules fixed.
- [x] Apple-life rules fixed.
- [x] Drunk random-hit mechanic defined.
- [x] Nine-level progression defined.
- [x] MVP scope locked: no coins/store/ads/backend.
- [x] Codex orchestration/subagent policy defined.
- [x] `SPEC.md` prepared.
- [x] `AGENTS.md` prepared.
- [x] `PROGRESS.md` prepared.
- [x] Milestone 0 bootstrap completed.
- [x] Godot 4.7.2 stable detected.
- [x] Portrait 1080×1920 project configured with `canvas_items`, `expand`, and Compatibility renderer.
- [x] Project directory structure created.
- [x] Basic headless test runner and smoke test added.
- [x] Milestone 1 core interaction prototype completed.
- [x] Milestone 2 complete Level 1 session completed.
- [x] Gameplay visual-depth pass completed: raised perspective stage, converging 3×3 layout, row depth scaling, extruded boxes, recessed openings, cast shadows, dimensional Normal clown and hammer.
- [x] Reference-matching presentation pass completed: original painted circus background, shared painted open-box asset, Normal clown and hammer assets, measured HUD/board alignment, automated overlay/difference workflow, impact capture and responsive visual QA.
- [x] Hammer art corrected: vertical top-to-bottom striking head with a centered perpendicular side handle; impact contact re-aligned without changing animation timing.
- [x] Animation anchoring correction: spring is clipped to the box opening and tracks the clown base; the clown is clipped while descending; hammer contact is aligned from above to the clown's top centre.
- [x] Seven-character gameplay set completed: Normal, Fast, Golden, Bomb, Clock, Glutton and Drunk.
- [x] Authored special-character asset pack and closed-box asset integrated with transparent-source QC.
- [x] Box lid now transitions between authored closed/open states; hammer impact compresses the spring and follows the compressed target.
- [x] Box artwork is baseline-aligned across lid states; active clowns own the gameplay touch target and hammer contact.
- [x] Gameplay taps now require an opaque box pixel or visible clown-head region; hammer makes an amplified arc around the far edge of its handle.
- [x] Regression checks protect the fixed box baseline and direct clown-face tap selection from later hammer changes.
- [x] HUD feedback added for Golden objective progress, Clock time, Glutton lives, Bomb penalty and Drunk confusion strikes.
- [x] Level 1-9 tuning resources, weighted character selection, double-spawn staggering and baseline fairness constraints implemented.
- [x] Round duration reduced to 60 seconds; spawn intervals now accelerate smoothly through each round; HUD life icons use the gameplay hammer.
- [x] Current tuning pass: Fast, Golden and Drunk are excluded from automatic spawns; Clock/Glutton hits preserve combo; Glutton escape no longer removes a life; local score/bonus floaters and a bright Bomb-confetti impact with a short flash are added.
- [x] Startup splash added: the approved portrait circus key art fades in on launch, can be skipped with one tap, and then opens the Main Menu.

---

## In progress

- Milestone 9 — functional physical-device QA complete; subjective haptic-feel sign-off remains.

---

## Next

### Milestone 0 — Bootstrap

- [x] Create Godot project.
- [x] Confirm installed Godot stable version.
- [x] Configure portrait mode.
- [x] Configure base 1080×1920 layout.
- [x] Configure `canvas_items` stretch and `expand` aspect.
- [x] Select Compatibility renderer.
- [x] Create repository/project directory structure.
- [x] Add `AGENTS.md`, `SPEC.md`, `PROGRESS.md`.
- [x] Add `.gitignore`.
- [x] Add basic test runner.
- [x] Add headless smoke test.
- [x] Verify empty project opens/runs without parser/runtime errors.

Acceptance:
- Godot project runs.
- Headless smoke check exits successfully.
- Test runner exits successfully.

---

### Milestone 1 — Core interaction prototype

- [x] Create `Gameplay.tscn`.
- [x] Create `BoxSlot.tscn`.
- [x] Place 9 BoxSlots in a fixed 3×3 board.
- [x] Implement `BoardController`.
- [x] Implement Normal clown.
- [x] Implement `SpawnDirector` with only Normal.
- [x] Implement tap-to-slot detection.
- [x] Implement Hammer animation/controller.
- [x] Correct hit gives +10.
- [x] Correct hit increases combo.
- [x] Empty tap resets combo but not life.
- [x] Missed Normal resets combo.
- [x] Add basic tests.

Acceptance:
`spawn → tap → hammer → +10 → combo → hide → repeat`

---

### Milestone 2 — Complete level session

- [x] Add 60-second timer.
- [x] Add three apple lives.
- [x] Add countdown `3 2 1 GO`.
- [x] Add pause/resume.
- [x] Add score HUD.
- [x] Add combo HUD.
- [x] Add lives HUD.
- [x] Add win state.
- [x] Add loss state.
- [x] Add Results popup.
- [x] Implement Level 1 config.
- [x] Test complete Level 1 loop.

---

### Milestone 3 — Special characters

Implement and verify one at a time.

- [x] Golden.
- [x] Bomb.
- [x] Fast.
- [x] Clock.
- [x] Glutton.
- [x] Drunk.

For each:
- [x] gameplay behavior;
- [x] spawn/despawn;
- [x] feedback;
- [x] tests;
- [x] no regression.

---

### Milestone 4 — Nine levels

- [x] Implement `LevelConfig` Resource.
- [x] Create `level_01.tres` … `level_09.tres`.
- [x] Implement objective checks.
- [x] Implement unlock progression.
- [x] Validate SpawnDirector fairness constraints.
- [x] Add deterministic-seed tests.

---

### Milestone 5 — Menu and navigation

- [x] Main Menu.
- [x] Level Select.
- [x] Pause popup.
- [x] Settings popup.
- [x] Results screen.
- [x] Scene routing.
- [x] Save progression.
- [x] Save settings.
- [x] Best score.
- [x] Best combo.

Acceptance flow:
`launch → menu → levels → gameplay → results → next/retry/menu`

---

### Milestone 6 — Final art integration

- [x] Circus background.
- [x] Reusable box layers.
- [x] Normal asset.
- [x] Fast asset.
- [x] Golden asset.
- [x] Bomb asset.
- [x] Clock asset.
- [x] Glutton asset.
- [x] Drunk asset.
- [x] Hammer asset.
- [x] Apple/UI assets.
- [x] Check pivots.
- [x] Check CanvasItem ordering.
- [x] Check 9:16 composition.
- [x] Remove obsolete placeholders from runtime scenes and Android export.

---

### Milestone 7 — Juice and polish

- [x] Pop spring animation.
- [x] Clown idle movement.
- [x] Correct-hit squash.
- [x] `+10` floating text.
- [x] Combo bounce.
- [x] Bomb impact flash.
- [x] Clock `+10 sec` HUD feedback.
- [x] Glutton apple-flight animation.
- [x] Drunk wobble and remaining-strikes indicator.
- [x] Light camera shake.
- [x] End-of-level transition delay.
- [x] Contextual first-time tutorial hints.

---

### Milestone 8 — Audio and haptics

- [x] Music loop.
- [x] Two normalized background tracks selected randomly per level without immediate repeats.
- [x] Two normalized, non-silent-fade miss sounds selected randomly when a scoring clown escapes.
- [x] Normalized authored Bomb-hit sound replaces the procedural Bomb SFX.
- [x] Box pop.
- [x] Hammer BONK.
- [x] Correct hit.
- [x] Empty hit.
- [x] Bomb.
- [x] Life lost.
- [x] Apple restored.
- [x] Clock.
- [x] Drunk.
- [x] Combo.
- [x] Countdown.
- [x] Victory.
- [x] Defeat.
- [x] UI button.
- [x] Music toggle.
- [x] SFX toggle.
- [x] Haptics toggle.

---

### Milestone 9 — Mobile QA

- [x] Android touch input verified by ADB tap on emulator.
- [x] Mouse emulation in editor.
- [x] 720×1280.
- [x] 1080×1920.
- [x] 1080×2340.
- [x] Tall phone safe area verified at 1080×2400 emulator resolution.
- [x] Pause/resume from OS verified through Android Home/resume.
- [x] No touch leakage through HUD.
- [x] 60 FPS target verified on physical Infinix X663 (Android 12) after warm-up.
- [x] Emulator memory baseline captured (about 160 MB PSS on Main Menu).
- [x] Android debug export, signature verification, install and launch.
- [x] Physical-device Android `VIBRATE` permission and haptic API invocation verified.

---

## Known issues

- A person holding the Infinix X663 must still judge the subjective strength and feel of the 20 ms correct-hit and 55 ms bomb/life-loss haptics; ADB can verify permission and error-free API delivery, but not tactile sensation.

---

## Tests

Bootstrap, audio hooks, scoring, combo, session state, lives, saves, navigation, all nine LevelConfigs, BoxSlot count and core interaction integration tests exist.

All seven character rules, nine level resources, asset loading, Clock cap, Golden objectives, Bomb/Glutton life rules, Drunk routing, lid opening, spring compression and special-character scene wiring are covered.

Last verified on Godot 4.7.2 stable:

- `godot_console --headless --path . --script res://tests/run_tests.gd` — PASS.
- `godot_console --headless --path . --script res://tests/smoke_test.gd` — PASS.
- `godot_console --headless --path . --quit-after 300` — exit code 0.
- Core interaction integration test — PASS (`spawn → tap → hammer → +10 → combo → hide → repeat`).
- Session tests — PASS (countdown, pause/resume timer freeze, three-life cap, zero-life loss, timer win and Results popup).
- Visible Compatibility-renderer captures — PASS at 720×1280, 1080×1920, 1080×2340 and 1440×3200.
- Reference-matching regression run — PASS: full tests, smoke test and headless main-scene load.
- Android debug export — PASS; APK signed with v2/v3 schemes and installed on the `Medium_Phone` emulator.
- Android runtime — PASS after 12+ seconds, touch interaction produced score 10/combo 1, Home/resume opened Pause, no GDScript/runtime error in logcat.
- Physical Infinix X663 (Android 12) — PASS: fresh APK installed and launched, menu and 1080×2400 gameplay captures reviewed, ADB gameplay interaction scored +10, `android.permission.VIBRATE` was present and granted, the successful hit no longer produced a VIBRATE exception, and post-warm-up frame pacing reported about 60.4 FPS.

## Visual verification

- Reference checked: YES — `assets/references/gameplay_field_reference.png` was opened before implementation and reopened after the runtime capture.
- Screenshot compared: YES — `verification/gameplay_1080x1920.png` was compared side by side with the reference.
- Responsive captures reviewed at 720×1280, 1080×1920 and 1080×2340 for this pass; controls remain readable and the board has no overlaps.
- Countdown, Pause and win-result captures reviewed at 1080×1920.
- The earlier procedural clown, box, hammer and tent rendering was replaced for this presentation pass; gameplay contracts, node paths and the fixed 3×3 rules remain unchanged.
- Reference-matching final: `artifacts/visual_tests/final.png`; overlay/difference and compliance report are in `artifacts/visual_tests/`.
- Two rendered comparison iterations completed. No P0 composition discrepancy remains. P1/P2 deviations: generated lids are taller than the reference, the board and apples are less painterly, and the fallback font is less decorative.
- Visible impact state captured at `artifacts/visual_tests/impact.png`; 720×1280 and 1080×2340 captures were inspected after the tall-screen background fix.
- Seven-character showcase reviewed at `verification/mvp_specials_1080x1920.png`; authored closed boxes, open boxes, springs and all six new special assets have coherent alignment and depth order.
- Gameplay-status HUD reviewed at `verification/mvp_hud_status_1080x1920.png` and `verification/mvp_hud_status_720x1280.png`; Golden and Drunk indicators remain readable without covering the playfield.
- Updated HUD/board capture reviewed at `verification/round60_hud_hammers_1080x1920.png`; the 60-second timer, hammer life icons, one-timer-height HUD offset and 10-pixel box-field offset are visible without overlaps.
- Physical Infinix X663 launch check completed for the 60-second/HUD update: refreshed debug APK installed, menu and active gameplay captured at `verification/physical_round60_hammers_infinix_x663_1080x2400.png` and `verification/physical_gameplay_round60_hammers_infinix_x663_1080x2400.png`; no fatal or GDScript error was found in the recent logcat window.
- Final hammer/spring contact reviewed at `verification/mvp_impact_1080x1920.png`; the hammer follows the compressed target and the spring shortens on impact.
- Main Menu reviewed at `verification/main_menu_720x1280.png`, `verification/main_menu_1080x1920.png` and `verification/main_menu_1080x2340.png`.
- Level Select and Results reviewed at `verification/level_select_1080x1920.png` and `verification/result_win_1080x1920.png`.
- Android 1080×2400 menu, gameplay, hit feedback and lifecycle pause reviewed in `verification/android_*.png`.

Planned:

- physical-device haptics;
- sustained frame pacing on a representative mid-range Android phone.

### 2026-09-12 — Monetization integration

- Added `MonetizationService` with platform adapters for Yandex Games/VK web exports, a RuStore Pay SDK integration boundary for Android, and a deterministic debug adapter.
- Added bottom sticky-banner requests and interstitial requests before levels 2–9 only.
- Added the styled `REMOVE_ADS` purchase button to Main Menu and session overlays; durable `ads_removed` entitlement hides ads and buttons after restore or confirmed purchase.
- Added `docs/monetization.md` with current official documentation links and the remaining console/SDK setup steps.
- Verification: Godot editor parse/load check passed; `tests/run_tests.gd` passed with exit code 0. Live ad inventory, payment, restore across accounts/devices, VK moderation, and RuStore Android SDK behavior remain unverified.

### 2026-09-12 — Yandex Games visual materials

- Added a standalone upload-ready static-media package in `promotion/yandex_games_2026-09-12/`: 512×512 icon, maskable icon, 800×470 catalog cover, 1560×520 storefront cover, and two real portrait gameplay screenshots in valid 9:16 JPEG 1440×2560 format.
- Reviewed generated icon/cover composition and confirmed the screenshots are based on existing rendered gameplay states. Required horizontal gameplay video remains intentionally uncreated: it must be recorded from an actual gameplay session rather than synthesized from static frames.

### 2026-09-12 — Yandex Games horizontal gameplay video

- Installed the freshly exported debug APK over the existing Android installation on a physical Infinix X663 (Android 12), launched it, and recorded a live 27.67-second gameplay session with real device taps.
- Added `promotion/yandex_games_2026-09-12/videos/gameplay_horizontal_1920x1080.mp4`: H.264 MP4, 1920×1080 (16:9), 27.5 seconds, 2.09 MB. It uses the unaltered portrait game capture over a blurred background derived from the same capture; no static screenshots were used as the gameplay video.
- Added `video/circus_ruckus_vertical_teaser_1080x1920.mp4`: a 9.67-second, 1080×1920 H.264/AAC teaser. It combines the branded title card, 5.67 seconds of real recorded mobile gameplay, a final call-to-action card, and the authored in-game music; a frame-by-frame contact-sheet review confirmed all three sections appear in the final render.
- Added `video/circus_tent_chase_vertical_1080x1920.mp4`: a 10.3-second, 1080×1920 H.264/AAC stylized cinematic based on the requested tent-entry and ringmaster-chase scenario. Four generated key frames are preserved under `video/ai_frames/`; the final sequence uses animated camera pushes, short crossfades, the authored in-game music and the localized startup title. Full decode and contact-sheet visual review passed.
- Added `video/circus_tent_chase_circus_text_1080x1920.mp4`, preserving the text-free cinematic as a separate source. Five timed Russian advertising captions use the game's cream, gold and dark-ink palette with layered marquee-style outlines and shadows. Full MP4 decode passed, and a 1-second contact-sheet review confirmed caption timing, readability and subject clearance across all scenes.

### 2026-09-12 — Portrait phone screenshot correction

- Reframed the seven JPG screenshots in `artifacts/phone_screenshots_2026-09-12/` from landscape 16:9 presentation frames to 9:16 portrait images. The game screen remains centered and intact; the superseded landscape sources are retained in `source_landscape_jpg/` for recovery.

### 2026-09-13 — VK Games publication texts

- Added `docs/vk_games_publication.md` with Russian and English store-card copy, gameplay instructions, category/tag recommendations and a conservative age-rating note for the VK Mini Apps web export.
- The exact live field limits and upload requirements on the linked VK cabinet page were not independently retrievable; they must be checked against the counters and hints shown in the authenticated cabinet before submission.

### 2026-09-13 — VK Games visual materials

- Added a standalone VK upload package in `promotion/vk_games_2026-09-13/`: 576×576 universal icon, 278×278 catalog/snippet icon, 150×150 small icon, 32×32 favicon, 1120×630 large snippet and five real-game 600×1200 portrait screenshots.
- Reused approved Clown Smash artwork and runtime/device captures; no synthetic image was presented as gameplay. All deliverables were visually reviewed and machine-checked for exact dimensions, format, file size and successful decode.
- The linked `dev.vk.ru` page could not be retrieved by the automated browser. Recheck the field hints in the authenticated VK cabinet before moderation in case the platform requirements changed after 13 September 2026.

### 2026-09-13 — Yandex Games English localization media

- Added `promotion/yandex_games_en_2026-09-13/` with two English gameplay videos and four English gameplay screenshots, covering both Mobile portrait and Desktop landscape upload fields.
- The upload videos are H.264/AAC MP4 at 1080×1920 and 1920×1080, 26.6 seconds each. Both show continuous rendered gameplay with English HUD text; the horizontal version preserves the undistorted portrait playfield over a blurred background derived from the same gameplay.
- Added two 1440×2560 mobile JPEGs and two 2560×1440 desktop JPEGs. Visual review confirmed English labels, readable HUD, real gameplay, and no external UI or Russian text in the upload-ready files.
- Rechecked the current official Yandex Games draft and moderation requirements on 13 September 2026. Final codec, duration, dimensions, aspect ratio, size, and decode validation passed.

### 2026-09-13 — Yandex Games bilingual desktop screenshots

- Replaced the cropped images in `promotion/yandex_games_desktop_bilingual_2026-09-13/` with full-frame portrait runtime captures fitted into 16:9 presentation images: four Russian and four English files, including localized startup splashes.
- All eight files are RGB JPEG at 2560×1440 (16:9). The portrait foreground is uniformly scaled and centered without cropping or non-uniform stretching; the side background is a blurred, darkened derivative of the same source capture.
- Visual review confirmed that each source screen, including the Russian and English localized splash titles, is complete and readable. The no-crop layout leaves the sharp foreground at 31.6% of the frame, so it is not claimed to independently satisfy Yandex Games' 70%-real-gameplay area requirement for Desktop uploads.

### 2026-09-13 — VK Mini Apps publication distribution

- Prepared a standalone release package in `builds/vk-mini-apps-delivery-2026-09-13/` with clean Web and cabinet-material ZIPs, a VK hosting configuration template, publication texts and SHA-256 manifest. The unpacked export workspace remains separate under `builds/vk-mini-apps-2026-09-13/` and is not the delivery artifact.
- Kept gameplay code and the `Web - Yandex Games` preset unchanged. The only project configuration change narrows the `Web - VK Mini Apps` export filter so tests, tools, promotional folders and the monetization demo video are not embedded in the production PCK.
- Rechecked the official VK Bridge package (`3.0.2`) and official `vk-miniapps-deploy` package (`1.0.2`) on 13 September 2026. Direct `dev.vk.ru` pages were blocked to the automated browser, so authenticated cabinet field limits, moderation and production hosting remain manual release gates.
- Added the supplied VK Mini App ID `54768735` to the delivery's ready-to-use `vk-hosting-config.json`; no access token or credential is stored in the package.

---

## Decisions log

### 2026-09-13

- Confirmed that missed Clock and Glutton bonus characters do not remove a life, including an empty-box strike while either bonus is active. Their hit, escape and bonus-miss messages now use the same localized circus-style floating, rising and fading effect as score bonuses at the relevant box.

### 2026-09-12

- Unified all program-rendered labels and menu controls around a circus marquee style: cream/gold type, dark outlines, dimensional red/wood panels, and consistent hover/pressed/disabled states across Main Menu, Level Select, Settings, Pause/Results, HUD and impact text.

### 2026-09-10

- Randomized the order and timing of the all-type guarantee: each of the seven types is now scheduled between 10% and 75% of every round rather than occupying the first seven spawns. Halved all level spawn intervals and visible/hittable times.
- Reduced every target score by 100, guaranteed all seven clown types once per level, and changed Drunk confusion to one redirected gameplay tap.
- Widened the score-progress field so multi-digit values such as `1230/600` remain fully visible on the 1080×2400 physical-phone viewport.
- Doubled the current clown spawn frequency across every level again by halving all configured spawn intervals.
- Increased clown spawn frequency by 25% across all nine level configurations. Empty BoxSlot strikes now cost one life; the HUD displays current/target score and has a dedicated background panel for life hammers.
- Updated the round duration to 60 seconds, moved the HUD down by one timer-panel height and shifted the box field down 10 design pixels. Spawn intervals now interpolate from their configured start values to 65% by round end.
- Completed progression, menu/navigation, settings, save integration, polish, contextual hints, audio/haptics hooks and Android export configuration.
- Fixed `AudioStreamWAV` music loop end to the final valid sample frame after emulator QA found an Android `AudioTrack` SIGSEGV at the first loop wrap.
- Added `fon1` and `fon2` as OGG/Vorbis background tracks, loudness-normalized to approximately -18 LUFS and randomly selected at every level start without an immediate repeat.
- Added `promah1` and `promah2` as normalized OGG/Vorbis scoring-clown-miss sounds; their final second fades smoothly to 35% volume instead of silence.
- Added `bomb` as the normalized OGG/Vorbis Bomb-hit sound, replacing the procedural tone while preserving the Bomb haptic and gameplay feedback.
- Added arm64-v8a and x86_64 debug architectures so the same QA APK runs natively on phones and the local emulator.
- Excluded references, verification captures and source-processing artifacts from Android export.
- Updated the Android application ID to `ru.mkulkov.circusruckus`.
- Re-exported the Android debug APK with the new application ID, installed it on the physical Infinix X663, and launched `ru.mkulkov.circusruckus/com.godot.game.GodotAppLauncher` successfully.
- Physical-device QA exposed a missing Android VIBRATE manifest permission. Added `permissions/vibrate=true` to the Android export preset, rebuilt, installed, and verified the permission grant plus an error-free hit on Infinix X663.

### 2026-09-08

- Coins removed completely from MVP.
- Empty-box hit does not remove a life.
- Every correct scoring hit gives exactly +10.
- Combo does not multiply score.
- Bonus-character hit resets combo.
- Glutton restores one lost apple when hit.
- Escaped Glutton consumes one apple.
- Drunk causes the next player tap to strike a random box.
- Cheap subagents are permitted only for bounded low-risk work.
- Astra requires explicit user permission before use.
## 2026-09-16 — Универсальный чек-лист модерации Яндекс Игр

- Добавлен `docs/yandex_games_release_moderation_checklist.md` для переноса в другие проекты.
- Чек-лист покрывает локализацию, production-состояние, ИАП, каталог/цену/валюту, покупку и восстановление прав, отключение рекламы, медиаматериалы, автоматические проверки и ручной pre-submit прогон.

## 2026-09-16 — Русское рекламное видео 15 секунд

- Добавлен вертикальный рекламный ролик `promotion/advertising_video_ru_2026-09-16/clown_smash_ad_ru_vertical_1080x1920_15s.mp4`, собранный из актуальной русской записи реального геймплея, фирменной заставки и игровых скриншотов.
- Монтаж показывает попадания, рост комбо, специальных клоунов, удар молотом и финальный призыв «ИГРАЙ СЕЙЧАС!». Титры приведены к стилю игрового UI: красные цирковые панели, золотые рамки и блики, кремовый текст, тёмная объёмная окантовка и звёздные акценты; игровые правила и ресурсы проекта не изменялись.
- Проверка пройдена: 15.000 с, 1080×1920, 60 FPS, H.264 `yuv420p`, AAC 48 кГц stereo, полное декодирование без ошибок и визуальный просмотр секундного контактного листа.

## 2026-09-16 — Английское рекламное видео 15 секунд

- Добавлен английский эквивалент утверждённого русского рекламного ролика: `promotion/advertising_video_en_2026-09-16/clown_smash_ad_en_vertical_1080x1920_15s.mp4`.
- Сохранены монтаж, тайминг, музыка и стиль цирковых титров; использованы английские HUD, заставка, игровые скриншоты и естественные английские рекламные формулировки.
- Проверка пройдена: 15.000 с, 1080×1920, 60 FPS, H.264 `yuv420p`, AAC 48 кГц stereo, полное декодирование без ошибок, крупные кадры титров и секундный контактный лист просмотрены визуально.

### 2026-09-24 — VK Mini Apps Web delivery refreshed

- Re-exported `Web - VK Mini Apps` with Godot 4.7.2 from the current checkout and prepared `builds/vk-mini-apps-delivery-2026-09-24/` for VK Mini App `54768735`.
- The Web ZIP has nine root runtime files and `index.html`; VK Bridge 3.0.2 bootstrap and `VKWebAppInit`, banner and interstitial requests are present. Cabinet media ZIP and RU/EN publication copy are included with a fresh SHA-256 manifest.
- Godot editor/import, `tests/run_tests.gd`, and `tests/smoke_test.gd` passed. ZIP entry, hosting config, credential absence, and manifest hash checks passed.
- VK cabinet upload, dev/production hosting, hosted desktop/mobile runtime, live ad inventory, metadata limits, and moderation remain unverified external steps. No cabinet action was taken.

- Release prep caught and fixed the empty-box rule mismatch: empty strikes now reset combo while preserving lives, and the feedback no longer says a life was lost. Full tests, gameplay smoke, Web export, and regenerated delivery archive passed afterward.

### 2026-09-28 — Android Yandex demo-ad device QA

- Updated the separate `Android - Monetization Demo` export profile to exercise the native Yandex Mobile Ads SDK with official demo placements (`demo-banner-yandex`, `demo-interstitial-yandex`); the production `R-M-*` IDs remain unchanged. The first ad-only APK had `no_purchases` set, which hid the existing remove-ads offer; the refreshed QA profile omits that flag so the menu button is visible. Purchase itself remains untested and was not invoked.
- Added the missing adaptive launcher-icon background resource required by the custom Android template and supplied the matching Godot 4.7.2 debug AAR from the local Gradle cache so this QA APK can build.
- Exported and installed `builds/monetization-demo/clown-smash-rustore-demo.apk` on the Infinix X663 under package `ru.mkulkov.circusruckus.monetizationdemo`; it does not replace the main app package.
- Yandex Mobile Ads 7.18.7 initialized on device. Logcat confirmed banner integration and `onBannerAdLoaded`, then interstitial integration, `onInterstitialAdLoaded` and `onInterstitialAdShown`. The actual demo creative was visible in the captured screen.
- Full `tests/run_tests.gd` passed. Godot reported pre-existing ObjectDB/resource leak warnings at test shutdown; no test assertion failed.
- Full-resolution device captures are in `verification/yandex_ads_demo_device_2026-09-28/`.

### 2026-09-28 — RuStore production monetization release prep

- Kept the production Yandex placements (`R-M-20038632-1` banner and `R-M-20038632-2` interstitial) in the RuStore profile; the demo-ad feature remains isolated to its QA profile.
- Connected RuStore Pay `get_products([remove_ads])` and now show the remove-ads action only after the SDK returns a non-consumable product title and formatted price. The button combines those two SDK fields; it no longer substitutes a hard-coded label/amount on Android.
- Retained one-step purchase and entitlement restoration through `get_purchases()`, granting/persisting `ads_removed` only for a confirmed `remove_ads` non-consumable purchase. No purchase was invoked.
- Updated the Android RuStore release preset to versionCode 3 / versionName 1.0.2 and an explicit release artifact path.
- Full `tests/run_tests.gd` passed, including the SDK title+price button contract; Godot reported existing ObjectDB/resource-leak warnings at shutdown.

### 2026-09-29 — Signed RuStore release candidate

- Exported signed `builds/clown-smash-rustore-release.aab` using the existing Android release keystore from the local signing directory; Godot signing inputs were supplied through process-scoped environment variables, not saved in `export_presets.cfg`.
- Verified the AAB JAR signature and confirmed its SHA-256 signing-certificate fingerprint matches the release certificate in the signing bundle. The artifact is versionCode 3 / versionName 1.0.2 per the release preset.
- Cabinet upload, real billing transaction, purchase restoration against RuStore, live ad fill, and moderation remain unverified; no store upload or publication was performed.

### 2026-09-29 — RuStore startup splash screenshot

- Captured and visually inspected the rendered Russian `StartupSplash` scene at `promotion/rustore_2026-09-29/startup_splash_ru_1080x1920.png` (1080×1920, 9:16, 2,789,022 bytes / 2.66 MiB). It fits RuStore phone screenshot dimensions and size limits as a supplemental image; it does not replace gameplay screenshots.

### 2026-10-01 — Locked-level icons, complete pause, miss haptics

- Replaced the locked-level text with `assets/ui/level_lock.svg`, retaining level numbers and disabled buttons. Rendered and visually reviewed `verification/level_select_lock_2026-10-01.png` at 540x960.
- Made clown visibility/cooldown and delayed double-spawn timers pause with SceneTree. Music and all SFX players explicitly use PAUSABLE processing so playback pauses and resumes with the game.
- Added a 65 ms haptic pulse for empty-box strikes and escaped scoring clowns; respects the existing haptics setting and mobile feature gate. Android export profiles already include VIBRATE permission.
- Import check, full `tests/run_tests.gd`, smoke test, and diff whitespace check passed. Added a regression covering a pause longer than the clown visibility window, frozen animation/time, and paused music/SFX players.
- ADB device inventory was empty. Updated APK/device playback and physical vibration validation remain unverified; no install or store action performed.

### 2026-10-01 — VK purchase immediately refreshes offer buttons

- Reproduced the stale menu offer with a regression: entitlement_changed supplied one argument to a zero-argument refresh handler, causing a Godot runtime error.
- Main menu and session overlay refresh handlers now accept the entitlement signal argument while retaining no-argument catalog/manual refresh calls. Verified purchase immediately hides both buttons without page reload.
- Full Godot tests, scene smoke test, VK bridge tests, release Web export and Dev package ValidateOnly passed. Prepared builds/vk-dev-purchase-refresh-2026-10-01/clown-smash-vk-dev-purchase-refresh-2026-10-01.zip; hosting upload and live verification of this build remain pending.


### 2026-10-01 — Odnoklassniki adaptation and server progress

- Detect `vk_client=ok` through VK Bridge initialization; keep the existing VK ad gate,
  but OK levels remain playable when inventory is unavailable or the ad fails.
- Added VK/OK backend progress under `/vk/payments/progress`, authenticated using signed
  launch parameters. SQLite keys include social network, app ID and user ID; achievements
  merge monotonically across devices. Local save filenames use the same identity.
  Unknown-owner old VK saves are not silently migrated. Offline progress is retained
  locally and synchronization retries after 30 seconds of active processing.
- Added VK Bridge hide/restore and document visibility handling for platform pause/audio,
  and a visible Web startup error message instead of a silent blank screen.
- Implemented OK checkout from the two user-supplied official VK PDF specifications:
  POST get_item on the VK callback chooses the configured price in OKs; signed GET
  callbacks.payment on `/ok/payments/callback/test` or `/live` commits an idempotent
  order before returning JSON true. Errors include Invocation-error. Separate OK ledger
  isolates VK and test/live rights; invalid signatures, prices, products and users fail.
  The client polls server entitlement after OK mobile SDK completion and never grants
  from the SDK response alone. A legacy VK-only server cannot supply OK entitlements.
- Added local refund recording after confirmed official refundUserPayment success;
  no unauthenticated administrative HTTP endpoint. Automatic refund reconciliation and
  subscriptions are outside this change. Refund tombstones survive late payment retries.
- OK checkout remains hidden until OK_APP_ID, OK_APP_PUBLIC_KEY, OK_PAYMENT_MODE and
  an explicit OK_REMOVE_ADS_PRICE are configured. Shared/separate callback secret remains
  server-only. README and .env.example describe both callback URLs and proxy routing.
- Verification: Godot import, full run_tests.gd, smoke_test.gd, VK/OK/Yandex bridge
  contracts and 12 server tests passed. Prepared Web/server artifacts under
  builds/ok-adaptation-2026-10-01. Existing uncommitted changes were preserved.
- Not performed: VPS deployment, real OK account launch/signature verification, sandbox
  payment, two physical device synchronization, current cabinet setup and moderation.
  Therefore local implementation/build evidence does not prove readiness for publication.


### 2026-10-01 — VPS server updated for OK / VK progress

- Connected to the user-authorized VPS 77.221.132.70:2313 and inspected the actual
  multi-game deployment. Updated only the active vk-shop@circusrucus instance code
  under /opt/vk-shop and the existing game's nginx virtual host.
- Backed up prior server/test source, nginx configuration, protected environment and
  the stopped instance's SQLite to /root/clown-ok-update-pBLjQAQU/backup.
- Ran 13 tests on the VPS: 12 updated server tests plus its existing multi-game
  isolation regression. All passed before service replacement.
- Preserved /etc/vk-shop/games/circusrucus.env and the configured test payment mode.
  Added only /games/circusrucus/ok/payments/ proxy routing; access_log is disabled
  for payment callback routes. nginx -t passed before reload.
- Restarted vk-shop@circusrucus.service and verified signed read-only HTTPS requests
  to catalog, entitlements and progress return HTTP 200. New OK callback path routes
  correctly and rejects unconfigured payments with Invocation-error 1001.
- Database /var/lib/vk-shop-circusrucus/payments.sqlite retained its existing one VK
  order; progress/ok_orders tables are present and SQLite quick_check returned ok.
  Source SHA-256 matches local server.mjs exactly:
  f3752979177f19ffe19786043a87c4b47a0faf2041b3490fe48e3ee4a542e53b.
- nginx, Docker and amnezia-peer-stats-web remain active. VPN client connectivity was
  not tested; no VPN, firewall, SSH or unrelated service configuration was changed.
- Still pending: OK app ID/public key/price/payment mode settings, OK cabinet callback
  URLs, sandbox and real device tests. Web game hosting was not updated by this VPS
  server deployment. No credentials were written to repository files or release ZIPs.

### 2026-10-01 — payment runtime configuration
- Backed up the protected VPS environment to /root/clown-payment-config-20261001-223146.
- Set VK_PAYMENT_MODE=live and OK_APP_ID=512005436129; restarted only vk-shop@circusrucus.
- Signed HTTPS catalog checks returned 200: VK mode live, price 14 votes; OK empty catalog because public key, price and payment mode remain unconfigured.
- VK cabinet test setting was not changed. OK purchase activation awaits public key and pricing decision; dynamic conversion has not been implemented.

### 2026-10-01 — OK price
- User-selected remove_ads price set to 80 OKs on VPS (OK_REMOVE_ADS_PRICE=80).
- Protected backup: /root/clown-ok-price-20261001-224309; instance restarted and active; configuration readback confirms price 80 and app ID 512005436129.
- OK checkout remains disabled: public key and payment mode are not configured.

### 2026-10-01 — OK live activation
- Configured user-provided OK public key and OK_PAYMENT_MODE=live on VPS; protected backup /root/clown-ok-live-20261001-224518.
- Instance active. Initial immediate request during restart returned 502; repeat after startup passed.
- Signed external HTTPS catalog and entitlements both return 200 for VK and OK; OK catalogue is remove_ads, 80 OKs, live. VK remains 14 votes, live.
- OK callback verification currently uses shared VK secret fallback. A real platform payment and cabinet callback configuration remain unverified; if OK secret differs it must be configured privately on VPS.

### 2026-10-02 — Live VK/OK monetization QA and OK launch authentication fix

- Chrome/Playwright confirmed the hosted Dev version was stale: no OK bridge and the pre-fix menu signal handler. Uploaded approved current Dev build to stage-app54768735-32aeda9fd118.pages.vk-apps.ru (hosting version 1790969982).
- Reproduced OK HTTP 401 with genuine signed launch parameters. Fixed validation of the VK/OK app ID pair, millisecond OK timestamp and OK entitlement lookup using signed vk_ok_user_id. Preserved signature checking, expiry and legacy launch format. Added a regression; 14 server tests pass. Compared VPS source before patch, created backup, deployed and restarted only circusrucus payment service. Real OK iframe now returns HTTP 200 verified entitlement/catalog.
- VK sandbox purchase completed with explicit user approval: signed order_status_change_test accepted, immediate menu-button disappearance and banner removal captured in verification/vk-after-purchase-2026-10-02.png. Reloaded game restores verified test entitlement. SDK instrumentation after purchase recorded only HideBannerAd; level-start ad bypass is covered by automated tests. Test order retained separately from live.
- Real banner visible in VK before purchase. Provider interstitial creatives visibly rendered in both VK and OK (verification/vk-fullscreen-ad-2026-10-02.png and ok-ads-2026-10-02.png). Completion callbacks timed out while Chrome reported hidden; do not claim completed viewing. OK banner returned SDK No ads.
- OK offer returns 80 OKs, checkout opens and cancellation leaves rights unowned. Successful OK payment/restoration remain unverified: platform checkout did not identify sandbox, balance is zero; developer settings require account two-factor authentication. No real payment or account-security change performed.
- OK still launched the previous hosting URL after Dev upload; tested the new build temporarily inside the genuine OK container using unchanged signed launch parameters. Automatic OK hosting propagation remains to be verified.
- Restored VK/OK payment modes to live and OK cabinet callback to /ok/payments/callback/live; other VPS services were not changed. Full Godot tests, import, smoke, VK/OK bridge tests, release Web export and Dev package validation passed.

### 2026-10-03 — Background music loudness alignment

- Processed both runtime background OGG files with two-pass loudness normalization at -18 LUFS / -1.5 dBTP, limiting loudness range to 5 LU, followed by measured gain correction. Final integrated loudness: fon1 -17.95 LUFS, fon2 -18.00 LUFS; true peaks -4.26 / -8.01 dBTP.
- Reduced fon1 loudness swings (original LRA 11.1 LU); retained existing resource paths and music selection behavior. SFX unchanged.
- Original OGG backups and before/after measurements: `verification/music_loudness_2026-10-03/`.
- FFmpeg decoded and measured both complete outputs; Godot import passed. No physical-device listening verification performed.

### 2026-10-03 — Life penalty for three consecutive misses

- Empty-box strikes and escaped Normal/Fast/Golden share a consecutive-miss counter. Every third miss removes exactly one life and clears the counter; zero lives ends the level.
- Any clown hit clears the streak. Ignored non-scoring clowns leave it unchanged; paused input does not count; new/restarted levels clear it. Existing scoring, combo and Bomb rules retained.
- Added localized third-miss feedback and synchronized SPEC.md / AGENTS.md with the user-authorized rule change.
- Godot import, full tests/run_tests.gd (new mixed-miss, reset, pause, restart, and nine-miss loss coverage), and smoke_test.gd passed.

### 2026-10-03 — Ordinary feedback for bonus misses

- Empty strikes while Clock/Glutton are visible show the standard MISS feedback; removed the special BONUS_MISSED presentation. Bonus escape feedback also uses MISS instead of bonus-specific captions.
- Retained duplicate escape-label suppression and existing life/miss-counter rules.
- Verification: Godot import, full tests/run_tests.gd (including duplicate bonus escape-label suppression), and diff whitespace checks passed.

### 2026-10-03 — Signed Android 1.0.3 release and phone installation

- Advanced Android - RuStore Release Ads to versionCode 4 / versionName 1.0.3. Built signed `builds/clown-smash-rustore-1.0.3-release.aab` and matching release APK using the existing signing key; no credentials persisted in the project.
- AAB JAR verification and APK apksigner verification passed, with the existing AB:D1:5F:11... certificate. APK identity is ru.mkulkov.circusruckus, ARM64, minSdk 24 / targetSdk 36.
- Installed the release APK successfully on Infinix X663 (07589251CL001154). Cold launch succeeded, process remained alive, version and VIBRATE grant confirmed; sampled logcat had no FATAL EXCEPTION, SCRIPT ERROR, Parse Error or SIGSEGV. Device screenshot captured under verification/android_release_2026-10-03.
- Full project tests passed. Both Godot exports reported DONE and created valid signed artifacts but lingered afterward; their specific export processes were terminated after completion. Restored the AAB export format after temporary APK export.
- Deleted three older/generated Android packages within this project after successful installation; only the new release AAB/APK remain. Deletion manifest and new SHA-256 hashes are in verification/android_release_2026-10-03.
- No store upload performed. This verifies packaging/install/startup, not physical haptic feel, complete gameplay/audio QA, or live purchases/ads.
