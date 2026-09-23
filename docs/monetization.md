# Монетизация

Игра использует единый `MonetizationService` и выбирает адаптер по export-feature:

- `yandex_games` / `vk_mini_apps` — web JavaScript bridge из `web/portrait_shell.html`;
- Android — `RuStoreMonetizationAdapter` и RuStore Pay SDK 11.1.0; Yandex Mobile Ads 7.18.3 остаётся необязательным плагином и не включается в текущий RuStore AAB;
- редактор и автоматические тесты — детерминированный `DebugMonetizationAdapter` без выдачи entitlement.

## Поведение игры

- sticky-баннер запрашивается снизу экрана после инициализации платформы;
- полноэкранная реклама запрашивается перед уровнями 2–9, но не перед первым;
- кнопка `ОТКЛЮЧИТЬ РЕКЛАМУ` добавлена в главное меню и игровые overlay-экраны для сборок с покупками; production-пресет `Web - Yandex Games` снова включает объявленный товар `remove_ads`;
- цена и код портальной валюты для `remove_ads` загружаются из `payments.getCatalog()` и показываются на кнопке без графической иконки; до получения каталога предложение в Яндекс-сборке скрыто, чтобы не показывать покупку без обязательных данных SDK;
- после подтвержденной покупки сохраняется `ads_removed`, баннер скрывается, реклама и кнопки больше не показываются;
- восстановление постоянной покупки выполняется при старте.
- `LoadingAPI.ready()` вызывается один раз после появления доступного игроку главного меню;
- `GameplayAPI.start()` вызывается только при переходе уровня в `RUNNING`; `GameplayAPI.stop()` — на countdown, пользовательской паузе, результате, переходе в меню и перед рекламным запросом;
- события `game_api_pause` / `game_api_resume` приостанавливают только активный раунд и все аудиошины, а затем восстанавливают только автоматически приостановленное состояние;
- SDK инициализируется единожды через общий Promise платформенного bridge; локализация, реклама, lifecycle и облачные сохранения используют тот же `ysdk`;
- прогресс гостевых и авторизованных игроков синхронизируется через `ysdk.getPlayer()` и `player.getData()/setData(..., true)` с локальным fallback и монотонным объединением достижений;
- музыка и звуки временно отключаются между `onOpen` и завершающим callback полноэкранной рекламы, затем восстанавливается прежнее состояние аудио.
- перед запросом sticky-баннера вызывается `getBannerAdvStatus()`; статус показа и причины `ADV_IS_NOT_CONNECTED`/`UNKNOWN` выводятся в консоль debug-панели Яндекса.

## Проверочная сборка без реальных списаний

Export-feature `monetization_demo` включает явно маркированный тестовый сценарий:

- жёлтый баннер занимает нижний sticky-слот и блокирует касания в своей области;
- перед запуском уровней 2–9 показывается четырёхсекундный ролик `assets/video/demo_ad_4s.ogv`; уровень 1 всегда свободен от внутриигрового interstitial;
- кнопка `ОТКЛЮЧИТЬ РЕКЛАМУ` завершает виртуальную покупку успешно, без обращения к магазину;
- право `ads_removed` сохраняется тем же `SaveManager`, что и production-право;
- после покупки и после перезапуска баннер, видео и кнопка не показываются.

Готовые пресеты: `Android - Monetization Demo`, `Web - Yandex Monetization Demo` и `Web - VK Monetization Demo`. Они проверяют общий игровой контракт и размещение, но не подтверждают доступность рекламного инвентаря, реальные callback SDK или платежи площадки.

## Перед публикацией

1. Яндекс Игры: production-архив включает постоянный товар `remove_ads`. В Консоли должен оставаться активный товар с точно таким ID; перед повторной модерацией нужно проверить через debug-панель каталог, смену mock-валюты, успешную покупку, исчезновение всей внутриигровой рекламы и восстановление права после перезапуска/на другом устройстве.
2. VK Mini Apps: подключить текущий VK Bridge, зарегистрировать рекламные блоки и согласовать платёжный контракт/товар. В текущем bridge-слое VK-покупка намеренно не имитируется: нужны выданные VK `app_id`/товар/сообщество и подтвержденный способ оплаты.
3. RuStore: в проект уже добавлены официальные `RuStoreGodotPay`/`RuStoreGodotCore` 11.1.0. В `android/build/res/values/rustore_values.xml` заменить `0` на числовой ID приложения из RuStore Console и зарегистрировать non-consumable товар `remove_ads`. Необязательный Android-плагин Yandex Mobile Ads 7.18.3 хранится в проекте, но отключён и исключён из текущего RuStore AAB; его идентификаторы в `project.godot` нужны только для отдельной сборки с рекламой. BillingClient не используется.
4. На вкладке **Реклама** в Консоли Яндекс Игр включить sticky-баннер для мобильной портретной ориентации **Внизу** и включить **Использовать API для показа sticky-баннера**. Для десктопа отдельно включить sticky-баннер на десктопе. В debug-консоли проверить строку `[ClownSmash][Ads] Sticky banner visible=true reason=`; `ADV_IS_NOT_CONNECTED` означает, что баннер не подключён в кабинете.
5. Проверить test users/sandbox, privacy/age/consent и модерацию каждой площадки.

Яндекс автоматически показывает собственную полноэкранную рекламу на старте всех игр. У неё нет callback-функций `showFullscreenAdv()`, и она обрабатывается через `game_api_pause` / `game_api_resume`. Игра сама никогда не запрашивает interstitial для уровня 1; запросы `showFullscreenAdv()` начинаются только с уровня 2.

## Документация, повторно проверенная 2026-09-15

- https://yandex.ru/dev/games/doc/ru/sdk/sdk-adv
- https://yandex.ru/dev/games/doc/ru/sdk/sdk-game-events
- https://yandex.ru/dev/games/doc/ru/sdk/sdk-events
- https://yandex.ru/dev/games/doc/ru/sdk/sdk-player
- https://yandex.ru/dev/games/doc/ru/sdk/sdk-purchases
- https://yandex.ru/dev/games/doc/ru/sdk/sdk-about
- https://www.rustore.ru/help/en/sdk/pay
- https://www.rustore.ru/help/sdk/pay/godot
- https://www.rustore.ru/help/sdk/pay/godot/history
- https://gitflic.ru/project/rustore/rustore-godot-pay
- https://yandex.com/dev/mobile-ads/index/
- https://github.com/noctisalamandra/godot-yandex-ads-android
- https://github.com/VKCOM/vk-bridge

Editor/headless checks cannot prove live ad inventory, payment completion, purchase restoration across accounts/devices, VK moderation, or RuStore Android plugin behavior.
