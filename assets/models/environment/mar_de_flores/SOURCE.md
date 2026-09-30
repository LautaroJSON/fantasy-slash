# Mar de Flores (terreno, fondo y vegetación generados)

- **Origen:** original de este proyecto, generado offline (Principio II, "Escenarios (stages)", constitución 6.2.0). Diseño y referencias: `docs/specs/stages.md` §3 (las seis imágenes de referencia del 2026-09-29 y la maqueta de primitivas).
- **Licencia:** la del proyecto. Las mallas de vegetación que se repiten en el scatter vienen de `../stylized_nature/` (CC0, ver su `SOURCE.md`).
- **Usado por:** `levels/stages/mar_de_flores/mar_de_flores_stage.tscn` (la escena adaptadora del mapa, `StageMap`).

## Cómo se genera

Todo sale de `tools/mar_de_flores_builder.gd` (`MarDeFloresBuilder`): constantes de forma (línea de muros, polígono de spawn, arroyo, sendero), relieve (ondulación, montículo de las ruinas, colinas del borde, ruido `FastNoiseLite` con semillas fijas), colores por vértice, ubicación de los props, bosque del borde, flores, pasto y nubes. `tools/build_mar_de_flores.gd` escribe los archivos y arma la escena del stage.

1. En una copia del proyecto, **sin `--headless`** (el renderer falso de `--headless` no guarda las instancias de los `MultiMesh`):
   `godot --path <copia> -s res://assets/models/environment/mar_de_flores/tools/build_mar_de_flores.gd`
2. Copiar al repo lo escrito: esta carpeta, `levels/stages/mar_de_flores/` y `data/stages/mar_de_flores/mar_de_flores_layout.tres`.

Un test (`test/levels/mar_de_flores_test.gd`) verifica que el builder reproduce el terreno y las alturas guardados, y los límites de relieve y separación entre obstáculos.

## Archivos

| Archivo | Qué es |
|---|---|
| `terrain.res` | Malla del terreno (grilla de 1 m sobre ±60 m, normales planas, colores por vértice). |
| `heights.res` | `HeightMapShape3D` de 81 × 81 (±40 m, 1 m) para la colisión y `StageMap.height_at`. |
| `backdrop.res` | Montañas con nieve, colinas lejanas y la colina del castillo (colores por vértice). |
| `water.res` | Superficie del arroyo. |
| `far_ground.tres`, `cloud_puff.tres` | `PlaneMesh` del suelo lejano y `SphereMesh` de las nubes (primitivas). |
| `scatter_meshes/*.res` | Copias de las mallas de `stylized_nature` con sus materiales puestos (un `MultiMesh` no tiene override por superficie). |
| `scatter/<tipo>_<parcela>.res` | `MultiMesh` de flores y pasto en 3 × 3 parcelas de 30 m (para el descarte por cámara). |
| `scatter/forest_<árbol>.res` | `MultiMesh` del bosque del borde; el color del follaje va en el color de cada instancia (30 % otoñal). |
| `scatter/clouds.res` | `MultiMesh` de las nubes. |
