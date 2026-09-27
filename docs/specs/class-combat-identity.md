# Feature: identidad de combate por clase (idle, locomoción y combo)

- **Estado:** Aprobada (2026-09-26, D1–D4 como están), en implementación.
- **Constitución:** `docs/constitution.md` v4.10.0 → **v4.10.1** (enmienda PATCH propuesta, ver §8).
- **Pilar (Principio I):** **combate.**
  - Pelear se vuelve más expresivo y legible: cada golpe tiene anticipación, impacto sostenido y follow-through, y la silueta de cada clase se reconoce de lejos.
  - Elegir clase cambia cómo se pelea: cuántos golpes tiene el combo, cuánto te compromete cada uno (*cancel point*), cuánto avanza, qué zona cubre y cuánto pesa el impacto.
- **Dependencias:** `humanoid-player-model.md`, `bdo-combat-feel.md` (combo, compromiso, estocada, hit lag y apuntado), `weapon-trail.md`, `berserker.md`, `samurai.md`, `berserker-air-slash.md`, `spin-dash-slash.md`, `sheathe-dash-cancel.md`, `tsubame-gaeshi.md`. Todas Implementadas.
- **Fuera de alcance:**
  - Rehacer las animaciones de las habilidades: siguen animando el pivot del arma y el humanoide hace `idle` (limitación aceptada en `humanoid-player-model.md` §2.6). Solo se verifica que se sigan viendo bien con las poses base nuevas.
  - Enemigos, cámara y el Golpe aéreo del Samurái (`samurai-air-strike.md`, todavía Propuesta).
  - Inputs nuevos (Principio VI): no hacen falta, las tres clases usan `attack`.

## 1. Objetivo

- **Hoy:**
  - Las tres clases usan el mismo combo de 3 golpes (`data/player/attack_combo_config.tres`) y las mismas poses. Solo cambia la velocidad del clip (`ATTACK_SPEED / 1.2`: el Berserker lo reproduce a ×0.5 y el Samurái a ×1.33), así que el Berserker parece un Guerrero en cámara lenta.
  - Idle, correr, frenar y saltar son iguales para todos.
  - El hit lag y el temblor del enemigo son iguales para todos (`data/player/hitstop_config.tres`).
  - Los momentos del golpe (daño, *cancel point*, fin) viven **solo** en los eventos del clip del asset. `AttackComboStep` no los conoce, aunque el Principio VII dice que el *cancel point* vive en los Resources.
- **Nuevo:**
  1. Cada clase tiene su **perfil de animación** dentro del asset `LowPolyHumanoid`: idle, `run`, `run_stop`, `jump_start`, `jump_air`, `jump_land`, `hit` y su combo (`attack_1` … `attack_N`).
  2. Cada clase tiene **su combo** (`data/classes/<clase>/<clase>_combo.tres`) con distinta cantidad de golpes, ritmo, estocada, alcance, arco y hit lag, y **su hitstop** (`<clase>_hitstop.tres`).
  3. `AttackComboStep` es la **fuente de verdad del timing** del golpe (inicio y fin del daño, *cancel point*, fin). `AttackComponent` lo ejecuta leyendo la posición del clip, y un test garantiza que los eventos del clip coinciden (§4).

## 2. Principios de diseño de la identidad

- **El timing es la personalidad.** Cada golpe tiene *startup* (anticipación, hasta `hit_start`), *active* (`hit_start` → `hit_end`) y *recovery* (`hit_end` → `end_time`). El *cancel point* (`cancel_point`) cierra el tramo comprometido (Principio VII): la clase ágil lo abre casi pegado al impacto y la pesada lo abre tarde.
- **Silueta:** cada pose clave (anticipación, impacto, remate) se lee sola, de lejos: el arma lejos del torso y una diagonal clara del cuerpo.
- **Estructura de cada golpe:** anticipación → impacto con un instante sostenido (un keyframe repetido: *hold*) → follow-through que termina en la guardia de la clase. La estela (`weapon-trail.md`) dibuja el arco de la punta: horizontal ancho (Berserker), diagonales cortas y rápidas (Samurái) y líneas rectas de estocada mezcladas con tajos (Guerrero).
- **Tiempos de las tablas:** en segundos del clip a velocidad 1, que es la velocidad de cada clase con sus stats base. `reference_attack_speed` pasa a ser el `ATTACK_SPEED` base de cada clase (§6.1), así que las tablas son tiempos reales de juego. Las cartas de velocidad de ataque siguen acelerando el clip.
- **Alcance y arco:** cada golpe multiplica los stats mejorables `ATTACK_RANGE` y `ATTACK_ARC` (`range_multiplier`, `arc_multiplier`). Las cartas siguen mejorando todos los golpes.
- **Daño relativo:** `damage_multiplier` × `DAMAGE`. Se mantiene el balance de hoy (AC601): encadenando en cada *cancel point*, `Σ damage_multiplier = ATTACK_SPEED base × Σ cancel_point`, así que el DPS base de cada clase sigue siendo `ATTACK_SPEED × DAMAGE`, ±10 %, sin contar el hit lag (ver D2).

## 3. Las tres clases

### 3.1 Guerrero (espada hoplita)

**Personalidad:** un hoplita disciplinado: guardia firme, estocadas y tajos alternados, avanza en formación sin perder la base.

| Clip | Descripción |
|---|---|
| `idle` (2.0 s, loop) | Guardia de hoplita: pies abiertos, pierna izquierda adelante y el peso centrado. Brazo izquierdo adelantado a la altura del pecho, como si llevara el escudo. Espada a la altura de la cadera, con la punta hacia adelante. Respiración lenta y pareja (la cadera baja 1 cm). |
| `run` (0.6 s) | Torso casi erguido (−10°), paso regular. El brazo izquierdo marca el ritmo y la espada queda quieta y baja, apuntando adelante: no se balancea. |
| `run_stop` (0.35 s) | Frenada controlada: planta el pie adelantado, baja un poco la cadera y vuelve a la guardia en un solo tiempo. |
| `jump_start` / `jump_air` / `jump_land` | Salto compacto, con las rodillas recogidas y la espada adelante. Cae amortiguando y vuelve directo a la guardia. |
| `hit` (0.35 s) | Retrocede medio paso sin perder la guardia. |

**Combo: 4 golpes.** Estocada → tajo → revés → estocada profunda.

| # | Golpe | Startup | Active | Cancel | Recovery (fin) | Estocada | Daño | Alcance / arco | Hit lag / shake |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Estocada rápida (jab) desde la guardia | 0.10 | 0.10–0.16 | 0.22 | 0.16–0.40 | 0.4 m (0.00–0.10) | ×0.28 | ×1.1 (2.4 m) / ×0.35 (42°) | 0.05 / 0.15 |
| 2 | Tajo horizontal de derecha a izquierda | 0.12 | 0.12–0.20 | 0.26 | 0.20–0.44 | 0.3 m (0.02–0.12) | ×0.32 | ×1.0 / ×1.0 (120°) | 0.06 / 0.20 |
| 3 | Revés de izquierda a derecha | 0.12 | 0.12–0.20 | 0.26 | 0.20–0.44 | 0.3 m (0.02–0.12) | ×0.32 | ×1.0 / ×1.0 (120°) | 0.06 / 0.20 |
| 4 | **Remate:** estocada frontal profunda, con paso largo y el brazo izquierdo atrás | 0.24 | 0.24–0.32 | 0.46 | 0.32–0.70 | 1.2 m (0.08–0.24) | ×0.52 | ×1.2 (2.6 m) / ×0.4 (48°) | 0.11 / 0.35 |

- Empuje (`knockback_multiplier`): 0.4 / 0.5 / 0.6 / 1.6. Ciclo encadenado: 1.20 s, con Σ daño = 1.44 = 1.2 × 1.20.
- `AttackComboConfig`: `windup_turn_speed` 360 °/s, `recovery_strafe_factor` 0.3, `input_buffer` 0.15 s.
- `HitstopConfig`: temblor del enemigo de 0.06 m a 30 Hz (el de hoy).

**Cómo se diferencia:** es el único que alterna **estocadas** (sector angosto y largo) con **tajos** (sector ancho). Su compromiso es medio y parejo: el *cancel point* llega entre 0.06 y 0.14 s después del fin del daño. Frente a la habilidad Estocada (rectángulo largo, con aviso y cooldown), el remate es un paso corto sin aviso dentro del combo.

### 3.2 Berserker (falchion, mandoble)

**Personalidad:** furia y peso. Cada golpe arrastra el cuerpo entero y, una vez que arranca, no hay vuelta atrás.

| Clip | Descripción |
|---|---|
| `idle` (1.0 s, loop) | Encorvado (torso −20°) y hombros echados adelante. El mandoble cuelga de la mano derecha con la punta cerca del piso, a su derecha, y la mano izquierda cerca del mango. **Respiración agitada:** ciclo corto con los hombros subiendo y la cadera bajando 3 cm. |
| `run` (0.72 s) | Corre **pisando fuerte**: la cadera cae marcada en cada apoyo y el torso va inclinado −20°. El mandoble va atrás, en la mano derecha, y el brazo izquierdo balancea amplio. |
| `run_stop` (0.5 s) | Derrape largo: el peso del arma lo tira hacia adelante antes de clavarse. |
| `jump_start` / `jump_air` / `jump_land` | Agachada profunda antes de despegar y el arma sube. Aterrizaje pesado: la cadera baja 22 cm y tarda más en volver a la guardia. |
| `hit` (0.35 s) | Casi no retrocede: encoge los hombros y aguanta. |

> **Revisión (2026-09-27, pedido del responsable con referencias: bocetos de un guerrero con el mandoble al hombro, Siegfried de Soul Calibur y una lámina de poses con mandoble):** la guardia y la locomoción cambian; los tiempos y los datos de gameplay de las tablas no.
> - **`idle`:** erguido y confiado (el pecho afuera, piernas abiertas con el peso en la derecha), **el mandoble apoyado en el hombro derecho y sostenido solo con la mano derecha**: el mango cruza sobre el hombro y la hoja va hacia atrás y arriba, por detrás de la cabeza. El puño izquierdo suelto al costado. La respiración agitada se mantiene (1.0 s, la cadera baja 3 cm y el torso se vuelca con cada exhalación).
> - **`run`, `run_stop`, salto y `hit`:** con el mandoble al hombro, pisando fuerte y con el puño izquierdo balanceando amplio.
> - **Combo (poses):** (1) saca el mandoble del hombro y se enrosca con la hoja arrastrada atrás a la derecha, casi al piso; barre al frente y termina a la izquierda. (2) Se enrosca más a la izquierda, barre de vuelta y **termina a una mano**, con el mandoble bajo a la derecha, las piernas muy abiertas y **la mano izquierda extendida adelante** (lámina, última pose). (3) Junta las manos, **alza el mandoble sobre la cabeza**, arqueado hacia atrás (lámina), y lo baja con un pisotón hasta clavar la punta en el piso. Al final de cada golpe vuelve a apoyarlo en el hombro.
> - **Dos manos:** en los golpes, la mano izquierda toma el `OffHand` de `greatsword.tscn` (peso de agarre 1, API de `sheath-socket-hand-grip.md` §2.3) en cada impacto; la suelta solo en el remate del golpe 2 y la vuelve a tomar al alzar el golpe 3. En idle y locomoción, peso 0.
> - `WeaponMount.update()` vuelve a aplicar los objetivos de mano después de mover el arma (`LowPolyHumanoid.refresh_hand_targets()`): antes la mano quedaba un cuadro atrás del mango, que con el mandoble se nota.
> - **Continuidad del combo (pedido del responsable, 2026-09-27):** cada golpe termina en la pose con la que empieza el siguiente. Desde el *cancel point* hasta el fin del clip, el golpe 1 queda en la pose inicial del golpe 2 y el golpe 2 en la del golpe 3, así que encadenar en cualquier momento de la recuperación no salta. El golpe 2 termina con el mandoble bajo, bien atrás a la derecha, y el golpe 3 lo sube desde ahí por detrás hasta alzarlo sobre la cabeza. El remate (golpe 3) termina en la guardia, igual que la pose con la que empieza el golpe 1.
> - **Salida a la guardia:** como los golpes 1 y 2 ya no terminan en la guardia, si el combo no sigue (o el jugador se mueve), el cuerpo pasa del último cuadro del golpe a la locomoción con una mezcla lenta: `PlayerAnimationConfig.attack_exit_blend` (0.35 s, `data/player/player_animation_config.tres`). El dash, el golpe recibido y las habilidades siguen con la mezcla corta de siempre.
> - Criterios nuevos: AC678–AC682 (§7).

**Combo: 3 golpes.** Barrido → barrido de vuelta → tajo de leñador.

| # | Golpe | Startup | Active | Cancel | Recovery (fin) | Estocada | Daño | Alcance / arco | Hit lag / shake |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Barrido horizontal amplio de derecha a izquierda. Anticipación larga, con el mandoble detrás del hombro derecho y el torso torcido. | 0.36 | 0.36–0.50 | 0.62 | 0.50–0.95 | 0.5 m (0.12–0.36) | ×0.40 | ×1.0 (3.0 m) / ×1.0 (160°) | 0.09 / 0.30 |
| 2 | Barrido de vuelta de izquierda a derecha, aprovechando el impulso: el cuerpo gira con el arma. | 0.40 | 0.40–0.54 | 0.66 | 0.54–1.00 | 0.5 m (0.14–0.40) | ×0.43 | ×1.0 / ×1.0 (160°) | 0.09 / 0.30 |
| 3 | **Remate:** "tajo de leñador". Diagonal descendente a dos manos, del hombro derecho a la cadera izquierda, con un pisotón adelante; queda clavado un instante. | 0.62 | 0.62–0.74 | 1.10 | 0.74–1.45 | 0.9 m (0.36–0.62) | ×0.60 | ×1.15 (3.45 m) / ×0.75 (120°) | 0.16 / 0.50 |

- Empuje: 0.8 / 0.9 / 2.0. Ciclo encadenado: 2.38 s, con Σ daño = 1.43 ≈ 0.6 × 2.38.
- `AttackComboConfig`: `windup_turn_speed` 240 °/s (le cuesta corregir el giro), `recovery_strafe_factor` 0.15, `input_buffer` 0.2 s.
- `HitstopConfig`: temblor de 0.10 m a 24 Hz (más ancho y más lento).

**Cómo se diferencia:**
- Tiene el combo más corto, los arcos más anchos y el mayor compromiso: el *cancel point* llega 0.12 a 0.36 s después del fin del daño.
- **No se pisa con el Giro:** el Giro son vueltas continuas de 360° mientras camina. Los barridos son de 160°, parado, con anticipación visible y de a uno.
- **No se pisa con el Tajo aéreo:** el Tajo aéreo es vertical, desde el aire y en franja. El remate del combo es diagonal, en el piso y en sector.

### 3.3 Samurái (katana con funda)

> **Revisión (2026-09-26, pedido del responsable con referencias de Musa en Black Desert):** una mano siempre en la funda, el torso de costado al enemigo y un combo de 4 golpes, el último doble. Reemplaza la versión de 5 golpes con cortes a dos manos.

**Personalidad:** calma y precisión. De costado al enemigo, con la mano en la funda. Casi no se mueve hasta que corta, y corta con una sola mano, muy rápido.

| Clip | Descripción |
|---|---|
| `idle` (3.0 s, loop) | **Pose por defecto:** la mano izquierda sostiene la funda (cadera izquierda) y la derecha, la katana baja, con la punta adelante y abajo. **El torso de costado** al enemigo (hombro izquierdo adelante, torso −40°) y **la cabeza mirando al frente**. Peso bajo. Respiración casi imperceptible: la cadera baja 0.5 cm. |
| `run` (0.56 s) | Deslizado y bajo: poco rebote de cadera y torso −15°. La mano izquierda sigue en la funda (no balancea) y la katana va atrás, en la mano derecha. |
| `run_stop` (0.3 s) | Frena corto y bajo, casi sin derrape, y vuelve enseguida a la guardia de costado. |
| `jump_start` / `jump_air` / `jump_land` | Salto liviano, con las piernas recogidas limpias y la mano izquierda en la funda. Aterriza sin ruido y con poca flexión. |
| `hit` (0.35 s) | Retrocede con un giro corto del torso, sin soltar la funda. |

**La mano izquierda nunca suelta la funda:** en todos los clips, golpes incluidos. Todos los cortes son a una mano.

> **Revisión 2 (2026-09-27, pedido del responsable con la lámina de los ocho cortes, a una mano):** movimientos más expresivos (más giro e inclinación de torso, hombros abiertos, brazo estirado del todo, recorridos largos), guardia más firme y erguida, y la funda, el mango y las manos más cerca de la cintura. Los tiempos y los datos de gameplay de la tabla no cambian; solo las poses y la funda.
> - Cortes de la lámina: 1 = horizontal (corte 4), 2 = diagonal ascendente de abajo a la derecha a arriba a la izquierda (corte 7), 3 = vertical (corte 1), 4a = diagonal ascendente de abajo a la izquierda a arriba a la derecha (corte 6), 4b = kesa de arriba a la derecha a abajo a la izquierda (corte 3).
> - **Funda en el cinturón:** `sheath_position` (−0.42, 0.95, −0.15) → **(−0.24, 0.95, −0.12)** y `sheath_rotation` (−0.35, π, 0) → **(−0.35, 2.69, 0)** (la punta atrás y afuera, para no cruzar el torso). Se actualizaron juntos `katana.tres`, `SheatheConfig.sheathed_*` y los dos primeros cuadros de `sheathe_slash` en `player.tscn`, como pide `CLAUDE.md`.
> - **La mano sostiene la funda de verdad:** el kit fija la muñeca izquierda en la boca de la funda cada 1/60 s de cada clip (antes quedaba hasta 8 cm de juego y se veía la mano moverse sobre una funda quieta). AC660 pasa de 8 cm a 3 cm.

**Combo: 4 golpes (5 impactos).** Tajo horizontal, diagonal ascendente, vertical descendente y un remate doble: sube en vertical desde abajo a la izquierda y vuelve a bajar.

| # | Clip | Golpe | Startup | Active | Cancel | Recovery (fin) | Estocada | Daño | Alcance / arco | Hit lag / shake |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `attack_1` | Tajo horizontal a una mano, de derecha a izquierda, girando el torso de costado a de frente (2.ª imagen) | 0.14 | 0.14–0.18 | 0.22 | 0.18–0.40 | 0.6 m (0.06–0.14) | ×0.36 | ×1.05 (2.4 m) / ×1.2 (120°) | 0.05 / 0.18 |
| 2 | `attack_2` | Diagonal ascendente, de abajo a la derecha hasta arriba a la izquierda (3.ª imagen) | 0.08 | 0.08–0.12 | 0.17 | 0.12–0.34 | 0.3 m (0.00–0.08) | ×0.28 | ×1.0 / ×0.9 (90°) | 0.04 / 0.12 |
| 3 | `attack_3` | Vertical descendente, de arriba abajo, con el torso volcado (4.ª imagen) | 0.10 | 0.10–0.14 | 0.20 | 0.14–0.38 | 0.4 m (0.00–0.10) | ×0.34 | ×1.1 (2.5 m) / ×0.5 (50°) | 0.05 / 0.16 |
| 4a | `attack_4` | **Remate, 1.er impacto:** desde abajo a la izquierda sube en vertical. **Encadena solo** (`auto_chain`) con 4b en su *cancel point*. | 0.10 | 0.10–0.13 | 0.16 | 0.13–0.24 (no se llega: encadena en 0.16) | 0.5 m (0.00–0.10) | ×0.28 | ×1.1 / ×0.5 | 0.04 / 0.14 |
| 4b | `attack_5` | **Remate, 2.º impacto:** desde arriba vuelve a bajar en vertical, con paso, y queda en *zanshin* (la hoja baja, la mano en la funda) | 0.08 | 0.08–0.12 | 0.34 | 0.12–0.60 | 0.4 m (0.00–0.08) | ×0.48 | ×1.15 (2.65 m) / ×0.55 (55°) | 0.10 / 0.30 |

- Empuje: 0.4 / 0.3 / 0.5 / 0.2 / 1.2.
- Ciclo encadenado: 0.22 + 0.17 + 0.20 + 0.16 + 0.34 = 1.09 s, con Σ daño = 1.74 = 1.6 × 1.09 (DPS base de hoy, D2).
- `AttackComboConfig`: `windup_turn_speed` 540 °/s, `recovery_strafe_factor` 0.4, `input_buffer` 0.12 s (ritmo preciso).
- `HitstopConfig`: temblor de 0.04 m a 40 Hz (seco y corto).

**Encadenado automático (`AttackComboStep.auto_chain`, nuevo):**
- Cuando un golpe con `auto_chain = true` llega a su `cancel_point`, el golpe siguiente arranca en ese mismo cuadro, sin toque de ataque. No hay ventana `CHAIN_OPEN` entre los dos: moverse o saltar no cortan el remate, y el dash sí, como siempre.
- Cada mitad es un paso normal, con su clip, su daño, su hit lag, su estocada y su sector. Así el doble golpe no necesita un sistema de impactos múltiples y el test de sincronía (AC641) sigue valiendo por clip.
- Solo el 4a lo usa. En el Guerrero y el Berserker vale `false`.

**Cómo se diferencia:**
- Es el único que golpea **a una mano y con la otra en la funda**, de costado al enemigo: la silueta se lee sola.
- Tiene los golpes más rápidos. El *cancel point* llega 0.04 a 0.06 s después del fin del daño (salvo el remate), así que se puede cortar casi al instante.
- El remate es doble (sube y baja en vertical): el único golpe del juego que pega dos veces sin volver a apretar.
- **Coherente con Envainar y no se pisa con él:** Envainar desenvaina desde la funda con un *gyaku kesa-giri* cargado y un corte de viento en V. El combo corta con la hoja ya desnuda y en vertical u horizontal. *Tsubame gaeshi* sigue siendo un segundo Envainar instantáneo, con su V, y no un golpe del combo.

### 3.4 Comparación rápida

| | Guerrero | Berserker | Samurái |
|---|---|---|---|
| Golpes (impactos) | 4 (4) | 3 (3) | 4 (5: el remate es doble) |
| Primer impacto | 0.10 s | 0.36 s | 0.14 s |
| Fin del daño (`hit_end`) → *cancel point* | 0.06–0.14 s | 0.12–0.36 s | 0.04–0.06 s (remate 0.22 s) |
| Ciclo encadenado | 1.20 s | 2.38 s | 1.09 s |
| Estocada del remate | 1.2 m | 0.9 m | 0.5 + 0.4 m |
| Arco típico / remate | 42°–120° / 48° | 160° / 120° | 50°–120° / 50°–55° |
| Hit lag del remate | 0.11 s | 0.16 s | 0.10 s |
| Giro en la anticipación | 360 °/s | 240 °/s | 540 °/s |
| Respiración (idle) | 2.0 s, media | 1.0 s, agitada | 3.0 s, casi quieta |

## 4. Una sola fuente de verdad para el timing

- **`AttackComboStep` manda en el gameplay** (Principios III y VII). Tiene cuatro campos nuevos en segundos del clip a velocidad 1:
  - `hit_start`: cae el daño y el frente queda fijo;
  - `hit_end`: fin de la fase *active* (hoy es informativo, porque el daño cae una vez);
  - `cancel_point`: `STRIKING` → `CHAIN_OPEN`;
  - `end_time`: el golpe termina.
- **`AttackComponent` deja de escuchar los eventos del clip.** En cada `advance()` compara `humanoid.anim.current_animation_position` con esos tiempos y dispara cada momento una sola vez al cruzarlo.
  - El hit lag pone `speed_scale = 0`, así que los momentos se pausan solos.
  - La red de seguridad (el clip dejó de sonar) y `animation_finished` siguen cerrando el golpe.
  - Así desaparecen los problemas de las pistas de método diferidas (`humanoid-player-model.md` §7).
- **El clip conserva sus eventos** (`hit_on`, `hit_off`, `combo`, `end`) como marcas de autoría de la pose (el demo del asset los usa), escritos en los mismos tiempos.
- **El test AC641 los compara** para cada golpe de cada clase, con tolerancia de 1 ms:
  - `hit_on = hit_start`, `hit_off = hit_end`, `combo = cancel_point` y `end = end_time = largo del clip`;
  - además, el orden `0 < hit_start < hit_end ≤ cancel_point < end_time` y que la estocada termine antes del impacto (`lunge_end ≤ hit_start`).

  Si alguien mueve una pose sin actualizar el `.tres` (o al revés), el test falla y dice qué golpe y qué evento no coinciden.
- **Alternativa descartada:** derivar los tiempos del `.tres` leyendo el clip en runtime. Deja el *cancel point* fuera de los Resources, en contra del Principio VII y de lo pedido. Al revés (que el asset lea el `.tres`) haría depender el asset de clases del juego, en contra del Principio II.

## 5. Plan técnico del asset (perfiles de animación)

### 5.1 Organización

```
assets/models/characters/low_poly_humanoid/
├── low_poly_humanoid.gd           # construcción, kit de poses (_p, _crouch, make_clip…), perfiles
├── humanoid_demo.gd               # demo: teclas 1-0 y un selector de perfil
├── profiles/
│   ├── humanoid_profile.gd        # class_name HumanoidProfile extends RefCounted (base)
│   ├── warrior_profile.gd         # HumanoidWarriorProfile
│   ├── berserker_profile.gd       # HumanoidBerserkerProfile
│   └── samurai_profile.gd         # HumanoidSamuraiProfile
└── SOURCE.md                      # se documentan los perfiles y cómo editarlos
```

- `HumanoidProfile.build(humanoid: LowPolyHumanoid) -> AnimationLibrary` arma todos los clips de una clase con el kit de poses del humanoide: su guardia (`stance`), su locomoción y su combo.
- **Construcción una sola vez:** en `_ready` (`_build()`), el humanoide construye la librería de **cada** perfil y las guarda en `_libraries: Dictionary[StringName, AnimationLibrary]`. Son unos 40 clips en total y es un costo único al cargar.
- **`set_profile(profile: StringName) -> void`** registra la librería del perfil como librería por defecto del `AnimationPlayer` (`remove_animation_library("")` + `add_animation_library("", …)` con la misma instancia ya construida). No crea animaciones. Los nombres de clip no cambian (`idle`, `attack_1`…), así que `PlayerAnimator`, `AttackComponent` y los tests existentes no usan prefijos.
- `@export var profile: StringName = &"warrior"`: el perfil inicial (demo y escenas sin clase).
- Métodos nuevos: `get_profile()`, `has_profile(profile)`, `get_profile_library(profile)` y `get_library_build_count() -> int` (cuántas veces se construyó cada librería, para AC642).
- **Se borran los clips genéricos de hoy.** El kit de poses (`_p`, `_crouch`, `_run_contact`…) se conserva y los perfiles lo parametrizan.
- **Transición:** mientras el Berserker y el Samurái no tienen perfil propio (pasos 2 y 3 del plan), usan un perfil `legacy` con los clips de hoy, que se borra al terminar.

### 5.2 Brazo izquierdo y arma a dos manos

- El arma sigue montada en la mano derecha con `WeaponMount` (sin cambios). El agarre a dos manos del Berserker y la mano en la funda del Samurái son **poses**: la mano izquierda se lleva cerca del mango o de la funda con los ángulos de la pose, sin IK.
- Si la mano derecha del Samurái necesita otra orientación de la katana en su idle, se resuelve con la rotación de muñeca de la pose, no con `grip_rotation`, para que las habilidades no cambien.

## 6. Resources (Principio III)

### 6.1 Cambios y agregados

| Resource | Cambio |
|---|---|
| `AttackComboStep` | + `hit_start`, `hit_end`, `cancel_point`, `end_time` (s del clip a velocidad 1) · + `range_multiplier`, `arc_multiplier` (sobre `ATTACK_RANGE` y `ATTACK_ARC`). + `auto_chain: bool` (el golpe siguiente arranca solo en el *cancel point*; solo el 4a del Samurái, §3.3). Cálculos puros: `startup()`, `recovery()`. |
| `CharacterClassData` | + `animation_profile: StringName` · + `combo: AttackComboConfig` · + `hitstop: HitstopConfig` |
| `data/classes/warrior/warrior_combo.tres` | tabla §3.1, `reference_attack_speed` 1.2 |
| `data/classes/berserker/berserker_combo.tres` | tabla §3.2, `reference_attack_speed` 0.6 |
| `data/classes/samurai/samurai_combo.tres` | tabla §3.3, `reference_attack_speed` 1.6 |
| `data/classes/<clase>/<clase>_hitstop.tres` | temblor del enemigo por clase (§3) |
| `data/player/attack_combo_config.tres`, `data/player/hitstop_config.tres` | **Se borran.** `player.tscn` apunta por defecto a los del Guerrero (la clase por defecto). |

- Los campos de `AttackComboConfig` que no se nombran en §3 (`aim_mode`, `windup_input_steering`, `assist_*`, `recovery_move`, `move_cancel_threshold`, `lunge_stop_*`) conservan los valores de hoy en las tres clases.
- Todo sigue siendo control de sensación, no stats mejorables. El combo escala con los stats mejorables `DAMAGE`, `ATTACK_SPEED`, `ATTACK_RANGE`, `ATTACK_ARC`, `CRIT_*` y `LIFESTEAL`.

### 6.2 Código

- **`Player._apply_character_class()`:**
  - `humanoid.set_profile(class.animation_profile)`;
  - `attack.combo = class.combo`;
  - `hitstop.config = class.hitstop`.

  Un perfil desconocido hace `push_error` y deja el perfil por defecto.
- **`AttackComponent`:**
  - tiempos por posición del clip (§4);
  - `_collect_hits()` usa `ATTACK_RANGE × range_multiplier` y `ATTACK_ARC × arc_multiplier`.

  Sin humanoide, el golpe sigue siendo instantáneo.
- **`ComboDriver.unit_combo()`** también pone `range_multiplier` y `arc_multiplier` en 1.
- Sin cambios en `PlayerAnimator`, `WeaponMount`, `HitstopComponent` ni `WeaponTrail`: leen los mismos nombres de clip y las mismas señales.

## 7. Criterios de aceptación (AC639–AC658, se reservan al empezar la implementación)

**Asset y datos**
- **AC639** Cada perfil (`warrior`, `berserker`, `samurai`) tiene `idle`, `run`, `run_stop`, `jump_start`, `jump_air`, `jump_land`, `hit` y `attack_1` … `attack_N`, con N = golpes del combo de su clase. `idle`, `run` y `jump_air` hacen loop, y el resto no.
- **AC640** Cada `AttackComboStep` de cada clase referencia un clip que existe en el perfil de su clase.
- **AC641** Para cada golpe de cada clase, los eventos del clip coinciden con los tiempos del step (±1 ms): `hit_on = hit_start`, `hit_off = hit_end`, `combo = cancel_point` y `end = end_time =` largo del clip. Además, `0 < hit_start < hit_end ≤ cancel_point < end_time` y `lunge_end ≤ hit_start`.
- **AC642** Las librerías se construyen una sola vez: después de crear el jugador y llamar `set_profile` con las tres clases (dos veces cada una), `get_library_build_count()` vale 1 por perfil y `get_profile_library()` devuelve siempre la misma instancia.
- **AC643** Al elegir cada clase, el jugador usa su perfil (la librería por defecto del `AnimationPlayer` es la del perfil), su combo y su hitstop.
- **AC644** Los combos tienen 4 (Guerrero), 3 (Berserker) y 5 pasos (Samurái: 4 golpes, el último doble), y después del último encadenan `attack_1`. *(Revisado: el Samurái pasó de 5 golpes a 4 con remate doble.)*
- **AC645** Los perfiles de locomoción son distintos: el período de `idle` es 2.0 / 1.0 / 3.0 s, la amplitud de la cadera en `idle` va Berserker > Guerrero > Samurái, y el período de `run` es 0.6 / 0.72 / 0.56 s.

**Gameplay del golpe**
- **AC646** El timing lo manda el step: con una copia del combo cuyo `hit_start` se mueve 0.05 s más tarde que el evento del clip, el daño cae en el `hit_start` del step (±1 cuadro), no en el evento. El estado es `STRIKING` hasta `cancel_point` y el golpe termina en `end_time`.
- **AC647** Alcance y arco por golpe:
  - con el Guerrero, un enemigo a 30° del frente recibe el tajo (`attack_2`, 120°) pero no la estocada del remate (`attack_4`, 48°);
  - un enemigo a `ATTACK_RANGE × 1.15` recibe la estocada del remate (×1.2) pero no el tajo (×1.0);
  - una carta de `ATTACK_RANGE` agranda los dos.
- **AC648** Estocada: sin enemigos, el remate de cada clase avanza su `lunge_distance` ±5 %.
- **AC649** Hit lag y shake: el remate del Berserker pausa el clip 0.16 s (±1 cuadro) y sacude la cámara con 0.5, y el enemigo golpeado tiembla con la amplitud de `berserker_hitstop.tres`. Con el Samurái, `attack_2` pausa 0.04 s.
- **AC650** La velocidad del clip es `ATTACK_SPEED / reference_attack_speed`: vale 1.0 con los stats base de las tres clases, y una carta de velocidad de ataque la sube.
- **AC651** A stats base y encadenando en cada *cancel point* sin hit lag, el DPS de cada clase queda a ±10 % de `ATTACK_SPEED × DAMAGE`.
- **AC652** Compromiso por clase: el tiempo desde que empieza `attack_1` hasta que se puede mover es 0.22 s con el Guerrero, 0.62 s con el Berserker y 0.22 s con el Samurái (±1 cuadro, sin hit lag). El dash lo corta en cualquier momento.

**Visual y regresión**
- **AC653** El arma no atraviesa el cuerpo: en cada clip de cada perfil, muestreado cada 1/30 s, ningún punto del segmento `TrailBase`–`TrailTip` del arma cae dentro del torso (el volumen elíptico de su malla, en el espacio de la articulación `torso`) ni de la cabeza (esfera de su malla). Las piernas son invisibles, así que no cuentan. *(Precisado al implementar: la distancia fija de 0.08 m al eje dejaba pasar la hoja por dentro del torso, que mide 0.17 × 0.11 m de semiejes.)*
- **AC654** La estela se emite durante cada golpe de cada clase y deja de emitirse al terminar.
- **AC655** Con cada clase, recibir daño sin golpe ni casteo reproduce `hit` de su perfil.
- **AC656** Las habilidades siguen igual: pasan `spin_test`, `spin_dash_slash_test`, `air_slash_test`, `sheathe_test`, `sheathe_dash_cancel_test`, `tsubame_gaeshi_test`, `thrust_test` y `swift_strike_test`, salvo los fallos previos registrados.
- **AC657** Datos:
  - los valores de §3 y §6 están en sus `.tres`;
  - los scripts nuevos o tocados no tienen literales de diseño;
  - no quedan referencias a `data/player/attack_combo_config.tres` ni a `data/player/hitstop_config.tres`;
  - el `humanoid_demo` reproduce los tres perfiles.
- **AC658** Regresión:
  - suite completa en verde (salvo los fallos previos y ajenos, que se re-verifican en `HEAD`);
  - import sin errores;
  - smoke test del arena con las tres clases sin errores ni warnings nuevos.

**Revisión del Samurái (2026-09-26):**
- **AC659** Con `auto_chain = true`, al llegar el golpe a su `cancel_point` arranca el golpe siguiente en el mismo cuadro, sin toque de ataque: el estado nunca pasa por `CHAIN_OPEN`, y mover o saltar no lo cortan. El dash sí corta cualquiera de las dos mitades. Con `auto_chain = false` el comportamiento es el de siempre.
- **AC660** Pose del Samurái: en todos los clips de su perfil, la muñeca izquierda queda a ≤ 0.03 m de la boca de la funda (la mano nunca la suelta, y la sostiene sin despegarse), y en `idle` el torso está girado de costado (≥ 30° respecto del frente) mientras la cabeza mira al frente (±10°).

**Revisión del Berserker (2026-09-27, AC678–AC682; AC661–AC677 los tomaron otras specs):**
- **AC678** Pose del Berserker: en `idle` y `run`, muestreados cada 1/30 s, la mano izquierda no tiene peso de agarre, el mango (del pivot del arma a `TrailBase`) pasa a ≤ 0.3 m de la articulación del hombro derecho, y la punta queda más de 1 m detrás de la mano y más de 0.4 m sobre el hombro (el mandoble apoyado en el hombro, hacia atrás y arriba).
- **AC679** En el `hit_start` de cada golpe del Berserker, la mano izquierda está a ≤ 1 mm del `OffHand` del mandoble (después de `WeaponMount.update()`).
- **AC680** En ningún clip del perfil del Berserker, muestreado cada 1/30 s, la punta del mandoble queda debajo del piso.
- **AC681** Continuidad: para cada golpe del Berserker menos el último, todas las pistas de valor del clip en su `cancel_point` y en su `end_time` coinciden con el primer cuadro del golpe siguiente.
- **AC682** Salida lenta: al terminar un golpe del Berserker sin encadenar, `PlayerAnimator` pasa a la locomoción con `attack_exit_blend`: a mitad de la mezcla la muñeca derecha sigue a más de 5° de la guardia (salvo el remate, que ya termina en ella), y durante toda la mezcla la hoja no atraviesa el torso, la cabeza ni el piso.

**Próximo libre después de esta spec: AC683.**

## 8. Enmienda propuesta: PATCH 4.10.1

- **Principio II, viñeta "Personaje procedural":** se aclara que el asset puede tener **perfiles de animación** (uno por clase), y que **todas** sus librerías se construyen una vez al cargar. Elegir perfil solo selecciona una librería ya construida.
- **Principio VII, última viñeta:** "Los tiempos del golpe (inicio y fin del daño, *cancel point* y fin) viven en `AttackComboStep`. Los eventos del clip del humanoide están en los mismos tiempos y un test los compara."
- **Pie del documento:** hoy dice `Version: 4.9.0` aunque el historial ya registra la 4.10.0. Pasa a `4.10.1`.
- **Por qué PATCH:** aclara cómo se cumplen reglas que ya existen (una construcción al cargar, valores del combate en Resources), sin agregar ni redefinir principios.

## 9. Plan de implementación

Cada paso deja el proyecto abriendo y jugable.

1. **Reserva y enmienda:** AC639–AC658 en `CLAUDE.md` (próximo libre → AC659), PATCH 4.10.1. Con la revisión del Samurái, AC659–AC660 (próximo libre → AC661).
2. **Infraestructura + Guerrero:**
   1. Asset: `HumanoidProfile`, librerías por perfil construidas una vez, `set_profile`, el perfil `legacy` (clips de hoy) y el perfil `warrior` (§3.1). `SOURCE.md` y demo.
   2. Datos: campos nuevos de `AttackComboStep` y `CharacterClassData`; `warrior_combo.tres` y `warrior_hitstop.tres`. Berserker y Samurái pasan provisoriamente a `legacy_combo.tres` (los valores de hoy, con los tiempos de los eventos de hoy y `reference_attack_speed` 1.2) y al perfil `legacy`.
   3. `AttackComponent` por posición del clip, rango y arco por golpe, y `Player._apply_character_class`.
   4. Tests del Guerrero (AC639–AC655 en lo que le toca) y adaptación de los tests viejos (§10).
   5. Capturas: idle, run, run_stop, salto y, por cada golpe, anticipación, impacto y remate. Corregir lo que se vea mal. **Te lo muestro y espero tu OK antes de seguir.**
3. **Berserker** (§3.2), con el mismo patrón: perfil, `.tres`, tests, capturas del combo, del Giro, del corte del dash y del Tajo aéreo con las poses nuevas. Te lo muestro.
4. **Samurái** (§3.3), igual: capturas del combo, de la carga y el tajo de Envainar, de *Tsubame gaeshi* y de la funda. Te lo muestro. *(Hecho en su primera versión; el orden pasó a Guerrero → Samurái → Berserker a pedido del responsable.)*
   - **Revisión** (§3.3 revisada):
     1. `AttackComboStep.auto_chain` y su lógica en `AttackComponent` (en el *cancel point*, si el golpe tiene `auto_chain`, arranca el siguiente como si hubiera un toque en el buffer). Tests de AC659 con un combo de prueba.
     2. Perfil del Samurái reescrito: guardia de costado, mano izquierda siempre en la funda, cortes a una mano, remate en dos clips.
     3. `samurai_combo.tres` con la tabla nueva (5 pasos), tests AC660 y actualización de AC644 y AC652.
     4. Capturas y ajuste visual; te lo muestro antes de seguir con el Berserker.
5. **Limpieza:** borrar el perfil `legacy`, `legacy_combo.tres`, `data/player/attack_combo_config.tres` y `hitstop_config.tres`, y actualizar `CLAUDE.md` (dónde se ajusta cada cosa).
6. **Cierre:** suite completa, import, smoke test del arena con las tres clases, review de la constitución (I–VII y Calidad) en esta spec y estado **Implementada**.

## 10. Tests

- **Nuevo:** `test/entities/player/class_combat_identity_test.gd` (AC639–AC655, AC657, AC659 y AC660).
- **Tests viejos que se adaptan** (verifican lo mismo; cada uno se anota en las notas al cerrar):
  - `attack_component_test`: el ciclo `attack_3 → attack_1` pasa a ser "el último golpe encadena `attack_1`" (4 golpes con el Guerrero). AC600 (velocidades 1.0 / 0.5 / 1.33) pasa a AC650. AC601 pasa a AC651 con el combo de cada clase.
  - `combat_feel_test`, `hitstop_test` y `humanoid_model_test`: leen el combo y el hitstop del Guerrero en lugar de `data/player/*`, y los tiempos fijos (p. ej. `hit_on` 0.12) pasan a leerse del step.
  - `berserker_run_test` y `samurai_run_test`: si fijan la velocidad del clip o la cantidad de golpes.
  - `weapon_trail_test` y `player_animator_test`: solo si leen tiempos fijos de los clips genéricos.
- **Validación visual:** una escena temporal en la copia del scratchpad, sin `--headless`, que pone cada clip en sus tiempos clave (anticipación, `hit_start`, *hold*, fin) y guarda capturas de frente y de costado. Se revisa que la silueta se lea y que el arma no atraviese el cuerpo.

## 11. Decisiones a confirmar

- **D1. Cantidad de golpes: 4 / 3 / 5** (Guerrero / Berserker / Samurái), para que la cantidad sea una marca de cada clase. Alternativa: 3 / 3 / 4, que es menos trabajo de poses pero se distingue menos. *(Revisado: el Samurái pasa a 4 golpes con 5 impactos; lo que lo distingue ahora es el remate doble y la mano en la funda.)*
- **D2. Balance: se conserva el DPS de hoy** (`Σ daño = ATTACK_SPEED × ciclo`), como en AC601. El hit lag resta un 12–20 % si todos los golpes pegan, parecido a hoy (Guerrero 18 %, Berserker 10 %, Samurái 22 %). Alternativa: compensar el hit lag en los multiplicadores. Afecta la vida de los bosses de `boss-health-tuning.md`.
- **D3. Timing:** `AttackComboStep` manda y un test compara los eventos del clip (§4).
- **D4. `reference_attack_speed` = `ATTACK_SPEED` base de cada clase,** así las tablas son tiempos reales.
- **D5 (revisión del Samurái). Remate doble con `auto_chain`** (dos clips encadenados solos) en lugar de un golpe con varios impactos. Alternativa: `AttackComboStep.hits` (lista de impactos por golpe, cada uno con tiempo, daño, hit lag y sector). Es más general, pero cambia el modelo de datos, el timing por posición y AC641 para un solo golpe del juego.
- **D6 (revisión del Samurái). Lado del costado:** hombro izquierdo (el de la funda) hacia el enemigo, torso a −40° y cabeza al frente. Es la guardia de iaido: la funda queda adelante y la katana atrás, lista para cortar. Si preferís el hombro derecho adelante, es solo un cambio de ángulos.

## 12. Traspaso a otra sesión (2026-09-27)

**Estado:** Guerrero y Samurái implementados y aprobados por el responsable con capturas. **Berserker implementado (2026-09-27, §3.2 revisada), esperando el OK de las capturas.** Falta la limpieza (paso 5) y el cierre (paso 6).

### Berserker (2026-09-27)
- `profiles/berserker_profile.gd`: guardia con el mandoble al hombro, locomoción y combo de §3.2 revisada. Los ángulos del brazo derecho se calcularon con un solver temporal (fuera del repo) a partir de la posición de la mano y la dirección de la hoja buscadas en cada pose clave.
- `berserker.tres` → perfil `berserker`, `berserker_combo.tres` y `berserker_hitstop.tres`; `OffHand` en `greatsword.tscn`; `BERSERKER` en `CLASSES` del test.
- `WeaponMount.update()` → `LowPolyHumanoid.refresh_hand_targets()` (§3.2).
- Continuidad del combo y `PlayerAnimationConfig.attack_exit_blend` (§3.2), con `PlayerAnimator._request_locomotion()`.
- Tests: `class_combat_identity_test` en verde (AC678–AC682 nuevos), salvo AC653 en el `sheathe_charge` del Samurái, que ya fallaba antes de este cambio (ver abajo). `sheath_grip_test` en verde salvo AC675 (previo).
- **Tests adaptados** (verifican lo mismo):
  - `sheath_grip_test` AC665: el Berserker tenía peso 1 en todos los cuadros de sus golpes; ahora se exige en el `hit_start` de cada golpe, porque suelta la izquierda al final del barrido de vuelta.
  - `berserker_run_test` AC187 ("golpes más lentos"): suponía el combo provisorio a velocidad ×0.5; ahora verifica que el primer golpe siga comprometido (sin aceptar otro toque) hasta su *cancel point*, que es más del doble del del Guerrero.
- **Fallos previos, ajenos a este cambio** (se reprodujeron sin él o no tocan datos modificados acá): AC653 del Samurái en `sheathe_charge` y AC675 (la pose de carga de `sheath-in-left-hand.md` y el primer cuadro de `sheathe_slash`), `berserker_run_test` AC221 (arco 150° vs. el `.tres`), `air_slash_test` AC578 (valores del `.tres`) y `spin_test` AC188.

### Qué está hecho
- **Infraestructura:**
  - perfiles del humanoide (`assets/models/characters/low_poly_humanoid/profiles/`), con librerías construidas una vez por ejecución y compartidas;
  - timing del golpe por posición del clip (`AttackComboStep.hit_start` … `end_time`), con rango y arco por golpe;
  - `auto_chain`;
  - `CharacterClassData.animation_profile` / `combo` / `hitstop`.
- **Guerrero** (`warrior_profile.gd`, `warrior_combo.tres`, `warrior_hitstop.tres`): versión "expresiva" con referencia de Kaeya (Genshin), §3.1.
- **Samurái** (`samurai_profile.gd`, `samurai_combo.tres`, `samurai_hitstop.tres`): §3.3 revisada, 4 golpes con remate doble, los ocho cortes, a una mano.
  - La funda, las manos y la pose de carga de Envainar se rigen por `sheath-socket-hand-grip.md` y por `sheath-in-left-hand.md`, esta última de **otra sesión**, que la cuelga de `wrist_l`. **Leé esas dos specs antes de tocar al Samurái.**
- **Tests:** `test/entities/player/class_combat_identity_test.gd`. La constante `CLASSES` lista las clases con perfil propio; hoy es `[WARRIOR, SAMURAI]`.

### Qué falta (en orden)
1. **Berserker** (§3.2; la tabla de tiempos y datos sigue vigente):
   - `profiles/berserker_profile.gd`, registrado en `LowPolyHumanoid.PROFILES`;
   - `data/classes/berserker/berserker_combo.tres` y `berserker_hitstop.tres`;
   - `berserker.tres`, que hoy apunta a `legacy` y a `data/player/*`: pasarlo a `animation_profile = &"berserker"` y a los datos nuevos;
   - sumar `BERSERKER` a `CLASSES` del test.
   - **Estilo que pide el responsable** (memoria `animation-expressiveness`): poses muy expresivas desde el primer intento, con giro e inclinación grandes de torso, brazos estirados, recorridos largos y zancadas bajas. Suele mandar referencias (juegos o fotos): pedile una antes de posar. Mostrale las capturas antes de seguir.
   - **Mandoble a dos manos:** usar la API genérica `set_hand_target(Hand.LEFT, marker)` con un `Marker3D` de mango en `greatsword.tscn` y `left_grip` en los clips (ver `sheath-socket-hand-grip.md` §2.3). Evaluá cómo convive con la funda del Samurái, que usa la mano izquierda en `sheath-in-left-hand.md`.
   - **No debe pisarse con el Giro ni con el Tajo aéreo** (§3.2). Verificá con capturas que esas habilidades se sigan viendo bien con la guardia nueva.
2. **Limpieza (paso 5):**
   - borrar `profiles/legacy_profile.gd` y su entrada en `PROFILES`;
   - borrar `data/player/attack_combo_config.tres` y `data/player/hitstop_config.tres`, y apuntar `player.tscn` a los del Guerrero;
   - adaptar `humanoid_model_test` (AC590 lee la librería `legacy`; AC607 lee `data/player/*`);
   - actualizar en `CLAUDE.md` las líneas "Ataque básico = combo" y "Cuerpo del jugador" (combo y hitstop por clase, perfiles).
3. **Cierre (paso 6):**
   - suite completa: el responsable la pidió en esta spec, aunque la memoria `targeted-tests-only` diga lo contrario para specs sin pedido explícito;
   - import y smoke test del arena con las tres clases;
   - checklist de la constitución (I–VII y Calidad) en esta spec y estado **Implementada**;
   - notas de implementación: tests adaptados y fallos previos AC236 y AC363, ver `sheath-socket-hand-grip.md` §9.

### Cómo se validaron las poses
- Las capturas salen de una escena temporal (`extends Node`) que corre sin `--headless` en una copia del proyecto en el scratchpad. Instancia `player.tscn` con la clase en `Session.character_class` y apaga `PlayerAnimator` y el proceso del jugador. Por cada `(clip, tiempo)` hace `anim.play(clip, 0)` + `anim.seek(t, true)` + `WeaponMount.update(1.0)`, y arma una hoja con una columna por tiempo y cuatro vistas por fila: juego (1.0, 2.3, 2.9), 3/4 de frente (1.7, 1.3, −2.3), costado (2.9, 1.0, −0.3) y frente a la altura del personaje (0.3, 0.9, −2.6).
- Para los golpes conviene capturar en `hit_start × 0.6`, `× 0.85`, `hit_start`, a mitad del *active*, en `hit_end` y en `cancel_point`.
- AC653 (la hoja no atraviesa torso ni cabeza) detecta la mayoría de los errores de pose antes de capturar.

**Próximo criterio de aceptación libre:** mirá `CLAUDE.md` (hoy AC683). AC639–AC660 y AC678–AC682 siguen reservados por esta spec.
