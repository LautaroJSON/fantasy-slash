# Feature: la funda sigue al torso y la mano izquierda la sostiene

- **Estado:** Aprobada (2026-09-27, con la pose de carga de Envainar de §2.7), en implementación. Revisión 4 de la pose de carga (§2.7, AC670) aprobada e implementada (2026-09-27).
- **Constitución:** `docs/constitution.md` v4.10.1 (sin enmienda: ver §8).
- **Pilar (Principio I):** **combate.** La silueta del Samurái (la mano en la funda, el cuerpo que gira sobre ella) es parte de cómo se lee su guardia y cada corte. Hoy la funda y la mano quedan quietas mientras el cuerpo gira, y el golpe se lee peor.
- **Reemplazos:** §2.1 (socket en el torso) y la curva `left_grip` de §2.4 quedan reemplazados por `sheath-in-left-hand.md` (la funda cuelga de la mano izquierda; AC661, AC662 y AC666 pasan a AC671–AC673, y AC667 a AC675).
- **Dependencias:** `class-combat-identity.md` (en implementación: perfiles del humanoide, Samurái revisado), `samurai.md`, `sheathe-dash-cancel.md`, `humanoid-player-model.md` (`WeaponMount`).
- **Fuera de alcance:** la segunda mano del mandoble del Berserker. La API queda lista para eso (§2.3), pero se usa recién en su spec.

## 1. Diagnóstico (estado actual)

1. **La funda cuelga del `Visual`.** `Player._equip_sheath()` la instancia como hijo de `Visual`, con `WeaponData.sheath_position`/`sheath_rotation` fijos. `Visual` solo gira hacia donde mira el jugador, así que la funda no acompaña giros, inclinaciones ni la respiración del torso.
2. **La hoja envainada también está fija.** `SheatheAbility.begin_charge()` usa `sword_swing.hold_pose(SheatheConfig.sheathed_position, …)`, en espacio del `Visual`, y `sheathe_slash` (el `SwingPlayer` de `player.tscn`) anima `Visual/SwordPivot` desde esa misma pose.
3. **La mano no agarra nada.** El perfil del Samurái (`class-combat-identity.md`, revisión 2) fija la muñeca izquierda en un punto del espacio del humanoide (la boca de una funda que no se mueve), resolviendo los ángulos del brazo al construir los clips (`pin_left_hand`). No hay vínculo en runtime entre la mano y la funda: la mano queda clavada en el aire mientras el torso gira.

## 2. Diseño

### 2.1 Socket de la funda en el torso

- `LowPolyHumanoid.attach_to_joint(joint: String, node: Node3D) -> void` (nuevo): agrega `node` como hijo de la articulación y **compensa la escala** del humanoide (`humanoid.tscn` lo escala ×1.333), así lo que cuelga del socket mide lo mismo que en el `Visual`.
- `Player._equip_sheath()` crea un `Node3D` **`SheathSocket`**, lo cuelga de la articulación `torso` con `attach_to_joint` y le pone la posición y rotación de `WeaponData.sheath_position`/`sheath_rotation`, que **cambian de significado**: pasan a ser relativas al torso (metros del jugador, ya compensada la escala). La funda se instancia como hijo del socket, sin offset.
- Así la funda acompaña al torso en todos los clips, locomoción, golpes, `hit` y habilidades, porque el `idle` también mueve el torso.
- `Player.get_sheath_socket() -> Node3D` (nuevo), junto al `get_sheath()` de hoy.

### 2.2 Marcador de agarre en la funda

- `katana_sheath.tscn` suma un `Marker3D` **`Grip`** donde la mano izquierda toma la funda: justo debajo de la boca, orientado como la mano. Es parte de la escena adaptadora (Principio II).

### 2.3 Objetivos de mano (API genérica del humanoide)

- `enum Hand { LEFT, RIGHT }`.
- `set_hand_target(hand: Hand, target: Node3D) -> void` y `clear_hand_target(hand: Hand) -> void`.
- `@export var left_hand_grip_weight: float` y `right_hand_grip_weight: float`, en [0, 1]. **Los anima cada clip** (§2.4).
- **Aplicación, cada vez que el `AnimationPlayer` aplica la animación** (señal `AnimationMixer.mixer_applied`, conectada una vez en `_ready`):
  - `pose_animada = wrist.global_transform * reposo_local_de_la_malla`;
  - `malla.global_transform = pose_animada.interpolate_with(target.global_transform, peso)`.
  - Con peso 0 (o sin objetivo), la malla vuelve a su transform local de reposo.
- **Se mueve solo la malla visual de la mano** (`MeshInstance3D` hija de la muñeca). `wrist_l`/`wrist_r` no se tocan, así que el arma que cuelga de la muñeca derecha (`WeaponMount`) y cualquier otra pieza siguen igual. Como los brazos son invisibles, no hace falta IK.
- **Orden garantizado:** `mixer_applied` se emite después de aplicar las pistas del cuadro, en el mismo paso de proceso, así que la mano nunca lleva un cuadro de atraso respecto de la animación. Si la funda se movió en ese mismo cuadro, ya está en su lugar, porque cuelga del torso animado.
- **Performance (Principio V):** solo matemática de `Transform3D` (valores, sin allocations), sin búsquedas de nodos: las mallas y los objetivos quedan cacheados.

### 2.4 El peso de agarre es parte del clip

- `make_clip()` agrega siempre dos pistas de valor: `.:left_hand_grip_weight` y `.:right_hand_grip_weight`. Cada pose clave puede llevar `"left_grip"` / `"right_grip"` (0 a 1). Si no lo lleva, vale el de la pose anterior, o 0 en la primera.
- Así un golpe puede soltar la funda en la anticipación y volver a tomarla en la recuperación, con la misma interpolación que el resto del clip.
- **Guerrero y Berserker:** 0 en todos sus clips (no tienen objetivo de mano).
- **Curva propuesta para el Samurái** ("siempre tiene una mano sosteniendo la funda"):

  | Clip | `left_grip` | Nota |
  |---|---|---|
  | `idle`, `run`, `run_stop`, `jump_*`, `hit` | 1 constante | La mano no suelta la funda. |
  | `attack_1` (horizontal) | 1 constante | *Saya-biki*: la mano tira de la funda, que acompaña al torso al girar. |
  | `attack_2` (diagonal ascendente) | 1 constante | |
  | `attack_3` (vertical) | 1 constante | |
  | `attack_4` / `attack_5` (remate) | 1 constante | |

  `right_grip` vale 0 en todo el perfil.
- **Alternativa:** soltar la funda en el remate (1 → 0.4 en la anticipación de `attack_5` y de vuelta a 1 en el *zanshin*), para que el brazo izquierdo acompañe el corte más amplio. No la propongo por defecto porque pediste que la mano esté siempre en la funda.
- **Se borra el ajuste de brazo horneado** de `class-combat-identity.md` (`pin_left_hand`, `with_left_hand_at`, `with_left_hand_on_grip` y su búsqueda). Deja de hacer falta y la construcción de las librerías vuelve a ser rápida. El brazo izquierdo del Samurái vuelve a una pose simple junto a la cintura, desde donde la mano "viaja" si algún clip baja el peso.

### 2.5 La hoja envainada sigue al socket (Envainar)

- **`WeaponMount`** suma un tercer dueño del pivot del arma: **la funda**.
  - `hold_in_sheath(held: bool) -> void`: mientras vale `true`, cada cuadro lleva `Visual/SwordPivot` a la pose global del socket (sin escala), aunque haya un casteo o una carga en curso.
  - Prioridad: funda > habilidades y barrido (sin tocar el pivot) > mano.
- **`SheatheAbility`:**
  - `begin_charge` llama `ability.weapon_mount.hold_in_sheath(true)` en lugar de `sword_swing.hold_pose(sheathed_*)`.
  - Al soltar (`begin`, `_end_charge`) y en `cancel_charge` llama `hold_in_sheath(false)`. El resto (la recuperación con `recover()`, el tajo, la V) queda igual.
- **`AbilityComponent`** suma `@export var weapon_mount: WeaponMount` (lo enlaza `player.tscn` en las dos ranuras).
- **`sheathe_slash`:** el tajo sale desde la funda. El primer cuadro de la animación (espacio del `Visual`) pasa a ser la pose del socket con el humanoide en `idle` (t = 0), que es el clip que suena mientras se carga. Un test compara ese cuadro con la pose real del socket (§4). Durante un dash con carga, el socket se mueve con el torso y la hoja lo sigue.
- **Mano izquierda en Envainar** (`samurai.md` no dice nada): sostiene la funda durante la carga y el tajo, porque el humanoide hace `idle` (peso 1). Es coherente con el iaido: la izquierda sujeta la saya mientras la derecha desenvaina.
- **`SheatheConfig.sheathed_position`/`sheathed_rotation` se borran:** la pose envainada ya no es un dato fijo en el `Visual`, es el socket.

### 2.7 Pose de carga de Envainar (agregada al aprobar, con imagen de referencia)

- **Clip nuevo del perfil del Samurái: `sheathe_charge`** (loop, 2 s de respiración contenida). *Revisado cuatro veces (2026-09-27) con las referencias del responsable. La revisión 4 reemplaza la sentadilla abierta y erguida de la 3 (de frente se leía como sumo, con la katana horizontal saliendo de costado) por la estocada baja y volcada de la foto de Renji en la escalera.*
  - **Piernas: estocada baja, adelante-atrás (no abiertas a los costados).** La izquierda adelante, con la rodilla flexionada sobre el pie (el muslo casi horizontal, el pie plano ≈ 40 cm delante de la cadera). La derecha estirada atrás, con la rodilla cerca del piso y el pie ≈ 45 cm detrás de la cadera. Los pies quedan casi en línea: ≤ 30 cm de separación lateral, contra los ≈ 55 cm de la revisión 3. La cadera ≈ 30 cm más baja que de pie y girada ≈ −35°, así que el hombro izquierdo sigue adelante.
  - **Torso: volcado hacia el enemigo (≈ 40°)**, con el pecho casi de frente (poca torsión), como quien se agazapa antes de saltar. Como la funda sigue al torso (§2.1), al volcarlo **la funda deja de estar horizontal**: el mango queda adelante y abajo, junto a la cadera izquierda, y la punta sube detrás de la espalda (≥ 20° sobre la horizontal), igual que en la foto. `katana.tres` no cambia: la inclinación sale del torso.
  - **Cabeza arriba:** el cuello compensa el vuelco (≈ +35°), así la cara mira al enemigo por encima de la guardia, como en la foto.
  - **Manos (sin cambios):** la izquierda sostiene la funda junto a la tsuba (`left_grip` 1) y la derecha cruza el cuerpo hasta el mango (`right_grip` 1, al `Hilt`). Como la funda baja por delante, las dos manos quedan juntas y bajas, adelante de la cadera izquierda.
  - **Respiración:** en 1 s la cadera baja 1 cm más y el torso se vuelca 1° más; en 2 s vuelve.
  - **Centrada:** la cadera se corre en el plano horizontal para que el promedio de cadera, torso, cabeza y pies quede sobre la posición del jugador (el torso volcado corre la cabeza adelante; la pierna derecha atrás compensa en parte).
  - Los ángulos exactos se ajustan con hojas de capturas (frente, perfil, tres cuartos y la cámara del juego) hasta que la silueta coincida con la referencia; los números de arriba son el punto de partida, y los que valen son los de AC670.
- **Mano derecha en el mango:** `katana.tscn` suma un `Marker3D` **`Hilt`** en el mango y `Player` lo registra como objetivo de la mano derecha (`set_hand_target(RIGHT, hilt)`). Solo `sheathe_charge` tiene `right_grip` en 1; en el resto de los clips vale 0 y la mano sigue su animación, mientras el arma sigue a la muñeca con `WeaponMount`.
- **Quién elige el clip:** `SheatheConfig.charge_body_clip: StringName` (`&"sheathe_charge"`). `AbilityBehavior.get_body_clip(ability) -> StringName` (nuevo; por defecto `&""`) lo devuelve mientras se carga. `PlayerAnimator` pide ese clip en lugar de `idle` mientras dure la acción, si el perfil activo lo tiene, y si no, `idle`. El dash con carga sigue sonando `run`.
- **El tajo** (`sheathe_slash`, recuperación) vuelve a `idle` con la mezcla de siempre. El primer cuadro de `sheathe_slash` se alinea con el socket **en `sheathe_charge`** (t = 0), que es la pose desde la que se suelta, en lugar de `idle`.
- **AC670** Con Envainar cargando suena `sheathe_charge` (revisión 4; medido en t = 0, en el espacio del `Visual`, con −Z hacia el enemigo):
  - la cadera está ≥ 20 cm más baja que en `idle` y el torso volcado hacia adelante ≥ 35°;
  - estocada: el tobillo izquierdo está ≥ 25 cm delante de la cadera y el derecho ≥ 25 cm detrás, con ≤ 30 cm de separación lateral entre los dos;
  - la funda sube hacia atrás: su eje, del mango a la punta, queda ≥ 20° sobre la horizontal, y la punta está detrás de la cadera;
  - la cabeza mira al enemigo: su frente queda a ≤ 25° de −Z del `Visual`;
  - la mano izquierda está sobre el `Grip` de la funda y la derecha sobre el `Hilt` de la katana envainada (≤ 1 mm);
  - el cuerpo está centrado: el promedio horizontal de cadera, torso, cabeza y pies queda a ≤ 5 cm de la posición del jugador;
  - al soltar, el primer cuadro de `sheathe_slash` coincide con el socket en esa pose (≤ 2 cm, ≤ 5°).

  *(Revisión 4: suben los mínimos de caída y vuelco, 12 cm → 20 cm y 20° → 35°, y se suman la estocada, la funda inclinada y la cabeza al frente. La spec sigue abierta, así que AC670 se reescribe en lugar de tomar un número nuevo.)*

  El Guerrero y el Berserker no tienen `sheathe_charge`, y sus habilidades siguen con `idle`.

### 2.6 Datos (Principio III)

| Resource / escena | Cambio |
|---|---|
| `WeaponData.sheath_position` / `sheath_rotation` | Pasan a ser **relativos al torso** (socket). Valor inicial en `katana.tres`: la cintura izquierda, adelante, con la punta atrás y afuera. Se ajustan con capturas; referencia ≈ (−0.19, 0.03, −0.08) m y (−0.35, 2.69, 0) rad. |
| `katana_sheath.tscn` | + `Marker3D` `Grip`. |
| `SheatheConfig` | − `sheathed_position`, − `sheathed_rotation` (y sus líneas en `sheathe_config.tres`); + `charge_body_clip` (`&"sheathe_charge"`, §2.7). |
| `katana.tscn` | + `Marker3D` `Hilt` (§2.7). |
| `player.tscn` | `AbilityComponent.weapon_mount` enlazado; primer cuadro de `sheathe_slash` actualizado. |
| Perfiles del humanoide | Curvas `left_grip`/`right_grip` (datos del asset, Principio II). |

Todo es sensación y arte, nada mejorable con cartas.

## 3. Interfaz pública (resumen)

- `LowPolyHumanoid`: `enum Hand`, `set_hand_target()`, `clear_hand_target()`, `left_hand_grip_weight`, `right_hand_grip_weight`, `attach_to_joint()`.
- `Player`: `get_sheath_socket()`.
- `WeaponMount`: `hold_in_sheath()`, `is_holding_in_sheath()`, `setup(weapon, sheath_socket)`.
- `AbilityComponent`: `weapon_mount`.

## 4. Criterios de aceptación (AC661–AC670; AC670 en §2.7)

- **AC661** La funda del Samurái es hija de `SheathSocket`, que cuelga de la articulación `torso` del humanoide con el `sheath_position`/`sheath_rotation` de `katana.tres` y la escala compensada: el modelo de la funda mide lo mismo en el mundo que con escala 1. El Guerrero y el Berserker no tienen socket ni funda.
- **AC662** La funda sigue al torso: en los clips del Samurái, muestreados cada 1/30 s, la transform global del socket es `torso.global_transform * socket_local` (±1 mm), y entre la anticipación y el impacto de `attack_1` la funda gira con el torso (≥ 30°).
- **AC663** `set_hand_target` es genérico y funciona para las dos manos, con un `LowPolyHumanoid` suelto y un `Marker3D`:
  - con peso 1, el origen de la malla de la mano coincide con el objetivo (≤ 1 mm);
  - con peso 0, la malla vuelve a su transform local de reposo;
  - con 0.5, queda a mitad de camino.

  `clear_hand_target` equivale a peso 0.
- **AC664** El agarre se aplica en el mismo cuadro que la animación: después de `anim.advance()`, sin esperar otro cuadro, la mano ya está en el objetivo, aunque el objetivo se haya movido en ese avance (cuelga del torso). `wrist_l` conserva exactamente el valor que le da el clip.
- **AC665** Todo clip de todo perfil tiene las pistas `left_hand_grip_weight` y `right_hand_grip_weight`. En el Samurái la izquierda vale 1 en todos sus clips (tabla de §2.4) y la derecha 0. En el Guerrero las dos valen 0.
- **AC666** Con el Samurái, la malla de la mano izquierda está sobre el `Grip` de la funda (≤ 1 mm) en todos sus clips, muestreados cada 1/30 s. *(Reemplaza la parte de la mano de AC660; la parte del torso de costado y la cabeza al frente sigue vigente.)*
- **AC667** Envainar:
  - mientras carga, el pivot de la katana está en la pose global del socket (±1 mm), también durante un dash con carga;
  - el primer cuadro de `sheathe_slash` coincide con la pose del socket en `idle` (t = 0), a ≤ 2 cm y ≤ 5°;
  - cancelar la carga o terminar la recuperación deja de sostener la hoja y el arma vuelve a la mano.

  *(Adapta AC250: "la katana descansa en la funda" pasa a compararse contra el socket y no contra `sheathed_*`.)*
- **AC668** Datos: `SheatheConfig` ya no tiene `sheathed_*`, `katana_sheath.tscn` tiene `Grip`, el kit del humanoide ya no tiene el ajuste de brazo horneado (`pin_left_hand` y compañía), y no hay literales de diseño nuevos en scripts de comportamiento.
- **AC669** Regresión: pasan `class_combat_identity_test`, `sheathe_test`, `sheathe_feel_test`, `tsubame_gaeshi_test`, `nuki_test`, `zanshin_test`, `wind_step_test`, `wind_cut_vfx_test`, `dash_cancel_test` y `samurai_run_test` (AC238 adaptado al socket), salvo los fallos previos y ajenos registrados. Import y smoke test del arena con el Samurái sin errores ni warnings.

**Próximo libre después de esta spec: AC671.**

## 5. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC661–AC670 en `CLAUDE.md` (próximo libre → AC671).
2. **Humanoide:**
   - `Hand`, objetivos de mano, pesos animados y `mixer_applied`;
   - pistas de peso en `make_clip`;
   - `attach_to_joint`;
   - borrar `pin_left_hand` y el ajuste de brazo;
   - `SOURCE.md`.
3. **Samurái:** curvas de peso (§2.4) y brazo izquierdo en una pose simple junto a la cintura. Guerrero y legacy: peso 0, por defecto.
4. **Funda:** `Grip` en `katana_sheath.tscn`; `SheathSocket` en `Player`; `sheath_position`/`sheath_rotation` recalculados como relativos al torso (captura); `set_hand_target(LEFT, grip)`.
5. **Envainar:** `WeaponMount.hold_in_sheath`, `AbilityComponent.weapon_mount`, `SheatheAbility`; borrar `sheathed_*`; primer cuadro de `sheathe_slash` alineado con el socket en `idle`.
6. **Tests:** AC661–AC668 nuevos en `test/entities/player/sheath_grip_test.gd`; AC660 (mano), AC250 y AC238 adaptados. Se corren las suites de AC669.
7. **Capturas:** idle, los 5 golpes y la carga de Envainar, para verificar que la funda acompaña al torso y la mano la sostiene. Después, cierre en esta spec y en las notas de `class-combat-identity.md`.

## 6. Tests adaptados (se anotan al cerrar)

- **AC238** (`samurai_run_test`): la funda deja de ser hija de `Visual` y pasa a ser hija del socket; el socket cuelga del torso con los datos del arma.
- **AC250** (`sheathe_test`): la katana cargando está en la pose del socket (ya no en `sheathed_*`).
- **AC660** (`class_combat_identity_test`): la parte de la mano pasa a AC666; se conserva la del torso de costado.

## 7. Riesgos

- **`mixer_applied` y los tests que avanzan los clips a mano:** `ComboDriver.drive_by_hand` usa proceso manual y `anim.advance()`, que también emite `mixer_applied`, así que la mano se actualiza igual (AC664 lo verifica).
- **Hit lag** (`speed_scale = 0`): el mixer igual aplica cada cuadro; si en algún caso no emite la señal, la mano queda donde estaba, que es la misma pose, porque el clip está pausado.

## 8. Constitución

Sin enmienda:
- Las mallas del humanoide se siguen construyendo una vez.
- Mover la malla de la mano en runtime es animación, igual que las pistas del `AnimationPlayer`.
- El socket y el marcador son nodos de escena sin geometría nueva.
- No hay colores, shaders ni assets nuevos.

La API de objetivos de mano se documenta en el `SOURCE.md` del asset.

## 9. Notas de implementación (2026-09-27)

- **Socket:** `sheath_position` (−0.19, 0.03, −0.08) m y `sheath_rotation` (−0.35, 2.69, 0) rad, relativos a la articulación `torso`, validados con capturas. La funda gira con el torso en todos los clips (en el tajo horizontal acompaña el giro de −54° a +84° del torso).
- **`sheathe_slash`:** su primer cuadro es la pose del socket en `sheathe_charge` (t = 0), medida con una escena temporal. Con la revisión 4: posición (−0.2295, 0.5112, 0.0334) y rotación (0.4539, 2.921, −0.1608) en el `Visual`.
- **Pose de carga, revisión 4** (ajustada con hojas de capturas de frente, de perfil, en tres cuartos y con la cámara del juego):
  - cadera `hips_pos` (−0.04, −0.44, 0.12), girada −35°;
  - torso (−45°, 55°, −15°): el giro abre el pecho y la inclinación lateral de −15° deja el vuelco derecho al frente, sin caer hacia la izquierda;
  - cuello (45°, −22°);
  - piernas: la izquierda (87°, 35°) con la rodilla en −63° y el tobillo en −24°; la derecha (−20°, 35°) con la rodilla en −72° y el tobillo en 32°.
  
  Medido en t = 0: la cadera 29 cm más baja, el torso volcado 47°, el tobillo izquierdo 39 cm adelante y el derecho 51 cm atrás (20 cm de separación lateral), la funda subiendo 26° hacia atrás, la cara a 6° del frente y el centro a 3 cm.
- **AC670 (revisión 4):** en `sheath_grip_test` se sumaron las comprobaciones de la estocada, la funda inclinada y la cabeza, y se subieron los mínimos de caída y vuelco. La punta detrás de la cadera se verifica con el eje de la funda apuntando hacia atrás (+Z del `Visual`). Pasan `sheath_grip_test` (11) y `sheathe_test` (18), y el smoke test del arena corre sin errores ni warnings.
- **`WeaponMount`** actualiza la hoja envainada también con `mixer_applied`, así no queda un cuadro atrás del torso.
- **Se borró el ajuste de brazo horneado** de `class-combat-identity.md` (revisión 2 del Samurái): el kit ya no tiene `pin_left_hand`, `with_left_hand_at`, `with_left_hand_on_grip` ni la búsqueda por descenso de coordenadas.
- **Tests (en verde):**
  - `sheath_grip_test` (11 casos, AC661–AC668 y AC670);
  - regresión de AC669: `class_combat_identity_test` (20), `humanoid_model_test`, `sheathe_test`, `sheathe_feel_test`, `tsubame_gaeshi_test`, `nuki_test`, `zanshin_test`, `wind_step_test`, `wind_cut_vfx_test`, `attack_component_test`, `combat_feel_test`, `hitstop_test`, `player_animator_test`, `weapon_mount_test` y `weapon_trail_test`.
- **Fallos previos y ajenos** (ya registrados):
  - **AC236** (`samurai_run_test`): stats del Samurái cambiados fuera de su spec. Hace abortar esa suite, así que AC238 adaptado no llega a correr ahí; la coincidencia funda ↔ Envainar la cubre AC667.
  - **AC363** (`dash_cancel_test`): tras cortar Envainar con un dash, la katana vuelve a la mano (`WeaponMount`, desde `humanoid-player-model.md`) y no a `rest_position`, que es lo que espera el test viejo. La diferencia es mayor que antes porque la mano del Samurái cambió de pose, pero la causa es la misma.
- **Tests adaptados** (verifican lo mismo):
  - **AC238:** la funda es hija del socket, que cuelga del torso con los datos del arma.
  - **AC250:** la katana cargando está en la pose del socket.
  - **AC660:** la parte de la mano pasó a AC666.
  - **AC653:** `sheathe_charge` se evalúa con la katana en la funda.
