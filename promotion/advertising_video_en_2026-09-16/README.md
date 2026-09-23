# Circus Ruckus advertising video

Delivery file:

- `clown_smash_ad_en_vertical_1080x1920_15s.mp4`
- H.264 High / AAC stereo
- 1080×1920, 9:16, 60 FPS
- 15.00 seconds
- 9.82 MB

The video reproduces the approved Russian advertising edit with localized English sources: the current English gameplay recording, English splash screen, English gameplay screenshots and English advertising captions. The sequence, music, timing and circus-panel caption styling are unchanged.

Caption copy:

- `READY TO SMASH?`
- `PICK YOUR TARGET!`
- `EVERY CLOWN HAS A SURPRISE!`
- `BUILD YOUR COMBO!`
- `PICK YOUR TARGET. BUILD YOUR COMBO.`
- `PLAY NOW!`

`ad_filter_en.ffscript` contains the reproducible FFmpeg edit. `final_contact_sheet.jpg` and `source_timeline_contact_sheet.jpg` are visual-review aids, not delivery files.

Verified:

- complete FFmpeg decode without errors;
- exact 15.000-second duration;
- 1080×1920, H.264, 60 FPS, `yuv420p`, limited range;
- AAC, 48 kHz, stereo;
- full-resolution caption frames and the final one-second contact sheet were visually reviewed;
- SHA-256: `50B48FE6FD6BF475697D0ADC9DF7EB2709D8AEDDDEB4C40F9E80C14E9AEF4090`.
