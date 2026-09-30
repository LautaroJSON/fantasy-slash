# Castle Kit (Kenney)

- **Autor:** Kenney ([kenney.nl](https://kenney.nl/assets/castle-kit)), versión de 2024.
- **Licencia:** CC0 1.0 (dominio público). Ver `License.txt` del zip original.
- **Origen:** `https://kenney.nl/media/pages/assets/castle-kit/a395102d20-1711543616/kenney_castle-kit.zip`, carpeta `Models/GLB format/`. Descargado el 2026-09-29.
- **Usado por:** el castillo lejano del Mar de Flores (`levels/stages/props/distant_castle.tscn`, `docs/specs/stages.md` §3.3).

## Archivos

- `meshes/*.res`: `tower-hexagon-base`, `tower-hexagon-mid`, `tower-hexagon-roof`, `tower-square-base`, `tower-square-mid`, `tower-square-mid-windows`, `tower-square-roof`, `tower-square-top-roof-high`, `wall`, `wall-pillar`, `gate` y `flag-pennant` (los guiones pasan a guion bajo).
- `textures/colormap.png`: la paleta compartida del kit, sin cambios (`Textures/colormap.png` del zip).

## Cambios respecto del original

Mallas derivadas con `../stylized_nature/tools/extract_environment_assets.gd`: geometría como `ArrayMesh` estática, sin materiales. La paleta se aplica con `materials/environment/castle_material.tres`. Para regenerar, poner los `.glb` en `<fuente>/castle_kit/` y `colormap.png` en `<fuente>/castle_kit/Textures/`, y seguir el `SOURCE.md` de `stylized_nature`.
