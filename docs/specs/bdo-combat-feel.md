# Feature: sensación de combate estilo BDO

- **Estado:** Implementada e incorporada a `main` (2026-09-26), tras probarla jugando en la PoC (rama `poc/bdo-combat-feel`, ya integrada). Rige la iteración 3 (§7) sobre las anteriores. Tests: solo las suites de esta spec y las que toca (a pedido del responsable), ver §5, §6.5 y §7.4. Import y smoke test del arena sin errores ni warnings.
- **Constitución:** `docs/constitution.md` v4.9.0 → **v4.10.0** (enmienda MINOR aplicada: nuevo Principio VII, *Sensación del combate*).
- **Pilar (Principio I):** combate. Cada golpe del combo compromete al jugador, avanza con la espada, se siente al impactar (el atacante y el golpeado se frenan un instante) y se apunta. Pelear queda más legible y expresivo: golpear al aire tiene costo, y encadenar o cortar el combo es una decisión.
- **Dependencias:** `humanoid-player-model.md` (combo, clips, `HitstopComponent`), Implementada.
- **Reemplaza en parte:** §2.8 de `humanoid-player-model.md`. La ralentización global (`Engine.time_scale`) pasa a ser un hit lag local, así que AC606 queda reemplazado por AC619–AC623 (ver §5).
- **Fuera de alcance:** las habilidades (no tienen compromiso, estocada ni hit lag nuevos), el stagger del remate (ítem E) y el pulso de cámara (ítem F).

## 1. Objetivo

- **Hoy:**
  - Durante un golpe del combo el jugador se mueve libremente con WASD o el stick; el clip de ataque se reproduce mientras el cuerpo se desliza.
  - El golpe no desplaza al personaje.
  - Al impactar se congela **todo el juego** (`Engine.time_scale = 0.05` durante 0.06 s), con el mismo shake en los tres golpes.
  - El golpe apunta al enemigo más cercano, de golpe, y queda fijo.
- **Nuevo:**
  - **A. Compromiso:** desde que empieza el golpe hasta que se abre su ventana de combo (*cancel point*), el input de movimiento y el salto no hacen nada. Después, moverse o saltar corta la recuperación. El dash corta siempre.
  - **B. Estocada:** cada golpe hace avanzar al personaje una distancia de datos, atada al tiempo del clip (como root motion). Se frena ante un enemigo que tiene delante.
  - **C. Hit lag local:** al impactar se pausa el clip del jugador y se congelan los enemigos golpeados, que tiemblan. La duración y el shake de cámara van por golpe (el remate pesa más). `Engine.time_scale` no se toca nunca.
  - **D. Apuntado:** el golpe se orienta según `aim_mode` (enemigo más cercano por defecto, o cámara) y durante la anticipación puede corregirse girando con velocidad limitada. Desde el impacto la orientación queda fija.

## 2. Diseño

### 2.1 Glosario del golpe

Con `attack_1` como ejemplo (tiempos del clip a velocidad 1):

| Tramo | `attack_1` | Qué pasa |
|---|---|---|
| Anticipación | 0.00 → 0.12 | Estocada (B) y giro limitado (D). |
| Impacto | 0.12 (`hit_on`) | Cae el daño y, si pega, el hit lag (C). La orientación queda fija. |
| Comprometido | 0.00 → 0.24 | Estado `STRIKING`: ni moverse ni saltar (A). |
| *Cancel point* | 0.24 (`combo`) | Pasa a `CHAIN_OPEN`: se puede encadenar, moverse o saltar. |
| Recuperación | 0.24 → 0.45 | Moverse o saltar la corta (A). |

### 2.2 A. Compromiso (`Player`, `AttackComponent`)

- `AttackComponent.is_committed() -> bool`: `true` en `STRIKING`.
- `Player._handle_movement`: si `attack.is_committed()`, el cuerpo lo mueve la estocada (`attack.move_body(delta, wish_direction)`, ver §2.3 y §2.5) y el input se ignora.
- En `CHAIN_OPEN`, si el input de movimiento supera `combo.move_cancel_threshold` (magnitud del vector, 0–1) y **no** hay un toque de ataque ese mismo cuadro ni en el buffer, se llama `attack.cancel()` y el jugador se mueve en el mismo cuadro con `MovementComponent.move()`. Un toque de ataque tiene prioridad: encadena.
- `Player._handle_jump`: ignorado si `attack.is_committed()`. En `CHAIN_OPEN`, saltar corta el golpe (`attack.cancel()`) y salta.
- El dash sigue cancelando en cualquier tramo (sin cambios).

### 2.3 B. Estocada (`AttackComponent`, `MovementComponent`)

- **Datos por golpe** (`AttackComboStep`): `lunge_distance` (m), `lunge_start` y `lunge_end` (segundos del clip a velocidad 1).
- **Cálculo, atado al clip:** la distancia recorrida hasta ahora es `lunge_distance × clamp((t − lunge_start) / (lunge_end − lunge_start), 0, 1)`, con `t = humanoid.anim.current_animation_position`. Cada cuadro, la diferencia con el cuadro anterior dividida por `delta` da la velocidad horizontal a lo largo de `get_facing()`. Consecuencias:
  - Con más `ATTACK_SPEED` el clip corre más rápido y la estocada también, pero recorre la misma distancia.
  - Durante el hit lag el clip está en pausa, así que el cuerpo no avanza.
- **Freno:** si algún enemigo activo está delante (dentro de ±`combo.lunge_stop_half_arc` grados del frente) y a una distancia de centro a centro, menos su `get_hit_padding()`, de `combo.lunge_stop_distance` o menos, la velocidad de la estocada es 0. Se recorre `registry.get_active()` sin crear arrays (Principio V).
- **`MovementComponent.drive(horizontal: Vector3, delta: float) -> void`** (nuevo): fija la velocidad horizontal, aplica gravedad y llama `move_and_slide()`, sin girar el visual. Las paredes frenan la estocada solas.
- Sin humanoide (tests unitarios) no hay estocada: el golpe es instantáneo, como hoy.

### 2.4 C. Hit lag local (`HitstopComponent`, reescrito; `Enemy`)

- **Datos por golpe** (`AttackComboStep`): `hitlag` (s, de juego) y `shake_strength` (0–1).
- **`HitstopConfig`** se reescribe: se quitan `duration`, `time_scale` y `shake_strength` (pasan al golpe o dejan de existir) y queda `enemy_shake_amplitude` (m) y `enemy_shake_frequency` (Hz).
- **Jugador:** cuando un golpe pega (`attacked` con `hit_count > 0`), `HitstopComponent` pone `humanoid.anim.speed_scale = 0` durante `step.hitlag` segundos y luego lo devuelve a `attack.get_clip_speed()`. Sacude la cámara con `step.shake_strength`. Si el golpe termina o se cancela antes (`step_ended`: dash, cast, sujeción, muerte), el hit lag se corta al instante sin tocar `speed_scale` (el animador ya pidió otro clip). El reloj es el `delta` de `_physics_process`.
- **Enemigos:** por cada `enemy_hit` del ataque básico se llama `Enemy.apply_hitlag(step.hitlag, config)`:
  - Durante `_hitlag_left` el enemigo no corre su comportamiento ni desliza su empuje. El empuje ya aplicado arranca **después** del congelamiento.
  - `Body` y `Hands` se desplazan de lado con `ShakeState` (amplitud × seno × decaimiento). Al terminar vuelven a su posición de reposo.
  - Un enemigo con `EnemyStats.resists_hitlag = true` (los tres bosses) solo tiembla: su comportamiento sigue, para que el combo no los congele en cadena.
  - `activate()` y `deactivate()` resetean el hit lag (pool).
- `Engine.time_scale` no se modifica en ningún momento.

### 2.5 D. Apuntado (`AttackComponent`)

- **`AttackComboConfig.aim_mode`** (`enum AimMode { NEAREST_ENEMY, CAMERA }`):
  - `NEAREST_ENEMY` (estilo Genshin/WuWa): al empezar el golpe mira al enemigo más cercano, como hoy (sin enemigos, conserva el frente). Durante la anticipación, la dirección de apuntado es la del **input de movimiento** si lo hay (corregir girando), y si no, la de **ese** enemigo (lo sigue si se mueve).
  - `CAMERA` (estilo BDO): al empezar el golpe, el frente pasa a ser el de la cámara (`camera.to_world_direction(Vector2(0, -1))`, plano). Durante la anticipación sigue a la cámara.
- **Giro limitado:** desde que empieza el golpe hasta `hit_on`, el visual gira hacia la dirección de apuntado a como mucho `combo.windup_turn_speed` grados por segundo. Con 0 no gira después del snap inicial. Desde `hit_on` hasta que el golpe termina, el frente queda fijo.
- El input de movimiento llega por `attack.move_body(delta, wish_direction)` (§2.3), que `Player` llama mientras el golpe está comprometido (la anticipación siempre lo está).
- `AttackComponent` recibe `@export var camera: ThirdPersonCamera`. Sin cámara (tests unitarios), `CAMERA` se comporta como `NEAREST_ENEMY`.

### 2.6 Resources (Principio III)

| Resource | Campo nuevo | Valores iniciales |
|---|---|---|
| `AttackComboStep` | `lunge_distance`, `lunge_start`, `lunge_end`, `hitlag`, `shake_strength` | `attack_1`: 0.5 m, 0.00–0.12 s, 0.06 s, 0.2 · `attack_2`: 0.5 m, 0.02–0.14 s, 0.06 s, 0.2 · `attack_3`: 1.0 m, 0.20–0.34 s, 0.12 s, 0.35 |
| `AttackComboConfig` | `aim_mode`, `windup_turn_speed`, `move_cancel_threshold`, `lunge_stop_distance`, `lunge_stop_half_arc` | `NEAREST_ENEMY`, 360 °/s, 0.3, 1.2 m, 60° |
| `HitstopConfig` (reescrito) | `enemy_shake_amplitude`, `enemy_shake_frequency` | 0.06 m, 30 Hz |
| `EnemyStats` | `resists_hitlag` | `true` en `verdugo`, `titan` y `colmena`; `false` (default) en el resto |

La estocada del remate cae durante la bajada de la espada (0.20–0.34 s, antes de `hit_on` a 0.32 s). Todos los campos nuevos son control de sensación, no stats del jugador: no se mejoran con cartas, igual que `AttackComboConfig` hoy.

### 2.7 Decisiones aprobadas

- **D1. `aim_mode` por defecto `NEAREST_ENEMY`** con corrección por input de movimiento (el responsable viene de Genshin/WuWa). `CAMERA` queda disponible para probar la variante BDO cambiando el `.tres`.
- **D2. Los bosses solo tiemblan** (`resists_hitlag`), para que el combo no los frene en cadena.

## 3. Criterios de aceptación (AC611–AC627)

**A. Compromiso**
- **AC611** Con el Guerrero, sin enemigos y con la estocada en 0: durante `STRIKING`, mantener input de movimiento no desplaza al jugador (≤ 0.01 m en XZ).
- **AC612** En `CHAIN_OPEN`, input de movimiento con magnitud > `move_cancel_threshold` termina el golpe (`step_ended`, estado `READY`) y el jugador se desplaza ese mismo cuadro. El próximo toque empieza por `attack_1`.
- **AC613** En `CHAIN_OPEN`, un toque de ataque en el mismo cuadro que el input de movimiento encadena `attack_2` (no cancela).
- **AC614** Saltar durante `STRIKING` no cambia `velocity.y`. Saltar en `CHAIN_OPEN` termina el golpe y salta.
- **AC615** Regresión: el dash corta el golpe en `STRIKING` y en `CHAIN_OPEN`.

**B. Estocada**
- **AC616** Sin enemigos, en el piso: al terminar el clip de `attack_1`, el jugador avanzó `lunge_distance` ± 5 % a lo largo de su frente. Con `ATTACK_SPEED` al doble, la misma distancia.
- **AC617** Con un enemigo delante a una distancia menor que `lunge_stop_distance`, la estocada no desplaza al jugador (≤ 0.01 m). Con el mismo enemigo detrás, la estocada avanza normal.
- **AC618** Un dash durante la estocada la corta: después del dash, el cuerpo solo se mueve por el dash.

**C. Hit lag**
- **AC619** Un golpe que pega pone `speed_scale` del clip en 0 durante `step.hitlag` (±1 cuadro) y después lo vuelve a la velocidad del clip. `Engine.time_scale` es 1 en todo momento.
- **AC620** Un enemigo golpeado (no boss) no se mueve ni avanza su comportamiento durante `step.hitlag`, y su `Body` está desplazado de su reposo. Al terminar, `Body` vuelve al reposo y el empuje recién ahí lo desplaza.
- **AC621** Un golpe al aire no produce hit lag. Un golpe que pega sacude la cámara con el `shake_strength` de su paso (el remate más que el primero).
- **AC622** Un dash durante el hit lag lo corta al instante: el golpe termina y el jugador dashea ese cuadro.
- **AC623** Un boss (`resists_hitlag`) golpeado tiembla, pero su comportamiento avanza durante el hit lag.

**D. Apuntado**
- **AC624** Con `aim_mode = CAMERA` y un enemigo cercano a 90° de la cámara, el golpe empieza mirando hacia la cámara, no al enemigo.
- **AC625** Con `NEAREST_ENEMY`, durante la anticipación, input de movimiento a 90° del frente lo hace girar como mucho `windup_turn_speed × tiempo` (±1°) hacia el input. Desde `hit_on` el frente no cambia aunque el input siga.
- **AC626** Con `aim_mode = NEAREST_ENEMY`, el golpe empieza mirando al enemigo más cercano (los tests de auto-apuntado existentes siguen en verde), y sin input lo sigue durante la anticipación si el enemigo se mueve.

**Regresión**
- **AC627** Pasan los tests de esta spec y las suites que ejercitan código cambiado: `attack_component_test`, `hitstop_test` (reescrito), `humanoid_model_test`, `dash_cancel_test` y `enemy_hit_feedback_test`. Import y smoke test del arena sin errores ni warnings.

**Próximo libre después de esta spec: AC628.**

## 4. Plan de implementación

1. **Reserva:** AC611–AC627 en `CLAUDE.md` (próximo libre → AC628).
2. **Datos:** campos nuevos en `AttackComboStep`, `AttackComboConfig` (con `enum AimMode`) y `EnemyStats`; reescribir `HitstopConfig`. Actualizar `attack_combo_config.tres`, `hitstop_config.tres` y los stats de los tres bosses. `ComboDriver.unit_combo()` pone también la estocada y el hit lag en 0, para que los tests viejos conserven sus posiciones y tiempos.
3. **`MovementComponent.drive()`.**
4. **`AttackComponent`:** `is_committed()`, apuntado (snap y giro limitado hasta `hit_on`), estocada (`move_body`) y export `camera`.
5. **`Player`:** compromiso del movimiento y del salto, cancelación por movimiento en `CHAIN_OPEN`.
6. **Hit lag:** reescribir `HitstopComponent` y agregar `Enemy.apply_hitlag()` con su avance en `_physics_process` (delegado a un método con nombre).
7. **`player.tscn`:** enlazar `camera` en `AttackComponent` y `humanoid` en `Hitstop`.
8. **Tests:** `test/components/combat_feel_test.gd` (AC611–AC626) y adaptar `hitstop_test.gd` (AC606 → AC619–AC623). Correr solo las suites de AC627, import y smoke test del arena.
9. **Cierre:** notas, checklist de review y marca en §2.8 de `humanoid-player-model.md`. Commit en la rama de la PoC.

## 5. Notas

- AC606 (`humanoid-player-model.md`) verificaba la ralentización global, que esta spec elimina a pedido del responsable. Sus tests se reemplazan (no se adaptan) por AC619–AC623.
- **Tests corridos (60 casos):**
  - `combat_feel_test` (14, nuevo) y `hitstop_test` (6, reescrito): en verde.
  - `attack_component_test` (21), `humanoid_model_test` (5) y `enemy_hit_feedback_test` (6): en verde.
  - `dash_cancel_test` (8): falla **AC363** (la katana no vuelve exacto a `rest_position` tras cortar Envainar con un dash; difiere ~0.02). Es un fallo previo y ajeno: ese camino no usa el ataque básico, y sin golpe en curso `Player` se comporta igual que antes de esta spec. Viene de `humanoid-player-model.md` (el arma sigue la mano del humanoide), que no corrió esta suite.
- **Tests adaptados** (sin cambiar lo que verifican):
  - `humanoid_model_test`: los valores de hitstop pasan a `hitlag` y `shake_strength` por golpe, y a `enemy_shake_amplitude`.
  - `attack_component_test` AC601 (DPS del combo contra la cadencia vieja): mide la cadencia de los clips, así que usa una copia del combo con `hitlag = 0`. `_advance_clip` también avanza el hit lag.
  - `ComboDriver`: `unit_combo()` pone `lunge_distance` y `hitlag` en 0, y `advance_until()` avanza el hit lag.
- **Input en tests:** una acción apretada con `Input.action_press` se lee como *just pressed* recién en el cuadro de física siguiente. AC613 aprieta el movimiento un cuadro después del ataque para que ambos lleguen juntos, como en el juego real.
- **Impacto en el balance:** el hit lag pausa el clip del jugador (0.06 + 0.06 + 0.12 s por combo completo), así que el DPS real del combo baja ~13 % si todos los golpes pegan. Se acepta en la PoC; si entra a `main`, se revisa con `boss-health-tuning.md`.

### Review de la constitución (cierre)

- [x] **Identidad (I):** combate (compromiso, estocada, impacto y apuntado).
- [x] **Arte (II):** sin assets ni materiales nuevos; el temblor del enemigo mueve sus primitivas.
- [x] **Datos (III):** todos los valores nuevos están en `AttackComboStep`, `AttackComboConfig`, `HitstopConfig` y `EnemyStats`; ningún Resource compartido se muta en runtime (los tests usan `duplicate(true)`).
- [x] **GDScript (IV):** tipado estático; `_physics_process` de `Enemy` y `HitstopComponent` delegan en métodos con nombre.
- [x] **Performance (V):** sin allocations ni búsquedas por cuadro (el freno de la estocada recorre `registry.get_active()`).
- [x] **Input (VI):** solo acciones del InputMap.
- [x] **Calidad:** import y smoke test sin errores ni warnings. Tests: ver arriba (AC363, fallo previo ajeno).

---

## 6. Iteración 2: pegar hacia el mouse y strafe en la recuperación

- **Estado:** Implementada (2026-09-26), pendiente de prueba jugando.
- **Pedido del responsable:** el golpe tiene que ir hacia donde mira el mouse, aunque apriete A o D para correrse un poco. Hoy A/D giran al personaje y el golpe sale hacia el costado.
- **Causa actual:**
  1. Con `NEAREST_ENEMY`, el input de movimiento desvía la anticipación (§2.5).
  2. En la recuperación, A/D cortan el golpe y el personaje gira hacia donde camina, así que el siguiente golpe sale desde ahí.

### 6.1 Diseño

- **Apuntado nuevo `AimMode.CAMERA_ASSIST`** (default), cámara con imán suave:
  - Al empezar el golpe, la dirección base es el frente de la cámara (mouse).
  - Si hay enemigos vivos a `assist_range` o menos (centro a centro) y a no más de `assist_half_angle` grados de esa dirección, el golpe mira al **más cercano en ángulo** y ese enemigo pasa a ser el objetivo.
  - Durante la anticipación, el giro limitado sigue al objetivo si lo hay, o a la cámara si no. **El input de movimiento nunca desvía el golpe** (lo mismo vale para `CAMERA`).
  - Sin cámara (tests unitarios), se comporta como `NEAREST_ENEMY`.
  - `NEAREST_ENEMY` y `CAMERA` quedan como estaban, para comparar.
- **Movimiento en la recuperación** (`AttackComboConfig.recovery_move`, `enum RecoveryMove { CANCEL, STRAFE }`):
  - `STRAFE` (default): en `CHAIN_OPEN`, A/D/W/S desplazan al jugador a `recovery_strafe_factor × MOVE_SPEED` **sin girar** (el frente queda en la dirección del golpe) y el golpe sigue: se puede encadenar. Lo cortan el dash y el salto, como antes.
  - `CANCEL`: el comportamiento de §2.2 (moverse corta la recuperación).
- **Frente bloqueado durante todo el golpe:** `face_direction_locked` se activa al empezar cualquier golpe (hoy solo si había a quién apuntar), para que el strafe nunca gire al personaje. Al terminar el golpe se libera como siempre.
- **Sin atacar no cambia nada:** el personaje mira hacia donde camina.

### 6.2 Datos (`AttackComboConfig`)

| Campo | Valor inicial |
|---|---|
| `aim_mode` | `CAMERA_ASSIST` (antes `NEAREST_ENEMY`) |
| `assist_half_angle` | 30° |
| `assist_range` | 5 m |
| `recovery_move` | `STRAFE` |
| `recovery_strafe_factor` | 0.3 |

### 6.3 Criterios de aceptación (AC628–AC635)

- **AC628** `CAMERA_ASSIST` con un enemigo cerca pero a 90° de la cámara: el golpe mira hacia la cámara.
- **AC629** `CAMERA_ASSIST` con un enemigo a 20° de la cámara y a 3 m: el golpe lo mira. Con dos enemigos dentro del cono, mira al de menor ángulo aunque esté más lejos.
- **AC630** `CAMERA_ASSIST` con un enemigo a 20° de la cámara pero más lejos que `assist_range`: el golpe mira hacia la cámara.
- **AC631** Con `CAMERA_ASSIST`, input lateral durante la anticipación no gira el frente; si la cámara gira, el frente la sigue a velocidad limitada.
- **AC632** Con `STRAFE`, en `CHAIN_OPEN` mantener A o D desplaza al jugador de costado a como mucho `recovery_strafe_factor × MOVE_SPEED`, el golpe sigue en curso y el frente no cambia.
- **AC633** Con `STRAFE`, un toque de ataque mientras se mantiene A o D encadena el golpe siguiente, y el dash sigue cortando.
- **AC634** Un golpe sin nadie a quien apuntar también bloquea el frente hasta que termina.
- **AC635** Regresión: con `recovery_move = CANCEL` y `aim_mode = NEAREST_ENEMY`, los tests de la iteración 1 (AC612, AC625, AC626) siguen en verde. Los tests que dependían del apuntado por defecto fijan `NEAREST_ENEMY` en su copia del combo (verifican lo mismo).

**Próximo libre después de esta iteración: AC636.**

### 6.4 Plan

1. Reservar AC628–AC635 en `CLAUDE.md` (próximo libre → AC636).
2. `AttackComboConfig`: `CAMERA_ASSIST`, `RecoveryMove` y los campos nuevos; actualizar el `.tres`.
3. `AttackComponent`: apuntado asistido (recorre `registry.get_active()` sin crear arrays), el input no desvía en los modos de cámara, frente siempre bloqueado.
4. `Player._handle_movement`: strafe en `CHAIN_OPEN` con `MovementComponent.move(dir, delta, factor)` (el frente bloqueado evita el giro).
5. Tests: casos nuevos en `combat_feel_test` y ajuste de los existentes a `NEAREST_ENEMY`/`CANCEL`. Solo se corren `combat_feel_test`, `hitstop_test` y `attack_component_test`, más el smoke test del arena.

### 6.5 Notas de implementación

- **Tests corridos (49 casos, en verde):** `combat_feel_test` (22: 14 de la iteración 1 y 8 nuevos), `hitstop_test` (6) y `attack_component_test` (21). Import y smoke test del arena sin errores ni warnings.
- **Tests adaptados** (verifican lo mismo):
  - `combat_feel_test`: los casos de la iteración 1 usan una copia del combo con `NEAREST_ENEMY` y `CANCEL` (`_use_iteration_one_combo`).
  - `attack_component_test`: fija `NEAREST_ENEMY` en su copia del combo, porque verifica el auto-apuntado al más cercano (AC8 y otros).
- `hitstop_test` pasa sin cambios con el apuntado por defecto: sus enemigos están delante de la cámara.

---

## 7. Iteración 3: auto-apuntado al más cercano, la cámara solo mira

- **Estado:** Implementada (2026-09-26), pendiente de prueba jugando.
- **Pedido del responsable:** el golpe apunta al enemigo más cercano y la cámara es solo para mirar. A/D no tienen que desviar el golpe (el problema de §6).

### 7.1 Diseño

- `aim_mode` por defecto vuelve a `NEAREST_ENEMY`. El golpe mira al más cercano al empezar y lo sigue durante la anticipación si se mueve.
- **`AttackComboConfig.windup_input_steering: bool`** (nuevo, `false`): con `true`, el input de movimiento desvía la anticipación en `NEAREST_ENEMY` (iteración 1). Con `false`, no la desvía nunca.
- Sin enemigos, el golpe conserva el frente que tenía (hacia donde caminaba). La cámara no influye.
- Se mantiene todo lo demás de §6: strafe en la recuperación (`STRAFE`), frente bloqueado durante el golpe, y `CAMERA`/`CAMERA_ASSIST` disponibles en datos.

### 7.2 Criterios de aceptación (AC636–AC638)

- **AC636** Con los datos por defecto, el golpe mira al enemigo más cercano aunque la cámara apunte a otro lado.
- **AC637** Con `windup_input_steering = false`, input lateral durante la anticipación no gira el frente, que sigue al enemigo. Con `true`, vale AC625.
- **AC638** Con los datos por defecto y sin enemigos, el golpe conserva el frente que tenía, aunque la cámara mire a otro lado.

**Próximo libre después de esta iteración: AC639.**

### 7.3 Plan

1. Reservar AC636–AC638 en `CLAUDE.md` (próximo libre → AC639).
2. Campo nuevo, `.tres` (`aim_mode = NEAREST_ENEMY`, `windup_input_steering = false`) y el condicional en `_windup_aim_direction`.
3. Tres tests nuevos en `combat_feel_test`; los de la iteración 1 fijan `windup_input_steering = true`.
4. Correr solo `combat_feel_test` y `attack_component_test`, más el smoke test del arena.

### 7.4 Notas de implementación

- **Tests corridos (46 casos, en verde):** `combat_feel_test` (25, con 3 nuevos) y `attack_component_test` (21). Import y smoke test del arena sin errores ni warnings.
- Los casos de la iteración 1 fijan `windup_input_steering = true` en su copia del combo (verifican lo mismo, AC625).
