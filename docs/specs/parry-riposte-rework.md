# Feature: Parry (ex Parada) con estocada, Estocada mejorada de 360° y Duelo más largo

- **Estado:** Implementada (2026-09-28). ACs: AC1017–AC1032.
- **Constitución:** `docs/constitution.md` v4.22.1 → **enmienda MINOR a 4.23.0** (ver §8).
- **Pilar (Principio I):** **combate.**
  - Hoy una parada exitosa solo anula el daño: la recompensa por leer el golpe llega recién con las mejoras doradas.
  - Con este cambio, toda parada exitosa responde con una estocada, así que leer el golpe siempre paga.
  - Contragolpe pasa a ser el momento culminante de la clase: el tiempo se congela y el Guerrero barre a todos a su alrededor.
  - La animación del escudo, instantánea y exagerada, hace legible el instante exacto de la parada.
- **Pedido del responsable (2026-09-28):**
  1. la habilidad pasa a llamarse **Parry**;
  2. al apretar, el escudo aparece al frente de golpe (como si mano y escudo se teletransportaran), con dinamismo, y el escudo crece;
  3. toda parada exitosa golpea con la **estocada**;
  4. **Contragolpe** mejora la estocada a la **Estocada mejorada**:
     - el tiempo se congela, con zoom y sacudida;
     - un golpe de 360° con +30 % del alcance: la espada va del hombro izquierdo a detrás del hombro derecho, el cuerpo inclinado adelante y la mirada abajo, con VFX de corte circular;
     - cuenta como ataque básico;
     - con Duelo aplica Retado y, si mata, da Triunfo;
     - el Guerrero es inmortal durante la animación;
  5. **Duelo:** Retado dura 10 s y Triunfo 15 s, con hasta 5 stacks;
  6. **Represalia** se elimina.
- **Decisiones del responsable (2026-09-28):**
  - la estocada base deja el enfriamiento en **1.5 s** y es **invulnerable**, como el Contragolpe de hoy;
  - Contragolpe **sigue renovando el enfriamiento** (queda en 0);
  - el golpe de 360° hace **daño de ataque básico × 1.5**;
  - el escudo crece **×1.35** (con un rebote a ×1.5) y el congelamiento dura **0.3 s**.
- **Dependencias:**
  - `warrior-abilities-rework.md` (la Parada, §3.2 y §5.2; AC830–AC840);
  - `warrior-sword-and-shield.md` (escudo en `wrist_l`, AC750 y AC751);
  - `bdo-combat-feel.md` (hit lag local, Principio VII);
  - `affliction.md` (fuentes: ataque básico o habilidad).

## 1. Estado actual (verificado sobre el working tree)

- `data/abilities/parry/parry.tres` se llama "Parada":
  - ventana de 0.35 s y enfriamiento de 5 s;
  - la estocada de Contragolpe: `base_damage` 20 + `attack_scaling` 0.30, rectángulo de 3 × 1.2 m;
  - tres mejoras únicas: `retribution` (Represalia), `riposte` (Contragolpe) y `duel` (Duelo).
- `ParryAbility` tiene los estados `WINDOW`, `SUCCESS`, `WHIFF` y `RIPOSTE`:
  - sin Contragolpe, un bloqueo deja 1.5 s de enfriamiento y hace un empujón del escudo (`shield_parry_success`);
  - con Contragolpe, renueva el enfriamiento y hace la estocada (`shield_riposte`, 0.5 s, invulnerable).
- `shield_parry` arranca en el reposo y llega a la pose de bloqueo en 0.06 s. El escudo no cambia de tamaño.
- `challenged.tres` ya dura 10 s, pero la descripción de Duelo dice 6 s. `triumph.tres` tiene 3 stacks y 10 s.
- El hit lag es local: se congela a los golpeados. La constitución prohíbe tocar `Engine.time_scale` (Principio VII).

## 2. Diseño

### 2.1 Nombre

- `parry.tres` pasa a llamarse **"Parry"** (`title`), y su descripción se reescribe.
- Las descripciones de Contragolpe y Duelo dicen "tu Parry".
- Retado, Triunfo, Contragolpe y Duelo conservan su nombre.

### 2.2 El escudo aparece al frente (animación)

- **Instantáneo:** `shield_parry` arranca **ya en la pose de bloqueo** (t = 0), y `PlayerAnimator` entra al clip **sin mezcla** (`ParryConfig.parry_enter_blend` = 0). Al cuadro siguiente de apretar, el escudo ya está al frente: se lee como un salto.
- **Dinamismo:** el cuerpo acusa el golpe del propio escudo:
  - t = 0: pose de bloqueo con el torso sobregirado, la cadera 4 cm más baja y el escudo **pasado de largo** (≥ 5 cm más adelante que su pose final);
  - t ≈ 0.06 s: vuelve y se asienta;
  - hasta el final de la ventana: firme, con un temblor leve de la cadera.
- **El escudo crece** (solo visual, sin cambiar el arco ni la reducción del bloqueo):
  - pasa de ×1.0 a **×1.5** en 0.04 s, se asienta en **×1.35** a los 0.1 s y se mantiene hasta que el escudo baja;
  - al bajar (fin de la ventana, estocada, fallo o dash) vuelve a ×1.0 en **0.12 s**;
  - la escala pivota sobre el `Grip`, así la mano sigue sosteniendo el escudo (AC750 sigue en ≤ 1 mm);
  - los tiempos y escalas viven en `ParryConfig` (`shield_pop_scale`, `shield_hold_scale`, `shield_pop_time`, `shield_settle_time`, `shield_shrink_time`);
  - `ShieldGuard` recibe una referencia al nodo del escudo (`Player` se la pasa al equipar), y `ParryAbility` le aplica la escala en `channel()`.

### 2.3 Parada exitosa = estocada (sin mejoras)

- El primer golpe anulado de cada uso dispara la **estocada** (la del Contragolpe de hoy):
  - hacia el atacante, en el rectángulo de 3 × 1.2 m;
  - `base_damage` + `attack_scaling` × daño, con crítico y empuje;
  - 0.5 s, **invulnerable**, con la estela solo mientras la hoja avanza;
  - cuenta como daño de **habilidad**, como hoy.
- El enfriamiento que queda baja a **1.5 s** (la regla de la parada exitosa de hoy). Se reemplazan el resto de la ventana y el empujón: el estado `SUCCESS` y el clip `shield_parry_success` se borran.
- La parada fallida no cambia.

### 2.4 Contragolpe: la Estocada mejorada

Con Contragolpe, el primer golpe anulado de cada uso **renueva el enfriamiento** (queda en 0) y dispara la **Estocada mejorada**, en lugar de la estocada:

| Tiempo desde el bloqueo | Qué pasa |
|---|---|
| 0 – 0.3 s | **Tiempo congelado:** todos los enemigos activos, bosses incluidos, quedan congelados (comportamiento, empuje y temporizadores de ataque en pausa, sin sacudida). La cámara hace un zoom corto (`kick_fov`, −8°) y una sacudida (0.6). El Guerrero salta a la **preparación**: inclinado adelante (≥ 20°), la mirada abajo, la espada cruzada sobre el hombro izquierdo y el escudo recogido |
| 0.3 – 0.55 s | **El golpe:** la espada barre en horizontal desde el hombro izquierdo, por delante, hasta detrás del hombro derecho (≥ 200° alrededor del cuerpo), con el torso girando. El **VFX de corte circular** recorre 360° alrededor del Guerrero. El daño cae en **t = 0.42 s** |
| 0.55 – 0.9 s | Recuperación al reposo |

- **Daño:** a **todos** los enemigos activos a menos de `ATTACK_RANGE × 1.3` (más su radio), **en cualquier dirección**, una sola vez.
- **Cuenta como ataque básico:**
  - daño = `1.5 ×` el daño de un golpe del combo (stat `DAMAGE`, `DAMAGE_BONUS` y crítico);
  - se cura por robo de vida;
  - emite `AttackComponent.enemy_hit` y `attacked`, así que carga las **Aflicciones de ataque básico** (no las de habilidad) y usa el hit lag y los impactos del ataque básico;
  - se hace con un método nuevo, `AttackComponent.strike_enemies(enemies, damage_multiplier, knockback_multiplier)`, la misma cuenta que `_strike()`.
- **Con Duelo:** cada enemigo alcanzado queda **Retado antes del daño**. Así, si el golpe lo mata, muere Retado y da un stack de **Triunfo** (el mismo `_on_challenged_killed` de hoy).
- **Inmortal:** invulnerable desde el bloqueo hasta el final del lanzamiento (0.9 s). El dash **no** corta el congelamiento ni el golpe (0 – 0.55 s); en la recuperación, sí.
- Todos los tiempos, el ×1.3, el ×1.5, el zoom y la sacudida viven en `ParryConfig`.

### 2.5 El congelamiento del mundo

- **No toca `Engine.time_scale`:** el jugador, la cámara y los VFX siguen andando.
- `Enemy.freeze_time(seconds)`: congela como el hit lag (comportamiento y empuje en pausa, reinicia y no suma) pero **sin sacudida** y **también en los bosses** (ignora `resists_hitlag`).
- Lo recorre `ParryAbility` sobre `registry.get_active()`, con un buffer reutilizado.
- Necesita la enmienda del Principio VII (§8).

### 2.6 VFX de corte circular (`CircleSlashVfx`)

- Una **cinta horizontal** alrededor del Guerrero, a la altura de la espada, con radio igual al del golpe.
- Barre 360° en 0.25 s, sincronizada con el golpe; la cola se desvanece.
- Se construye con `ImmediateMesh` desde buffers preasignados, como la estela del arma (Principio II, VFX que siguen una trayectoria).
- **Blanco translúcido**, unshaded, alpha ≤ 0.5 en la cabeza y 0 en la cola, con un material `.tres` compartido.
- Sus parámetros (segmentos, ancho, altura, alpha, duración y desvanecimiento) viven en `CircleSlashVfxConfig`.
- Un nodo por habilidad, prearmado en `parry_ability.tscn`: no se instancia en combate.

### 2.7 Duelo y Triunfo

- **Retado:** 10 s (`challenged.tres` ya dice 10; se corrige la descripción).
- **Triunfo:** **15 s** y hasta **5 stacks** (`triumph.tres`). Siguen igual:
  - +10 % de velocidad y +10 % de daño por stack;
  - cada muerte de un Retado suma un stack y reinicia el tiempo;
  - al vencer se pierden todos los stacks juntos.

### 2.8 Represalia se elimina

- Se borran `data/abilities/parry/unique/retribution.tres`, la constante y la función `_retaliate()` de `ParryAbility`.
- `parry.tres` queda con **Contragolpe** y **Duelo**.

## 3. Resources y datos

| Archivo | Cambio |
|---|---|
| `data/abilities/parry/parry.tres` | `title` "Parry", descripción nueva, sin Represalia |
| `resources/parry_config.gd` y `parry_config.tres` | + `parry_enter_blend`, escala del escudo (`shield_pop_scale` 1.5, `shield_hold_scale` 1.35, `shield_pop_time` 0.04, `shield_settle_time` 0.1, `shield_shrink_time` 0.12) y Estocada mejorada (`empowered_freeze` 0.3, `empowered_hit_time` 0.42, `empowered_duration` 0.9, `empowered_dash_lock` 0.55, `empowered_range_scale` 1.3, `empowered_damage_multiplier` 1.5, `empowered_knockback_multiplier`, `empowered_zoom_deg` 8, `empowered_zoom_return` 0.3, `empowered_shake` 0.6, `empowered_body_clip` `shield_riposte_empowered`, `empowered_trail_start`/`_end`, `empowered_slash_vfx`); se borran `success_recovery` y `success_body_clip` |
| `data/abilities/parry/unique/riposte.tres` | descripción: renueva el enfriamiento y la estocada pasa a ser la Estocada mejorada |
| `data/abilities/parry/unique/duel.tres` | descripción: 10 s, 15 s, 5 stacks, y la Estocada mejorada también reta |
| `data/buffs/triumph.tres` | `max_stacks` 5, `stack_duration` 15 |
| `data/abilities/parry/circle_slash_vfx_config.tres`, `materials/vfx/circle_slash_material.tres` | nuevos (§2.6) |
| `data/abilities/parry/unique/retribution.tres` | se borra |

## 4. Interfaz pública

```gdscript
# AttackComponent
## Hits `enemies` as a basic-attack strike: damage_multiplier × the combo damage
## (crit, bonus), knockback, lifesteal; emits enemy_hit and attacked. Returns the total.
func strike_enemies(enemies: Array[Enemy], damage_multiplier: float, knockback_multiplier: float) -> float

# Enemy
## Freezes the enemy (behavior, push, attack timers) for `seconds`, bosses too, without shaking.
func freeze_time(seconds: float) -> void
func is_time_frozen() -> bool

# ShieldGuard
var shield: Node3D            # set by Player when the class has a shield
func set_shield_scale(scale: float) -> void   # pivots on the shield's Grip

# CircleSlashVfx
func play(center: Node3D, radius: float) -> void
func is_playing() -> bool

# ParryAbility.State: IDLE, WINDOW, WHIFF, RIPOSTE, EMPOWERED   (SUCCESS se borra)
```

`AbilityBehavior` gana `get_body_clip_blend(ability) -> float` (por defecto, la mezcla de siempre). La Parry devuelve `parry_enter_blend` en la ventana, y `PlayerAnimator` la usa al entrar al clip del cuerpo.

## 5. Criterios de aceptación (AC1017–AC1032)

**Nombre y escudo**

- **AC1017** `parry.tres` se llama "Parry"; ningún `.tres` de `data/` dice "Parada" ni nombra a Represalia.
- **AC1018** Aparece de golpe: al apretar, `PlayerAnimator` entra al clip sin mezcla y, en el primer cuadro animado (≤ 1/60 s), el `Center` del escudo está a ≤ 15 cm de su posición en la pose de bloqueo (el resto es el rebote de AC1019), que queda a > 30 cm del reposo. *(Ajustado al implementar, §11.)*
- **AC1019** Dinamismo: entre 0 y 0.06 s de `shield_parry`, el `Center` del escudo llega ≥ 5 cm más adelante (−Z) que su posición a los 0.15 s.
- **AC1020** El escudo crece:
  - escala ×1.5 (±0.02) a los 0.04 s y ×1.35 (±0.01) desde los 0.1 s hasta el final de la ventana;
  - vuelve a ×1.0 (±0.01) a ≤ 0.12 s de bajar el escudo (fin de la ventana, estocada, fallo o dash);
  - durante todo eso, la mano izquierda sigue sobre el `Grip` (≤ 1 mm).
- **AC1021** Solo visual: con el escudo en ×1.35 el bloqueo anula exactamente lo mismo (arco de `guard_arc_degrees`, reducción de `block_reduction`) que con ×1.0.

**Estocada base**

- **AC1022** Sin mejoras, el primer golpe anulado dispara la estocada:
  - daña a un enemigo dentro del rectángulo de 3 × 1.2 m (`base_damage` + `attack_scaling` × daño) y lo empuja;
  - el jugador es invulnerable los 0.5 s de la estocada;
  - el enfriamiento que queda es 1.5 s (±1 cuadro);
  - el daño se reporta como de habilidad (`AbilityComponent.enemy_hit`).
- **AC1023** Ya no existe el estado `SUCCESS` ni el clip `shield_parry_success`; la parada fallida sigue igual (AC832).

**Estocada mejorada**

- **AC1024** Con Contragolpe, el primer golpe anulado deja el enfriamiento en 0, pasa al estado `EMPOWERED` y el jugador es invulnerable desde el bloqueo hasta el final del lanzamiento (0.9 s). Un golpe recibido en ese lapso hace 0 de daño.
- **AC1025** Tiempo congelado:
  - durante 0.3 s todos los enemigos activos, bosses incluidos, están congelados: su posición y el temporizador de su ataque no avanzan;
  - la cámara hace un `kick_fov` de −8° y una sacudida de 0.6;
  - `Engine.time_scale` sigue en 1.
- **AC1026** El golpe de 360°: en t = 0.42 s, cada enemigo activo a ≤ `ATTACK_RANGE × 1.3` (más su radio), en cualquier dirección (adelante, al costado y atrás), recibe un golpe; uno apenas más lejos, no. Cada enemigo recibe un solo golpe.
- **AC1027** Cuenta como básico:
  - el daño es `1.5 ×` el de un golpe del combo con los mismos stats (sin crítico para el test);
  - el robo de vida cura;
  - se emiten `AttackComponent.enemy_hit` y `attacked`, y **no** `AbilityComponent.enemy_hit`.
- **AC1028** Con Duelo, cada enemigo alcanzado queda Retado; uno que muere por el golpe da un stack de Triunfo.
- **AC1029** La animación (`shield_riposte_empowered`, en el espacio del `Visual`):
  - en la preparación, la mano derecha está a la izquierda del torso (x < −0.05 m) y a ≥ 1.1 m de alto, el torso inclinado ≥ 20° adelante y la cabeza mirando abajo (≥ 15°);
  - en el golpe, la punta de la espada gira ≥ 200° alrededor del eje vertical, de izquierda-adelante a atrás-derecha, sin subir ni bajar más de 0.3 m;
  - la estela emite solo durante el barrido;
  - termina en el reposo (AC754);
  - la hoja no atraviesa el cuerpo (AC653) y el escudo cumple AC751.
- **AC1030** El VFX de corte circular:
  - se enciende con el golpe y recorre 360° en 0.25 s (±1 cuadro), con radio igual al del golpe;
  - material compartido, blanco, unshaded, alpha ≤ 0.5;
  - sin allocations por cuadro (buffers preasignados) y un solo nodo por habilidad.

**Duelo, datos y limpieza**

- **AC1031** `challenged.tres` dura 10 s; `triumph.tres` tiene `max_stacks` 5 y `stack_duration` 15; cinco muertes de Retados dan 5 stacks y la sexta no suma más; al vencer se pierden todos.
- **AC1032** Represalia no existe:
  - ni el `.tres` ni `RETRIBUTION` en el código;
  - `parry.tres` ofrece solo Contragolpe y Duelo;
  - pasan `parry_test` (adaptado), `unique_upgrades_test`, `unique_upgrade_run_test`, `boss_challenge_run_test`, `warrior_sword_and_shield_test`, `class_combat_identity_test`, `attack_component_test`, `hitstop_test`, `player_animator_test` y `affliction_loadout_test`, salvo los fallos previos registrados;
  - import y smoke test del arena sin errores ni warnings.

**Próximo libre después de esta spec: AC1033.**

## 6. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC1017–AC1032 en `CLAUDE.md` y la enmienda 4.23.0.
2. **Datos y limpieza:** nombre "Parry", descripciones, Duelo y Triunfo, y se borra Represalia (código, `.tres` y tests).
3. **Estocada base:** el bloqueo sin mejoras dispara la estocada; se borran `SUCCESS` y su clip. Tests de AC1022 y AC1023.
4. **Escudo:** `ShieldGuard.shield` y la escala con pivote en el `Grip`; `shield_parry` nuevo (arranque instantáneo, rebote) y la mezcla 0. Hoja de capturas de la parada cuadro a cuadro. **Te la muestro.**
5. **Estocada mejorada:**
   - `Enemy.freeze_time()`, `AttackComponent.strike_enemies()`, el estado `EMPOWERED`, el zoom y la sacudida;
   - el clip `shield_riposte_empowered` calculado con el script de brazos (preparación sobre el hombro izquierdo y barrido de ≥ 200°);
   - `CircleSlashVfx` y su material.
   - Hoja de capturas del golpe cuadro a cuadro, con el VFX. **Te la muestro.**
6. **Tests:** AC1017–AC1032 en `test/components/abilities/parry_rework_test.gd`, y adaptación de `parry_test` y de los tests de Represalia; solo esas suites y las de AC1032.
7. **Cierre:** notas, constitución, `CLAUDE.md`, y `warrior-abilities-rework.md` marcado como revisado en §3.2.

## 7. Tests que cambian

- `parry_test`: los casos de la parada exitosa con empujón (`SUCCESS`) pasan a la estocada base; los de Represalia se borran; los de Contragolpe pasan a la Estocada mejorada.
- `unique_upgrades_test`, `unique_upgrade_run_test` y `boss_challenge_run_test`: los casos que usan Represalia pasan a Contragolpe o Duelo, o se borran si solo probaban Represalia.
- Cualquier test con "Parada", 3 stacks o 8 s de Triunfo fijos.

## 8. Constitución: enmienda MINOR 4.23.0

1. **Principio VII**, después de "Hit lag local":
   > **Tiempo congelado** (desde 4.23.0): un remate excepcional, definido en datos (hoy solo la Estocada mejorada de Contragolpe), puede congelar a todos los enemigos activos (bosses incluidos) durante una fracción de segundo, sin tocar `Engine.time_scale`: el jugador, la cámara y los VFX siguen animándose. Sigue prohibido modificar `Engine.time_scale`.
2. **Principio II, tabla de colores:** fila nueva: "Corte circular (VFX de la Estocada mejorada): cinta horizontal procedural (`ImmediateMesh`) | **Blanco translúcido** `Color(1, 1, 1)`, unshaded, alpha ≤ 0.5 en la cabeza y 0 en la cola". Se suma a la lista de elementos que comparten el blanco (es una franja translúcida que se desvanece en décimas de segundo, como la estela).

## 9. Riesgos

- **Congelar bosses:** rompe por 0.3 s la regla de que "los bosses solo tiemblan". Es breve y excepcional, pero si se siente mal se puede excluir a los bosses con un dato (`freezes_bosses`).
- **La escala del escudo ×1.5 frente al cuerpo** puede tapar la vista en la cámara del juego. La revisa la hoja de capturas; la escala es un dato.
- **Inmortal 0.9 s y enfriamiento renovado** pueden encadenarse contra grupos grandes. Es el mismo riesgo del Contragolpe de hoy, y cada uso exige leer un golpe nuevo.
- **"Cuenta como ataque básico"** carga las Aflicciones del combo con un golpe a muchos enemigos. Es buscado: se nota como recompensa.

## 10. Checklist de review de la constitución (se completa al cerrar)

- [x] I. Pilar declarado (combate).
- [x] II. VFX con `ImmediateMesh` y buffers preasignados, material compartido, blanco translúcido registrado.
- [x] III. Todos los tiempos, escalas y multiplicadores en `ParryConfig`, `triumph.tres` y `challenged.tres`.
- [x] IV. Tipado estático, identificadores en inglés, callbacks delgados.
- [x] V. Sin allocations por cuadro (buffers de enemigos y del VFX reutilizados).
- [x] VI. Sin input nuevo.
- [x] VII. Tiempo congelado sin `Engine.time_scale` (enmienda 4.23.0).

## 11. Notas de implementación (2026-09-28)

- **Escudo:**
  - `ShieldGuard` recibe el nodo del escudo (lo asigna `Player` al equiparlo) y anima su escala en su propio `_process` (`pop_shield()`, `shrink_shield()`, `advance_shield()`). Así el escudo vuelve a ×1.0 aunque el lanzamiento se corte con un dash. La escala pivota sobre el `Grip`;
  - `shield_parry` arranca con el brazo del escudo pasado de largo hacia adelante (hombro 90°, codo 30°) y se asienta a los 0.06 s. El evento `raise` pasó a t = 0 y `raise_time` a 0.
- **AC1018 ajustado:** la versión aprobada pedía ≤ 3 cm de la pose de bloqueo en el primer cuadro, lo que contradice el rebote de AC1019 (≥ 5 cm adelante). Quedó en ≤ 15 cm (el primer cuadro está a 12 cm) y a > 30 cm del reposo.
- **Estocada mejorada:**
  - `Enemy.freeze_time()` corre antes del hit lag en `_physics_process` y se limpia al activar el enemigo;
  - `AttackComponent.strike_enemies()` recibe además `crit_roll` (como `try_attack_with_roll()`), para que los tests sean deterministas;
  - el hit lag del golpe sale de `empowered_feel` (hitlag 0.1, sacudida 0.4): como no hay un paso del combo en curso, `HitstopComponent` no lo tomaría de `attacked`;
  - `AbilityComponent` gana `attack` (conectado en `player.tscn`), y `AbilityBehavior` gana `get_body_clip_blend()` y `locks_dash()`.
- **Animación** (`shield_riposte_empowered`, calculada con el script de brazos encadenando cada pose con la anterior):
  - arranca **ya en la preparación** y se entra sin mezcla, como el escudo. Pasar del bloqueo a la preparación en 0.08 s hacía que el mango cruzara la cabeza (AC653);
  - el barrido recorre **219°** entre 0.3 y 0.55 s, con la punta entre 1.04 y 1.27 m de alto. Hizo falta una pose intermedia a 0.33 s: sin ella, la punta subía 70 cm al salir del hombro.
- **Captura en vivo** (arena, cuatro Brutos alrededor): el anillo recorre la vuelta, los cuatro reciben 30 de daño (20 × 1.5) con su impacto, y el congelamiento se ve en los primeros cuadros.
- **Tests:**
  - `parry_rework_test` (17 casos, AC1017–AC1032) y `parry_test` (11), en verde;
  - regresión de AC1032: `unique_upgrades_test` (4), `unique_upgrade_run_test` (5), `warrior_abilities_test` (5), `class_combat_identity_test` (25), `hitstop_test` (6) y `player_animator_test` (13), en verde;
  - smoke test del arena sin errores ni warnings.
- **Tests adaptados:**
  - `parry_test`: AC829 (el arco se lee del dato, 180° hoy, y el golpe lateral va antes que el frontal, porque este dispara la estocada invulnerable), AC831 (el éxito pasa a la estocada), AC836 (sin Contragolpe, la estocada deja 1.5 s de enfriamiento), AC837 (la estocada base es invulnerable), AC838 (cada parada marca a un atacante; Triunfo llega a 5) y AC846 (una chispa por parada). Se borró AC835 (Represalia);
  - `unique_upgrade_run_test`: la run equipa la Carga de escudo. Contundencia (2 niveles) reemplaza a Represalia en los casos con niveles, e Impulso a Contragolpe en los binarios;
  - `boss_challenge_run_test` y `unique_upgrades_test`: sin Represalia;
  - `warrior_abilities_test` AC847 y `warrior_sword_and_shield_test` AC848: `shield_parry_success` pasa a `shield_riposte_empowered`, con sus eventos.
- **Fallos previos y ajenos** (datos cambiados por otras sesiones):
  - `attack_component_test` AC8 (stats del Guerrero);
  - `affliction_loadout_test` AC942 (Frost dura 3.5 s);
  - `boss_challenge_run_test` AC146 (bosses cada 12 oleadas);
  - `warrior_sword_and_shield_test` AC751 en los clips de dash y sprint (ya registrado en AC848).
