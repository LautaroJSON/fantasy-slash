# Feature: La duración del dash como parámetro

> **Nota (2026-09-29):** la invulnerabilidad del dash tiene ahora su propio parámetro (`dash-invulnerability-parameter.md`); la duración del movimiento sigue siendo `DASH_DURATION`.
- **Estado:** Implementada (2026-09-29), en la rama `feature/perfect-dodge`. Verificada a mano por el responsable (2026-09-29); los tests están escritos pero no se corrieron en esta sesión.
- **Constitución:** `docs/constitution.md` **v5.1.0** → **PATCH 5.1.1** (Principio III: la invulnerabilidad del dash dura `DASH_DURATION`, ya no `DASH_DISTANCE / DASH_SPEED`).
- **Criterios de aceptación:** sin números nuevos: adapta AC395–AC398, AC547, AC549 y AC550 (`dash_component_test.gd` y `stats_component_test.gd`), sin cambiar lo que verifican.
- **Pilar (Principio I):** Combate. La invulnerabilidad del dash es la base del esquive y del esquive perfecto (`perfect-dodge.md`); pasa a ser un número que se ajusta directamente por clase.
- **Tipo:** refactor de datos con un cambio de regla de diseño (ver *Cambio de comportamiento*).
- **Dependencias:** `dash-speed.md` y `dash-iframes.md` (reemplazadas en parte), `perfect-dodge.md` (su ventana se recorta a la duración del dash).

## Qué cambia

- **`PlayerStats.dash_duration`** (segundos) reemplaza a `dash_speed` (m/s), en el mismo lugar del enum (`Stat.DASH_DURATION` ocupa el lugar de `DASH_SPEED`, así los índices guardados en los `.tres` no se mueven).
- **`DashComponent.try_dash`** toma la duración del stat (`_dash_time_left = _duration = DASH_DURATION`, con un mínimo estructural `MIN_DURATION` de 0.001 s por si un dato dice 0) y **deriva** la velocidad: `_speed = DASH_DISTANCE / _duration`.
- **`StatsComponent._apply_limits`:** el piso del enfriamiento es `DASH_DURATION + min_dash_cooldown_gap`.
- **Datos** (valores que conservan el juego actual):

| Clase | `dash_duration` | `dash_distance` | Velocidad derivada |
|---|---|---|---|
| Guerrero | 0.20 s | 3.0 m | 15 m/s |
| Berserker | 0.20 s | 3.0 m | 15 m/s |
| Samurái | 0.14 s | 3.5 m | 25 m/s |

## Cambio de comportamiento

Antes, una mejora de `DASH_DISTANCE` alargaba el dash y con él la invulnerabilidad (AC549). Ahora la duración es un parámetro: subir la distancia hace el dash **más rápido** y la invulnerabilidad no cambia. Subir `DASH_DURATION` alarga los dos. Ninguna carta del catálogo toca estos stats (son fijos por diseño), así que hoy no se nota.

## Tests adaptados (sin cambiar lo que verifican)

- AC395: `DASH_DURATION` es el último stat antes de los de aguante y cada clase lo tiene.
- AC396: es interno (sin fila en la pausa ni carta).
- AC397: el dash dura `dash_duration` y recorre `dash_distance`.
- AC398: con la mitad de la duración recorre lo mismo en la mitad del tiempo; con el doble de distancia dura lo mismo y va más rápido.
- AC547: el Guerrero y el Samurái son invulnerables exactamente `dash_duration`.
- AC549: la invulnerabilidad sigue a `DASH_DURATION`; una mejora de distancia no la cambia.
- AC550: el piso del enfriamiento es `dash_duration + gap` y sigue a las mejoras de duración.
- `stats_rework_test` y `pause_menu_test`: `DASH_DURATION` en las listas de stats fijos y ocultos.

## Review (checklist de la constitución)

- [x] **III.** El valor vive en los `.tres`; el único literal en código es `MIN_DURATION`, estructural.
- [x] **IV.** Tipado estático.
- [x] **V.** Sin costo por cuadro: una división por dash.
- [x] **Calidad:** verificación manual del responsable; tests escritos, sin correr en esta sesión.
