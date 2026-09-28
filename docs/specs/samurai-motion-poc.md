# Prueba de concepto: movimiento procedural en los cortes del Samurái

**Estado:** Prueba de concepto (rama `poc/samurai-motion`, sin tests; el responsable liberó las reglas de la constitución para esta prueba)
**Reemplaza a:** la propuesta `berserker-motion-poc.md` (misma idea, otra clase y otro enfoque)

## Qué cambia

Una capa nueva, `HumanoidMotion` (`assets/models/characters/low_poly_humanoid/motion/`), corre cada cuadro justo después de que el `AnimationPlayer` aplica el clip. Hace tres cosas:

1. **Cortes como geometría (`SlashArc`).** En los cinco golpes del combo, la muñeca derecha no sale de los ángulos de hombro, codo y muñeca. Se ubica para que el agarre recorra un **arco circular real** alrededor del hombro derecho, con la hoja hacia afuera, el filo adelante y la punta que se atrasa cuando la hoja va rápido (latigazo). Como los brazos son invisibles, lo que se ve (la mano y la katana) sigue una curva limpia, y la estela también.
   - Cada corte se escribe con tres direcciones (inicio, frente y final) y una tabla de tiempos: dónde está la hoja en cada momento (carga lenta, golpe explosivo en `hit_start`, frenado con un rebote chico).
   - Entra y sale con una mezcla desde y hacia la pose del clip. Al encadenar golpes hay una mezcla corta desde lo último que se vio, así no hay saltos.
2. **Resortes** en cuello y torso: llegan un poco tarde y se asientan. Corren en todos los clips del Samurái.
3. **Pies clavados:** el pie de atrás queda fijo en el piso durante la estocada de cada corte y después da un paso corto hasta su pose.

Además, los clips de los golpes se **hornean** a 60 cuadros por segundo con una curva monótona entre poses (sin quiebres lineales) y con superposición: la cadera arranca primero y el torso, la cabeza y el brazo de la funda siguen escalonados (`OVERLAP` en `samurai_profile.gd`).

## Dónde se ajusta

- **Arcos, tiempos, pies y resortes:** `build_motion()` en `profiles/samurai_profile.gd`.
- **Rangos de mezcla, estiramiento máximo del pie clavado y altura del paso:** `motion/humanoid_motion_setup.gd`.
- **Dirección de la hoja y del filo:** la calcula `WeaponMount._send_weapon_frame()` desde `TrailBase`/`TrailTip` del arma. El filo es el −X del modelo; si sale al revés, se invierte con `edge_sign`.
- **Apagarlo:** `LowPolyHumanoid.motion_enabled = false` vuelve exactamente al sistema anterior. Las librerías de ese modo se guardan aparte, así pueden convivir las dos versiones.

## Qué no cambia

Los tiempos del combo (`samurai_combo.tres`), los eventos de los clips, el daño, la estocada y el hit lag. El Guerrero y el Berserker no tienen setup, así que no cambian.

## Herramienta de captura

`tools/clip_capture.tscn` arma el Samurái sin la capa y con la capa, lado a lado, con la katana, la funda, la estocada y el hit lag del combo. Los puntos amarillos marcan el recorrido de la punta, y los verdes y magenta, los pies.

- **Hojas por vista** (`frente`, `costado`, `juego`, `arriba`):
  `godot --path <copia> --fixed-fps 60 res://assets/models/characters/low_poly_humanoid/tools/clip_capture.tscn -- --out=<carpeta>`
- **Video** antes/después (combo a velocidad real, después al 30 %, y cada corte al 30 %):
  `godot --path <copia> --fixed-fps 60 --resolution 1280x720 --write-movie <archivo>.avi res://assets/models/characters/low_poly_humanoid/tools/clip_capture.tscn -- --movie`

## Verificación

- Captura y video generados sin errores.
- Smoke test: la arena con el Samurái atacando 400 cuadros, sin errores de script.
- Sin tests (pedido del responsable). Los que leen las pistas de los golpes del Samurái (p. ej. AC641 compara eventos y sigue valiendo; los de pose de la hoja podrían fallar) no se corrieron.

## Pendiente si se adopta

Ajustar los arcos a ojo en el juego, llevar los valores a Resources, pasar el enfoque a los combos del Guerrero y el Berserker y, si hace falta, sumar capas (piernas y brazos por separado).

## Adenda: combo "Nagare" (2026-09-28)

El combo del Samurái pasa a ser un péndulo: cada corte empieza donde terminó el anterior y vuelve por el mismo camino. Así la hoja no tiene que volver cruzando el cuerpo entre golpes, que era lo que los hacía sentir desconectados.

| # | Corte | Recorrido | Pie que avanza | Tiempos (impacto / encadenado / fin) |
|---|---|---|---|---|
| 1 | Kesa-giri | desde la guardia baja sube por el hombro derecho (carga con el lomo adelante) y cae a abajo a la izquierda | izquierdo | 0.16–0.21 / 0.25 / 0.46 |
| 2 | Kiriage | de abajo a la izquierda sube por la misma línea a arriba a la derecha | derecho | 0.09–0.13 / 0.17 / 0.36 |
| 3 | Yokogiri | baja al costado derecho mientras la cadera se enrosca y barre horizontal hasta atrás a la izquierda | izquierdo | 0.15–0.20 / 0.24 / 0.46 |
| 4 | Tsuki | la hoja vuelve al frente, el agarre se recoge en la cadera derecha y sale recto (solo cambia el radio) | derecho, zancada de 1 m | 0.10–0.14 / 0.16 (encadena solo) / 0.30 |
| 5 | Karatake-wari + chiburi | desde la estocada sube sobre la cabeza y parte en vertical con pisotón; zanshin, sacudida a la derecha y vuelta a la guardia baja | pisotón del izquierdo | 0.14–0.18 / 0.50 / 0.90 |

- **Datos:** `samurai_combo.tres`. La estocada tiene alcance ×1.3 y arco 0.3. El horizontal tiene arco 1.3. El remate tiene hit lag de 0.12 s y empuje 1.4. Los daños se mantienen.
- **Varios arcos por golpe:** carga, corte y chiburi. Cada arco manda desde el primer tiempo de su `timing`. `edge_flip` pone el lomo adelante en las cargas, `radius_timing` hace la estocada y `SlashArc.fixed()` sostiene la hoja quieta.
- **Mezclas:** entre arcos de un mismo golpe, 0.05 s (`arc_blend`). Al salir del combo, 0.24 s (`exit_blend`).
- **Sin la capa** (`motion_enabled = false`), el perfil arma los cinco cortes anteriores. La herramienta de captura los compara con sus tiempos originales (`tools/samurai_combo_classic.tres`).

## Adenda 2: más dinámico, y la mano fuera de lugar (2026-09-28)

**Ritmo.** Se aplican técnicas de animación de acción:
- **Carga legible con tensión:** la hoja se pasa un poco de su marca y se sostiene 1–2 cuadros.
- **Golpe en 2–3 cuadros:** la hoja cruza casi todo el arco (f 0.15 → 1.7) entre el soltado y 18 ms después del impacto. La estela hace de smear.
- **Follow-through largo:** frena de a poco, se pasa apenas y se asienta.
- **Poses más extremas** en la carga y el remate (torsión de hasta 74° y más inclinación).
- **Estocada concentrada** en los cuadros del golpe: un impulso de ~35 ms, no un deslizamiento.
- **Latigazo de la punta más marcado:** `tip_lag` 0.02.
- **Resortes más firmes** (el cuerpo no flota) y menos superposición.

La helper `_cut()` de `samurai_profile.gd` arma ese perfil de tiempos a partir de tres datos: soltado, impacto y fin.

Tiempos nuevos (impacto / encadenado / fin):

| Corte | Tiempos |
|---|---|
| 1 | 0.11–0.15 / 0.18 / 0.36 |
| 2 | 0.065–0.10 / 0.13 / 0.28 |
| 3 | 0.105–0.145 / 0.18 / 0.36 |
| 4 | 0.075–0.11 / 0.12 / 0.24 |
| 5 | 0.115–0.15 / 0.40 / 0.72 |

El combo completo pasa de ~1.3 s a ~1.0 s hasta el remate.

**La mano fuera de lugar.**
- **Causa:** al salir de un golpe, el animador mezcla 0.35 s desde la última pose del clip del golpe. Los ángulos del brazo de esos clips no coinciden con dónde el arco dejaba la mano. La mezcla de salida de la capa duraba menos que ese fundido (0.24 s), así que al terminar la mano saltaba a una mezcla que apuntaba a otro lado.
- **Arreglo:** durante `exit_hold` (0.45 s), la muñeca sigue el brazo del clip nuevo solo, encadenado sobre el torso ya mezclado (`HumanoidMotion._clip_wrist()`). Cuando termina, coincide con la animación.
- **Verificación:** en una pelea simulada de 40 s con golpes, dashes y Envainar, el desvío después de cada golpe es 0°.

## Adenda 3: arcos horneados en los clips (2026-09-28)

El bug de la mano seguía apareciendo al cancelar un básico con dash.

- **Causa de fondo:** la capa en tiempo real movía la muñeca por encima de un clip cuyo brazo guardado era otro. Cada cancelación (dash, salto, daño) mezclaba el motor desde ese brazo falso, y cada parche dejaba otro caso suelto.
- **Arreglo:** los arcos se **hornean** en los clips. Al construir la librería, `LowPolyHumanoid._bake_arm()` recorre cada cuadro del golpe ya horneado:
  1. reconstruye el torso y el hombro derecho a partir de las claves del clip;
  2. ubica el agarre sobre el arco, con el latigazo de la punta y la mezcla entre arcos;
  3. resuelve hombro, codo y muñeca con IK de dos huesos (codo hacia `ARM_POLE`);
  4. escribe los ángulos, desenrollados para que no giren de golpe (`_unwrap_euler`).
- **Resultado:** los clips traen el brazo verdadero, y cualquier mezcla del motor parte de la pose correcta.
- **La capa en tiempo real** queda solo con los resortes y los pies clavados. El código de la muñeca sigue ahí, pero sin arcos no actúa.
- **Marco de la katana para el horneado:** lo calcula el perfil desde `katana.tres` (`_set_bake_weapon()`), con la misma cuenta que `WeaponMount`.
- **Verificación:** golpe y dash de 3 a 10 cuadros después, 16 veces. La capa nunca toca la muñeca, y la diferencia que queda es el fundido normal del motor entre el golpe y el dash.
- **Limitación:** si el arco pide más alcance que el brazo (la estocada), la muñeca queda en el máximo del brazo y la mano no llega del todo al radio pedido.
