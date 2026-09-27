# katana

- **Origen:** modelo low poly de katana con funda (`katana.glb`), provisto por el usuario.
- **Licencia:** free to use.
- **Uso:** el glb es la fuente. Trae una sola malla skinned con dos huesos (`katana.base`: hoja y mango; `katana.sheath`: funda, hijo de la hoja), así que no se puede mostrar una parte sin la otra desde el glb. Por eso se derivaron dos mallas estáticas, una por hueso:
  - `katana_blade.res` → `entities/player/weapons/katana.tscn`
  - `katana_sheath.res` → `entities/player/weapons/katana_sheath.tscn`
  
  Las animaciones del glb (`Draw`, `Idle`, `Sheath`, `Unsheathed`) no se usan: el arma la mueven `SwordSwing` y el `SwingPlayer` del jugador.
- **Material:** el material embebido se reemplaza por `materials/weapons/katana_material.tres`, que usa `katana_palette.png` (paleta 10×10) como albedo (Principio II, 3.2.0). El importador descarta la imagen embebida (`gltf/embedded_image_handling=0`).
- **Modificaciones:**
  - La textura `low-assets-texture.png` se renombró a `katana_palette.png`.
  - `katana_blade.res` y `katana_sheath.res` se generan copiando posiciones, normales, tangentes y UV de los vértices de cada hueso, y los triángulos cuyos tres vértices son de ese hueso. Sin pesos ni huesos.
  - **Reproporcionadas a la mano del jugador** (`docs/specs/katana-hand-proportions.md`, constitución 4.11.0). Cada vértice se mapea según su altura Y original (el eje de la hoja en la malla):
    - **mango** (Y de 0.004 a 0.1605): Y se estira de 16.5 a 30.3 cm y la sección se escala ×1.5;
    - **tsuba** (Y de 0.1605 a 0.1725): diámetro ×2 (8.7 → ~17 cm), espesor ×1.25 (→ 1.65 cm), ubicada 1 cm delante del puño derecho. Los vértices de la hoja dentro de esa franja (|z| ≤ 1.1 mm) conservan el ancho de la hoja;
    - **hoja** y **funda**: Y se comprime para que la boca siga a la tsuba y la punta no se mueva (z = −1.27 en el arma).

    Las normales se escalan por la inversa de la escala y las tangentes por la escala. Vértices, índices y UV no cambian, así que la paleta sigue calzando. Con el `Model` en ×1.1 y el origen en z = 0.055, el pomo queda 8 cm detrás del puño y la tsuba entre z = −0.170 y −0.187.
  - **Para regenerarlas:** `tools/build_katana_meshes.gd` (`extends SceneTree`, headless, desde la raíz del proyecto; el comando está en el encabezado del script). Los límites de las regiones y los factores son constantes del script. Si cambia la mano del humanoide (`_gem(0.08)` × 1.333, medio largo sobre el eje del arma `h` = 0.1067 m) o el `grip_position` de `katana.tres`, recalculá `NEW_POMMEL_Y` y `NEW_GUARD_BACK_Y`. `weapon_model_test` (AC688) verifica que el script reproduzca las mallas del repo.
