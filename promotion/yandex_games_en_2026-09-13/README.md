# Yandex Games English localization media

Prepared on 13 September 2026 for the English localization of **Circus Mayhem**.

## Upload-ready files

| Console field | File | Verified specification |
| --- | --- | --- |
| Vertical gameplay video | `video/gameplay_vertical_en_1080x1920.mp4` | MP4, H.264/AAC, 1080×1920, 9:16, 26.6 s |
| Horizontal gameplay video | `video/gameplay_horizontal_en_1920x1080.mp4` | MP4, H.264/AAC, 1920×1080, 16:9, 26.6 s |
| Mobile screenshot | `screenshots/mobile/gameplay_hammer_impact_en_1440x2560.jpg` | JPEG, 1440×2560, 9:16 |
| Mobile screenshot | `screenshots/mobile/gameplay_specials_en_1440x2560.jpg` | JPEG, 1440×2560, 9:16 |
| Desktop screenshot | `screenshots/desktop/gameplay_hammer_impact_en_2560x1440.jpg` | JPEG, 2560×1440, 16:9 |
| Desktop screenshot | `screenshots/desktop/gameplay_specials_en_2560x1440.jpg` | JPEG, 2560×1440, 16:9 |

All upload-ready materials show the English in-game HUD. The videos are continuous rendered gameplay with real scene animation, character appearances, hammer strikes, score/combo changes, sound effects, and music. The horizontal video keeps the full portrait playfield undistorted over a blurred background derived from the same live gameplay.

The desktop screenshots are full-frame 16:9 crops of actual gameplay. The mobile screenshots show the complete portrait playfield. No external UI, third-party logos, or Russian text is present in the upload-ready files.

## Current Yandex Games limits checked

- Video: MP4, vertical 9:16 or horizontal 16:9, at least 400 px high, no more than 28 seconds, no more than 100 MB.
- Screenshots: JPEG or 24-bit PNG, portrait 9:16 or landscape 16:9, long side from 1280 to 2560 px.
- At least two screenshots are required for every selected platform (Mobile and Desktop).
- Screenshots must show real gameplay occupying at least 70% of the image; ordinary gameplay videos must show real gameplay for at least 70% of their duration.
- The localized game title must match the title shown in the game and promotional materials.

Official sources checked on 13 September 2026:

- <https://yandex.ru/dev/games/doc/ru/console/add-new-game/draft>
- <https://yandex.ru/dev/games/doc/ru/concepts/requirements>

## QA and reproducibility

- `video/vertical_contact_sheet.jpg` and `video/horizontal_contact_sheet.jpg` are review sheets, not upload files.
- `tools/capture_en_gameplay.gd` is the deterministic Godot capture script used for the video.
- PNG files without the `_en_` suffix are intermediate lossless screenshot sources and should not be uploaded.

