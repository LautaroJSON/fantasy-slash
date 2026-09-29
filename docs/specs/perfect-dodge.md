# Feature: Esquive perfecto con recompensa

- **Estado:** Propuesta (2026-09-28). Fase B, 3 de 3: `fodder-minion` → `kill-feedback` → **`perfect-dodge`**.
- **Constitución:** `docs/constitution.md` **v5.0.0** → propuesta de enmienda **MINOR 5.1.0** (Principio VII, "Tiempo lento", y anexo de colores; §10). Si `kill-feedback.md` aplica antes su PATCH 5.0.1, esta queda como 5.1.0 igual.
- **Criterios de aceptación:** reserva **AC1171–AC1190** (dentro del rango AC1141–AC1190 de la Fase B).
- **Pilar (Principio I):** Combate.
  - Hoy esquivar solo evita el daño: dashear en el momento justo y dashear "por las dudas" terminan igual, y los jugadores dicen que esquivar no se siente recompensante.
  - Con esta spec, un dash que atraviesa un golpe enemigo en el momento justo responde al instante: los enemigos se ralentizan un momento, hay un destello, el dash vuelve a estar listo y el próximo golpe es crítico. Esquivar pasa a ser el arranque de un contraataque, no solo una defensa, y lleva de vuelta a lo divertido: pegar.
- **Tipo:** feature (mecánica de combate común a las tres clases).
- **Dependencias:** `dash-iframes.md` (la invulnerabilidad dura exactamente el dash), `dash-feel.md` (`DashComponent`, `DashVfx`, imágenes residuales, `kick_fov`), `enemy-attack-telegraph.md` y `enemy-types.md` (todos los golpes enemigos pasan por `HealthComponent.receive_hit_from`), `parry-riposte-rework.md` (identidad de la Parry y `Enemy.freeze_time`, Principio VII 4.23.0), `status-icons.md` (ícono del buff), `readable-damage-numbers.md` (`DamageNumberPool.spawn_text`). Encaja con la horda de `fodder-minion.md` y la racha de `kill-feedback.md`, pero no depende de ellas.

## Preguntas abiertas (para el responsable)

1. **Tamaño de la ventana.** La invulnerabilidad dura lo que el dash (0.2 s Guerrero y Berserker, 0.14 s Samurái), así que un golpe solo puede "esquivarse" dentro de ese tiempo. Propongo `perfect_window` = **0.2 s** desde que empieza el dash, recortada a la duración del dash: en la práctica, **todo golpe que el dash atraviesa cuenta como perfecto**. Dashear temprano y alejarse del golpe no cuenta (el golpe nunca te alcanza). *Recomendación: 0.2 s.* Es generosa a propósito (celular, público casual) y se puede ajustar en el `.tres` (p. ej. 0.12 s para exigir más).
2. **Latencia táctil.** La ventana se mide entre el comienzo del dash y el contacto del golpe, los dos en tiempo de juego: la latencia del toque atrasa el dash, pero no achica la ventana. Lo que ayuda en el teléfono es el aviso largo (preparaciones ×1.8 a nivel 1) y que la ventana sea el dash entero. **No propongo** alargar la invulnerabilidad para el táctil (rompería `dash-iframes.md` y la igualdad entre dispositivos). *Recomendación: dejarlo así y medirlo jugando en el teléfono.*
3. **Tiempo lento: cuánto y cuán lento.** El pedido sugiere ~0.15 s. A ×0.25 durante 0.15 s los enemigos pierden apenas 0.11 s: casi no se percibe. *Recomendación: 0.3 s a ×0.25* (los enemigos pierden ~0.22 s y se nota el "respiro" para contraatacar). Todo en datos.
4. **¿Cómo se hace el tiempo lento?** Con `Engine.time_scale` se ralentizaría también al jugador, la cámara y la UI, y el Principio VII lo prohíbe como feedback. *Recomendación:* ralentizar **solo a los enemigos** (su comportamiento, sus temporizadores y su empuje), como ya hace el congelamiento de la Estocada mejorada. Requiere la enmienda MINOR del §10.
5. **¿Los bosses también se ralentizan?** *Recomendación: sí*, con la misma escala: es corto, y la Estocada mejorada ya los congela. Si resulta demasiado fuerte, `EnemyStats.time_dilation_resistance` queda como extensión (no se especifica ahora).
6. **Crítico garantizado: ¿solo el ataque básico o cualquier golpe?** *Recomendación: el primer golpe que conecte, del combo o de una habilidad*, con un buff visible "Instinto" que dura 3 s si no se usa. Así también premia abrir con Envainar o el Giro.
7. **¿Cuentan los golpes de los Esbirros?** *Recomendación: sí.* Son lentos y muy avisados: un buen lugar para aprender el esquive perfecto.
8. **Esquivar "hacia afuera"** (el golpe cae donde estabas, pero el dash ya te sacó del alcance) **no cuenta** en esta versión: para detectarlo, cada comportamiento enemigo tendría que exponer su zona de golpe futura. *Recomendación: no por ahora; si jugando el perfecto sale poco, se hace en otra spec.*
9. **Agarres de bosses:** hoy se esquivan con `is_invulnerable` sin pasar por `receive_hit_from`, así que no cuentan. *Recomendación: dejarlo así en esta spec.*

## 1. Objetivo

Si un golpe enemigo alcanza al jugador **mientras dashea** y dentro de los primeros `perfect_window` segundos del dash (sin daño, como hoy), se dispara un **esquive perfecto**:

1. **Tiempo lento:** todos los enemigos activos se mueven y actúan a `enemy_time_scale` (×0.25) durante `slow_duration` (0.3 s de tiempo real). El jugador, la cámara, los VFX y la UI siguen a velocidad normal.
2. **Destello:** un viñeteado blanco en los bordes de la pantalla que aparece y se apaga en `flash_time` (0.2 s), un golpe de FOV de la cámara, una imagen residual brillante en el punto del esquive y el texto flotante "¡Esquive perfecto!".
3. **Dash listo:** al **terminar** ese dash, el enfriamiento del dash vuelve a 0 (no a mitad del dash, para no encadenar invulnerabilidades; §2.4).
4. **Instinto:** un buff de 1 stack durante `crit_buff_duration` (3 s) que hace crítico el primer golpe que conecte (combo o habilidad) y se consume con él.

Un solo esquive perfecto por dash y, como mucho, uno cada `min_interval` (0.5 s).

## 2. Diseño

### 2.1 Detección (sin duplicar la de la Parry)

- **Todos** los golpes enemigos (Bruto, Embestidor, Saltador, Hostigador, Escudero, Esbirro, ondas y golpes de bosses) llaman a `target.health.receive_hit_from(daño, enemigo)`. La Parry se apoya en el mismo punto (`ShieldGuard.absorb`), pero solo con el escudo levantado.
- **`HealthComponent`** suma la señal **`hit_evaded(raw: float, attacker: Enemy)`**: `receive_hit_from` la emite cuando el golpe llega con `is_invulnerable` y el dueño no está muerto (hoy ese caso devuelve 0 en silencio). `receive_hit`, `receive_true_damage` y los ticks de estados no la emiten.
- **`PerfectDodgeComponent`** (nodo nuevo del jugador) escucha `hit_evaded` y dispara el esquive perfecto si:
  1. `dash.is_dashing()` (la invulnerabilidad viene del dash; la de la estocada de la Parry no cuenta);
  2. `dash.get_elapsed() ≤ config.effective_window(dash.get_duration())`, con `effective_window(d) = minf(perfect_window, d)`;
  3. no hubo otro esquive perfecto en este dash;
  4. pasaron `min_interval` segundos desde el anterior;
  5. `attacker != null`.
- Como los comportamientos enemigos marcan el golpe como usado aunque el jugador sea invulnerable (`_has_hit = true`, "A dodge with iframes also uses up the hit"), cada ataque produce como máximo un `hit_evaded`.

**Identidad de la Parry (no se pisa):** la Parry es del Guerrero, se planta con el escudo, tiene su ventana de 0.35 s y 5 s de enfriamiento, y responde con una estocada (y, con Contragolpe, congela el tiempo y barre 360°). El esquive perfecto es de todas las clases, sale del dash y da una recompensa chica y rápida (tiempo lento corto y un crítico). No comparten código de detección ni se disparan uno al otro: durante la Parry el dash está bloqueado (`locks_dash`) y durante el dash el escudo no está levantado.

### 2.2 Tiempo lento (`Enemy.dilate_time`)

- `Enemy.dilate_time(scale: float, seconds: float)`: durante `seconds` de tiempo real, el `delta` que recibe el comportamiento y el del deslizamiento del empuje se multiplican por `scale`. Se combina multiplicando con la lentitud de los debuffs (`debuffs.get_speed_scale()`), así un enemigo con Escarcha queda aún más lento. La gravedad no se escala (como con la lentitud).
- El congelamiento (`freeze_time`), el hit lag y la aparición desde el piso **ganan** sobre el tiempo lento (se evalúan antes). El tiempo lento sigue descontándose mientras tanto.
- Una llamada nueva reinicia la duración (no se suma). `activate()` y `deactivate()` lo limpian.
- `PerfectDodgeComponent` lo aplica a todos los enemigos de `registry.get_active()` (lista viva, sin copiar), bosses incluidos (pregunta 5). Los que aparecen durante el tiempo lento no se ralentizan.
- **`Engine.time_scale` no se toca.**

### 2.3 Destello

- **Viñeteado (`PerfectDodgeFlash`)**: un `TextureRect` a pantalla completa en el `Hud`, con un `GradientTexture2D` radial (centro transparente, bordes blancos; creado una vez en `_ready`), `mouse_filter = IGNORE`. Su alpha sube a `flash_alpha` (0.3) en `flash_rise` (0.03 s) y vuelve a 0 en el resto de `flash_time`. El centro queda libre: no tapa al personaje ni al enemigo que se va a contraatacar (importante en el teléfono).
- **Cámara:** `camera.kick_fov(fov_kick_degrees, fov_kick_return)` (−4°, 0.25 s: se cierra un poco y vuelve).
- **Imagen residual del esquive:** `DashAfterimageVfx.leave_ghost(alpha, fade_time)` deja **una** copia del cuerpo en su pose actual con `ghost_alpha` (0.35, el máximo registrado) que se desvanece en `ghost_fade` (0.35 s). El pool de copias suma 1 copia reservada, creada al cargar.
- **Texto:** `DamageNumberPool` escucha `player.perfect_dodge.perfect_dodged` y llama a `spawn_text(config.popup_text, punto sobre la cabeza del jugador)` ("¡Esquive perfecto!", en el `.tres`).
- No se usa `Engine.time_scale` ni se pausa el clip del jugador: el dash sigue su recorrido.

### 2.4 Dash listo al terminar

- El esquive perfecto marca `_refund_pending`. En `dash.dash_ended` (termine o se corte), si está marcado, `dash.reset_cooldown()`: el enfriamiento vuelve a 0 y `dash_ready` se emite (el botón del dash ya late con esa señal, en PC y en táctil).
- **Por qué al final y no en el acto:** si el dash se recargara a mitad del recorrido, se podría encadenar otro dash dentro de la invulnerabilidad del anterior, que es justo lo que protege el piso `min_dash_cooldown_gap` (`dash-iframes.md`). Al final, la invulnerabilidad ya terminó: el próximo dash es uno normal y, para volver a recargarse, tiene que ser perfecto otra vez. No hace falta enmienda (mismo razonamiento que la nota de `zanshin.md`).

### 2.5 Instinto (crítico garantizado)

- **`data/buffs/instinct.tres`** (`BuffData`): `id &"instinct"`, título "Instinto", `max_stacks` 1, `stack_duration` = `crit_buff_duration` (3 s), `global = true`, modificador `CRIT_CHANCE` +1.0 por stack, ícono SVG nuevo y `icon_color` turquesa (§10).
- **`StatsComponent`** suma el modificador global de `CRIT_CHANCE` a `get_stat(CRIT_CHANCE)` (hoy los buffs globales suman `MOVE_SPEED`, `DAMAGE` y `ATTACK_SPEED`), respetando `CombatRules.max_crit_chance` (1.0). Con Instinto activo, la probabilidad de crítico es 1: cualquier golpe que tire crítico (combo, Estocada de la Parry, Giro, Envainar…) lo es.
- **Consumo:** `PerfectDodgeComponent` escucha `attack.attacked` (con `hit_count > 0`) y `enemy_hit` de los dos `AbilityComponent`. Al primero, marca el consumo y **quita el buff al final del cuadro de física** (en su `_physics_process`), así todos los enemigos de ese mismo golpe reciben el crítico. Un golpe al aire no lo consume.
- Se ve en la `BuffBar` como cualquier buff (ícono, reloj y marco verde).

## 3. Estructura de nodos

```
entities/player/player.tscn
└─ PerfectDodge (Node, components/perfect_dodge_component.gd)     ← nuevo
     exports: dash, health, buffs, attack, abilities, registry, camera, afterimages, config

ui/hud.tscn
└─ PerfectDodgeFlash (TextureRect, ui/perfect_dodge_flash.gd)     ← nuevo, pantalla completa, detrás del resto del HUD
```

- `Player` suma `@onready var perfect_dodge: PerfectDodgeComponent`. `registry` lo asigna la arena igual que a los demás componentes que lo usan.
- `Hud._ready` conecta `player.perfect_dodge.perfect_dodged` con `PerfectDodgeFlash.play()`.

## 4. Resources y datos

- **`resources/perfect_dodge_config.gd`** (`PerfectDodgeConfig`), instancia en `data/player/perfect_dodge_config.tres` (común a las tres clases):

| Campo | Valor | Qué es |
|---|---|---|
| `perfect_window` | 0.2 s | Desde el inicio del dash; recortada a la duración del dash. |
| `min_interval` | 0.5 s | Entre dos esquives perfectos. |
| `enemy_time_scale` | 0.25 | Velocidad de los enemigos durante el tiempo lento. |
| `slow_duration` | 0.3 s | Tiempo real. |
| `refund_dash` | `true` | Recarga el dash al terminar. |
| `crit_buff` | `data/buffs/instinct.tres` | El buff que da. |
| `flash_alpha` / `flash_rise` / `flash_time` | 0.3 / 0.03 s / 0.2 s | Viñeteado. |
| `vignette_inner_radius` | 0.55 | Fracción del radio donde empieza el blanco. |
| `fov_kick_degrees` / `fov_kick_return` | −4° / 0.25 s | Cámara. |
| `ghost_alpha` / `ghost_fade` | 0.35 / 0.35 s | Imagen residual. |
| `popup_text` | "¡Esquive perfecto!" | Texto flotante. |

  Función pura: `effective_window(dash_duration: float) -> float`.
- La duración del buff vive en `instinct.tres` (`stack_duration`), no se duplica en el config.
- **Nuevo ícono:** `assets/icons/status/dodge.svg` (game-icons.net, p. ej. "dodging" de Lorc, CC BY 3.0; se confirma al implementar), con su fila en `assets/icons/status/SOURCE.md`.
- **Sin stats nuevos del jugador y sin cartas nuevas.** La ventana y las recompensas son reglas del esquive, no stats de la clase (como las reglas de la Parry viven en `ParryConfig`). Si más adelante una carta las mejora (p. ej. "Instinto dura más"), se hace en otra spec.

## 5. Interfaz pública

- **`HealthComponent`:** señal `hit_evaded(raw: float, attacker: Enemy)`.
- **`DashComponent`:** `get_elapsed() -> float` (segundos del dash en curso; hoy `_elapsed` es privado).
- **`PerfectDodgeComponent`:**
  - señal `perfect_dodged(attacker: Enemy)`;
  - `is_refund_pending() -> bool`, `get_time_since_last() -> float`;
  - `advance(delta: float)` (intervalo y consumo del buff; lo llama `_physics_process`).
- **`Enemy`:** `dilate_time(scale: float, seconds: float)`, `is_time_dilated() -> bool`, `get_time_dilation() -> float` (1 sin tiempo lento).
- **`DashAfterimageVfx`:** `leave_ghost(alpha: float, fade_time: float)`.
- **`PerfectDodgeFlash`:** `play()`, `get_alpha() -> float`.
- **`StatsComponent`:** sin firma nueva (suma el global de `CRIT_CHANCE`).

## 6. Lógica interna

```
_on_hit_evaded(raw, attacker):
    if not _can_trigger(attacker): return          # §2.1, condiciones 1–5
    _triggered_this_dash = true
    _since_last = 0
    _slow_enemies()                                 # registry.get_active() → dilate_time
    buffs.add_stack(config.crit_buff)
    _refund_pending = config.refund_dash
    afterimages.leave_ghost(config.ghost_alpha, config.ghost_fade)
    camera.kick_fov(config.fov_kick_degrees, config.fov_kick_return)
    perfect_dodged.emit(attacker)                   # HUD (destello) y DamageNumberPool (texto)

_on_dash_started(): _triggered_this_dash = false
_on_dash_ended(_cancelled): if _refund_pending: dash.reset_cooldown(); _refund_pending = false
_on_strike_landed(): _consume_pending = buffs.get_stacks(crit_buff.id) > 0
_physics_process(delta): advance(delta)            # _since_last += delta; consumo diferido
```

Todo en miembros `bool`/`float`: sin allocations por cuadro (Principio V).

## 7. Criterios de aceptación (AC1171–AC1190)

**Detección** (`test/components/perfect_dodge_test.gd`):
- **AC1171:** `receive_hit_from` con `is_invulnerable` emite `hit_evaded(raw, attacker)` una vez y devuelve 0; sin invulnerabilidad no la emite; muerto, tampoco. `receive_hit`, `receive_true_damage` y un tick de sangrado nunca la emiten.
- **AC1172:** con el Guerrero, un golpe de Bruto que conecta a los 0.05 s de empezar el dash dispara `perfect_dodged` con ese Bruto y no hace daño.
- **AC1173:** con `perfect_window` 0.1 s en un config de prueba, el mismo golpe a los 0.15 s del dash no hace daño pero no dispara el esquive perfecto. `effective_window(0.14)` con `perfect_window` 0.2 devuelve 0.14.
- **AC1174:** dos golpes durante el mismo dash disparan un solo esquive perfecto; un segundo dash dentro de `min_interval` no dispara otro.
- **AC1175:** un golpe durante la estocada invulnerable de la Parry (sin dash) no dispara el esquive perfecto; un golpe que llega justo después de terminar el dash hace daño y no lo dispara (AC551 sigue igual).

**Tiempo lento** (`test/entities/enemy/time_dilation_test.gd`):
- **AC1176:** tras un esquive perfecto, todos los enemigos activos (un boss incluido) tienen `get_time_dilation()` = `enemy_time_scale` durante `slow_duration` (± 1 cuadro) y 1 después. `Engine.time_scale` queda en 1 y el dash del jugador recorre su `DASH_DISTANCE` en su duración normal.
- **AC1177:** un Bruto en preparación avanza su preparación a ×0.25 mientras dura el tiempo lento: una preparación que terminaba en 0.2 s termina 0.225 s más tarde (0.3 × 0.75), con tolerancia de un cuadro.
- **AC1178:** con Escarcha (lentitud) el factor se multiplica; con `freeze_time` activo el enemigo sigue congelado; `activate()` limpia el tiempo lento.

**Dash** (`test/components/perfect_dodge_test.gd`):
- **AC1179:** después de un esquive perfecto, el enfriamiento del dash sigue corriendo mientras el dash dura (`get_cooldown_remaining() > 0`) y queda en 0 en el cuadro en que el dash termina, con `dash_ready` emitido. También si el dash se corta.
- **AC1180:** un dash que empieza inmediatamente después de la recarga no se superpone con la invulnerabilidad del anterior: hay al menos un cuadro sin `is_invulnerable` entre los dos, o el anterior terminó en el cuadro previo (la recarga ocurre en `dash_ended`).
- **AC1181:** sin esquive perfecto, el dash no se recarga (regresión de `dash-iframes`).

**Instinto** (`test/components/perfect_dodge_test.gd` y `test/components/stats_component_test.gd`):
- **AC1182:** el esquive perfecto agrega 1 stack de `instinct`; mientras está, `get_stat(CRIT_CHANCE)` = `min(base + 1.0, max_crit_chance)`; al vencer `stack_duration` sin usarse, desaparece y la probabilidad vuelve a la base.
- **AC1183:** el siguiente golpe del combo que conecta es crítico aunque su `crit_roll` sea 0.99, y el buff ya no está en el cuadro siguiente. Un golpe al aire no lo consume.
- **AC1184:** un golpe del combo que alcanza a 3 enemigos con Instinto es crítico en los 3 (el consumo es al final del cuadro); un golpe de habilidad que conecta también lo consume.
- **AC1185:** `instinct.tres` tiene ícono (`assets/icons/status/dodge.svg`, con fila en su `SOURCE.md`) e `icon_color` registrado, y aparece en la `BuffBar` con marco de buff.

**Destello** (`test/ui/perfect_dodge_flash_test.gd` y `test/components/dash/dash_vfx_test.gd`):
- **AC1186:** `PerfectDodgeFlash.play()` lleva el alpha a `flash_alpha` (≤ 0.3) en `flash_rise` y a 0 al terminar `flash_time`; el centro de su textura es transparente; `mouse_filter = IGNORE`; está invisible en reposo.
- **AC1187:** en un esquive perfecto, `camera.kick_fov` recibe `fov_kick_degrees` y `fov_kick_return`, y `DashAfterimageVfx` deja una copia visible con alpha `ghost_alpha` (≤ 0.35) que llega a 0 en `ghost_fade`, sin quitarle copias al rastro normal del dash.
- **AC1188:** `DamageNumberPool` muestra `popup_text` sobre el jugador una vez por esquive perfecto.

**Integración** (`test/levels/perfect_dodge_arena_test.gd`):
- **AC1189:** en la arena, con cada clase, un dash que empieza 0.05 s antes de que el golpe de un Bruto entre en su fase activa (jugador dentro del arco) dispara el esquive perfecto; un dash que empieza 0.5 s antes, alejándose, no lo dispara y tampoco recibe daño.
- **AC1190:** `perfect_dodge_config.tres` existe con `perfect_window > 0`, `0 < enemy_time_scale < 1`, `flash_alpha ≤ 0.3` y `ghost_alpha ≤ 0.35`, y el nodo `PerfectDodge` de `player.tscn` lo tiene asignado.

## 8. Plan de implementación

1. Reservar AC1171–AC1190 al empezar. Releer `player.tscn`, `health_component.gd`, `dash_component.gd`, `stats_component.gd` y `enemy.gd` (otras sesiones los tocan).
2. `HealthComponent.hit_evaded` y `DashComponent.get_elapsed()`. Test AC1171.
3. `PerfectDodgeConfig` y su `.tres`; `PerfectDodgeComponent` con detección y señal (sin recompensas). Tests AC1172–AC1175 y AC1190.
4. `Enemy.dilate_time` y su aplicación. Tests AC1176–AC1178.
5. Recarga del dash al terminar. Tests AC1179–AC1181.
6. `StatsComponent` con el global de `CRIT_CHANCE`; `instinct.tres`, ícono y `SOURCE.md`; consumo diferido. Tests AC1182–AC1185.
7. Destello: `PerfectDodgeFlash` en el HUD, `kick_fov`, `leave_ghost` y el texto. Tests AC1186–AC1188.
8. Enmienda MINOR (Principio VII, anexo de colores e historial).
9. Integración en la arena. Test AC1189.
10. Tests de la spec con `godot-tester`; **video antes/después** con `godot-capture` (Principio VIII §8 y §6): un Guerrero y un Samurái esquivando el golpe de un Bruto y de un Embestidor, a velocidad real y al 30 %, vista de juego, para revisar que el tiempo lento se lea, que el viñeteado no tape la acción y que el ritmo del contraataque crítico se sienta. Smoke test en la arena con las tres clases (y, si se puede, en el teléfono).
11. Checklist, spec **Implementada**, `where-to-tune.md` (viñeta nueva "Esquive perfecto" y nota en "Dash") y próximo AC libre.

## 9. Review (checklist de la constitución)

- [ ] **I.** Combate: esquivar en el momento justo paga, y el pago lleva a pegar.
- [ ] **II.** Viñeteado 2D con `GradientTexture2D` (sin shader) e imagen residual con el material ya registrado; ícono SVG en `assets/icons/status/` con `SOURCE.md`; colores registrados (§10).
- [ ] **III.** Todos los números y textos en `perfect_dodge_config.tres` e `instinct.tres`. Ningún Resource compartido se muta.
- [ ] **IV.** Tipado estático; `_physics_process` solo llama a `advance(delta)`.
- [ ] **V.** Sin allocations por cuadro; el tiempo lento recorre la lista viva del registro sin copiarla; la copia residual extra se crea al cargar.
- [ ] **VI.** Sin acciones nuevas: el esquive perfecto sale del `dash` de siempre (teclado, mando y táctil). El viñeteado ignora el mouse y los toques.
- [ ] **VII.** Sin `Engine.time_scale`: solo los enemigos se ralentizan, con la enmienda del §10. El golpe del jugador no cambia (el crítico usa las reglas de daño de siempre).
- [ ] **VIII.** No hay clips nuevos del cuerpo. Los VFX (imagen residual, viñeteado) se revisan con video antes/después.
- [ ] **Calidad:** tests en verde, suite sin fallos nuevos, smoke test.

## 10. Enmienda de la constitución (MINOR → 5.1.0)

- **Principio VII, nueva viñeta después de "Tiempo congelado":**
  > **Tiempo lento** (desde 5.1.0): un esquive perfecto (un golpe enemigo que alcanza al jugador durante los primeros instantes de su dash, definido en datos; ver `perfect-dodge.md`) puede ralentizar a todos los enemigos activos, bosses incluidos, a una fracción de su velocidad durante una fracción de segundo, sin tocar `Engine.time_scale`: el jugador, la cámara, los VFX y la UI siguen a velocidad normal. Sigue prohibido modificar `Engine.time_scale`.
- **Anexo `color-registry.md`, colores no reservados en uso:** turquesa `Color(0.2, 0.85, 0.65)` para el ícono de Instinto (distinto del cian de Escarcha y del verde del marco de buff), y el blanco translúcido (alpha ≤ 0.3) del viñeteado 2D del esquive perfecto, que no se confunde con el blanco reservado porque es UI 2D en los bordes de la pantalla.
- Se agrega su entrada en `constitution-history.md`. **MINOR** porque suma una regla nueva (una segunda forma permitida de alterar el tiempo de los enemigos) sin quitar ni redefinir ninguna.

## 11. Notas

- La ventana se mide con el tiempo del dash (`get_elapsed()`), no con timestamps del input: con el buffer de eventos táctiles de Android (`mobile-touch-controls.md`), el dash ya empieza en el cuadro en que la acción se procesa, y desde ahí corre la ventana.
- Si la Fase A alarga las preparaciones (o baja los atacantes simultáneos), el esquive perfecto se vuelve más fácil de leer sin tocar esta spec.
- Ideas para después (fuera de alcance): cartas que mejoren el esquive perfecto (más tiempo lento, Instinto con más daño), el esquive "hacia afuera" (pregunta 8) y vibración háptica en el teléfono.
