# Feature: guardia de reposo del Samurái (de frente, katana baja)

- **Estado:** Implementada (2026-09-27).
- **Constitución:** `docs/constitution.md` v4.x (sin enmienda: ver §7).
- **Pilar (Principio I):** **combate.** La guardia es la pose en la que el jugador ve al Samurái la mayor parte del tiempo, y desde la que arranca y a la que vuelve cada corte. El responsable quiere la silueta de su referencia: calma, de frente y con la hoja baja y lista.
- **Referencia:** tres imágenes del responsable (una espadachina en reposo, de frente, desde arriba y en tres cuartos de espaldas).
- **Decisiones del responsable (2026-09-27):**
  - se reemplaza **toda la guardia** (`_stance()`): `idle` y todos los clips que arrancan o terminan en ella, incluidos los golpes del combo;
  - el torso queda **de frente, como en la foto**, y se reescribe AC660 (`class-combat-identity.md`), que pedía el torso de costado.
- **Dependencias:**
  - `class-combat-identity.md` (perfil del Samurái, AC660);
  - `sheath-in-left-hand.md` (la funda en la mano izquierda; AC672 y AC674 rigen para todo clip);
  - `sheathe-release-animation.md` (el suelte termina en la guardia; AC724).

## 1. La pose de la referencia

- **Cuerpo:** erguido y relajado, **de frente** al enemigo, sin inclinarse. La cabeza al frente.
- **Pies:** casi juntos, un poco más angostos que los hombros, a la par (ninguno adelantado), con las puntas apenas abiertas.
- **Mano derecha y katana:** el brazo cuelga relajado junto a la cadera derecha. La katana baja en diagonal **hacia adelante y hacia la derecha**, con la punta cerca del piso (≈ 40° bajo la horizontal).
- **Mano izquierda y funda:** la mano en la cadera izquierda sostiene la funda junto a la boca. La funda va en diagonal **hacia atrás y abajo**, un poco hacia afuera.
- **Respiración:** la de hoy, casi imperceptible (3 s: el pecho sube apenas).

## 2. Diseño

### 2.1 La guardia nueva (`_stance()`)

`samurai_profile.gd` reemplaza la base de `_stance()`:

| Parte | Hoy (guardia de costado) | Nueva (reposo de frente) |
|---|---|---|
| `hips` | Y −20 (de costado) | ≈ 0 (de frente) |
| `torso` | (3, −20, 0) | ≈ (0, 0, 0): erguido y de frente |
| `neck` | (−3, 40, 0) (compensa el giro) | ≈ (0, 0, 0): la cabeza al frente |
| Piernas | La izquierda adelante (18°), la derecha atrás | A la par, casi juntas, las puntas apenas abiertas |
| Brazo derecho | `WAIST_BLADE`: katana a la cintura, la punta adelante y abajo | **`LOW_BLADE`** (reemplaza a `WAIST_BLADE`): brazo colgando, la katana baja adelante y a la derecha |
| Brazo izquierdo | `LEFT_SHEATH_ARM` | El brazo de la guardia se calcula para la funda de la referencia, atrás y abajo, y queda como `LEFT_SHEATH_ARM` |

- Los ángulos exactos se calculan con el script de brazos (mano y dirección de la hoja o de la funda como objetivo) y se ajustan con hojas de capturas al lado de las tres referencias.
- **Los golpes del combo** se arman con `_stance(over)`: heredan de la guardia lo que no escriben, que suelen ser las piernas y, a veces, la cadera o el cuello. Con la guardia de frente cambian su primer y su último cuadro (arrancan y terminan en el reposo) y las partes heredadas. Las poses intermedias que escriben cadera, torso y brazos no cambian. Si alguna se rompe (la hoja atraviesa el cuerpo, la funda se sale de la cintura o el golpe se lee mal), se corrige en esa pose y se anota.
- `run_stop`, `hit`, `jump_start`/`jump_land` y el suelte de Envainar terminan en la guardia nueva, porque la usan. El salto usa `WAIST_BLADE`, que pasa a `LOW_BLADE`.
- `_stride()` (la zancada de los cortes) no cambia.

### 2.2 Datos (Principio II/III)

- Las poses son datos del asset, en el perfil: no hay Resources ni scripts de comportamiento nuevos.
- `WAIST_BLADE` pasa a llamarse `LOW_BLADE`: la katana ya no va a la cintura.

## 3. Interfaz pública

Sin cambios.

## 4. Criterios de aceptación (AC731–AC736)

Se miden en `idle` en t = 0, en el espacio del `Visual` (−Z hacia el enemigo, +X a la derecha del personaje):

- **AC731** De frente y erguido:
  - el frente del torso queda a ≤ 10° de −Z;
  - el torso se inclina ≤ 8° de la vertical;
  - la cabeza mira al frente (±10°).
- **AC732** Los pies:
  - están a la par: ≤ 8 cm de diferencia adelante-atrás entre los tobillos;
  - casi juntos: 12 a 30 cm de separación lateral;
  - planos (≤ 10°), con la punta de cada uno a ≤ 25° de −Z.
- **AC733** La katana baja adelante y a la derecha:
  - la mano derecha está junto a la cadera derecha (x ≥ 0.12 m, y entre 0.7 y 1.0 m);
  - la punta de la hoja (`TrailTip`) está adelante (z < −0.3 m), a la derecha (x ≥ 0.3 m) y baja (y ≤ 0.4 m);
  - la hoja apunta entre 25° y 60° bajo la horizontal.
- **AC734** La funda atrás y abajo:
  - la boca (`Grip`) está a la izquierda de la cadera (x < 0) y a ≤ 30 cm de ella;
  - el eje de la funda, de la boca a la punta, apunta atrás (z ≥ 0.5) y baja entre 10° y 45° bajo la horizontal.
- **AC735** **AC660 reescrito** (`class-combat-identity.md`), que reemplaza "en `idle` el torso está girado de costado (≥ 30°)": en `idle` el torso está de frente (AC731) y la cabeza mira al frente (±10°). La parte de la mano izquierda ya estaba reemplazada por AC672.
- **AC736** Regresión:
  - pasan `class_combat_identity_test` (AC653: la hoja no atraviesa el cuerpo en ningún clip; AC652: los tiempos de compromiso no cambian), `sheath_grip_test` (AC672 y AC674 en todos los clips), `sheathe_release_test` (AC724: el suelte termina en la guardia), `sheathe_test`, `attack_component_test`, `combat_feel_test`, `hitstop_test`, `player_animator_test` y `humanoid_model_test`;
  - quedan exceptuados los fallos previos registrados (AC363);
  - import y smoke test del arena sin errores ni warnings.

**Próximo libre después de esta spec: AC737.**

## 5. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC731–AC736 en `CLAUDE.md`.
2. **Guardia:**
   - piernas, cadera, torso y cuello nuevos en `_stance()`;
   - `LOW_BLADE` y el brazo izquierdo, calculados con el script para los objetivos de §1;
   - hoja de capturas de `idle` (de frente, de arriba, en tres cuartos de espaldas, de perfil y con la cámara del juego) al lado de las referencias. Te la muestro.
3. **Golpes y demás clips:** hojas de capturas de los 5 golpes, `hit`, `run_stop`, el salto y el suelte. Corrijo las poses que se rompan (AC653, AC674 y la lectura del corte) y te las muestro.
4. **Tests:** AC731–AC734 en `test/entities/player/samurai_rest_guard_test.gd`, AC660 reescrito (AC735) en `class_combat_identity_test`, y las suites de AC736.
5. **Cierre:**
   - notas en esta spec;
   - AC660 marcado como reescrito en `class-combat-identity.md`;
   - `SOURCE.md` y `CLAUDE.md`.

## 6. Tests adaptados (se anotan al cerrar)

- **AC660** (`class_combat_identity_test`): "torso de costado ≥ 30°" pasa a "torso de frente ≤ 10°" (AC735).
- Cualquier test con valores fijos de la guardia vieja que aparezca en las suites de AC736.

## 7. Constitución

Sin enmienda. Son poses del asset, sin geometría, colores, datos de juego ni lógica nuevos.

## 8. Riesgos

- **Los golpes se diseñaron desde la guardia de costado.** El primer cuadro de cada golpe ahora parte de frente, así que la anticipación gira más. Puede verse mejor (más recorrido) o raro en algún corte. Se revisa con capturas.
- **La funda en los golpes:** el brazo izquierdo de la guardia lo heredan los golpes que no escriben el suyo. AC674 lo controla, y se corrige pose por pose si hace falta.
- **La katana baja hacia adelante** puede leerse como apuntando al piso desde la cámara del juego. Se revisa en la captura con esa cámara.

## 9. Notas de implementación (2026-09-27)

- **Guardia (`_stance()`):**
  - `hips_pos` (0, −0.03, 0), `hips` 0;
  - `torso` (1, 0, 0), `neck` (−1, 0, 0);
  - piernas a la par: `hip_l` (6, 12, −3) y `hip_r` (6, −12, 3), las rodillas en −12 y los tobillos en 6, con las puntas abiertas 12°;
  - la respiración de `idle` en 1.5 s: el torso (2, 0, 0).
- **Brazos** (calculados con el script, al primer intento):
  - `LOW_BLADE` (reemplaza a `WAIST_BLADE`): `shoulder_r` (−2, 47, 9), `elbow_r` (56, 0, 0), `wrist_r` (−143, 53, −14). Pone la mano en (0.22, 0.85, −0.08) y la hoja 38° bajo la horizontal, hacia adelante y a la derecha.
  - `LEFT_SHEATH_ARM`: `shoulder_l` (−47, −1, 19), `elbow_l` (82, 0, 0), `wrist_l` (−13, −33, −20). Deja la boca de la funda en (−0.2, 0.8, 0.02) y la funda 23° bajo la horizontal, hacia atrás.
- **Los golpes no necesitaron correcciones:**
  - la hoja no atraviesa el cuerpo en ningún clip (AC653);
  - la funda cumple AC674 en todos los clips (boca a ≤ 28 cm de la cadera, nunca adelante);
  - las capturas de los 5 golpes (arranque, anticipación, impacto y final) se leen bien.
- **Tests:**
  - `samurai_rest_guard_test` (4 casos, AC731–AC734);
  - regresión de AC736: 150 casos en verde, en `class_combat_identity_test` (25, con AC660 reescrito), `sheath_grip_test` (16), `sheathe_release_test` (13), `sheathe_test` (18), `attack_component_test` (21), `combat_feel_test` (30), `hitstop_test`, `player_animator_test` y `humanoid_model_test`;
  - smoke test del arena sin errores ni warnings.
- **Test adaptado:** AC660 (`class_combat_identity_test`) pasa de "torso de costado ≥ 30°" a "torso de frente ≤ 10°" (AC735), y el test cambia de nombre a `test_ac660_the_samurai_rests_facing_forward_looking_ahead`.
