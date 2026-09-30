# sbs_cloudy_sky_04

- **Origen:** "Cloudy Skyboxes" de Screaming Brain Studios en OpenGameArt (`https://opengameart.org/content/cloudy-skyboxes-0`). Se bajó `sbs_-_cloudy_skyboxes_-_panorama.zip` (28.6 MB) el 2026-09-29 y de ahí se usó solo `Panorama/Panorama_Sky_04-512x512.png` (el resto del pack no está en el repo).
- **Licencia:** CC0 1.0 (dominio público): "free to use in any and all projects, commercial or non-commercial, with no restrictions". Texto del autor en `License.txt`.
- **Resolución:** 2048 × 1024, PNG equirectangular 2:1.
- **Uso:** `PanoramaSkyMaterial` en el `Environment` de `data/stages/mar_de_flores/mar_de_flores_lighting.tres` (ver `docs/specs/stage-lighting-sky.md`). Solo lo referencia ese `Environment`. La imagen trae el sol pintado en (u = 0.754, v = 0.352), azimut +91.4° y unos 27° de elevación; `sky_yaw_offset_deg` lo alinea con el sol del juego y el sol del stage baja a −30° de pitch para coincidir. Por eso el cielo no gira (`sky_rotation_speed_deg = 0`): el sol pintado se movería respecto de la luz.
- **Colores:** el cielo es fondo, no un elemento del mundo: no cuenta para la tabla de `docs/color-registry.md`.
