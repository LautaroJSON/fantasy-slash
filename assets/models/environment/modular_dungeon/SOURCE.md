# Modular Dungeons Pack (Quaternius)

- **Autor:** Quaternius ([quaternius.com](https://quaternius.com/packs/modulardungeon.html)).
- **Licencia:** CC0 1.0 (dominio público).
- **Origen de los archivos:** los `.glb` individuales publicados en Poly Pizza ([bundle](https://poly.pizza/bundle/Modular-Dungeons-Pack-HaFPqhAp3w)). Descargados el 2026-09-29.
- **Usado por:** las ruinas del Mar de Flores (`docs/specs/stages.md` §3.3).

| Malla del juego (`meshes/`) | Modelo original | Página | Archivo fuente |
|---|---|---|---|
| `column_a.res` | Column (Column2) | `https://poly.pizza/m/wLubNpOTX4` | `column_11.glb` |
| `column_b.res` | Column | `https://poly.pizza/m/6y1EFzpRI9` | `column_12.glb` |
| `arch.res` | Arch | `https://poly.pizza/m/QwWdOcNIMh` | `arch_22.glb` |

## Cambios respecto del original

Mallas derivadas con `../stylized_nature/tools/extract_environment_assets.gd`: la geometría como `ArrayMesh` estática con la escala de sus nodos aplicada (el original viene en centímetros con escala ×100) y sin materiales; los colores planos del original se reemplazan por la piedra clara y el musgo de `materials/environment/` (ver `stages.md` §3.5). Para regenerar, poner los `.glb` en `<fuente>/modular_dungeon/` y seguir el `SOURCE.md` de `stylized_nature`.
