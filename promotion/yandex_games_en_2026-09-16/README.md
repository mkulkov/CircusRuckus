# English videos for Yandex Games moderation

Prepared on 16 September 2026 as the English-language equivalent of the Russian video package from the same date.

## Upload-ready files

| Console field | File | Verified specification |
| --- | --- | --- |
| Vertical video `[en]` | `video/gameplay_vertical_en_1080x1920.mp4` | H.264/AAC, 1080x1920, 9:16, 60 FPS, 26.27 s, 13.19 MB |
| Horizontal video `[en]` | `video/gameplay_horizontal_en_1920x1080.mp4` | H.264/AAC, 1920x1080, 16:9, 60 FPS, 26.27 s, 8.72 MB |

Both videos come from one fresh continuous render of real gameplay. All meaningful on-screen text is English; there is no operating-system UI, Yandex Games UI, or purchase button. The horizontal version preserves the complete portrait playfield without cropping and uses a blurred background derived from the same video stream.

`video/raw/gameplay_en_540x960.avi` is the reproducible Godot Movie Maker source, not an upload file. The deterministic capture script is `tools/capture_en_gameplay.gd`. Contact sheets are for visual review only.

## Verification

- both MP4 files fully decode through FFmpeg without errors;
- duration is below 28 seconds;
- video is H.264 at 60 FPS and audio is AAC 48 kHz stereo;
- both contact sheets were visually reviewed for English HUD text, readable gameplay, full portrait framing, and absence of Russian text;
- vertical video SHA-256: `07D8C5BD7F7ED8EAABEFCF0F87C7202EEC869D2E2056373FBFBAD414C2937917`;
- horizontal video SHA-256: `8140325D7E13428897EF89629C9FF4FCE9EBC41EBD60C3C49492EA0C43FD0C3D`.

The matching current Russian package is `promotion/yandex_games_ru_2026-09-16/`.
