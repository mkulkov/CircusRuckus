# Platform language detection

Checked on 2026-09-12.

The game supports `ru` and `en`; every other locale falls back to Russian. Detection is performed by `LocalizationManager` before the first game screen is instantiated.

## Yandex Games

The `Web - Yandex Games` export loads `/sdk.js`. A shared platform bridge initializes the SDK once; localization reads `ysdk.environment.i18n.lang` from that shared instance, as required by Yandex Games.

Official documentation: <https://yandex.ru/dev/games/doc/ru/requirements/2/14>

Verify both languages with the Yandex Games debug panel and SDK mocks before publication.

## VK Mini Apps

VK supplies launch parameters in the Mini App URL. The game reads `vk_language` from `window.location.search` before it creates the first screen. This matches the official VK Bridge launch-parameter parser contract.

Official sources:

- <https://dev.vk.ru/mini-apps/development/launch-params>
- <https://github.com/VKCOM/vk-bridge#functions>

Verify launches with `vk_language=ru` and `vk_language=en` in the VK developer environment before publication.

## RuStore / Android

RuStore does not expose a store-specific UI-language API for the running game. The Android build uses the device locale reported by Godot (`OS.get_locale_language()`), matching Android's standard locale-based resource selection model.

Official sources:

- <https://developer.android.com/guide/topics/resources/localization>
- <https://www.rustore.ru/help/sdk>

Verify Russian, English, and an unsupported device language on a RuStore-installed build before publication.
