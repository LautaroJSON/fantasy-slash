# Feature: Envainar interrumpe el dash

- **Estado:** Implementada (2026-09-25, partes 1 y 2; 436 tests GdUnit4 en verde, 0 orphans; `dash_cancel_test` y `sheathe_test` pasaron 3 corridas seguidas; import y smoke test sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.4.0 (sin enmienda).
- **Pilar (Principio I):** combate. Hace más fluido el loop dash → Envainar (sobre todo con "Nuki"), así el control responde en el momento en que el jugador aprieta.
- **Dependencias:** `samurai.md` y `nuki.md` (Implementadas).

## 1. Objetivo

- **Hoy:** una habilidad no puede empezar durante un dash; hay que esperar a que termine (0.15 s de dash más lo que tarde el input).
- **Nuevo:** si se aprieta la tecla de una habilidad que **interrumpe el dash** y esa habilidad **puede lanzarse** (equipada, lista, sin estar cargando ni casteando), el dash **se corta en el acto** y la habilidad empieza en ese mismo cuadro. Para Envainar, empieza la carga.
- **Solo Envainar lo tiene.** Es un dato de la habilidad (`AbilityData.interrupts_dash = true` en `sheathe.tres`). Como Envainar es exclusiva del Samurái, las demás clases siguen igual.
- **Al cortar el dash:**
  - se frena el movimiento del dash (la velocidad horizontal vuelve a 0);
  - la **invencibilidad sigue** su tiempo normal;
  - el enfriamiento del dash no cambia.
- Si Envainar no puede lanzarse (por ejemplo, está en enfriamiento), apretar E durante el dash no hace nada y el dash sigue.

## 2. Diseño

- **`AbilityData`:** `@export var interrupts_dash: bool`. En `false` por defecto, así que la Estocada, el Golpe Veloz, el Giro y el Tornado no cambian.
- **`AbilityComponent`**
  - `can_cast()`: equipada, sin cast, sin carga y sin enfriamiento. Es la misma condición que ya usa `try_cast()`, que pasa a reutilizarla.
  - `interrupts_dash()`: está equipada y `_data.interrupts_dash`.
- **`DashComponent.cancel()`:** corta un dash en curso (`_dash_time_left = 0` y velocidad horizontal en 0). No toca iframes ni enfriamiento.
- **`Player._handle_abilities()`:** durante un dash, en lugar de salir directamente, revisa cada slot. Si se apretó su acción, `interrupts_dash()` y `can_cast()` dan verdadero, llama `dash.cancel()` y después `try_cast()`. Como las habilidades se procesan antes que el movimiento en `_physics_process`, en ese mismo cuadro el cuerpo ya se mueve con las reglas de la carga.

## 3. Criterios de aceptación (reservados al empezar la implementación)

- **AC355** `sheathe.tres` tiene `interrupts_dash = true`. La Estocada, el Golpe Veloz y el Giro lo tienen en `false`.
- **AC356** Samurái con Envainar lista: dashear y apretar E a mitad del dash corta el dash en ese cuadro, empieza la carga y el recorrido queda por debajo de `DASH_DISTANCE`.
- **AC357** *(reemplazado por AC548 de `dash-iframes.md`: la invulnerabilidad termina con el corte)* Después del corte, el jugador sigue invulnerable hasta completar `IFRAME_DURATION` desde el inicio del dash, y el enfriamiento del dash sigue corriendo.
- **AC358** Con Envainar en enfriamiento, apretar E durante el dash no lo corta: recorre `DASH_DISTANCE` completo.
- **AC359** Guerrero con la Estocada: apretar E durante el dash no la lanza ni corta el dash (comportamiento actual).
- **AC360** Loop con "Nuki": después de un tajo, dashear recarga Envainar y apretar E en el mismo dash lo corta y empieza la carga. Regresión: suite completa en verde.

## 4. Plan de implementación

1. Reservar AC355–AC360 en `CLAUDE.md` (próximo libre → AC361).
2. `AbilityData.interrupts_dash` y el dato en `sheathe.tres`.
3. `AbilityComponent.can_cast()` / `interrupts_dash()` y `DashComponent.cancel()`.
4. `Player._handle_abilities()`: corte del dash.
5. Tests AC355–AC360, suite completa, smoke test y cierre (estado **Implementada**).

## 5. Parte 2 (Implementada): golpe al soltar y recuperación cancelable con el dash

**Pedido:** al terminar Envainar, el samurái queda clavado en el suelo y el dash tiene que poder cortar ese momento.

**Medición:** al soltar E, el jugador queda quieto exactamente `CAST_DURATION` (0.25 s, 15 cuadros) y no puede dashear. El golpe cae **al final** de ese tiempo; después arranca a caminar acelerando desde 0.

**Decisión del usuario:** el golpe pasa a caer **al soltar**, y los 0.25 s que siguen son **recuperación**, que el dash corta.

### Objetivo
- Al soltar E, el tajo se aplica en el acto: daño, crítico, empuje, onda, corte en V, Zanshin y desvanecido del indicador.
- La animación `sheathe_slash` sigue durando `CAST_DURATION` como recuperación, durante la que el jugador queda quieto como hoy.
- **Durante la recuperación se puede dashear.** El dash la corta:
  - termina el cast;
  - la katana vuelve al reposo;
  - la estela se apaga;
  - el enfriamiento de Envainar sigue corriendo.
- Si la recuperación se corta con un dash, **Nuki** actúa sobre ese mismo dash, porque Envainar ya no está casteando.
- Solo Envainar: nuevo dato `AbilityData.dash_cancels_cast` (true en `sheathe.tres`, false por defecto). El resto de las habilidades mantiene el bloqueo del dash durante el cast.

### Diseño
- **`SheatheAbility`:** el golpe (hoy en `release()`) pasa a `begin()`, después de apuntar. `release()` queda sin efecto.
- **`AbilityBehavior.cancel_cast(ability)`:** hook nuevo que corta el cast antes de tiempo. Envainar detiene la animación y llama `sword_swing.recover()`.
- **`AbilityComponent`**
  - `dash_cancels_cast()`: está casteando y `_data.dash_cancels_cast`.
  - `cancel_cast()`: `_cast_left = 0`, `behavior.cancel_cast()` y emite `cast_released`.
- **`Player`**
  - `_can_dash()` permite dashear si ninguna habilidad castea, o si todas las que castean tienen `dash_cancels_cast()`.
  - Si `try_dash()` tiene éxito, primero corta los casts cancelables y después llama `notify_dash()`, así Nuki ve a Envainar fuera del cast.

### Criterios de aceptación
- **AC240** *(reemplazado por AC361)*.
- **AC361** El golpe de Envainar cae en el cuadro en que se suelta E. El cast (recuperación) sigue durando `CAST_DURATION` y el cooldown arranca en el mismo momento.
- **AC362** Durante la recuperación, un dash la corta:
  - `is_casting()` pasa a falso;
  - el dash recorre `DASH_DISTANCE`;
  - el enfriamiento de Envainar sigue activo.
- **AC363** Después del corte, la katana vuelve a su pose de reposo y la estela deja de emitir.
- **AC364** Sin dash, la recuperación dura `CAST_DURATION` y el jugador queda quieto durante ella, como hoy.
- **AC365** Con Nuki, el dash que corta la recuperación también recarga Envainar.
- **AC366** Otras habilidades (la Estocada) siguen bloqueando el dash durante su cast. Regresión: suite completa en verde. Los tests que esperaban el golpe al final del cast se adaptan a AC361.

### Plan
1. Reservar AC361–AC366 en `CLAUDE.md` (próximo libre → AC367).
2. `AbilityData.dash_cancels_cast` y el dato en `sheathe.tres`.
3. Hook `cancel_cast`, `AbilityComponent.dash_cancels_cast()`/`cancel_cast()`, y en `Player` `_can_dash()` y el orden corte → aviso.
4. `SheatheAbility`: golpe en `begin()` y `cancel_cast()`.
5. Tests AC361–AC366, adaptación de AC240, suite completa, smoke test y cierre de toda la spec.

## 6. Notas de implementación

- **Timing de input en tests:** una acción apretada con `Input.action_press` entre cuadros se lee en el **segundo** cuadro de física siguiente, así que los tests esperan 2 cuadros después de apretar E. Además, `before_test` suelta las acciones por si otro archivo las dejó apretadas.
- `Player._handle_dash()` primero corta los casts cancelables y después avisa `notify_dash()`. Así "Nuki" ve a Envainar fuera del cast y la recarga con el mismo dash (AC365).
- `SheatheAbility.cancel_cast()` detiene la animación del `SwingPlayer` y llama `sword_swing.recover()`. `AbilityComponent.cancel_cast()` emite `cast_released`, así la estela se apaga igual que al final de un cast normal.
- **Test viejo reemplazado:** `sheathe_test` AC240 (el golpe al final del cast) pasa a ser AC361 (el golpe al soltar). En `samurai.md`, AC240 queda marcado como reemplazado.

### Review de la constitución (cierre)
- **I:** combate.
- **II:** sin cambios visuales nuevos.
- **III:** `interrupts_dash` y `dash_cancels_cast` son datos de la habilidad (solo Envainar en true).
- **IV:** tipado estricto; `_physics_process` sigue delegando.
- **V:** sin allocations por frame.
- **VI:** solo acciones del InputMap (`dash`, `ability_basic`).
- **Calidad:** suite completa en verde.
