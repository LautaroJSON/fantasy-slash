# Feature: Pausa a pantalla completa y botones "Max" en las mejoras

- **Estado:** Implementada (2026-09-29). `pause_fullscreen_max_test` (12) en verde, junto con `pause_menu_tabs_test`, `sandbox_run_test`, `sandbox_arena_control_test`, `pause_menu_test`, `unique_upgrade_run_test` y `touch_ui_sizes_test`. Pestañas revisadas en capturas (Sandbox con y sin Max, y Normal).
- **Constitución:** `docs/constitution.md` (sin enmiendas: ver §6)
- **Pilar (Principio I):** Progresión, como herramienta. Armar una build en el sandbox pasa de decenas de clics a uno por sección, y la pestaña Mejoras muestra casi todo el pool sin scroll.
- **Dependencias:** `sandbox-arena-control.md` (pausa por pestañas, `UpgradePanel`).
- **ACs:** AC1361–AC1375 (reservados).

## 1. Resumen

1. **La pausa ocupa toda la pantalla**, en los dos modos. El panel se estira hasta los bordes con un margen de `PauseMenuConfig.screen_margin` (16 px). Las pestañas usan todo el alto libre y los botones Reanudar y Menú principal quedan abajo.
2. **Mejoras en dos columnas:** Ofensivo y Defensivo a la izquierda, Habilidad y Aflicción a la derecha. A 1152 × 648 entran unas 8 filas por columna (hoy son 5 en total). Si no alcanza, se desplaza igual que hoy.
3. **Botón "Max" por fila** (solo Sandbox), al lado del +: sube esa carta hasta su tope (`max_stacks` o `max_level`) en un clic. Se desactiva cuando la carta ya está en el tope.
4. **Botón "Max" por sección** (solo Sandbox), junto al título de Ofensivo, Defensivo y Habilidad. Sube al tope todas las cartas de esa sección, con las doradas de Habilidad incluidas. **Aflicción no tiene botón de sección**, pero sus filas sí tienen "Max".

## 2. Layout

```
PauseMenu (Control, pantalla completa)
├─ Dim, ModeLabel
└─ Frame (MarginContainer, anclado a toda la pantalla; márgenes = screen_margin)   ← reemplaza Center
   └─ Panel (PanelContainer)
      └─ Margin/Layout (VBox)
         ├─ Header (HBox): Title "PAUSA" · RunLabel                              ← una sola línea
         ├─ Tabs (TabContainer, size_flags_vertical = EXPAND_FILL)
         │  ├─ Personaje                 (contenido centrado horizontalmente)
         │  ├─ Mejoras (UpgradePanel)
         │  │  ├─ Scroll (EXPAND_FILL en ambos ejes)
         │  │  │  └─ Columns (HBox)
         │  │  │     ├─ LeftColumn  (VBox): sección Ofensivo, sección Defensivo
         │  │  │     └─ RightColumn (VBox): sección Habilidad, sección Aflicción
         │  │  └─ ResetButton
         │  └─ Enemigos                  (centrado horizontalmente)
         ├─ TabHint
         └─ Buttons (Reanudar, Menú principal)
```

- **Encabezado de sección** (HBox): el título y, en Sandbox, el botón "Max" de la sección (salvo en Aflicción).
- **Fila en Sandbox:** nombre · (base → actual) · n/tope · − · + · Max (6 columnas). En Normal: nombre · valor · n/tope (3 columnas, como hoy).
- Qué columna usa cada sección es un dato: `PauseMenuConfig.right_column_groups` (hoy `[ABILITY, AFFLICTION]`). El resto va a la izquierda.
- `PauseMenuConfig.upgrades_max_height` se elimina, porque el Scroll ahora ocupa el alto libre.
- Todos los botones nuevos miden al menos 44 px de alto (Principio VI) y el foco del mando los recorre como a − y +.

## 3. Datos

- **`PauseMenuConfig`:**
  - Suma `screen_margin: float` (16), `right_column_groups: Array[UpgradeCard.Group]` (`[ABILITY, AFFLICTION]`), `max_button_text: String` ("Max") y `max_section_groups: Array[UpgradeCard.Group]` (`[OFFENSE, DEFENSE, ABILITY]`: las secciones con botón "Max").
  - Quita `upgrades_max_height`.

## 4. Interfaz pública y lógica

- **`UpgradePanel`:**
  - `max_card(card: UpgradeCard) -> void`: aplica la carta hasta que `player.is_maxed(card)`. Si una aplicación no sube el contador (por ejemplo, porque se llegó al tope de 3 tipos de Aflicción), corta, para que el bucle nunca sea infinito. Emite `upgrades_changed` una sola vez.
  - `max_group(group: UpgradeCard.Group) -> void`: `max_card` para cada carta listada de ese grupo. Emite una sola vez.
  - Consultas para tests: `is_max_enabled(card)`, `has_group_max_button(group)` y `get_section_column(group) -> int` (0 = izquierda, 1 = derecha).
  - `refresh()` desactiva el "Max" de fila con el mismo criterio que el +.
- **`PauseMenu`:** en `_ready` aplica `screen_margin` al `Frame` (el valor sale del Resource). Sin más cambios de API.

## 5. Criterios de aceptación

- **AC1361** El panel de la pausa ocupa la pantalla menos `screen_margin` por lado. Con la ventana de 1152 × 648, su rectángulo es (16, 16) – (1136, 632), ±1 px.
- **AC1362** La pestaña Mejoras usa el alto libre: el Scroll mide al menos el 50 % del alto de la ventana.
- **AC1363** Las secciones Ofensivo y Defensivo van en la columna izquierda y Habilidad y Aflicción en la derecha, según `right_column_groups`.
- **AC1364** "Max" en la fila de Daño deja la carta en `max_stacks`, sube el stat en `max_stacks × amount` y actualiza la pestaña Personaje. Después, el "Max" y el + quedan desactivados.
- **AC1365** "Max" en una única de habilidad la deja en `max_level`.
- **AC1366** "Max" en una carta de Aflicción la deja en su `max_level`. Con el tope de tipos de Aflicción ya lleno, "Max" en un tipo nuevo no la aplica y no se cuelga.
- **AC1367** "Max" de la sección Ofensivo deja en su tope todas las cartas de Ofensivo, sin tocar Defensivo, Habilidad ni Aflicción.
- **AC1368** "Max" de la sección Defensivo hace lo mismo con Defensivo.
- **AC1369** "Max" de la sección Habilidad deja en su tope los stats y las doradas de la habilidad equipada.
- **AC1370** La sección Aflicción no tiene botón "Max". Las otras tres sí.
- **AC1371** Un "Max" (de fila o de sección) emite `upgrades_changed` una sola vez.
- **AC1372** En Normal no hay botones "Max" ni −/+: la pestaña Mejoras sigue siendo de solo lectura (AC1355).
- **AC1373** Los botones "Max" (plantilla y de sección) miden al menos 44 px de alto (`touch_ui_sizes_test`).
- **AC1374** Las tres pestañas entran en la ventana (AC1359 sigue en verde).
- **AC1375** Regresión: `pause_menu_tabs_test`, `sandbox_run_test`, `sandbox_arena_control_test`, `pause_menu_test`, `unique_upgrade_run_test` y `touch_ui_sizes_test` en verde. Captura de las tres pestañas en Sandbox y de Mejoras en Normal, revisada a ojo.

## 6. Constitución

- **I:** Progresión, como herramienta del sandbox.
- **II:** solo UI 2D.
- **III:** el margen, las columnas, las secciones con "Max" y el texto del botón están en `PauseMenuConfig`. Los topes siguen siendo `max_stacks` y `max_level`.
- **IV:** tipado completo.
- **V:** "Max" es un bucle acotado por el tope y solo corre al pulsar. Las filas se construyen al abrir la pausa.
- **VI:** botones de al menos 44 px, alcanzables con el foco del mando. La pausa sigue abriéndose y cerrándose con `pause` y `ui_cancel`.

## 7. Plan

1. `PauseMenuConfig`: los campos nuevos, y se quita `upgrades_max_height` (y su uso en `UpgradePanel._ready`).
2. `pause_menu.tscn` a pantalla completa (`Frame` + encabezado en una línea + `Tabs` con expansión), y el margen aplicado en `_ready`. Tests AC1361, AC1362 y AC1374.
3. `upgrade_panel.tscn` y `.gd`: las dos columnas, los encabezados de sección con "Max", la columna "Max" en las filas (6 columnas en Sandbox), `max_card` y `max_group`. Tests AC1363–AC1372.
4. `touch_ui_sizes_test` (AC1373) y las suites de AC1375 con `godot-tester`. Captura con `godot-capture`.
5. Cierre: notas, estado Implementada, registro de ACs (próximo libre AC1376) y la viñeta de `where-to-tune.md`.

## 8. Notas de implementación

- **Fila en Sandbox:** el valor (base → actual) va debajo del nombre, en la misma celda (`CellTemplate`). Quedan 5 columnas: nombre y valor, n/tope, −, + y Max. En Normal son 2. Con 6 columnas, como estaba en la spec, la captura mostró los nombres cortados ("Daño crí…", "Carga de escudo: …").
- **Foco:** el primer foco de Mejoras es el "Max" de la primera sección, así su título queda a la vista. `PauseMenu` mueve el foco un frame después del cambio de pestaña y vuelve el scroll arriba. Sin ese frame, la pestaña recién mostrada todavía no tiene layout y `follow_focus` la desplazaba mal, tapando los títulos de Ofensivo y Habilidad. `test_ac1348` espera esos frames.
- **AC898** (`sandbox_run_test`), adaptado: el panel ahora se estira sobre todo el viewport, así que el test mide `get_combined_minimum_size()` (lo que necesita el contenido) en lugar de `size`. Verifica lo mismo: que la pausa entre en 1152 × 648. Igual que AC1359.
- **Ruta del panel:** `Center/Panel` pasó a ser `Frame/Panel` (`%Frame`, `PauseMenu.get_panel()`).
- **Huérfanos:** `test_ac1372` espera un frame al final para que se liberen las filas editables que pasan por `queue_free` al volver a solo lectura.
