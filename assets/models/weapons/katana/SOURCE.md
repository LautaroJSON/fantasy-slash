# katana

- **Origen:** modelo original, generado por script (`tools/build_katana_meshes.gd`), a partir de las referencias del responsable (`docs/specs/katana-visual-rework.md`). No hay archivo fuente de terceros: reemplaza al `katana.glb` con textura de paleta que se usó hasta la versión anterior y que se borró.
- **Licencia:** propia del proyecto.
- **Uso:** dos mallas `ArrayMesh` de normales planas, guardadas como `.res` y cargadas por sus escenas adaptadoras:
  - `katana_blade.res` → `entities/player/weapons/katana.tscn`. 6 superficies: 0 acero, 1 hamon, 2 hierro (tsuba), 3 oro, 4 tela de la tsuka, 5 rombos de la trenza.
  - `katana_sheath.res` → `entities/player/weapons/katana_sheath.tscn`. 4 superficies: 0 laca negra, 1 laca roja, 2 oro, 3 sageo (gris).
  - Materiales: `materials/weapons/katana_*_material.tres` (color plano, sin texturas).
- **Espacio del arma** (los dos `Model` en identidad): la hoja apunta a −Z, el filo va a −X y el lomo a +X, la punta se curva hacia +X y las caras planas de la hoja son el plano XZ. El puño derecho queda en z = −0.0533 (marcador `Hilt`), el pomo en z = +0.133, la tsuba entre −0.173 y −0.181, la punta en z = −1.267 (x = +0.096) y el final de la funda en z = −1.282.
- **Medidas:** todas son constantes del generador (tsuba de 12 cm con 4 calados, hoja de 5.0 → 4.0 cm con sori de 2 cm y kissaki de 5 cm, tsuka de 26 cm con 6 rombos y 2 menuki, funda de 2.5 cm de espesor con kurigata y sageo).
- **Para regenerarlas:** `tools/build_katana_meshes.gd` (`extends SceneTree`, headless, desde la raíz del proyecto; el comando está en el encabezado del script). Reutiliza los helpers de `assets/models/weapons/knight_set/tools/build_knight_meshes.gd`. Si cambia la mano del humanoide o el `grip_position` de `katana.tres`, revisá `FIST_Z`, `KASHIRA_BACK_Z` y las medidas de la tsuka. `katana_visual_test` (AC1238) verifica que el script reproduzca las mallas del repo.
- **Colores:** ver la tabla de `docs/specs/katana-visual-rework.md` §2.1 y `docs/color-registry.md`.
- **Historial:** las proporciones de la mano (`katana-hand-proportions.md`) y la forma de la funda (`katana-sheath-shape.md`) se hicieron sobre el modelo derivado del glb; esta versión las conserva en cuanto a posiciones (pomo 8 cm detrás del puño, tsuba delante del puño, punta y final de la funda) y rehace las formas.
