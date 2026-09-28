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
