# Feature: el salto corta el golpe como el dash

- **Estado:** Implementada (2026-09-27). ACs: AC689–AC693. Tests: solo los de esta spec (`combat_feel_test.gd`, a pedido del responsable); ver §8.
- **Constitución:** `docs/constitution.md` v4.11.0 → **enmienda MINOR a 4.12.0** (aplicada, ver §6).
- **Pilar (Principio I):** **combate.** Los jugadores piden poder salir de un golpe del combo saltando. Hoy la única salida de un golpe comprometido es el dash, que tiene recarga. Con el salto como segunda salida se puede esquivar verticalmente en medio del combo y encadenar golpe → salto → golpe aéreo (o Tajo aéreo del Berserker): el combate gana opciones de posicionamiento y de encadenamiento.
- **Dependencias:** `bdo-combat-feel.md` (Implementada; esta spec **reemplaza** la primera mitad de su AC614 y su regla A de compromiso para el salto), `humanoid-player-model.md`, `berserker-air-slash.md`.

## 1. Estado actual

1. `Player._handle_jump()` ignora el salto si `is_casting()` o `attack.is_committed()` (estado `STRIKING`, desde que empieza el golpe hasta su `cancel_point`).
2. En `CHAIN_OPEN` (recuperación), saltar llama `attack.cancel()` y salta.
3. El dash corta el golpe en cualquier estado (`_handle_dash()` → `attack.cancel()` solo si `try_dash` tuvo éxito).
4. Constitución, Principio VII: "un golpe del ataque básico no permite moverse libremente **ni saltar** hasta su *cancel point* […] El dash corta el golpe en cualquier momento."

## 2. Diseño

### 2.1 Regla

Durante **cualquier** golpe del ataque básico (`STRIKING` o `CHAIN_OPEN`, incluido el hit lag), si el jugador está **en el piso** y aprieta saltar:

1. El golpe se corta con `attack.cancel()` (el mismo corte que usa el dash): se emite `step_ended`, el estado vuelve a `READY`, se borra el toque en buffer y el próximo toque empieza por `attack_1`.
2. Si la ventana de daño (`hit_start`) todavía no se abrió, ese golpe **no hace daño**. Si ya se abrió, el daño aplicado queda como está.
3. El jugador salta ese mismo cuadro (`MovementComponent.jump()`, `JUMP_VELOCITY` del stat). La velocidad horizontal que traía la estocada se conserva; desde el cuadro siguiente el movimiento es el normal.

Sin cambios:
- **En el aire** (p. ej. un golpe aéreo del Guerrero, AC608) el salto no hace nada y **no corta** el golpe: no hay doble salto, así que no hay nada que cancelar.
- Casts, cargas (Envainar), Tajo aéreo y sujeciones de boss siguen bloqueando el salto (`is_casting()` / `_hold_left`).
- El movimiento sigue comprometido en `STRIKING` (AC611): solo el dash y el salto sacan al jugador del golpe.
- El salto no tiene recarga (igual que hoy). Ver riesgo en §7.

### 2.2 Animación

El corte usa el mismo camino que hoy tiene el salto en la recuperación: `PlayerAnimator` sale de la pose del golpe con `attack_exit_blend` hacia `jump_start`. No hay clips ni datos nuevos.

### 2.3 Estructura de nodos, Resources y datos

Ninguno nuevo. No se agrega flag de datos: igual que el dash, cortar el golpe es una regla del jugador y no un valor de tuning (Principio III no aplica: no hay números nuevos).

### 2.4 Interfaz pública

Sin cambios de firma. Cambia la documentación de `AttackComponent.is_committed()`: "el jugador no puede moverse" (ya no menciona el salto).

### 2.5 Lógica interna

`Player._handle_jump()`:

```gdscript
## The jump cuts any strike of the combo, like the dash
## (docs/specs/jump-cancels-strike.md); in the air there is nothing to cut.
func _handle_jump() -> void:
	if not _input_guard.is_just_pressed(ACTION_JUMP) or is_casting() or not is_on_floor():
		return
	attack.cancel()
	_movement.jump()
```

`attack.cancel()` sin golpe en curso solo limpia el buffer y reinicia el combo, igual que ya hace el dash.

## 3. Criterios de aceptación

- **AC689** En `STRIKING` de `attack_1`, en el piso, tocar saltar termina el golpe (`step_ended`, `is_attacking()` falso) y `velocity.y > 0` ese mismo cuadro. El próximo toque de ataque empieza por `attack_1`.
- **AC690** Con un enemigo delante, saltar en `STRIKING` antes de `hit_start` corta el golpe sin daño: la vida del enemigo sigue intacta después del tiempo que habría durado el clip.
- **AC691** Saltar después de `hit_start` pero antes del `cancel_point` (durante el hit lag si lo hay) corta el golpe y salta; el daño ya aplicado al enemigo se conserva y no se aplica otra vez.
- **AC692** Un toque de ataque en buffer se descarta al cortar con el salto: al aterrizar no arranca ningún golpe solo.
- **AC693** Regresiones: (a) saltar en `CHAIN_OPEN` sigue cortando y saltando (segunda mitad de AC614); (b) en el aire, durante un golpe aéreo, apretar saltar no corta el golpe; (c) cargando Envainar el salto sigue ignorado (AC246). El caso (c) lo sigue cubriendo el test de AC246 (`sheathe_test.gd`); no se duplica.

## 4. Tests

- `test/components/combat_feel_test.gd`: `test_ac614_jump_is_ignored_while_committed_and_cuts_the_recovery` cambia lo que verifica (la primera mitad pasa a ser lo contrario), así que no se "adapta": se reemplaza por `test_ac689_*` y la segunda mitad queda como `test_ac693_jump_still_cuts_the_recovery`. Se anota en `bdo-combat-feel.md` que AC614 (primera mitad) quedó reemplazado por AC689.
- Nuevos: AC689–AC693 en el mismo archivo (AC693 b junto al test de AC608 si hace falta el setup de golpe aéreo).

## 5. Plan

1. Enmienda de la constitución (§6) y nota de reemplazo en `bdo-combat-feel.md` (AC614 y la regla A).
2. `Player._handle_jump()` según §2.5; comentario de `AttackComponent.is_committed()`.
3. Tests: reemplazar AC614, sumar AC689–AC693.
4. Suite completa + smoke test (`--quit-after 300` del proyecto y de `arena.tscn`).
5. Cerrar: checklist de la constitución, estado **Implementada**, `CLAUDE.md` (próximo AC libre: AC694; spec en "Specs recientes").

## 6. Enmienda de la constitución (MINOR, 4.11.0 → 4.12.0)

Principio VII, viñeta **Compromiso**, pasa a decir:

> **Compromiso:** un golpe del ataque básico no permite moverse libremente hasta su *cancel point* (la apertura de su ventana de combo). En la recuperación, el movimiento se limita a un desplazamiento lento sin girar (o la corta, según datos). El dash y el salto (desde el piso) cortan el golpe en cualquier momento.

Historial: **4.12.0** (2026-09-27): Principio VII: el salto corta el golpe en cualquier momento, como el dash (ver `jump-cancels-strike.md`).

Por qué MINOR y no MAJOR: el principio (golpes con peso, compromiso del movimiento, cancel point) no se elimina ni se redefine; se amplía el conjunto de salidas explícitas, que ya existía para el dash. Por qué no PATCH: cambia el significado de una regla.

## 7. Riesgo de diseño

El salto no tiene recarga, así que se vuelve una salida gratuita del compromiso (el dash la tiene). Mitigaciones que ya existen: saltar corta el golpe **sin daño** si la ventana no se abrió, reinicia el combo en `attack_1` y deja al jugador en el aire, donde no puede esquivar con el salto de nuevo. Si en juego resulta demasiado fuerte, la alternativa es una spec aparte que agregue un flag o un tramo mínimo en `AttackComboConfig` (p. ej. "el salto corta solo después de `hit_start`").

## 8. Checklist de review de la constitución

- [x] Principio I: pilar de combate (una segunda salida del golpe, vertical, y el encadenamiento golpe → salto → golpe aéreo).
- [x] Principio II: sin geometría, materiales ni clips nuevos.
- [x] Principio III: sin valores nuevos; el salto usa `JUMP_VELOCITY` de `<clase>_stats.tres`.
- [x] Principio IV: tipado estricto; código y comentarios en inglés.
- [x] Principio V: sin allocations por cuadro (se quitó una condición de `_handle_jump`).
- [x] Principio VI: el salto sigue siendo la acción `jump` del InputMap.
- [x] Principio VII: enmendado a 4.12.0 (§6). Estocada, hit lag, apuntado y compromiso del movimiento no cambian.

## 9. Notas de implementación

- `test_ac614_jump_is_ignored_while_committed_and_cuts_the_recovery` no se adaptó porque su primera mitad verificaba lo contrario de esta spec: se reemplazó por `test_ac689_the_jump_cuts_a_committed_strike`, y su segunda mitad quedó como `test_ac693_the_jump_still_cuts_the_recovery`. Anotado en `bdo-combat-feel.md` (regla A y AC614).
- Las lambdas de varias líneas dentro de un test hacen que GdUnit deje de descubrir los tests siguientes del archivo; `_advance_clip()` avanza el clip con un bucle.
- Resultado: `combat_feel_test.gd` 30/30 en verde. Antes del pedido de correr solo los tests de la spec, una corrida de la suite completa mostró 11 fallos que también fallan en `main` sin este cambio (datos de clases, Giro, funda, `class_combat_identity`); no son de esta spec.
