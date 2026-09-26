# IA de grupo: turnos de ataque, rodear y aparición con aviso

- **Estado:** Implementada (2026-09-26, 503 tests GdUnit4: 495 en verde y los mismos 8 fallos previos ajenos a esta spec, ver `enemy-attack-telegraph.md`; 0 orphans; tests de niveles y entidades repetidos 3 veces sin fallos intermitentes; import y smoke test de la arena sin errores; capturas del anillo y de la aparición revisadas)
- **Constitución:** `docs/constitution.md` **v4.2.0** → **v4.3.0** (enmienda MINOR, ver abajo)
- **Pilar (Principio I):** Combate + Supervivencia.
  - **Combate:** con turnos de ataque, cada golpe se puede leer aunque haya muchos enemigos. Los que esperan rodean al jugador en vez de apilarse en línea, así que posicionarse importa.
  - **Supervivencia:** la cantidad de atacantes simultáneos crece con las oleadas, y la presión sube sin volverse injusta.
- **Tipo:** feature. Tercera de la hoja de ruta: `enemy-attack-telegraph` → `enemy-types` → **`enemy-group-ai`** → `boss-verdugo` → `boss-titan` → `boss-colmena`.
- **Dependencias:** `enemy-attack-telegraph.md`, `enemy-types.md`.

## Objetivo

1. **Turnos de ataque:** un `AttackCoordinator` reparte *tokens*. Un enemigo solo puede empezar la preparación de un ataque si tiene un token. Hay como máximo `max_attackers` tokens a la vez; entre dos entregas pasa al menos `token_gap`, así que dos golpes no caen en el mismo frame; y el que más tiempo lleva esperando es el primero en recibirlo.
2. **Rodear:** los enemigos cuerpo a cuerpo (Bruto y Escudero) ocupan **lugares alrededor del jugador** en vez de llegar todos por el mismo lado. Todos los enemigos que caminan se **separan** entre sí para no amontonarse.
3. **Aparición con aviso:** los enemigos de una oleada salen del suelo. Durante `spawn_in_time` hay un agujero negro en el piso, el cuerpo y las manos suben desde abajo y el enemigo no se mueve ni ataca.

Los **bosses** (Coloso y Gemelos por ahora) no piden token. Los enemigos creados sin coordinador, como en los tests unitarios, funcionan como hasta ahora.

## Turnos de ataque

- Un enemigo **pide** token cuando podría empezar un ataque: cooldown listo y distancia de su ataque. Hasta recibirlo:
  - **Bruto y Escudero:** esperan en su lugar del anillo de espera, a `attack_range + wait_margin` (1.5 m) del jugador, mirándolo. Con el token se acercan hasta `trigger_range` y atacan.
  - **Embestidor y Saltador:** se quedan en su distancia, mirando al jugador, sin preparar el ataque.
  - **Hostigador:** sigue orbitando. Si ya no tiene la apertura, deja de pedir.
- Si un enemigo deja de estar en condición de atacar (se aleja, lo empujan, cambia de fase), **retira** su pedido.
- Un token se **devuelve** cuando el ataque termina (fin de la recuperación), se cancela, el enemigo muere o se desactiva, o si con el token el enemigo no llega a empezar la preparación en `token_approach_timeout` (2 s).
- **Cantidad:** `max_attackers` = `base_attackers` (2) + 1 cada `waves_per_extra_attacker` (6) oleadas, con tope `max_attackers_cap` (4). Es 2 en las oleadas 1–6, 3 en las 7–12 y 4 desde la 13.
- **Orden:** cola FIFO por el momento del primer pedido. Si se libera un token y pasó `token_gap` (0.35 s) desde la última entrega, lo recibe el primero de la cola.

## Rodear y separarse

- **Anillo:** el coordinador divide el círculo alrededor del jugador en `slot_count` (8) lugares. Un Bruto o Escudero que se acerca pide el lugar libre más cercano a su ángulo actual y camina hacia `jugador + dirección(lugar) × radio`. El radio es `wait_distance` sin token y su `attack_range` con token. Cada `slot_refresh_time` (0.5 s) vuelve a elegir, así sigue al jugador cuando este se mueve. Dos enemigos nunca ocupan el mismo lugar. Si no hay lugar libre, espera en el lugar ocupado más cercano, un paso más afuera (`wait_distance + 1.0 m`).
- **Separación:** al caminar (`Enemy.move_towards`), cada enemigo suma un empuje que lo aleja de los enemigos a menos de `separation_radius` (1.3 m × `body_scale`), con peso `separation_weight`. No se aplica durante cargas, estocadas ni saltos.

## Aparición con aviso

- `WaveManager`, después de `activate()`, llama a `enemy.begin_spawn_in(spawn_in_time)` (0.9 s), en oleadas normales y de boss.
- Mientras dura:
  - el comportamiento está en pausa: no se mueve ni ataca;
  - `SpawnMarker` (disco negro translúcido en el piso, de radio 0.8 m × `body_scale`) crece de 0 a su tamaño;
  - `Body` y `Hands` suben desde `spawn_depth` (2.0 m × `body_scale`) bajo el piso hasta su lugar, con *ease out*.
- El enemigo **cuenta como vivo** (`alive_count`) y **se le puede pegar** mientras aparece. Así se premia al jugador que se anticipa, y los tests de oleadas no cambian.
- Al terminar, el disco se oculta y el comportamiento arranca.
- `activate()` cancela cualquier aparición en curso.

## Enmienda a la constitución (MINOR → 4.3.0)

- **Principio II, colores no reservados:** se registra el **negro translúcido** `Color(0.05, 0.05, 0.05)` con alpha ≤ 0.7 del disco de aparición (`CylinderMesh` plano, unshaded, sobre el piso). El negro no está reservado desde 3.0.0 y un agujero en el piso no se confunde con ningún elemento de la tabla.

## Estructura de nodos

```
arena.tscn
├─ EnemyRegistry, EnemyPool*, BossPool*   (los pools pasan `coordinator` a sus enemigos)
└─ AttackCoordinator (Node, systems/attack_coordinator.gd)        ← nuevo

enemy.tscn
└─ SpawnMarker (MeshInstance3D, CylinderMesh plano, materials/vfx/spawn_marker_material.tres)   ← nuevo
```

## Resources y datos

- **`resources/group_ai_config.gd`** (`GroupAIConfig`), en `data/enemies/group_ai_config.tres`:
  - `base_attackers`, `waves_per_extra_attacker` y `max_attackers_cap`;
  - `token_gap` y `token_approach_timeout`;
  - `wait_margin`, `slot_count` y `slot_refresh_time`;
  - `separation_radius` y `separation_weight`;
  - `spawn_in_time`, `spawn_depth` y `spawn_marker_radius`.
  - Funciones puras: `max_attackers_for(wave) -> int` y `slot_direction(index) -> Vector3`.
- **`EnemyStats.ignores_attack_tokens: bool`**: `true` en `colossus_stats.tres` y `twin_stats.tres`.
- **`materials/vfx/spawn_marker_material.tres`**: negro, alpha 0.7, unshaded, transparente.

## Interfaz pública

- **`AttackCoordinator`** (`@export config: GroupAIConfig`, `registry`, `run_state`, `player`):
  - `request_token(enemy) -> bool`: `true` si ya lo tiene o si se lo entrega ahora. Si no, lo encola.
  - `withdraw(enemy)`, `release_token(enemy)`, `has_token(enemy)` y `get_holder_count()`.
  - `claim_slot(enemy) -> int`, `free_slot(enemy)` y `slot_position(index, radius) -> Vector3`.
  - `separation_for(enemy) -> Vector3`.
  - `advance(delta)`: temporizadores de `token_gap` y `token_approach_timeout`. Escucha `registry.enemy_killed` y la desactivación para liberar tokens y lugares.
- **`Enemy`:**
  - `@export var coordinator: AttackCoordinator`, que puede ser null.
  - `begin_spawn_in(duration)` e `is_spawning_in()`.
  - `can_start_attack() -> bool`: pide token, o devuelve `true` si no hay coordinador o si el tipo ignora los tokens.
  - `end_attack()`: devuelve el token.
- **`EnemyBehavior`:** cada comportamiento llama a `can_start_attack()` antes de entrar en preparación y a `end_attack()` al volver a su fase inicial. `MeleeBehavior` y `ShieldbearerBehavior` caminan hacia su lugar del anillo en vez de ir al jugador.
- **`EnemyPool`:** `@export var coordinator`, que asigna a cada enemigo.

## Criterios de aceptación (AC440–AC457, reservados)

**Tokens** (`test/systems/attack_coordinator_test.gd`):
- **AC440:** con `max_attackers` 2, un tercer pedido se niega hasta que se devuelve un token.
- **AC441:** después de una entrega, la siguiente espera `token_gap` aunque haya tokens libres.
- **AC442:** los tokens se entregan en el orden del primer pedido (FIFO). Un pedido retirado sale de la cola.
- **AC443:** el token se libera al terminar o cancelar el ataque, al morir o desactivarse el enemigo, y a los `token_approach_timeout` si el enemigo no empezó la preparación.
- **AC444:** `max_attackers_for`: 2 en las oleadas 1 y 6, 3 en la 7, 4 en la 13 y 4 en la 40.
- **AC445:** un enemigo con `ignores_attack_tokens` ataca sin pedir y no ocupa token.

**Comportamiento con coordinador** (`test/entities/enemy/group_ai_test.gd`):
- **AC446:** con 4 Brutos alrededor del jugador, en 6 s nunca hay más de `max_attackers` en `WINDUP`/`ACTIVE` a la vez, y todos atacan al menos una vez.
- **AC447:** un Bruto sin token se queda a `wait_distance` ± 0.5 m del jugador, mirándolo, sin atacar.
- **AC448:** sin token, el Embestidor y el Saltador no empiezan la preparación y el Hostigador sigue orbitando.
- **AC449:** sin coordinador, los comportamientos atacan como antes (los tests de `enemy-attack-telegraph` y `enemy-types` siguen en verde sin cambios).

**Rodear y separarse:**
- **AC450:** 4 Brutos que aparecen del mismo lado terminan repartidos: a los 3 s, la separación angular mínima entre ellos es ≥ 0.8 × 360° / `slot_count`.
- **AC451:** dos enemigos nunca ocupan el mismo lugar. Uno que muere o se desactiva lo libera.
- **AC452:** dos Brutos que arrancan a 0.2 m uno del otro quedan a ≥ 0.8 × `separation_radius` después de 1 s de caminar.

**Aparición** (`test/entities/enemy/spawn_in_test.gd` y `test/levels/arena_waves_test.gd`):
- **AC453:** durante la aparición el enemigo no se mueve ni ataca, `SpawnMarker` está visible y el cuerpo está por debajo de su posición de reposo.
- **AC454:** a los `spawn_in_time`, el marcador se oculta, el cuerpo y las manos están en su lugar y el comportamiento arranca.
- **AC455:** mientras aparece, cuenta en `alive_count` y recibe daño.
- **AC456:** en la arena, los enemigos de una oleada normal y los de una de boss arrancan apareciendo.
- **AC457:** `activate()` durante una aparición la cancela y deja el cuerpo en su lugar.

## Plan de implementación

1. Reservar AC440–AC457 en `CLAUDE.md` (próximo libre → AC458).
2. `GroupAIConfig` y su `.tres`. Test AC444.
3. `AttackCoordinator`: tokens, cola, lugares y separación. Tests AC440–AC443, AC445 y AC451.
4. `Enemy`: `coordinator`, `can_start_attack` y `end_attack`, y la separación en `move_towards`. `EnemyPool.coordinator` y el nodo en `arena.tscn`.
5. Integrar los tokens en `MeleeBehavior`, `ShieldbearerBehavior`, `ChargerBehavior`, `LeaperBehavior` y `HarasserBehavior`, y el anillo en los dos cuerpo a cuerpo. Tests AC446–AC450 y AC452.
6. Aparición: `SpawnMarker`, material, `begin_spawn_in` y la llamada en `WaveManager`. Enmienda de la constitución (4.3.0). Tests AC453–AC457.
7. Suite completa (los tests de niveles, 3 veces), smoke test y captura (anillo de espera y aparición). Checklist, spec **Implementada** y `CLAUDE.md`.

## Review (checklist de la constitución)

- [x] **I.** Combate y Supervivencia, como se explica arriba.
- [x] **II.** El disco es un `CylinderMesh` con material `.tres` compartido y sin shaders; el negro queda registrado en 4.3.0.
- [x] **III.** Todos los números en `group_ai_config.tres`. `max_attackers_for` y `slot_direction` son puros.
- [x] **IV.** Tipado estático.
- [x] **V.** No se asigna memoria por frame: la cola y los lugares son arrays reutilizados, la separación recorre la lista del registro sin copiarla y el disco existe en cada enemigo del pool.
- [x] **VI.** Sin input nuevo.

## Notas

- Los números (2 atacantes, 0.35 s, 8 lugares, 0.9 s de aparición) son un punto de partida. Se ajustan en `group_ai_config.tres`.
- Los bosses de `boss-verdugo`, `boss-titan` y `boss-colmena` definirán en su spec si piden token. La Colmena, por ejemplo, podría hacer que sus esbirros sí lo pidan.

### Implementación: ajustes respecto de lo aprobado

- **Valores nuevos en `GroupAIConfig`** (antes eran constantes, y el Principio III no las permite):
  - `arrive_tolerance` (0.25 m): a qué distancia de su lugar un enemigo en espera deja de caminar.
  - `overflow_step` (1.0 m): el paso extra del anillo cuando no hay lugar libre.
  - `spawn_marker_grow_time` (0.25 s): el agujero llega a su tamaño completo en ese tiempo y no durante toda la aparición. Así el aviso se lee antes de que salga el cuerpo; en la primera captura quedaba chico y tapado por el cuerpo.
- **Con token, el cuerpo a cuerpo va directo al jugador** y no a su lugar del anillo. Con `attack_range` = `trigger_range` (Bruto), el lugar podía quedar apenas fuera de rango y el enemigo se trababa hasta perder el token.
- **`Enemy.walk()`:** camina con separación y sin girar; `move_towards()` es `walk()` + `face()`. El Escudero y los enemigos en espera usan `walk()` para seguir mirando al jugador.
- **Retirar pedidos:** además de `withdraw()`, un pedido que no se renueva en `AttackCoordinator.STALE_REQUEST_FRAMES` (2) frames de física sale solo de la cola. Por eso los comportamientos no necesitan retirar su pedido a mano cuando dejan de poder atacar. Es una constante estructural (frames de tolerancia), no de diseño.
- **Captura:** en la escena de prueba el piso no tiene malla, así que el cuerpo se ve bajo el agujero. En la arena el piso lo tapa.

## Modificada después del cierre

- **2026-09-26, `enemy-level-pace.md`:** un turno devuelto después de un ataque que empezó descansa `rest_for(nivel, rage)` (1.5 s a nivel 1, 0.5 s a nivel 25, mínimo 0.3 s) antes de volver a entregarse. Los atacantes simultáneos dependen del Rage desde `enemy-pace.md`.
