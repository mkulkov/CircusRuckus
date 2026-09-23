# Bilingual horizontal gameplay videos

Two new 16:9 localized gameplay videos for Clown Smash.

| Locale | File | Content |
| --- | --- | --- |
| Russian | `gameplay_horizontal_ru_1920x1080.mp4` | Russian startup splash, followed by Russian gameplay |
| English | `gameplay_horizontal_en_1920x1080.mp4` | English startup splash, followed by English gameplay |

Both files are 26.266667 seconds, 1920x1080, 60 FPS H.264 video with AAC audio. The opening 1.5 seconds use the matching localized in-game splash. The rest is continuous gameplay from the corresponding localized runtime recording. Portrait gameplay remains uniformly scaled and centered over a blurred, darkened derivative of the same frame; no source pixels are cropped or stretched.

`ru_contact_sheet_1448x548.jpg`, `en_contact_sheet_1448x548.jpg`, and `bilingual_contact_sheet.jpg` are visual review aids. `splash_frames_comparison_1920x540.jpg` confirms the localized title cards.

Verification: FFprobe confirmed H.264/AAC, 1920x1080, 60 FPS and 26.266667-second duration for both outputs. Both MP4 files completed a full FFmpeg decode, and their title cards and gameplay contact sheets were visually inspected.
