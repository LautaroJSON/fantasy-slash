# Feature: la funda va en la mano izquierda

- **Estado:** Implementada (2026-09-27).
- **Constitución:** `docs/constitution.md` v4.10.x (sin enmienda: ver §7).
- **Pilar (Principio I):** **combate.** El ángulo de la funda es parte de la silueta del Samurái: en la guardia, en cada corte (*saya-biki*) y sobre todo en la carga de Envainar. Hoy solo se puede cambiar girando el torso, así que no se puede inclinar la funda sin deformar el cuerpo. Con la funda en la mano, el brazo izquierdo la orienta como el derecho orienta la katana.
- **Dependencias:** `sheath-socket-hand-grip.md` (en implementación; esta spec **reemplaza** su §2.1 "socket en el torso" y la curva `left_grip` de §2.4), `class-combat-identity.md`, `humanoid-player-model.md` (`WeaponMount`).
- **Decisiones del responsable (2026-09-27):** la funda va en la mano izquierda **en todos los clips** del Samurái, y su ángulo se controla **con el brazo** (`shoulder_l`, `elbow_l`, `wrist_l` de cada pose).

## 1. Estado actual

1. `Player._equip_sheath()` cuelga `SheathSocket` de la articulación `torso` (`SHEATH_JOINT = "torso"`, un literal en el script) con `WeaponData.sheath_position`/`sheath_rotation`.
2. La mano izquierda va a la funda: la malla de la mano se lleva al `Grip` con `left_grip` = 1 en todos los clips del Samurái. El brazo izquierdo no importa, porque la mano no está donde el brazo la deja.
3. Consecuencia: la funda sigue al torso y su ángulo respecto del torso es un dato fijo. Ninguna pose puede inclinarla por separado.

## 2. Diseño

### 2.1 La funda cuelga de la muñeca izquierda

- `WeaponData` suma `@export var sheath_joint: StringName`, la articulación del humanoide de la que cuelga el socket de la funda. En `katana.tres` vale `&"wrist_l"`. Reemplaza al literal `SHEATH_JOINT` de `player.gd` (Principio III).
- `sheath_position`/`sheath_rotation` **cambian de significado otra vez**: pasan a ser el agarre de la funda en la mano izquierda, relativos a `wrist_l` (metros del jugador, con la escala compensada por `attach_to_joint`). Son el equivalente de `grip_position`/`grip_rotation` de la katana en la mano derecha.
- Valor inicial: el que deja el `Grip` de `katana_sheath.tscn` sobre el centro de la malla de la mano izquierda, con la funda a lo largo del antebrazo hacia atrás cuando la muñeca está en reposo. Se calcula en la implementación y se ajusta con capturas.
- `Player.get_sheath_socket()` y `LowPolyHumanoid.attach_to_joint()` no cambian.

### 2.2 La mano ya no busca la funda

- Como la funda viene a la mano, la malla de la mano izquierda **queda donde la deja el brazo**: `Player` deja de registrar el `Grip` como objetivo de la mano izquierda, y los clips del Samurái pasan `left_grip` a 0.
- El `Grip` queda sobre la mano por construcción del socket, así que "la mano sostiene la funda" se sigue cumpliendo (AC672).
- La API de objetivos de mano (`set_hand_target`, pesos animados) **no se borra**: la sigue usando la mano derecha en la carga de Envainar (`right_grip` 1, al `Hilt`) y queda disponible para el mandoble del Berserker.

### 2.3 Brazo izquierdo en todas las poses del Samurái

Como el brazo ahora decide dónde está la funda, cada pose del perfil del Samurái necesita un brazo izquierdo pensado. Hoy es una pose simple junto a la cintura.

- **Guardia** (`_stance`, y con ella `idle`, `run_stop`, `hit` y los finales de los golpes): la mano izquierda en la cadera izquierda, con la funda en diagonal hacia atrás y un poco hacia abajo, en la posición en que hoy cuelga del torso. El pulgar sobre la tsuba (la mano apenas adelante de la cadera).
- **Carrera** (`_run_contact`, `_run_pass`): la mano sujeta la funda contra la cadera para que no se balancee; la punta atrás.
- **Salto** (`jump_*`): igual que la carrera.
- **Golpes** (`attack_1` a `attack_5`): *saya-biki*. En la anticipación la mano tira la funda hacia atrás (la boca retrocede), y en el impacto la funda acompaña el giro de la cadera. Se escribe en las mismas poses clave que ya tiene cada golpe.
- **Carga de Envainar** (`sheathe_charge`): la mano sostiene la funda junto a la cadera izquierda, delante, con la punta subiendo por detrás, como en la revisión 4 de `sheath-socket-hand-grip.md` §2.7. Ahora la inclinación la da `wrist_l`, y el torso puede ajustarse solo por el cuerpo.

**Guía para ajustar el ángulo** (va en el comentario del perfil y en `SOURCE.md`): con la funda en la mano, `wrist_l` X levanta o baja la punta, `wrist_l` Y la abre o la cierra respecto del cuerpo, y `shoulder_l`/`elbow_l` mueven la boca de la funda (la mano).

Los brazos siguen invisibles (estilo Rayman): solo se ven la mano y la funda, así que el brazo puede tomar la pose que haga falta para dejarlas bien.

### 2.4 Envainar

- La katana cargando sigue al socket igual que hoy (`WeaponMount.hold_in_sheath`), solo que el socket ahora está en la mano. `WeaponMount` no cambia.
- El primer cuadro de `sheathe_slash` en `player.tscn` se vuelve a medir con el socket en `sheathe_charge` (t = 0).
- La mano derecha sigue yendo al `Hilt` durante la carga (`right_grip` 1).

### 2.5 Datos (Principio III)

| Resource / escena | Cambio |
|---|---|
| `WeaponData` | + `sheath_joint: StringName`; `sheath_position`/`sheath_rotation` pasan a ser relativos a esa articulación. |
| `katana.tres` | `sheath_joint = &"wrist_l"`; nuevos `sheath_position`/`sheath_rotation` (el agarre en la mano). |
| `player.gd` | − `SHEATH_JOINT`; − el objetivo de la mano izquierda. |
| Perfil del Samurái | Brazo izquierdo en todas las poses; `left_grip` 0 en todos los clips. |
| `player.tscn` | Primer cuadro de `sheathe_slash`. |

Todo es arte y sensación: nada mejorable con cartas.

## 3. Interfaz pública

- `WeaponData.sheath_joint` (nuevo). Sin otros cambios de API.

## 4. Criterios de aceptación (AC671–AC677)

- **AC671** La funda del Samurái es hija de `SheathSocket`, que cuelga de la articulación `WeaponData.sheath_joint` (`wrist_l` en la katana) con el `sheath_position`/`sheath_rotation` de `katana.tres` y la escala compensada. El Guerrero y el Berserker no tienen socket ni funda. *(Adapta AC661: el padre pasa de `torso` a `sheath_joint`.)*
- **AC672** La mano sostiene la funda sin objetivo de mano: en todos los clips del Samurái, muestreados cada 1/30 s, `left_hand_grip_weight` vale 0 y el centro de la malla de la mano izquierda está sobre el `Grip` de la funda (≤ 1 mm). *(Reemplaza AC666 y la parte izquierda de AC665.)*
- **AC673** El ángulo de la funda lo da el brazo: la transform global del socket es `wrist_l.global_transform * socket_local` (±1 mm) en todos los clips muestreados, y girar `wrist_l` X en 20° gira el eje de la funda 20° (±1°). *(Reemplaza AC662.)*
- **AC674** La funda queda en la cintura y no atraviesa la escena: en todos los clips del Samurái, muestreados cada 1/30 s, en el espacio del `Visual`:
  - la boca de la funda (el `Grip`) está a ≤ 30 cm de la articulación `hips`;
  - el eje de la funda, de la boca a la punta, nunca apunta adelante (componente +Z ≥ 0) y queda a ≤ 60° de la horizontal;
  - la punta está a ≥ 5 cm sobre el piso.
- **AC675** Envainar: mientras carga, el pivot de la katana está en la pose del socket (±1 mm), y el primer cuadro de `sheathe_slash` coincide con el socket en `sheathe_charge` (t = 0) a ≤ 2 cm y ≤ 5°. *(Adapta AC667.)*
- **AC676** La pose de carga conserva AC670: la estocada, el torso volcado, la funda subiendo ≥ 20° hacia atrás, la cabeza al frente, la mano derecha en el `Hilt` (≤ 1 mm) y el cuerpo centrado.
- **AC677** Datos y regresión: `player.gd` ya no tiene `SHEATH_JOINT`; `katana.tres` tiene `sheath_joint`. Pasan `sheath_grip_test`, `sheathe_test`, `class_combat_identity_test` y `samurai_run_test` (AC238 adaptado), salvo los fallos previos y ajenos registrados en `sheath-socket-hand-grip.md` §9. Import y smoke test del arena con el Samurái sin errores ni warnings.

**Próximo libre después de esta spec: AC678.**

## 5. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC671–AC677 en `CLAUDE.md` (próximo libre → AC678).
2. **Datos:** `WeaponData.sheath_joint`; `katana.tres` con `wrist_l` y un agarre inicial calculado para que el `Grip` caiga en la mano; `player.gd` usa `sheath_joint` y deja de registrar el objetivo de la mano izquierda.
3. **Perfil del Samurái:** `left_grip` 0 y el brazo izquierdo en la guardia; con eso quedan bien `idle`, `run_stop` y `hit`. Después la carrera y el salto, los cinco golpes y `sheathe_charge`. Cada grupo se revisa con una hoja de capturas (frente, perfil, tres cuartos y la cámara del juego) y te la muestro antes de seguir con el próximo.
4. **Envainar:** volver a medir el primer cuadro de `sheathe_slash`.
5. **Tests:** AC671–AC677 en `sheath_grip_test.gd`. Se adaptan AC661, AC662, AC665, AC666 y AC667 (quedan anotados en §6). Corro solo las suites de AC677.
6. **Cierre:** notas en esta spec, marca de reemplazo en `sheath-socket-hand-grip.md` (§2.1 y la curva de §2.4), `SOURCE.md` del humanoide y mapa de `CLAUDE.md` ("Funda del arma").

## 6. Tests adaptados (se anotan al cerrar)

- **AC661 → AC671:** el socket cuelga de `sheath_joint`, no del torso.
- **AC662 → AC673:** la funda sigue a la muñeca, no al torso.
- **AC665:** en el Samurái `left_grip` pasa de 1 a 0; las pistas siguen existiendo en todos los clips.
- **AC666 → AC672:** la mano sigue sobre el `Grip`, pero porque la funda está en la mano.
- **AC667 → AC675:** el primer cuadro de `sheathe_slash`, medido otra vez.

## 7. Riesgos

- **Mucho arte nuevo:** hay que escribir el brazo izquierdo en unas 25 poses clave. Mitigación: la guardia define un brazo base (`LEFT_SHEATH_ARM`, como `WAIST_BLADE` para la derecha) que la mayoría de las poses hereda, y solo los golpes y la carga lo cambian.
- **La funda es larga (≈ 80 cm):** un giro chico de muñeca mueve mucho la punta, que puede atravesar las piernas o el piso en poses bajas (carga, zanshin). AC674 lo acota, y las capturas lo revisan.
- **Interpolación entre poses:** entre dos poses clave la muñeca interpola en Euler, y la funda puede hacer un arco raro. Se revisa muestreando cada 1/30 s (AC674).

## 8. Constitución

Sin enmienda:
- no hay geometría, materiales ni colores nuevos;
- el socket se mueve de una articulación a otra;
- el literal `SHEATH_JOINT` pasa a un dato (refuerza el Principio III);
- las mallas y los clips del humanoide se siguen construyendo una vez.

## 9. Notas de implementación (2026-09-27)

- **Agarre de la funda** (`katana.tres`):
  - `sheath_joint = &"wrist_l"`;
  - `sheath_position` (0, −0.0533, −0.03) m, que deja el `Grip` sobre el centro de la malla de la mano (medido: 0 mm);
  - `sheath_rotation` (0, 3.14159, 0), con la punta sobre el +Z de la muñeca. Así `wrist_l` X inclina la punta y `wrist_l` Y la abre.
- **Brazo base `LEFT_SHEATH_ARM`:** `shoulder_l` (−34, 0, 14), `elbow_l` (87, 0, 0), `wrist_l` (−28, −41, 22). Se calculó con un script temporal para que la funda quede exactamente donde colgaba del torso, así que los clips que no lo cambian se ven igual que antes. `_clip` se lo pone a toda pose que no escriba su propio `wrist_l`.
- **Sentido de `wrist_l` X:** más negativo **sube** la punta (medido; el comentario del perfil y `SOURCE.md` lo dicen).
- **Poses con brazo propio:**
  - la anticipación de `attack_1`: `wrist_l` (−18, 5, 30);
  - `_double_top` (fin de `attack_4` y comienzo de `attack_5`): `wrist_l` (−39, −14, 18).

  En las dos, con el torso girado, la funda apuntaba adelante. La muñeca la mantiene atrás (*saya-biki*), con el mismo eje que en `idle`, calculado con un script temporal.
  - `_rising_end` (fin de `attack_2` y comienzo de `attack_3`): `wrist_l` (−43, −41, 22). Con el cuerpo estirado, la punta quedaba a 4 cm del piso; ahora queda a 30 cm.
  - `sheathe_charge`: el brazo base, escrito explícito para ajustarlo ahí mismo.
- **Medido en todos los clips, cada 1/30 s:**
  - la boca de la funda queda a ≤ 25 cm de la cadera;
  - el eje de la funda nunca apunta adelante (+Z ≥ 0.23);
  - la inclinación máxima es de 32°;
  - el punto más bajo de la funda queda a ≥ 11 cm del piso.
- **`sheathe_slash`:** primer cuadro (−0.2286, 0.5127, 0.0328) y (0.4467, 2.9245, −0.1522).
- **Tests:**
  - `sheath_grip_test` (13 casos: AC663–AC665, AC668, AC670/AC676 y AC671–AC677);
  - `sheathe_test` (18) y `class_combat_identity_test` (20), en verde;
  - smoke test del arena sin errores ni warnings.
- **Fallo previo y ajeno:** AC236 (`samurai_run_test`: stats del Samurái cambiados fuera de su spec, ya registrado en `sheath-socket-hand-grip.md` §9). Hace abortar esa suite, así que AC238 adaptado no llega a correr; la funda en el socket la cubre AC671.
- **Tests adaptados** (verifican lo mismo, con la funda en la mano):
  - AC661 → AC671;
  - AC662 → AC673;
  - AC665: `left_grip` del Samurái pasa a 0;
  - AC666 → AC672;
  - AC667 → AC675;
  - AC238: el socket cuelga de `sheath_joint`.

  AC664 sigue pasando, porque la mano coincide con el `Grip` por construcción. El agarre en el mismo cuadro lo sigue ejercitando la mano derecha en la carga.

### Checklist de la constitución

- [x] Principio I: pilar de combate (la silueta del Samurái).
- [x] Principio II: sin geometría, materiales ni colores nuevos; el humanoide se sigue construyendo una vez.
- [x] Principio III: la articulación de la funda pasa a ser un dato (`WeaponData.sheath_joint`); las poses son datos del asset.
- [x] Principio IV: tipado estricto; código y comentarios de código en inglés (los comentarios del perfil siguen en español, como el resto del asset).
- [x] Principio V: sin allocations nuevas por cuadro (el socket es un nodo más en la jerarquía).
- [x] Principios VI y VII: sin cambios.
