# Ticket HUD art — preview assets

Generated with built-in image_gen, 2026-10-09. Not connected to gameplay.

hud_tickets_ru_v1.png is a 1536x1024 RGBA sprite sheet with eight separate elements: time, level, score, series, misses, gold objective, lives holder, pause. Static captions and decorative icons are baked in. Dynamic numeric values and life hammers remain runtime overlays; existing hammer art can be reused. The progress track is baked, its fill is dynamic. Printed captions are Russian; other locales need separate artwork or text-free variants.

Alpha checked: outside corner and gutters alpha=0; ticket interiors alpha=253-254. The brown RGB under fully transparent pixels is not a visible background in an alpha-aware renderer.

Final prompt: Remove all brown background from the eight-sprite sheet; preserve ivory tickets, printed Cyrillic text, clock, gold star and pause bars; keep dynamic fields blank; deliver transparent RGBA gutters and sharp sprite edges.

Series revision: hud_series_v2.png replaces series region only. Generated with built-in image_gen; prompt: single 6:1 ticket in existing ivory/red/gold style, baked СЕРИЯ with normal serif proportions and balanced vertical whitespace, right numeric area blank, transparent RGBA background. Original atlas preserved.
