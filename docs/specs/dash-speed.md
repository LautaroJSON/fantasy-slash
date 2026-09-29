# Feature: velocidad del dash como stat
> **Reemplazada en parte (2026-09-29):** la duración del dash ya no es `DASH_DISTANCE / DASH_SPEED`: es el parámetro `DASH_DURATION` de cada clase y `dash_speed` dejó de existir. Ver `dash-duration-parameter.md`.

- **Estado:** Implementada (2026-09-26). 446 tests GdUnit4: los 10 del dash en verde; 5 tests fallan por cambios de datos ajenos a esta spec (ver notas). Import y smoke test sin errores ni warnings.
- **Constitución:** `docs/constitution.md` v4.0.1 (sin enmienda).
- **Pilar (Principio I):** combate. La velocidad del dash define cómo se siente esquivar y reposicionarse. Tenerla como dato explícito por clase permite darle a cada clase un dash con carácter propio (p. ej. un samurái más rápido que un berserker) sin tocar código.

## 1. Objetivo

- **Hoy:** la velocidad del dash no existe como dato: sale de `dash_distance / PlayerTuning.dash_duration` (3.0 m / 0.2 s = **15 m/s**, igual para las tres clases). `dash_duration` es común a todas las clases.
- **Nuevo:** la velocidad es un stat de cada clase, `PlayerStats.dash_speed` (m/s), y la duración pasa a ser la derivada:
  `duración = DASH_DISTANCE / DASH_SPEED`.
- Se mantienen los **15 m/s** en las tres clases. El guerrero y el berserker dashean igual que hoy (3.0 m en 0.2 s). El samurái tiene `dash_distance = 3.5` (cambio de otra sesión durante esta spec), así que su dash dura 0.233 s en lugar de ir a 17.5 m/s.
- **Stat interno:** no se muestra en la pausa (no entra en `stat_display_table.tres`) y no tiene carta en el catálogo (fijo por diseño, como el resto del dash; constitución 3.1.1). Sigue siendo mejorable por el sistema (Principio III) si en el futuro se le agrega una carta.
- **Consecuencia de diseño:** si la distancia del dash sube (p. ej. con una carta futura), el dash dura más y conserva su velocidad. Hoy pasaría lo contrario: duraría lo mismo e iría más rápido.

## 2. Diseño

- **`PlayerStats`** (`resources/player_stats.gd`)
  - `@export var dash_speed: float` con doc `## Dash speed in m/s. The dash lasts dash_distance / dash_speed.`
  - Nuevo valor **al final** del enum: `Stat.DASH_SPEED`. Va al final para no correr los índices que las cartas `.tres` guardan como entero.
  - `get_base()` devuelve `dash_speed` para `Stat.DASH_SPEED`.
- **Datos:** `dash_speed = 15.0` en `warrior_stats.tres`, `berserker_stats.tres` y `samurai_stats.tres`.
- **`DashComponent.try_dash()`**
  - `_speed = stats.get_stat(Stat.DASH_SPEED)`
  - `_dash_time_left = stats.get_stat(Stat.DASH_DISTANCE) / _speed`
  - El resto no cambia: el último paso se acorta para recorrer exactamente la distancia, y los iframes y el enfriamiento no dependen de la duración.
- **Se elimina `PlayerTuning.dash_duration`** (sin otros usos) y su línea en `player_tuning.tres`. `DashComponent` deja de necesitar `tuning`: se quita el `@export var tuning` y su asignación en `player.tscn` y en `dash_component_test`.
- **Sin cambios** en `StatsComponent` (itera `Stat.size()`), pausa, catálogo ni sandbox.

## 3. Criterios de aceptación (reservados al empezar la implementación)

- **AC395** `PlayerStats.Stat.DASH_SPEED` existe, es el último valor del enum y `get_base(DASH_SPEED)` devuelve `dash_speed`. Warrior, Berserker y Samurái tienen `dash_speed = 15.0`. *(Adaptado en `dash-iframes.md`: el samurái pasó a 25 por un ajuste de datos, así que el test verifica que cada clase tenga `dash_speed` > 0.)*
- **AC396** `DASH_SPEED` es un stat interno: no aparece en `stat_display_table.tres` ni en ninguna carta de `upgrade_catalog.tres`.
- **AC397** El dash se mueve a `DASH_SPEED` y dura `DASH_DISTANCE / DASH_SPEED` (0.2 s con los datos del guerrero, con tolerancia de un cuadro de física) y recorre `DASH_DISTANCE` (± 0.1), igual que hoy.
- **AC398** Con una mejora de `DASH_SPEED` (+15, total 30 m/s), el dash recorre la misma `DASH_DISTANCE` (± 0.1) en la mitad del tiempo. Con una mejora de `DASH_DISTANCE`, el dash dura más y conserva la velocidad.
- **AC399** `PlayerTuning` ya no tiene `dash_duration` y `DashComponent` no tiene `tuning`. Regresión: suite completa en verde (AC14–AC16, AC247, AC356–AC358, AC362 y los tests que iteran todos los stats).

## 4. Plan de implementación

1. Reservar AC395–AC399 en `CLAUDE.md` (próximo libre → AC400).
2. `PlayerStats`: campo `dash_speed`, `Stat.DASH_SPEED` al final del enum y `get_base()`. Dato `dash_speed = 15.0` en los tres `<clase>_stats.tres`. El proyecto sigue funcionando (el stat existe pero nadie lo lee).
3. `DashComponent.try_dash()` lee `DASH_SPEED` y calcula la duración. Quitar `tuning` de `DashComponent`, de `player.tscn` y del test; quitar `dash_duration` de `PlayerTuning` y de `player_tuning.tres`.
4. Tests: agregar `DASH_SPEED` a `FIXED_STATS` (`stats_rework_test`) y a `HIDDEN_STATS` (`pause_menu_test`); tests nuevos AC395–AC399 en `dash_component_test`.
5. Actualizar `CLAUDE.md` (sección "Dónde se ajusta cada cosa": velocidad del dash en `<clase>_stats.tres`) y la mención de `dash_duration` en `combat-mvp.md` como reemplazada por esta spec.
6. Import, suite completa, smoke test, review de la constitución y estado **Implementada**.

## 5. Notas de implementación

- **Datos del samurái:** al empezar la implementación, `samurai_stats.tres` ya tenía `dash_distance = 3.5`, un cambio de otra sesión que no forma parte de esta spec. Con `dash_speed = 15` su dash dura 0.233 s. El test `samurai_run_test` AC236, que exige la misma distancia que el guerrero, falla por ese cambio y no se tocó.
- **Fallos ajenos:** AC188, AC285/AC298 y AC288 fallan por el cambio de datos de Conmoción (`data/buffs/concussion.tres`), igual que en el cierre de `tsubame-gaeshi.md`.
- **Medición de la duración (AC397/AC398):** los tests cuentan cuadros de física mientras `is_dashing()` y aceptan un cuadro de diferencia (1/60 s). La tolerancia alcanza para distinguir 0.1 s, 0.2 s y 0.4 s.
- **Tests adaptados sin cambiar lo que verifican:** `DASH_SPEED` se sumó a `FIXED_STATS` (`stats_rework_test`) y a `HIDDEN_STATS` (`pause_menu_test`). `dash_component_test` ya no asigna `tuning`.
- `combat-mvp.md`: las menciones a `dash_duration` quedan marcadas como reemplazadas por esta spec.

### Review de la constitución (cierre)
- **I:** combate.
- **II:** sin cambios visuales.
- **III:** la velocidad del dash es un stat en `.tres` por clase, mejorable por el sistema y fijo por diseño (sin carta). No quedaron literales: la duración se calcula a partir de dos stats.
- **IV:** tipado estricto; `_physics_process` sin cambios.
- **V:** sin allocations nuevas por frame (el cálculo ocurre una vez por dash).
- **VI:** sin cambios de input.
- **Calidad:** import y smoke test sin errores ni warnings; los tests de esta spec y los del dash en verde. Los fallos restantes son ajenos (ver arriba).
