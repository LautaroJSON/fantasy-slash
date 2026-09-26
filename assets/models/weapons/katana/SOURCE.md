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
  - `katana_blade.res` y `katana_sheath.res` se generaron copiando posiciones, normales, tangentes y UV de los vértices de cada hueso, y los triángulos cuyos tres vértices son de ese hueso. Sin pesos ni huesos. Para regenerarlas: script headless (`extends SceneTree`) que lee `surface_get_arrays(0)` de la malla `Katana` del glb, filtra por `ARRAY_BONES` y guarda con `ResourceSaver`.
