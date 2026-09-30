# Boss: el Rey

- **Nota:** el modelo, las manos, el nombre ("The King") y las animaciones se rehicieron en `boss-king-rework.md`; lo que dice aquí del modelo (paleta bronce, materiales, hojas) quedó reemplazado por esa spec. El gameplay de esta spec no cambia.
- **Estado:** Implementada (2026-09-29). A pedido del usuario se corrieron solo los suites de esta spec y los que toca: `king_moves_test`, `king_test` (21), `king_model_test`, `enemy_models_test`, `boss_health_tuning_test` y `boss_challenge_run_test`; smoke test de la arena sin errores; hojas de captura del modelo y del Rey en vivo revisadas. Fallos que **no son de esta spec** y ya estaban: AC1203 del Titán (ancho del modelo, de `enemy-models.md` en curso) y `test_ac155_boss_offer_is_normal_without_golden_cards_left` (falla también en un HEAD limpio). La suite completa no se corrió.
- **Constitución:** `docs/constitution.md` 6.0.1 → **6.1.0** (enmienda MINOR, ver *Enmienda*).
- **Criterios de aceptación:** **AC1241–AC1265** (próximo libre: AC1266).
- **Notas de la implementación:**
  - Los tests calculan el daño como `20 × Mult. − defensa del jugador` con la vida y la defensa reales de la clase por defecto (Guerrero: 200 y 5); los números de los AC (con 100 y 3) son solo de referencia.
  - `EnemyAttackData.is_hit` devuelve `true` con `hit_arc_degrees` ≥ 360 sin comparar ángulos: con 360° un punto justo detrás fallaba por redondeo (afecta al Giro de acero; el Verdugo y el Titán no cambian).
  - Presupuesto de partículas del modelo: 8 + 8 (el test suma los emisores; el tope de boss es 16 en total).
  - Tests ajustados sin cambiar lo que verifican: `boss_challenge_run_test` (la rotación pasa de 3 a 4 desafíos y suma AC1257), `boss_health_tuning_test` (suma al Rey) y `enemy_models_test` (suma al Rey a `TYPES`, `POSES` y `LONG_HANDS`, y la excepción de oro por ruta).
- **Pilar (Principio I):** Combate + Progresión.
  - **Combate:** un duelo de espadachines que se gana **solo leyendo avisos**, sin mecánicas extra de armadura ni puntos débiles. Cada ataque pide una respuesta distinta (salir del arco, esquivar de costado, saltar el anillo, usar el dash). En la fase 2 aparece un ataque de aviso larguísimo que premia el esquive perfecto y el Contragolpe.
  - **Progresión:** es un desafío de boss que entrega las cartas doradas al vencerlo.
- **Tipo:** feature (boss + modelo + datos). Un boss más del sorteo, junto al Titán, la Colmena y el Verdugo.
- **Dependencias:**
  - `boss-verdugo.md` (`BossBehavior`, `ComboMoveData`, `ShockwaveMoveData`, fase 2) y `boss-titan.md` (ganchos `_begin_other_move`/`_update_other_move`, `SweepMoveData`).
  - `enemy-models.md` (`EnemyModel`, `MeshKit`, `EnemyClipKit`, presupuestos de boss). **El modelo del Rey se implementa después de que esa spec cierre** (sus pasos 4 a 7 y la revisión del piloto). La lógica y los datos no dependen de ella y pueden ir antes con la cápsula gris.
  - `enemy-attack-telegraph.md`, `enemy-ground-telegraph.md`, `enemy-group-ai.md` (aparición), `enemy-levels.md`, `enemy-rage.md`, `enemy-pace.md`, `boss-health-tuning.md`, `perfect-dodge.md` (solo como respuesta natural al Juicio).
  - Estándar `docs/animation-standard.md` (Principio VIII) para sus clips.

## Objetivo

Un boss noble, de estilo "light fantasy": un caballero con armadura ornamentada, capa larga y un **mandoble enorme**. Todas sus habilidades son **cuerpo a cuerpo y de suelo** (sin proyectiles, sin invocaciones, sin aire). No tiene armadura frontal ni puntos débiles: el desafío es leer sus avisos.

- **Cuerpo:** `body_scale` 2.0, altura de ~3.6 m. Manos flotantes como el resto de los enemigos; **la mano derecha es el mandoble** (como la hoja del Verdugo) y la izquierda es un puño enguantado que sube al pomo en las poses a dos manos.
- **Barra:** la del HUD, con el nombre "Rey".
- **Turnos y aparición:** no pide turno de ataque (`ignores_attack_tokens`) y aparece desde el piso como todos.
- **Referencias visuales** (dos pinturas del responsable):
  - **Fase 1** (imagen 1): postura de guardia, con la punta del mandoble apoyada delante y las dos manos sobre el pomo; capa vino larga y hombreras ornamentadas.
  - **Fase 2** (imagen 2): el mandoble en alto a dos manos, el faldón claro con borlas doradas ondeando y un brillo dorado.

## Repertorio

Se elige como el del Verdugo: `BossMoveTable.pick` por distancia y fase, sin repetir el movimiento anterior. Entre movimientos espera `attack_interval` (0.9 s) acercándose. Si ninguno alcanza, camina hacia el jugador.

| Movimiento | Distancia | Peso | Qué hace | Respuesta |
|---|---|---|---|---|
| **Tajo real** | 0 – 4.5 m | 3 | 3 tajos con avance de 0.8 m antes de cada uno: diagonal derecha, revés y un tajo vertical final más grande. Arco de 110°, alcance 3.6 m. Preparación 0.7 / 0.45 / 0.9 s, golpe 0.15 s, recuperación 0.25 / 0.25 / 1.0 s. `Mult.` 1.0 / 1.0 / 1.7. **Fase 2:** suma un cuarto tajo cruzado (preparación 0.4, `Mult.` 1.2, recuperación 1.0). | Salir del arco o esquivar cada golpe; cada uno se evalúa por separado. |
| **Estocada** | 3 – 10 m (peso 0 a menos de 3 m) | 3 | Aviso de franja en el piso. Fija la dirección al terminar la preparación (0.8 s, gira a 60°/s) y se lanza hasta 7 m a 16 m/s con la punta al frente, frenando a 1.5 m del jugador. Pega **una vez** a lo largo del recorrido (arco de 50°, alcance 1.8 m), `Mult.` 1.8. Recuperación 1.2 s aunque acierte o falle. **Fase 2:** encadena una segunda estocada 0.5 s después, re-apuntada (preparación de 0.35 s). | Salirse del recorrido de costado, o esquivar con el dash. La recuperación es la ventana para castigar. |
| **Giro de acero** | 0 – 4.5 m (peso 2 también más cerca) | 2 | Giro de 360° con el mandoble, alcance 4.2 m. Preparación 0.9 s (aviso de círculo), golpe 0.3 s, recuperación 1.0 s, `Mult.` 1.5. **No se salta** (es a la altura del pecho). | Alejarse del radio o esquivar con el dash. Castiga al que se queda pegado a sus pies. |
| **Juramento** | 3 – 13 m (peso 1 a menos de 3 m) | 3 | Levanta el mandoble (1.1 s) y lo clava en el piso. Un anillo crece desde 0.5 m hasta 13 m a 9 m/s, 0.9 m de ancho. Pega una vez, `Mult.` 1.2, si el anillo pasa por el jugador y este está a menos de 0.3 m del piso. Recuperación 1.2 s con la espada clavada. **Fase 2:** 2 anillos separados 0.6 s. | **Saltar** el anillo o esquivarlo con el dash. |
| **Juicio del Rey** (solo fase 2) | 0 – 7 m | 2 | Alza el mandoble sobre la cabeza durante **2.0 s** (aviso de sector de 90° y alcance 6.5 m, gira a solo 45°/s) y descarga un tajo enorme, `Mult.` 3.0. Recuperación larga de 1.8 s con la espada clavada. | Salir del sector o esquivar con el dash. Es el momento natural del **esquive perfecto** (tiempo lento) y del Contragolpe. |

Todos los tiempos, alcances, arcos y multiplicadores son datos (`EnemyAttackData`, `*MoveData`). En la fase 2 las preparaciones y recuperaciones se multiplican por `time_scale`.

## Fase 2 (vida ≤ 50 %)

- **Transición, una sola vez por vida:** cuando la vida baja al 50 % o menos y termina el movimiento en curso, pasa **1.5 s** quieto y **invulnerable**, en la pose de la imagen 2 (mandoble en alto), y no ataca.
- **Más rápido:** `time_scale` 0.8.
- **Cambios de repertorio:** el tajo suma su cuarto golpe, la estocada se encadena, el Juramento lanza 2 anillos y se habilita el **Juicio del Rey**.
- **Cambio visual:** se enciende el brillo dorado del mandoble y del peto, empieza a soltar motas de luz y la capa y el faldón se agitan más. Las manos crecen un 10 %.

## Enmienda a la constitución (MINOR)

La paleta de un boss noble choca con las reglas de color de los enemigos de `color-registry.md`:

- **Oro** (armadura y mandoble): su tono cae a ±20° de la miel `Color(0.95, 0.78, 0.25)` de la Colmena, que hoy está prohibida en un cuerpo enemigo.
- **Marfil** del faldón: es casi blanco.

**Implementado:** el marfil (saturación 0.25) supera el mínimo del test contra grises (0.1) y no necesita excepción. Queda una excepción **nominal y cerrada** para dos materiales del Rey (`king_accent_material`, el oro, y `king_glow_material`), en `materials/enemies/`. Constitución 6.1.0. Se justifica igual que el latón del Guerrero frente a la miel: son mallas opacas, facetadas y en un boss distinto, mientras que la miel de la Colmena es un aura translúcida. El test de paletas (`enemy_models_test`) excluye **exactamente esos dos** por ruta; cualquier otro material de enemigo sigue sujeto a las reglas. El resto de la paleta respeta las reglas sin excepción:

| Parte | Color | Nota |
|---|---|---|
| Armadura (dominante) | bronce oscuro `Color(0.42, 0.34, 0.3)` | Saturación ≤ 0.3 |
| Capa | vino `Color(0.5, 0.1, 0.28)` | Tono ~336°, fuera del rango del rojo de Rage y del aviso |
| Oro (acento) | `Color(0.85, 0.66, 0.22)` | **Excepción** `king_gold` |
| Faldón (tabard) | marfil `Color(0.96, 0.9, 0.72)` | **Excepción** `king_tabard` |
| Brillo (fase 2) | luz dorada pálida `Color(1.0, 0.93, 0.6)`, emisivo | **Excepción** `king_glow`; solo se enciende en la fase 2 |

Se registran también en la tabla *Paletas de enemigos*. El anillo del Juramento reutiliza el tierra ya registrado (`shockwave_material.tres`), sin enmienda.

## Estructura de nodos

No hay nodos nuevos en `enemy.tscn` (usa los anillos `Shockwave` y `Shockwave2`). Comportamiento: `components/enemies/king_behavior.tscn`, que extiende `BossBehavior`. Modelo: `entities/enemy/models/king_model.tscn` con el script `assets/models/enemies/king/king_model.gd` (`KingModel extends EnemyModel`):

```
KingModel
├─ Flinch → Hips → Torso → Head (yelmo con cimera y visera), Shoulders (hombreras ornamentadas), Chest (gema, glow)
│                  ├─ Tabard (faldón, cuelga de la cadera)
│                  ├─ Cape (capa larga, cuelga del torso)
│                  └─ FootL, FootR
├─ Motion, Overlay (como el resto)
└─ Fx → Sparks (mandoble clavado), Motes (motas doradas, solo fase 2)
```

Mallas de normales planas con `MeshKit`, compartidas entre instancias. **Presupuesto de boss:** ≤ 6.000 triángulos, ≤ 16 mallas, ≤ 4 materiales, ≤ 2 emisores de ≤ 16 partículas (los verifica `enemy_models_test`). El mandoble es la malla de la mano derecha, de la familia de `knight_set` (hoja ancha con canal central, guarda de latón dorado con extremos ensanchados, mango largo).

## Resources y datos

- **`ThrustMoveData`** (`resources/thrust_move_data.gd`, `BossMoveData`): `attack: EnemyAttackData` (preparación, golpe, recuperación, arco, alcance, `Mult.`), `thrust_speed`, `thrust_distance`, `stop_distance`, `line_width` (ancho del aviso), `chain_phase_two: int` (estocadas en la fase 2, 2) y `chain_delay`. Función pura `lunge_length(distance_to_target) -> float` = `clampf(distance − stop_distance, 0, thrust_distance)`.
- **`SweepMoveData`** (existente): el Giro de acero usa `hit_arc_degrees` = 360 y `clear_height` alto (99: "no se salta"). No cambia.
- **`ComboMoveData`, `ShockwaveMoveData`, `BossPhaseData`, `BossConfig`** (existentes): sin cambios. El Juicio es un `ComboMoveData` de un solo paso con `in_phase_one = false`.
- **Datos:**
  - `data/enemies/king_stats.tres`: vida base **499** (la misma que el Verdugo, para cumplir el objetivo de ~60 s a la ola 10 de `boss-health-tuning`, con multiplicador de esfuerzo 1; se suma a `BASES` de su test), daño 20, defensa 0 (crece con el nivel como la de los demás), velocidad 2.8, `attack_interval` 0.9, `body_scale` 2.0, `health_bar_scale` 1.7, `display_name` "Rey", barra en el HUD, `ignores_attack_tokens`, `resists_hitlag`, `resists_control`, `stun_duration_scale` 0.3, `affliction_resistance` 0.5, crecimiento por nivel como el Verdugo.
  - `data/enemies/hands/king_hands.tres`, `data/enemies/configs/king_boss.tres` (`BossConfig`, fase 2: umbral 0.5, transición 1.5, `time_scale` 0.8, manos ×1.1).
  - `data/enemies/attacks/king_*.tres` (tajos 1 a 4, estocada, giro, juramento, juicio).
  - `data/enemies/boss_challenges/king.tres` (1 enemigo), agregado a `data/waves/wave_config.tres` (`boss_challenges`) y con su pool `BossPoolKing` en `levels/arena/arena.tscn`.
  - `materials/enemies/king_*.tres` (armadura, capa, oro, marfil, brillo).

## Interfaz pública

- **`KingBehavior`** (`components/enemies/king_behavior.gd`/`.tscn`, extiende `BossBehavior`): implementa la Estocada y el Giro en los ganchos `_begin_other_move` / `_update_other_move`. Expone `get_other_stage()` y, para tests, `get_thrust_direction()`. Los otros movimientos los resuelve la base. Suma sus arcos a `get_telegraph_arcs()` (360° del giro).
- **`KingModel`** implementa `on_phase(phase)`: en la fase 2 enciende el brillo y las motas; `activate()` los apaga.
- **Clips propios** (nombres en `model_clip`): `slash_a`, `slash_b`, `slash_c`, `slash_d`, `thrust`, `spin`, `oath` (Juramento), `judgment` (Juicio), `transition`, además de `idle` y `walk`.

## Criterios de aceptación (AC1241–AC1265, a reservar)

Daño de referencia: `daño × Mult. − defensa del jugador (3)`, con daño base 20.

**Datos puros** (`test/resources/king_moves_test.gd`):
- **AC1241:** `ThrustMoveData.lunge_length` respeta `stop_distance` y `thrust_distance` (0 si el jugador está más cerca que `stop_distance`).
- **AC1242:** `SweepMoveData` con 360° y `clear_height` 99 pega al jugador delante, detrás y de costado dentro del radio, pega a uno en el aire, y no pega fuera del radio.
- **AC1243:** `BossMoveTable.pick` con el `BossConfig` del Rey: a 10 m solo salen Estocada o Juramento; a 2 m, Tajo, Giro (y Juramento con `close_weight`); en la fase 1 nunca sale el Juicio y en la 2 sí.

**Tajo real** (`test/entities/enemy/king_test.gd`):
- **AC1244:** a 3 m, el tajo pega 3 veces (20 − 3 = 17, 17 y 20 × 1.7 − 3 = 31), cada golpe después de su preparación y avanzando `advance_distance`.
- **AC1245:** si el jugador sale del arco después del primero, los otros dos no pegan. En la fase 2 el tajo pega 4 veces.

**Estocada:**
- **AC1246:** durante la preparación muestra una franja de aviso; la dirección se fija al terminar y el Rey recorre `lunge_length` sin pasar de `thrust_distance`.
- **AC1247:** un jugador en el recorrido recibe 20 × 1.8 − 3 = 33 **una sola vez**; uno fuera del arco o con iframes del dash no recibe daño. Después queda `recovery_time` en recuperación.
- **AC1248:** en la fase 2 encadena una segunda estocada `chain_delay` después, re-apuntada al jugador.

**Giro de acero:**
- **AC1249:** un jugador dentro del radio recibe 20 × 1.5 − 3 = 27 aunque haya saltado; con iframes del dash o fuera del radio, no recibe daño. Muestra un aviso de círculo durante la preparación.

**Juramento:**
- **AC1250:** el anillo crece a `speed` y un jugador en el piso a 6 m recibe 20 × 1.2 − 3 = 21 una sola vez; uno en el aire o con iframes, no. En la fase 2 lanza 2 anillos separados `ring_delay`.

**Juicio del Rey:**
- **AC1251:** la preparación dura `windup_time` × `time_scale` (2.0 × 0.8 en la fase 2), gira a `windup_turn_speed` bajo, y un jugador dentro del sector recibe 20 × 3.0 − 3 = 57; uno fuera del sector, no.
- **AC1252:** un jugador con iframes del dash no recibe daño del Juicio. El tiempo lento del esquive perfecto ya es genérico para todo enemigo y lo cubre `perfect-dodge.md`.

**Fase 2 y sin armadura:**
- **AC1253:** al bajar al 50 % entra en `TRANSITION`: durante 1.5 s es invulnerable y no ataca, una sola vez aunque se cure.
- **AC1254:** en la fase 2 las preparaciones y recuperaciones duran `time_scale` × las de la fase 1 y las manos crecen `phase_two_hand_scale`.
- **AC1255:** el Rey **no tiene armadura**: `HealthComponent.damage_reduction` es 0 en ambas fases y un golpe de frente le hace el daño completo.

**Selección e integración:**
- **AC1256:** en 10 movimientos seguidos nunca repite el mismo dos veces.
- **AC1257:** `king.tres` está en `WaveConfig.boss_challenges` y tiene su pool en la arena. Forzar ese desafío genera 1 Rey que aparece desde el piso, no usa turnos y muestra "Rey" en la barra del HUD.
- **AC1258:** escala con nivel y rage como el resto; su vida base está en `BASES` de `boss_health_tuning_test`.
- **AC1259:** `activate()` lo devuelve a la fase 1, sin anillos visibles ni brillo encendido.
- **AC1260:** `get_telegraph_arcs()` incluye el arco de 360° del giro y el de 90° del Juicio.

**Modelo** (`test/assets/enemy_models_test.gd`, `test/entities/enemy/king_model_test.gd`):
- **AC1261:** respeta el presupuesto de boss (≤ 6.000 triángulos, ≤ 16 mallas, ≤ 4 materiales, ≤ 2 emisores de ≤ 16 partículas) y sus mallas se construyen una vez y se comparten.
- **AC1262:** existen los clips `idle`, `walk`, `transition` y todos los `model_clip` que usan sus ataques (`*_windup` y `*_strike`).
- **AC1263:** test de paletas: los materiales del Rey cumplen las reglas de color salvo `king_accent_material` (oro) y `king_glow_material`, que son las únicas excepciones registradas.
- **AC1264:** `on_phase(2)` enciende el brillo y las motas; `activate()`/`reset` los apaga.
- **AC1265:** los tests de otros suites que dependen de la lista de bosses (`boss_challenge_run_test`, `enemy_models_test`, `boss_health_tuning_test`) se adaptan sin cambiar lo que verifican; se anota aquí al cerrar.

## Plan de implementación

1. Verificar el estado de las otras sesiones: qué de `enemy-models` y de `boss_behavior.gd` está ya integrado. Reservar AC1241–AC1265 en `CLAUDE.md` y `docs/ac-registry.md` (próximo libre AC1266). Trabajar en una rama o worktree para no pisar cambios sin confirmar.
2. `ThrustMoveData` y datos del Rey (`king_stats`, `king_hands`, `king_boss`, `king_*` ataques, `king.tres`). Tests AC1241–AC1243.
3. `KingBehavior` con la Estocada y el Giro, y datos del Juramento, el Tajo y el Juicio (la base ya los resuelve). Con la cápsula gris. Tests AC1244–AC1256 y AC1259–AC1260.
4. Integración: desafío en `wave_config.tres`, pool en la arena, `BASES` en el test de vida. Tests AC1257–AC1258 y AC1265.
5. Enmienda de la constitución y del registro de colores (la excepción de tres materiales) y `SOURCE.md` de `assets/models/enemies/`.
6. `KingModel`: mallas, materiales, emisores y clips, siguiendo el estándar de animación (video antes y después con `godot-capture`, hojas de captura revisadas por mí). Tests AC1261–AC1264.
7. Cierre: `godot-tester` con los suites de esta spec y los que toca (a pedido del usuario, sin la suite completa), smoke test de la arena forzando el desafío, checklist de review de la constitución en esta spec, estado **Implementada**, y actualizar `README.md` de specs y el contador de AC.

## Fuera de alcance (posibles ampliaciones)

- Proyectiles, invocaciones (guardia real) y ataques aéreos: descartados por decisión del responsable.
- Una mecánica de armadura frontal o guardia: descartada. El desafío es solo leer ataques.
- Textura pictórica: el estilo se traduce a normales planas y paleta, no a pinceladas.
