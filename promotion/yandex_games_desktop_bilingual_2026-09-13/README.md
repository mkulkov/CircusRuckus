# Yandex Games 16:9 presentation screenshots — Russian and English

Prepared on 13 September 2026 from visible Godot 4.7.2 Compatibility/OpenGL runtime captures.

## Files

| Locale | File | Scene |
| --- | --- | --- |
| Russian | `screenshots/ru/01_gameplay_ru_2560x1440.jpg` | Normal target during an active round |
| Russian | `screenshots/ru/02_hammer_impact_ru_2560x1440.jpg` | Hammer impact and +10 score feedback |
| Russian | `screenshots/ru/03_special_clowns_ru_2560x1440.jpg` | Fast, Golden and Bomb character showcase |
| Russian | `screenshots/ru/04_startup_splash_ru_2560x1440.jpg` | Localized startup splash |
| English | `screenshots/en/01_gameplay_en_2560x1440.jpg` | Normal target during an active round |
| English | `screenshots/en/02_hammer_impact_en_2560x1440.jpg` | Hammer impact and +10 score feedback |
| English | `screenshots/en/03_special_clowns_en_2560x1440.jpg` | Fast, Golden and Bomb character showcase |
| English | `screenshots/en/04_startup_splash_en_2560x1440.jpg` | Localized startup splash |

Every file is a 2560×1440 RGB JPEG in 16:9 landscape orientation. The paired Russian and English images use matching gameplay states and framing. No browser chrome, external UI, third-party logo, or synthetic poster content is included.

The complete 1440×2560 portrait runtime image is preserved without cropping or non-uniform stretching: it is uniformly scaled to 810×1440 and centered. The surrounding area is a blurred, darkened presentation backdrop produced from the same source image. It is not part of the source screen and does not hide or replace any source pixels.

The lossless runtime captures used to prepare the upload files are retained in `portrait_sources/`. The direct landscape diagnostic captures in `sources/` are evidence only and are not intended for upload.

## Yandex Games publication note

The current Yandex Games draft instructions were checked on 13 September 2026:

- desktop screenshots must be landscape 16:9;
- the long side must be between 1280 and 2560 pixels;
- JPEG or 24-bit PNG is accepted;
- at least two screenshots are required for each selected platform;
- screenshots must demonstrate actual gameplay occupying at least 70% of the image.

These no-crop presentation files satisfy the geometry and format requirements, but the unaltered foreground screen occupies 31.6% of a 16:9 frame. They should therefore not be represented as automatically compliant with the 70% gameplay-area rule. A genuinely responsive landscape game screen is required for unambiguous Desktop-gallery compliance; that would be a product/UI change rather than a media conversion.

Official sources:

- <https://yandex.ru/dev/games/doc/ru/console/add-new-game/draft>
- <https://yandex.ru/dev/games/doc/ru/concepts/requirements>
