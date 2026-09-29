# Feature: Esquive perfecto (tiempo lento de los enemigos)

- **Estado:** Implementada (2026-09-29), revisión 2, en la rama `feature/perfect-dodge`. Los tests están escritos pero no se corrieron en esta sesión: la verificación es manual (pedido del responsable). Fase B, 3 de 3: `fodder-minion` (implementada) → `kill-feedback` (implementada) → **`perfect-dodge`**.
- **Constitución:** `docs/constitution.md` **v5.0.0** → **MINOR 5.1.0** aplicada con esta spec (Principio VII, viñeta "Tiempo lento"; ver `constitution-history.md`). Sin cambios en el anexo de colores.
- **Criterios de aceptación:** reserva **AC1171–AC1183** (los AC1184–AC1190 del rango original quedan libres).
- **Pilar (Principio I):** Combate.
  - Hoy esquivar solo evita el daño: dashear en el momento justo y dashear "por las dudas" terminan igual, y los jugadores dicen que esquivar no se siente recompensante.
  - Con esta spec, un dash que atraviesa un golpe enemigo responde al instante: los enemigos se ralentizan un segundo mientras el jugador sigue a velocidad normal, y un texto lo confirma. Esquivar pasa a abrir un respiro para contraatacar, no solo a defender.
- **Tipo:** feature (mecánica de combate común a las tres clases).
- **Dependencias:** `dash-iframes.md` (la invulnerabilidad dura exactamente el dash), `enemy-attack-telegraph.md` y `enemy-types.md` (todos los golpes enemigos pasan por `HealthComponent.receive_hit_from`), `parry-riposte-rework.md` (identidad de la Parry y `Enemy.freeze_time`, Principio VII 4.23.0), `readable-damage-numbers.md` (`DamageNumberPool.spawn_text`), `fodder-minion.md` (los golpes de los Esbirros cuentan).

## Decisiones del responsable (2026-09-29)

| Pregunta | Decisión |
|---|---|
| Ventana | **0.2 s** desde el inicio del dash, recortada a la invulnerabilidad del dash (`DASH_INVULNERABILITY`, ver `dash-invulnerability-parameter.md`): con la invulnerabilidad de las clases actuales igual al movimiento, todo golpe que el dash atraviesa cuenta. |
| Tiempo lento | **1 s a ×0.25, bosses incluidos** (revisión posterior: era 0.3 s). Es **solo de los enemigos**: no es una cámara lenta global; el jugador, la cámara, los VFX y la UI siguen a velocidad normal. |
| Recompensas | El tiempo lento de los enemigos, un golpe de FOV de la cámara (+10°, se recupera en 0.6 s; agregado después) y el texto flotante "¡Esquive perfecto!". |
| Fuera de esta spec | Viñeteado blanco e imagen residual; recarga del dash; Instinto (crítico garantizado, su buff, su ícono y el cambio en `StatsComponent`). Pueden volver en otra spec. |
| Golpes de Esbirros | **Cuentan.** |
| Esquivar "hacia afuera" | **No** por ahora. |
| Agarres de bosses | **No** en esta spec. |
| Latencia táctil | Sin cambios (recomendación aceptada por defecto): la ventana se mide en tiempo de juego entre el comienzo del dash y el contacto del golpe, así que la latencia atrasa el dash pero no achica la ventana; no se alarga la invulnerabilidad. Se mide jugando en el teléfono. |

## 1. Objetivo

Si un golpe enemigo alcanza al jugador **mientras dashea** y dentro de los primeros `perfect_window` segundos del dash (sin daño, como hoy), se dispara un **esquive perfecto**:

1. **Tiempo lento:** todos los enemigos activos se mueven y actúan a `enemy_time_scale` (×0.25) durante `slow_duration` (1 s de tiempo real). El jugador, la cámara, los VFX y la UI siguen a velocidad normal.
2. **Texto:** "¡Esquive perfecto!" flota sobre la cabeza del jugador.
3. **Golpe de FOV:** la cámara se ensancha `fov_kick_degrees` de golpe y vuelve en `fov_kick_return` (`ThirdPersonCamera.kick_fov`).

Un solo esquive perfecto por dash y, como mucho, uno cada `min_interval` (0.5 s).

## 2. Diseño

### 2.1 Detección (sin duplicar la de la Parry)

- **Todos** los golpes enemigos (Bruto, Embestidor, Saltador, Hostigador, Escudero, Esbirro, ondas y golpes de bosses) llaman a `target.health.receive_hit_from(daño, enemigo)`. La Parry se apoya en el mismo punto (`ShieldGuard.absorb`), pero solo con el escudo levantado.
- **`HealthComponent`** suma la señal **`hit_evaded(raw: float, attacker: Enemy)`**: `receive_hit_from` la emite cuando el golpe llega con `is_invulnerable` y el dueño no está muerto (hoy ese caso devuelve 0 en silencio). `receive_hit`, `receive_true_damage` y los ticks de estados no la emiten.
- **`PerfectDodgeComponent`** (nodo nuevo del jugador) escucha `hit_evaded` y dispara el esquive perfecto si:
  1. `dash.is_invulnerable_by_dash()` (la invulnerabilidad viene del dash; la de la estocada de la Parry no cuenta);
  2. `dash.get_invulnerability_elapsed() ≤ config.effective_window(dash.get_invulnerability_total())`, con `effective_window(i) = minf(perfect_window, i)`;
  3. no hubo otro esquive perfecto en este dash;
  4. pasaron `min_interval` segundos desde el anterior;
  5. `attacker != null`.
- Como los comportamientos enemigos marcan el golpe como usado aunque el jugador sea invulnerable (`_has_hit = true`, "A dodge with iframes also uses up the hit"), cada ataque produce como máximo un `hit_evaded`. Los golpes de los Esbirros pasan por el mismo camino, así que cuentan sin cambios.

**Identidad de la Parry (no se pisa):** la Parry es del Guerrero, se planta con el escudo y responde con una estocada. El esquive perfecto es de todas las clases y sale del dash. No comparten código de detección ni se disparan uno al otro: durante la Parry el dash está bloqueado (`locks_dash`) y durante el dash el escudo no está levantado.

### 2.2 Tiempo lento (`Enemy.dilate_time`)

- `Enemy.dilate_time(scale: float, seconds: float)`: durante `seconds` de tiempo real, el `delta` que recibe el comportamiento, el del deslizamiento del empuje y la velocidad al caminar se multiplican por `scale`. Se combina multiplicando con la lentitud de los debuffs (`debuffs.get_speed_scale()`), así un enemigo con Escarcha queda aún más lento: `_speed_scale = debuffs.get_speed_scale() × get_time_dilation()`. La gravedad no se escala (como con la lentitud: `_unscaled()` ya la compensa).
- El congelamiento (`freeze_time`), el hit lag y la aparición desde el piso **ganan** sobre el tiempo lento (se evalúan antes). El tiempo lento se descuenta al principio de `_physics_process`, así también corre mientras esos estados están activos.
- Una llamada nueva reinicia la duración (no se suma). `activate()` y `deactivate()` lo limpian.
- `PerfectDodgeComponent` lo aplica a todos los enemigos de `registry.get_active()` (lista viva, sin copiar), bosses incluidos. Los que aparecen durante el tiempo lento no se ralentizan.
- **`Engine.time_scale` no se toca.**

### 2.3 Texto y golpe de FOV

- `DamageNumberPool` escucha `player.perfect_dodge.perfect_dodged` y llama a `spawn_text(config.popup_text, punto sobre la cabeza del jugador)`; el punto es la posición del jugador más `popup_height` de alto. Sin tinte propio (blanco, como los demás textos). El pool ya tiene `player` como export.
- **Golpe de FOV:** `PerfectDodgeComponent` llama a `camera.kick_fov(fov_kick_degrees, fov_kick_return)` (export `camera`, el `CameraRig` del jugador). El dash ya da un golpe de +6° en 0.25 s al empezar (`dash_fov_kick_config.tres`); un `kick_fov` nuevo reinicia el anterior, así que el del esquive (+10°, 0.6 s) continúa el gesto sin saltos. Un valor negativo cierra la vista en lugar de abrirla.

## 3. Estructura de nodos

```
entities/player/player.tscn
└─ PerfectDodge (Node, components/perfect_dodge_component.gd)     ← nuevo
     exports: dash, health, registry, config
```

- `Player` suma `@onready var perfect_dodge: PerfectDodgeComponent`. `registry` lo asigna la arena igual que a los demás componentes que lo usan.
- Sin cambios en el HUD ni en la arena, salvo el enlace de `DamageNumberPool` (que ya tiene la referencia al jugador).

## 4. Resources y datos

- **`resources/perfect_dodge_config.gd`** (`PerfectDodgeConfig`), instancia en `data/player/perfect_dodge_config.tres` (común a las tres clases):

| Campo | Valor | Qué es |
|---|---|---|
| `perfect_window` | 0.2 s | Desde el inicio del dash; recortada a la invulnerabilidad del dash. |
| `min_interval` | 0.5 s | Entre dos esquives perfectos. |
| `enemy_time_scale` | 0.25 | Velocidad de los enemigos durante el tiempo lento. |
| `slow_duration` | 1.0 s | Tiempo real. |
| `fov_kick_degrees` / `fov_kick_return` | 10° / 0.6 s | Golpe de FOV de la cámara: se ensancha de golpe y vuelve (negativo la cierra). El dash ya da +6° en 0.25 s; este continúa el gesto. |
| `popup_text` | "¡Esquive perfecto!" | Texto flotante. |
| `popup_height` | 2.4 m | Altura del texto sobre los pies del jugador. |

  Función pura: `effective_window(dash_duration: float) -> float`.
- **Sin stats nuevos del jugador, sin cartas nuevas, sin buffs ni íconos nuevos.** Si más adelante una carta mejora el esquive, se hace en otra spec.

## 5. Interfaz pública

- **`HealthComponent`:** señal `hit_evaded(raw: float, attacker: Enemy)`.
- **`DashComponent`:** `get_elapsed() -> float` (segundos del dash en curso; hoy `_elapsed` es privado).
- **`PerfectDodgeComponent`:**
  - señal `perfect_dodged(attacker: Enemy)`;
  - `get_time_since_last() -> float`;
  - `advance(delta: float)` (intervalo entre esquives; lo llama `_physics_process`).
- **`Enemy`:** `dilate_time(scale: float, seconds: float)`, `is_time_dilated() -> bool`, `get_time_dilation() -> float` (1 sin tiempo lento).

## 6. Lógica interna

```
_on_hit_evaded(raw, attacker):
    if not _can_trigger(attacker): return          # §2.1, condiciones 1–5
    _triggered_this_dash = true
    _since_last = 0
    _slow_enemies()                                 # registry.get_active() → dilate_time
    perfect_dodged.emit(attacker)                   # DamageNumberPool (texto)

_on_dash_started(): _triggered_this_dash = false
_physics_process(delta): advance(delta)            # _since_last += delta
```

Todo en miembros `bool`/`float`: sin allocations por cuadro (Principio V). Con la horda (hasta 16 Esbirros más la mezcla), el recorrido de `registry.get_active()` son ~25 llamadas por esquive perfecto, una vez cada 0.5 s como mínimo.

## 7. Criterios de aceptación (AC1171–AC1183)

**Detección** (`test/components/perfect_dodge_test.gd`):
- **AC1171:** `receive_hit_from` con `is_invulnerable` emite `hit_evaded(raw, attacker)` una vez y devuelve 0; sin invulnerabilidad no la emite; muerto, tampoco. `receive_hit`, `receive_true_damage` y un tick de sangrado nunca la emiten.
- **AC1172:** con el Guerrero, un golpe de Bruto que conecta a los 0.05 s de empezar el dash dispara `perfect_dodged` con ese Bruto y no hace daño.
- **AC1173:** con `perfect_window` 0.1 s en un config de prueba, el mismo golpe a los 0.15 s del dash no hace daño pero no dispara el esquive perfecto. `effective_window(0.14)` con `perfect_window` 0.2 devuelve 0.14.
- **AC1174:** dos golpes durante el mismo dash disparan un solo esquive perfecto; un segundo dash dentro de `min_interval` no dispara otro.
- **AC1175:** un golpe durante la estocada invulnerable de la Parry (sin dash) no dispara el esquive perfecto; un golpe que llega justo después de terminar el dash hace daño y no lo dispara (AC551 sigue igual).
- **AC1176:** un golpe de Esbirro que conecta a los 0.05 s de empezar el dash también dispara `perfect_dodged`.

**Tiempo lento** (`test/entities/enemy/time_dilation_test.gd`):
- **AC1177:** tras un esquive perfecto, todos los enemigos activos (un boss incluido) tienen `get_time_dilation()` = `enemy_time_scale` durante `slow_duration` (± 1 cuadro) y 1 después. `Engine.time_scale` queda en 1 y el dash del jugador recorre su `DASH_DISTANCE` en su duración normal.
- **AC1178:** un Bruto en preparación avanza su preparación a ×0.25 mientras dura el tiempo lento: una preparación de 0.2 s que empieza con el tiempo lento activo dura 0.8 s (0.2 s a ×0.25), con tolerancia de un cuadro. Su velocidad al caminar y su empuje también se reducen a ×0.25.
- **AC1179:** con Escarcha (lentitud) el factor se multiplica; con `freeze_time` activo el enemigo sigue congelado y el tiempo lento se descuenta igual; `activate()` y `deactivate()` limpian el tiempo lento; un enemigo que aparece durante el tiempo lento no queda ralentizado.

**Texto** (`test/effects/damage_number_pool_test.gd`, caso nuevo):
- **AC1180:** `DamageNumberPool` muestra `popup_text` a `popup_height` sobre el jugador, una vez por esquive perfecto.

**Integración y datos** (`test/levels/perfect_dodge_arena_test.gd`):
- **AC1181:** en la arena, con cada clase, un dash que empieza 0.05 s antes de que el golpe de un Bruto entre en su fase activa (jugador dentro del arco) dispara el esquive perfecto; un dash que empieza 0.5 s antes, alejándose, no lo dispara y tampoco recibe daño.
- **AC1183:** al dispararse un esquive perfecto, la cámara recibe `kick_fov(fov_kick_degrees, fov_kick_return)`: su FOV queda al menos `fov_kick_degrees` sobre el base y el config lo tiene con `fov_kick_return` > 0.
- **AC1182:** `perfect_dodge_config.tres` existe con `perfect_window > 0`, `0 < enemy_time_scale < 1` y `slow_duration > 0`, y el nodo `PerfectDodge` de `player.tscn` lo tiene asignado.

## 8. Plan de implementación

1. Reservar AC1171–AC1183 al empezar (ya reservados en `docs/ac-registry.md`; ajustar el texto al rango reducido). Releer `player.tscn`, `health_component.gd`, `dash_component.gd`, `enemy.gd` y `damage_number_pool.gd` (otras sesiones los tocan).
2. `HealthComponent.hit_evaded` y `DashComponent.get_elapsed()`. Test AC1171.
3. `PerfectDodgeConfig` y su `.tres`; `PerfectDodgeComponent` con detección y señal (sin recompensas). Tests AC1172–AC1176 y AC1182.
4. `Enemy.dilate_time` y su aplicación desde el componente. Tests AC1177–AC1179.
5. Texto flotante en `DamageNumberPool`. Test AC1180.
6. Enmienda MINOR (Principio VII e historial).
7. Integración en la arena. Test AC1181.
8. Tests de la spec (targeted); **video antes/después** con `godot-capture` (Principio VIII §8): un Guerrero y un Samurái esquivando el golpe de un Bruto y de un Embestidor, a velocidad real y al 30 %, para revisar que el tiempo lento se lea y que el respiro alcance para contraatacar. Smoke test en la arena con las tres clases (y, si se puede, en el teléfono).
9. Checklist, spec **Implementada**, `where-to-tune.md` (viñeta nueva "Esquive perfecto" y nota en "Dash") y próximo AC libre.

## 9. Review (checklist de la constitución)

- [x] **I.** Combate: esquivar en el momento justo paga con un respiro para contraatacar.
- [x] **II.** Sin mallas, materiales, íconos ni colores nuevos: el texto usa el sistema de números flotantes existente.
- [x] **III.** Todos los números y textos en `perfect_dodge_config.tres`. Ningún Resource compartido se muta.
- [x] **IV.** Tipado estático; `_physics_process` solo llama a `advance(delta)`.
- [x] **V.** Sin allocations por cuadro; el tiempo lento recorre la lista viva del registro sin copiarla.
- [x] **VI.** Sin acciones nuevas: el esquive perfecto sale del `dash` de siempre (teclado, mando y táctil).
- [x] **VII.** Sin `Engine.time_scale`: solo los enemigos se ralentizan, con la enmienda del §10. El golpe del jugador no cambia.
- [ ] **VIII.** No hay clips nuevos del cuerpo. Video antes/después del tiempo lento.
- [ ] **Calidad:** tests en verde, suite sin fallos nuevos respecto de `main`, smoke test.

## 10. Enmienda de la constitución (MINOR → 5.1.0)

- **Principio VII, nueva viñeta después de "Tiempo congelado":**
  > **Tiempo lento** (desde 5.1.0): un esquive perfecto (un golpe enemigo que alcanza al jugador durante los primeros instantes de su dash, definido en datos; ver `perfect-dodge.md`) puede ralentizar a todos los enemigos activos, bosses incluidos, a una fracción de su velocidad durante un breve lapso definido en datos, sin tocar `Engine.time_scale`: el jugador, la cámara, los VFX y la UI siguen a velocidad normal. Sigue prohibido modificar `Engine.time_scale`.
- Se agrega su entrada en `constitution-history.md` y se actualiza la versión al pie de `constitution.md`. **MINOR** porque suma una regla nueva (una segunda forma permitida de alterar el tiempo de los enemigos) sin quitar ni redefinir ninguna. Sin cambios en el anexo de colores: no hay colores nuevos.

## 11. Notas

- La ventana se mide con el tiempo del dash (`get_elapsed()`), no con timestamps del input: con el buffer de eventos táctiles de Android (`mobile-touch-controls.md`), el dash ya empieza en el cuadro en que la acción se procesa, y desde ahí corre la ventana.
- Con la Fase A las preparaciones son ×2.2 a nivel 1 (Bruto 1.1 s), así que el esquive perfecto se lee sin tocar esta spec.
- **Sacado de la revisión 1 (puede volver en otra spec):** viñeteado blanco de pantalla, golpe de FOV, imagen residual, recarga del dash al terminar el dash, y "Instinto" (crítico garantizado en el primer golpe, con su buff, su ícono y el modificador global de `CRIT_CHANCE` en `StatsComponent`). Si se agregan, la enmienda tendría que registrar los colores nuevos en `color-registry.md`.
- Otras ideas para después (fuera de alcance): cartas que mejoren el esquive perfecto, el esquive "hacia afuera" y vibración háptica en el teléfono.
- **Desviaciones de la implementación (2026-09-29):**
  - AC1181 inyecta el golpe con `receive_hit_from` usando un Bruto real de la oleada como atacante, en los momentos descritos (0.05 s dentro del dash, y con el dash ya terminado), en vez de esperar el ataque real del Bruto: con el ritmo de la Fase A la fase activa depende del nivel y de la oleada.
  - El aviso del suelo del enemigo (`GroundTelegraph`) corre con tiempo real: durante el tiempo lento su animación puede terminar antes que la preparación ralentizada, como ya pasa con los debuffs de lentitud. Se puede revisar si molesta jugando.
  - Pendiente: video antes/después con `godot-capture` (Principio VIII) y la verificación manual del responsable; por eso VIII y Calidad quedan sin marcar.
