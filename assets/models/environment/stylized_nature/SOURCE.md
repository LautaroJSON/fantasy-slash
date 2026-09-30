# Stylized Nature MegaKit (Quaternius)

- **Autor:** Quaternius ([quaternius.com](https://quaternius.com/packs/stylizednaturemegakit.html)).
- **Licencia:** CC0 1.0 (dominio público). Sin atribución obligatoria; se acredita igual.
- **Origen de los archivos:** los `.glb` individuales de la versión gratuita, publicados por el autor en Poly Pizza ([bundle](https://poly.pizza/bundle/Stylized-Nature-MegaKit-T34GZFA0fm)). Descargados el 2026-09-29.
- **Usado por:** el Mar de Flores (`docs/specs/stages.md` §3.3), vía las escenas adaptadoras de `levels/stages/props/` y el scatter del mapa.

## Modelos usados

| Malla del juego (`meshes/`) | Modelo original | Página en Poly Pizza |
|---|---|---|
| `tree_a.res` | Tree (CommonTree_3) | `https://poly.pizza/m/QVOop92WmG` |
| `tree_b.res` | Tree (CommonTree_4) | `https://poly.pizza/m/YWjGDJ9F7g` |
| `tree_c.res` | Tree (CommonTree_2) | `https://poly.pizza/m/aVOxaHRPWe` |
| `tree_d.res` | Tree (CommonTree_1) | `https://poly.pizza/m/qZtx0AHhcy` |
| `tree_e.res` | Tree (CommonTree_5) | `https://poly.pizza/m/t9KbsfYdXz` |
| `bush.res` | Bush | `https://poly.pizza/m/EoTERLq3z2` |
| `bush_flowers.res` | Bush with Flowers | `https://poly.pizza/m/U1ymDy8tbY` |
| `rock_a.res` | Rock Medium (2) | `https://poly.pizza/m/KZdEP3uUpa` |
| `rock_b.res` | Rock Medium (1) | `https://poly.pizza/m/s1OJ3bBzqc` |
| `rock_c.res` | Rock Medium (3) | `https://poly.pizza/m/JQxF95498B` |
| `pebble.res` | Pebble Round | `https://poly.pizza/m/icVsN3lmVy` |
| `stone_path.res` | Rock Path Round Wide | `https://poly.pizza/m/mWb3XxOctl` |
| `flower_group_a.res` | Flower Group (3) | `https://poly.pizza/m/hfPzQAedOe` |
| `flower_group_b.res` | Flower Group (4) | `https://poly.pizza/m/LqTljN6Wg2` |
| `flower_single_a.res` | Flower Single (3) | `https://poly.pizza/m/rHBoS64rRL` |
| `flower_single_b.res` | Flower Single (4) | `https://poly.pizza/m/GvfHo0roi3` |
| `flower_petal.res` | Flower Petal | `https://poly.pizza/m/HifQHnKf4h` |
| `violet_patch.res` | Plant Big | `https://poly.pizza/m/uwJ1rwrZlB` |
| `grass_short.res` | Grass | `https://poly.pizza/m/vUJjrRsFp4` |
| `grass_wispy.res` | Grass Wispy | `https://poly.pizza/m/Msr9zx66VU` |
| `grass_tall.res` | Tall Grass | `https://poly.pizza/m/JSIYtscPmP` |
| `fern.res` | Fern | `https://poly.pizza/m/jqcanvH7D6` |

## Cambios respecto del original (mallas y texturas derivadas)

Cada `.glb` trae sus texturas de 1024 px embebidas y repetidas (34 MB para 22 modelos). El repo no guarda los `.glb`: guarda lo que el juego usa, generado por `tools/extract_environment_assets.gd`:

- **Mallas** (`meshes/*.res`): la geometría de cada modelo como `ArrayMesh` estática, con la transformación de sus nodos aplicada y **sin materiales** (las escenas adaptadoras ponen los `.tres` compartidos de `materials/environment/`). No se agregan ni quitan vértices, ni cambian UV.
- **Texturas** (`textures/`), una vez cada una y reducidas a 512 px: `bark.png`, `rocks.png`, `path_rocks.png`, `grass.png` y `leaves.png`, sin cambios de color. Los mapas de normales no se usan.
- **`leaves_mask.png`** (derivada de `Leaves_NormalTree_C.png`): la misma silueta de hojas, en blanco con un poco de sombreado. El color lo pone el material de cada árbol (verde claro, verde oscuro, amarillo o naranja; ver `stages.md` §3.5).
- **`flowers.png`** (derivada de `Flowers.png`): los pétalos rojos y rosa salmón pasan a magenta (tono 318°), porque caían a menos de 20° del rojo anaranjado de los avisos de ataque (`docs/color-registry.md`). El resto del atlas no cambia.

## Cómo regenerar

1. Bajar los `.glb` de la tabla (botón "Download" de cada página, formato GLB) a `<fuente>/stylized_nature/` con los nombres que usa `MODELS` en el script (`tree_4.glb`, `bush_0.glb`…), y los de `modular_dungeon/` y `castle_kit/` según sus `SOURCE.md`.
2. En una copia del proyecto: `godot --headless --path <copia> -s res://assets/models/environment/stylized_nature/tools/extract_environment_assets.gd -- <fuente>`.
3. Copiar `assets/models/environment/` de la copia al repo.
