# falchion

- **Origen:** pack de terceros `Swords_pack_01` (exportado de Blender a `.obj`/`.mtl`).
- **Licencia:** a confirmar.
- **Uso:** mesh estático del arma; se usa solo desde su escena adaptadora en `entities/player/weapons/`. Materiales reemplazados por `materials/weapons/*.tres`.
- **Modificaciones:** renombrado a `snake_case` (y su línea `mtllib`); líneas `Ka` del `.mtl` eliminadas para evitar el warning de luz ambiente del importador PBR.
