# Feature: Refuerzo de las muertes (impacto más grande al matar y hit lag por muerte múltiple)

- **Estado:** Implementada en la rama `feature/kill-feedback` (2026-09-29), revisión 2. Los tests están escritos pero no se corrieron: la verificación es manual (pedido del responsable). Fase B, 2 de 3: `fodder-minion` (implementada) → **`kill-feedback`** → `perfect-dodge`.
- **Constitución:** `docs/constitution.md` **v5.0.0**, **sin enmienda** (la revisión 1 proponía un PATCH por los textos blancos 2D del HUD; sin HUD ya no hace falta).
- **Criterios de aceptación:** reserva **AC1156–AC1162** (los AC1163–AC1170 del rango original quedan libres).
- **Pilar (Principio I):** Combate.
  - Hoy matar a un enemigo se ve y se siente igual que pegarle: el impacto es el mismo y el golpe que mata a cuatro pausa lo mismo que el que le pega a uno. Con la horda de `fodder-minion.md` los barridos matan a varios a la vez, y ese momento merece más peso.
  - Con esta spec, el golpe que mata muestra un impacto más grande y el golpe que mata a varios pausa y sacude un poco más: es la recompensa inmediata del "farmeo".
- **Tipo:** feature (feedback de combate).
- **Dependencias:** `bdo-combat-feel.md` (hit lag local, Principio VII), `hit-impact-vfx.md` (`HitImpactVfxHost`, `HitImpactVfxConfig`), `warrior-abilities-rework.md` §4.4 (`AbilityComponent.struck`, `StrikeFeel`), `fodder-minion.md` (implementada; no bloqueante).

## Decisiones del responsable (2026-09-29)

La revisión 1 de esta spec proponía seis piezas. Se conservan dos:

| Pieza | Decisión |
|---|---|
| Impacto de muerte más grande | **Se incorpora.** Con crítico se combinan los dos tamaños (respuesta: "ambos"). |
| Hit lag y sacudida extra por muerte múltiple | **Se incorpora.** |
| Muerte con vuelo | **Fuera.** Es una animación sobre la cápsula gris que se va a rehacer: habrá una spec de rework visual de los enemigos y no vale la pena animar un modelo que se va a cambiar. |
| Racha y multi-kill en el HUD (`KillTracker`, `KillStreakView`) | **Fuera.** |
| Mejor racha en la pausa y el Game Over | **Fuera.** |
| Señal `kill_registered` para el botín de la Fase C | **Fuera.** La Fase C definirá su propio enganche cuando se especifique. |

Sin racha ni vuelo, la spec no toca `Enemy`, `EnemyPool`, `RunState`, el HUD ni la arena.

## 1. Objetivo

1. **Impacto de muerte:** el `HitImpactVfx` del golpe que deja muerto al enemigo sale más grande (`kill_scale`). Un crítico ya es más grande (`crit_scale`); cuando el golpe es crítico **y** mata, se combinan los dos tamaños con un tope (`max_kill_crit_scale`).
2. **Hit lag extra por muerte múltiple:** un golpe del combo (o de una habilidad no canalizada) que deja muertos a 2 o más enemigos pausa el clip del jugador y sacude la cámara un poco más.

## 2. Qué se ve y qué se siente

### 2.1 Impacto de muerte (`HitImpactVfxHost`)

- `show_impact(enemy, is_crit)` mira si el enemigo quedó muerto (`enemy.health.is_dead()`, ya evaluado cuando llega `enemy_hit`) y se lo pasa al efecto: `HitImpactVfx.play(point, normal, slash_dir, is_crit, is_kill)`.
- Escala del efecto entero, calculada por `HitImpactVfxConfig.scale_for(is_crit, is_kill)`:

| Crítico | Mata | Escala |
|---|---|---|
| no | no | 1.0 |
| sí | no | `crit_scale` (1.4, como hoy) |
| no | sí | `kill_scale` (1.5) |
| sí | sí | `minf(crit_scale × kill_scale, max_kill_crit_scale)` = 1.8 |

- El fragmento cruzado sigue apareciendo solo con crítico. Mismo blanco y mismo material (Principio II): solo cambia el tamaño. No cambia la cantidad de chispas (cambiar `amount` de las partículas en pleno combate reasigna memoria).
- Aplica a los golpes del combo y de las habilidades con `AbilityData.shows_hit_impact`, que ya pasan por `show_impact`.

### 2.2 Hit lag extra por muerte múltiple (`HitstopComponent`)

- `HitstopComponent` cuenta, con una variable miembro, cuántos enemigos quedaron muertos en el golpe: en cada `attack.enemy_hit` suma uno si `enemy.health.is_dead()`, y `_on_attacked` lo consume (y lo reinicia). No hace falta tocar `AttackComponent`: `enemy_hit` se emite por cada enemigo antes de `attacked`.
- `_on_attacked`: pausa del clip = `step.hitlag + multi_kill.hitlag_bonus_for(kills)` y sacudida = `step.shake_strength + multi_kill.shake_bonus_for(kills)`.
- `_on_struck` (habilidades no canalizadas, con su `StrikeFeel`): los muertos se cuentan de la lista `enemies` que recibe, y suma lo mismo al hit lag y a la sacudida del `StrikeFeel`. El bonus solo aplica si el `StrikeFeel` ya tiene hit lag (una habilidad que no pausa no empieza a pausar).
- Las habilidades canalizadas (el Giro) nunca emiten `struck`: no se tocan y siguen sin pausar al jugador.
- **Tablas** (`MultiKillFeelConfig`): `hitlag_bonus` = [0.02, 0.035, 0.05] para 2, 3 y 4 o más muertes (el último valor se repite), y `shake_bonus` = [0.05, 0.1, 0.15]. Una muerte sola no suma nada.
- No se toca `Engine.time_scale` (Principio VII) y el hit lag sigue siendo local: pausa del clip del jugador, congelamiento de los enemigos golpeados y sacudida de cámara.

## 3. Estructura de nodos

Sin nodos nuevos. Cambios en nodos existentes del jugador:

```
entities/player/player.tscn
├─ Hitstop (HitstopComponent)     + export multi_kill: MultiKillFeelConfig
└─ HitImpactVfx (HitImpactVfxHost) sin export nuevo (lee kill_scale de su HitImpactVfxConfig)
```

## 4. Resources y datos

- **`resources/multi_kill_feel_config.gd`** (`MultiKillFeelConfig`), instancia común a las tres clases en `data/player/multi_kill_feel_config.tres`:

| Campo | Valor inicial |
|---|---|
| `min_kills` | 2 |
| `hitlag_bonus` | [0.02, 0.035, 0.05] |
| `shake_bonus` | [0.05, 0.1, 0.15] |

  Funciones puras: `hitlag_bonus_for(kills: int) -> float` y `shake_bonus_for(kills: int) -> float` (0 con menos de `min_kills`; con más muertes que entradas, el último valor).
- **`HitImpactVfxConfig`** suma `kill_scale` (1.5) y `max_kill_crit_scale` (1.8), y la función pura `scale_for(is_crit, is_kill) -> float`. Valores en `data/player/hit_impact_vfx_config.tres`.
- El config de hit lag por clase (`*_hitstop.tres`) no cambia: la tabla de muerte múltiple es común y vive aparte.

## 5. Interfaz pública

- **`HitImpactVfxConfig.scale_for(is_crit, is_kill) -> float`** (pura).
- **`HitImpactVfx.play(point, normal, slash_dir, is_crit, is_kill := false)`:** un parámetro nuevo con valor por defecto; los llamadores y tests existentes no cambian.
- **`HitImpactVfxHost.show_impact(enemy, is_crit)`:** misma firma; deduce `is_kill` de `enemy.health.is_dead()`.
- **`MultiKillFeelConfig.hitlag_bonus_for(kills)` / `shake_bonus_for(kills)`** (puras).
- **`HitstopComponent`:** `@export var multi_kill: MultiKillFeelConfig`. Opcional: sin él, no suma nada (como hoy).

## 6. Lógica interna

- `HitstopComponent._on_enemy_hit(enemy, ...)`: además de lo que ya hace, `if enemy.health.is_dead(): _kills_in_strike += 1`.
- `HitstopComponent._on_attacked(hit_count, ...)`: `var kills := _kills_in_strike; _kills_in_strike = 0` antes de salir por `hit_count <= 0`; si hay `multi_kill`, suma los bonus a `start(...)` y `camera.shake(...)`.
- `HitstopComponent._on_struck(feel, enemies)`: cuenta `is_dead()` en `enemies` (un bucle sobre la lista recibida, sin copiarla) y suma los bonus a `feel.hitlag` y `feel.shake_strength` solo dentro de la llamada, sin mutar el `StrikeFeel` compartido (Principio III).
- `HitImpactVfx.play`: `effect_scale = config.scale_for(is_crit, is_kill)` en lugar de `config.crit_scale if is_crit else 1.0`.
- Solo miembros `int`/`float`: sin allocations por cuadro (Principio V).

## 7. Criterios de aceptación (AC1156–AC1162)

**Impacto de muerte** (`test/components/vfx/hit_impact_vfx_test.gd`, casos nuevos):
- **AC1156:** `scale_for` devuelve 1.0 (ni crítico ni muerte), `crit_scale` (solo crítico), `kill_scale` (solo muerte) y 1.8 (crítico y muerte; con los valores por defecto `crit_scale × kill_scale` = 2.1 se recorta al tope). Con `kill_scale` = 1 el resultado sin muerte no cambia.
- **AC1157:** en el combo, un golpe que deja muerto al enemigo reproduce el efecto con escala `kill_scale`, y uno que no lo mata, con escala 1.0; con crítico son `min(crit_scale × kill_scale, max_kill_crit_scale)` y `crit_scale`. El fragmento cruzado solo se ve con crítico.
- **AC1158:** un golpe de habilidad con `shows_hit_impact` que mata al enemigo también reproduce el efecto con `kill_scale`.

**Muerte múltiple** (`test/resources/multi_kill_feel_config_test.gd` y `test/components/hitstop_test.gd`, casos nuevos):
- **AC1159:** `hitlag_bonus_for` y `shake_bonus_for` valen 0 con 0 y 1 muertes; 0.02 / 0.05 con 2; 0.035 / 0.1 con 3; y 0.05 / 0.15 con 4 y con 9 (el último valor se repite).
- **AC1160:** un golpe del combo que mata a 1 enemigo pausa el clip exactamente `step.hitlag`; uno que mata a 3, `step.hitlag + 0.035`; uno que mata a 6, `step.hitlag + 0.05`. La sacudida de cámara suma lo mismo con `shake_bonus`. Un golpe que alcanza a 3 pero no mata a ninguno no suma nada. `Engine.time_scale` queda en 1.
- **AC1161:** un `struck` de habilidad no canalizada con `StrikeFeel.hitlag` > 0 y 2 enemigos muertos en la lista suma el bonus de 2 a la pausa y a la sacudida; con `hitlag` = 0 no pausa. El `StrikeFeel` compartido no cambia. Un golpe del Giro (canalizado) sigue sin pausar al jugador.

**Datos:**
- **AC1162:** `multi_kill_feel_config.tres` existe con las tres tablas de arriba, el `Hitstop` de `player.tscn` lo tiene asignado, y `hit_impact_vfx_config.tres` tiene `kill_scale` > 1 y `max_kill_crit_scale` ≥ `kill_scale`.

## 8. Plan de implementación

1. Reservar AC1156–AC1162 al empezar (ya reservados en `docs/ac-registry.md`; ajustar el texto del registro al rango reducido). Releer `hitstop_component.gd`, `hit_impact_vfx.gd` y `hit_impact_vfx_host.gd`.
2. `HitImpactVfxConfig.kill_scale` / `max_kill_crit_scale` / `scale_for`, `HitImpactVfx.play(..., is_kill)` y `HitImpactVfxHost` que deduce `is_kill`. Tests AC1156–AC1158; los tests de impacto existentes siguen en verde.
3. `MultiKillFeelConfig` y su `.tres`, y el contador de muertes en `HitstopComponent`. Tests AC1159–AC1162; los tests de hit lag existentes siguen en verde (una muerte sola no suma).
4. Tests de la spec con `godot-tester` (targeted); **video antes/después** con `godot-capture` (Principio VIII §8, VFX de golpe): un barrido del Guerrero sobre 4 Esbirros a velocidad real y al 30 %, en vista de juego, para revisar el tamaño del impacto y el hit lag extra. Smoke test en la arena.
5. Checklist, spec **Implementada**, `where-to-tune.md` (viñeta "Impacto de golpe": `kill_scale`; viñeta nueva "Hit lag por muerte múltiple") y próximo AC libre en `CLAUDE.md`/`ac-registry.md`.

## 9. Review (checklist de la constitución)

- [x] **I.** Combate: matar pesa más que pegar, y matar a varios pesa más que matar a uno.
- [x] **II.** Sin mallas ni materiales nuevos: el impacto de muerte es el mismo efecto blanco, más grande.
- [x] **III.** Todo número en `multi_kill_feel_config.tres` e `hit_impact_vfx_config.tres`; funciones puras en los configs; el `StrikeFeel` compartido no se muta.
- [x] **IV.** Tipado estático; `HitstopComponent` no suma trabajo a `_physics_process`.
- [x] **V.** Sin allocations por cuadro (contadores en miembros, bucle sobre la lista recibida sin copiarla); no cambia la cantidad de partículas.
- [x] **VI.** Sin input nuevo.
- [x] **VII.** Hit lag local, sin `Engine.time_scale`; las habilidades canalizadas no pausan al jugador.
- [ ] **VIII.** VFX de golpe: mismo efecto, más grande, con video antes/después. (pendiente: el video antes/después no se hizo)
- [ ] **Calidad:** tests en verde, sin fallos nuevos respecto de `main`, smoke test.

## 10. Notas

- **Sin enmienda:** la revisión 1 proponía un PATCH 5.0.1 (registrar el blanco 2D del HUD). Sin HUD, no hay enmienda: `perfect-dodge` es ahora la única de la Fase B y será la MINOR 5.1.0 sobre la versión vigente.
- **Ideas para después (fuera de alcance):** la muerte con vuelo, junto con el rework visual de los enemigos; contador de racha y multi-kill en el HUD; sonido cuando exista un sistema de audio (los disparadores naturales serían el impacto de muerte y el hit lag extra); vibración del teléfono en la muerte múltiple.
- **Botín (Fase C):** esta spec ya no deja un punto de extensión. Cuando se especifique el oro, su enganche natural es `registry.enemy_killed(enemy)`, que ya existe.
