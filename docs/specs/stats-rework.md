# Feature: Rework de stats (crítico, robo de vida, dash fijo) y pausa en columnas

- **Estado:** Implementada (2026-09-25, 298 tests GdUnit4 en verde, 0 orphans; import y smoke test headless del menú y de la arena sin errores ni warnings; captura real del menú de pausa)
- **Constitución:** `docs/constitution.md` v3.1.1 (PATCH aprobada con esta spec: stats fijos por diseño)
- **Pilares (Principio I):**
  - **Progresión:** el crítico es una build que se construye desde 5 % hasta 100 %, y el robo de vida se gana con cartas.
  - **Combate:** dash, salto y arco quedan como identidad fija de la clase; la pausa muestra solo lo que se puede mejorar.
- **Dependencias:** `combat-mvp.md`, `upgrade-caps.md`, `berserker-heavy-sweep.md`.

## 1. Stats base (`data/classes/warrior/warrior_stats.tres`, Guerrero; `data/classes/berserker/berserker_stats.tres`)

| Stat | Antes | Ahora |
|---|---|---|
| `crit_chance` | 0.15 | **0.05** |
| `crit_damage` | 1.5 (multiplicador) | **1.0** (bonus: +100 %, ×2) |
| `lifesteal` | 0.1 | **0.0** |
| `dash_cooldown` | 2.0 s | **1.5 s** |
| `dash_distance` | 3.6 m | **3.0 m** |

- **Cambio de significado:** `crit_damage` guarda el **bonus**. Un crítico hace daño × (1 + `crit_damage`). El valor guardado es el que se muestra (1.0 → "100 %").
- Invencibilidad (1.0 s), salto (4.5) y arco (Guerrero 120°, Berserker 150°) no cambian de valor y quedan **fijos**.
- Piso del dash: 1.0 + `min_dash_cooldown_gap` 0.5 = 1.5 s, se cumple exactamente.

## 2. Cartas de mejora

| Carta | Antes | Ahora |
|---|---|---|
| `crit_chance.tres` | +5 %, ×10 | +5 %, **×19** (5 % → 100 % = `max_crit_chance`) |
| `crit_damage.tres` | +0.25x, ×8 | **+15 %, ×14** (100 % → 300 %); nuevo `CombatRules.max_crit_damage = 3.0` |

- Se eliminan del catálogo y del proyecto: `attack_arc`, `dash_distance`, `dash_cooldown`, `iframe_duration`, `jump_velocity`. El catálogo queda con 10 cartas.

## 3. Menú de pausa

- `StatDisplayTable`: `rows` se reemplaza por `left_column`, `right_column` y `bottom_rows`. `find()` busca en los tres (lo usa el panel del sandbox).

| Grupo | Filas (en orden) |
|---|---|
| Columna izquierda | Daño · Probabilidad de crítico · Daño crítico · Robo de vida · Bono de daño |
| Columna derecha | Vida máxima · Defensa |
| Debajo | Velocidad de ataque · Velocidad de movimiento · Rango |

- Daño crítico: formato `"%.0f %%"` con multiplicador 100 ("100 %").
- Escena `ui/pause_menu.tscn`: `StatsGrid` → `StatsBlock` (VBox) con `StatColumns` (HBox: `LeftGrid`, `RightGrid`) y `BottomGrid`; todas `GridContainer` de 2 columnas.
- No se muestran: arco de ataque, recarga del dash, invencibilidad, distancia de dash, fuerza de salto.

## 4. Criterios de aceptación

- **AC229** Las dos clases arrancan con 5 % de crítico, 100 % de daño crítico, 0 % de robo de vida, 1.5 s de recarga y 3.0 m de dash.
- **AC230** Un crítico base hace el doble del daño normal. Con 19 cartas de Crítico la probabilidad es 100 % y la carta sale del pool.
- **AC231** Con 14 cartas de Daño crítico el bonus queda en 300 % (tope) y la carta sale del pool.
- **AC232** El catálogo tiene 10 cartas, sin arco, dash, invencibilidad ni salto.
- **AC233** La pausa muestra exactamente la columna izquierda, la derecha y el bloque inferior en el orden pedido, sin los 5 stats ocultos.
- **AC234** El daño crítico se muestra "100 %" (y "300 %" en el tope).
- **AC235** Regresión: suite completa en verde.

## 5. Plan de implementación

1. Enmienda 3.1.1 y esta spec.
2. Datos: stats, `max_crit_damage`, cartas de crítico, catálogo; borrar las 5 cartas.
3. Código: `DamageMath.outgoing` con bonus, tope en `StatsComponent`, `StatDisplayTable` con tres grupos, `PauseMenu` y su escena.
4. Tests adaptados y AC229–AC234; suite, smoke test, captura de la pausa; estado **Implementada**.

## 6. Notas de implementación

- Tests con valores viejos fijos, adaptados sin cambiar su intención: AC8 (el robo de vida se prueba con una mejora de +10 %), AC15 (la recarga se lee de `PLAYER_STATS`), AC33 (crítico base = "30!"), AC122 (sandbox "(5 % → 30 %)"), AC21 (el catálogo cubre los 10 stats con carta), AC26 (pausa con las filas de `StatDisplayTable`) y los tests de `DamageMath` (bonus en vez de multiplicador).
- `test_ac119_dash_cooldown_cap_stays_above_its_floor` se reemplazó por AC230/AC231: ya no existe la carta de recarga de dash.
- GdUnit muestra los strings fallidos como diff entre esperado y obtenido ("(15 % → 430 %)" era "(5 % → 30 %)").

### Review de la constitución (cierre)
- **I:** Progresión (crítico y robo de vida como build) y Combate (dash, salto y arco fijos).
- **II:** solo UI 2D; sin assets nuevos.
- **III (v3.1.1):** valores en `.tres`; los stats fijos siguen en `PlayerStats` sin carta; topes en `CombatRules` (`max_crit_chance`, nuevo `max_crit_damage`) y `max_stacks` elegidos para no desperdiciar copias.
- **IV:** firmas tipadas; `_refresh` delega en `_refresh_group`.
- **V:** la pausa construye sus labels una vez en `_ready`.
- **VI:** sin cambios de input.
