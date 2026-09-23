# Bilingual horizontal gameplay collages

Six 16:9 JPEG collages for the Russian and English localizations of Clown Smash.

Each collage is 2560x1440 and contains three complete vertical runtime captures at their original 9:16 framing. The Russian first collage contains the Russian startup splash, and the English first collage contains the English startup splash. Their other panels, and all panels in the other four collages, are distinct frames from the matching localized gameplay recordings. No vertical image is reused anywhere in the set.

## Files

| Locale | File | Gameplay panels after splash |
| --- | --- | --- |
| Russian | `ru/collage_01_ru_2560x1440.jpg` | Russian startup splash, two unique gameplay frames |
| Russian | `ru/collage_02_ru_2560x1440.jpg` | Three unique gameplay frames |
| Russian | `ru/collage_03_ru_2560x1440.jpg` | Three unique gameplay frames |
| English | `en/collage_01_en_2560x1440.jpg` | English startup splash, two unique gameplay frames |
| English | `en/collage_02_en_2560x1440.jpg` | Three unique gameplay frames |
| English | `en/collage_03_en_2560x1440.jpg` | Three unique gameplay frames |

The contact sheet `contact_sheet_1280x1080.jpg` is a review aid, not a delivery collage.

## Sources and verification

The two splash sources are the visible Compatibility-renderer Russian and English portrait captures in `promotion/yandex_games_desktop_bilingual_2026-09-13/portrait_sources/`. The 16 unique gameplay sources are extracted into `sources/` from the current localized runtime recordings. No game art or runtime UI was modified. Each JPEG was checked with FFprobe as 2560x1440, 16:9, and `yuvj420p`; the complete set was visually reviewed using the contact sheet.
