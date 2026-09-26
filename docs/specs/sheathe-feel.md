# Feature: Envainar — mirada fija, feedback de carga, corte de viento en V y más rango

- **Estado:** Implementada (2026-09-25, 335 tests GdUnit4 en verde, 0 orphans; `sheathe_feel_test`, `sheathe_test` y `samurai_run_test` pasaron 3 corridas seguidas; import y smoke test headless del menú y de la arena sin errores ni warnings). El corte de viento en V horizontal (AC265) fue reemplazado por `wind-cut-v.md`.
- **Constitución:** `docs/constitution.md` v3.2.0 → enmienda **MINOR 3.3.0** (la tabla de colores suma el corte de viento, en blanco translúcido).
- **Pilar (Principio I):** combate. Hace más legible y expresiva la carga: sabés a quién apuntás, sentís cada segundo que acumulás, y el golpe se ve con su alcance real.
- **Dependencias:** `samurai.md` (Implementada).

## 1. Objetivo

1. **Mirada fija mientras cargás.**
   - En cada paso de la carga, el samurái gira instantáneamente hacia el **enemigo vivo más cercano**, aunque cambie cuál es.
   - Caminar (y dashear) no lo hace girar: camina de costado o de espaldas.
   - Sin enemigos vivos, mantiene la orientación que tenía (la del momento de apretar, o la última hacia un enemigo).
   - Al soltar o cancelar, caminar vuelve a girarlo como siempre.
2. **Feedback en cada segundo de carga.** Hay un *hito* en cada segundo entero cargado (1 s, 2 s…) y uno al llegar a la carga completa. Si la carga completa cae justo en un segundo entero, ese es el hito de carga completa. Cada hito produce tres efectos:
   - un **temblor de cámara** que crece con cada hito, y el más fuerte en la carga completa;
   - un **pulso del indicador**: el rectángulo se vuelve más opaco un instante y vuelve a su transparencia;
   - un **temblor del cuerpo**: `Visual/Body` vibra unas décimas de segundo, más fuerte en cada hito, y vuelve a su posición.
   
   Seguir manteniendo la tecla con la carga completa no genera más hitos.
3. **Corte de viento en V.**
   - Cuando cae el tajo (fin del cast), aparecen dos franjas de viento que salen del samurái y se abren en **V hacia adelante**.
   - El largo de cada franja es el del tajo (`HIT_RANGE × factor`) y el ángulo entre ellas es `2 × half_angle`.
   - Las franjas crecen desde el vértice hasta la punta en `grow_duration` y se desvanecen en `fade_duration`.
   - Es solo visual (`top_level`, queda donde se lanzó). Son dos `BoxMesh` planos con un material blanco translúcido, unshaded, con alpha ≤ 0.5 (Principio II, 3.3.0).
4. **Más rango.**
   - Largo: `hit_range` 4 → **6 m** a carga completa (1.8 m sin carga).
   - Ancho: `hit_width` 1.2 → **1.6 m**.
   - La onda de empuje (2.5 m) no cambia.

## 2. Diseño

- **`AbilityComponent`**
  - Nueva señal `charge_milestone_reached(index: int, is_full: bool)`, con `index` desde 1.
  - Nuevo hook de behavior `charge_milestone(ability, index, is_full)`.
  - El intervalo de los hitos sale de un nuevo export `charge_feedback: ChargeFeedbackConfig`, asignado en `player.tscn`.
  - Un hito se emite una sola vez por carga, cuando `_charge_elapsed` cruza un múltiplo del intervalo o llega a `CHARGE_TIME`.
- **`SheatheAbility`**
  - **Mirada:** `_face_target()` mira al enemigo más cercano, o mantiene `_held_yaw` si no hay ninguno. Se llama en `begin_charge`, en `charge` (así cubre también el dash) y después de `movement.move()` en `move_body`, lo que anula el giro hacia donde se camina.
  - **Pulso del indicador:** `charge_milestone` → `_indicator.pulse()`.
  - **Corte en V:** en `release()` se llama `_wind_cut.play(origin, yaw, length)`.
- **`ChargeFeedbackComponent`** (nuevo, en `player.tscn`)
  - Escucha `charge_milestone_reached` de los dos slots.
  - Llama `camera.shake(strength)` con `strength = full_shake` si es el hito de carga completa, o `min(base_shake + step_shake × (index − 1), full_shake)` si no.
  - Hace vibrar `Visual/Body` alrededor de su posición de reposo durante `tremor_duration`: desplazamiento horizontal senoidal de frecuencia `tremor_frequency`, con amplitud que se calcula igual que la del shake y decae a 0.
  - No cambia colores ni visibilidad (el parpadeo de `HitFeedback` usa `visible`, así que no hay conflicto).
- **`AbilityRectIndicator.pulse()`:** baja la transparencia a `pulse_transparency` y la recupera linealmente en `pulse_duration` hasta la transparencia actual. No interfiere con `start_fade()`.
- **`WindCutVfx`** (nuevo, `Node3D` con `top_level`)
  - Crea sus dos brazos en `_ready` y los reutiliza (Principio V).
  - `play(origin, yaw, length)` los ubica a `height` sobre el piso, rotados ±`half_angle` desde el frente del samurái.
  - Crecen escalando en Z de 0 a `length` durante `grow_duration`, y después se desvanecen con `transparency` de `start_transparency` a 1 durante `fade_duration`.

### Datos (Principio III)

| Resource | Campos |
|---|---|
| `ChargeFeedbackConfig` (`data/player/charge_feedback_config.tres`) | `milestone_interval 1.0` · `base_shake 0.25` · `step_shake 0.15` · `full_shake 0.8` · `base_tremor 0.02` · `step_tremor 0.015` · `full_tremor 0.06` (m) · `tremor_duration 0.2` · `tremor_frequency 40` (Hz) |
| `AbilityIndicatorConfig` | + `pulse_transparency` · `pulse_duration`. Envainar usa `0.1` / `0.2`. La Estocada no usa pulso (valores en 0). |
| `WindCutConfig` (`data/abilities/sheathe/wind_cut_config.tres`) | `height 1.1` · `half_angle_degrees 20` · `arm_width 0.15` · `arm_thickness 0.03` · `grow_duration 0.1` · `fade_duration 0.3` · `start_transparency 0.5` |
| `sheathe.tres` | `hit_range 6.0` · `hit_width 1.6`, y la descripción actualizada |
| `materials/wind_cut_material.tres` | blanco `Color(1,1,1)`, unshaded, transparencia alpha, sin culling |

### Enmienda 3.3.0 (MINOR)

La tabla de colores del Principio II suma la fila **"Corte de viento (Envainar) | `BoxMesh` | blanco translúcido, unshaded, alpha ≤ 0.5 (transparency ≥ 0.5)"**. El blanco pasa a compartirse también con esta VFX. Se lee como viento y dura décimas de segundo, igual que la estela.

## 3. Criterios de aceptación

- **AC256** Envainar tiene `hit_range` 6 m y `hit_width` 1.6 m. Un enemigo a 5 m recibe el tajo a carga completa y no lo recibe sin carga.
- **AC257** Mientras carga, el `Visual` mira al enemigo más cercano aunque se camine en otra dirección. Si otro enemigo pasa a ser el más cercano, la mirada cambia a él.
- **AC258** Si se dashea mientras carga, al terminar el dash sigue mirando al enemigo más cercano.
- **AC259** Sin enemigos, caminar mientras carga no cambia el yaw del `Visual`.
- **AC260** Después de soltar, caminar vuelve a girar al personaje hacia donde camina.
- **AC261** Los hitos se emiten una vez cada uno:
  - con `CHARGE_TIME` 3 s: (1, no completa), (2, no completa), (3, completa);
  - con `CHARGE_TIME` 2.7 s: 1, 2 y (3, completa) a los 2.7 s;
  - mantener hasta los 5 s no emite más.
- **AC262** Cada hito sacude la cámara con fuerza creciente (0.25, 0.40), y la carga completa con 0.8.
- **AC263** En cada hito, el indicador pasa a `pulse_transparency` y vuelve a su transparencia anterior después de `pulse_duration`.
- **AC264** En cada hito, `Visual/Body` se desplaza de su posición de reposo. Vuelve exactamente a ella después de `tremor_duration`, y la amplitud máxima crece por hito.
- **AC265** *(Reemplazado por `wind-cut-v.md` AC271–AC275)* Cuando cae el tajo, el corte de viento:
  - se muestra con dos brazos a ±`half_angle` del frente, a `height` de altura;
  - llega a `HIT_RANGE × factor` de largo después de `grow_duration`;
  - tiene transparencia ≥ 0.5 (alpha ≤ 0.5);
  - se oculta después de `grow_duration + fade_duration`.
- **AC266** Regresión: suite completa en verde. `AbilityIndicatorConfig` con pulso en 0 no cambia la Estocada.

## 4. Plan de implementación

1. Esta spec, la enmienda 3.3.0 y los datos: `ChargeFeedbackConfig`, `WindCutConfig`, el material, el pulso en `AbilityIndicatorConfig` y el rango de `sheathe.tres`.
2. `AbilityComponent`: hitos, señal y hook, y el export en `player.tscn`.
3. `SheatheAbility`: mirada fija (`_face_target`, `_held_yaw`) y pulso del indicador.
4. `ChargeFeedbackComponent` en `player.tscn`: shake y temblor del cuerpo.
5. `WindCutVfx` como hijo de `sheathe_ability.tscn`, lanzado en `release()`.
6. Tests AC256–AC266. Los tests de `samurai.md` que usan el rango (AC243, AC250) siguen derivando de `SHEATHE.hit_range`, así que no necesitan cambios.
7. Suite completa, smoke test, captura del corte en V y cierre (estado **Implementada**, `CLAUDE.md` → AC267).

## 5. Notas de implementación

- `AbilityRectIndicator` separa `resize()` (mueve y redimensiona sin tocar la transparencia) de `show_rect()`, y guarda una transparencia de reposo sobre la que se superpone `pulse()`. Así el pulso no lo pisa el re-dimensionado de cada paso de la carga.
- La transparencia de carga completa se aplica en el hito de carga completa y no comparando `ratio >= 1.0`, porque la suma de pasos queda apenas por debajo de `CHARGE_TIME`. `get_charge_ratio()` devuelve 1 desde ese hito.
- `ThirdPersonCamera.get_shake_strength()` es un getter nuevo de solo lectura, para verificar AC262.
- **Test viejo adaptado:** `sheathe_test` AC250 avanza el indicador `pulse_duration` antes de comprobar la transparencia de carga completa (ahora el hito de carga completa hace un pulso encima). Verifica lo mismo.
- **Mirada:** `move_body` vuelve a apuntar después de `movement.move()` en el mismo paso, así el giro hacia donde se camina nunca llega a verse.

### Review de la constitución (cierre)
- **I:** combate.
- **II:** el corte de viento son `BoxMesh` con un material `.tres` compartido, blanco translúcido unshaded con alpha ≤ 0.5 (enmienda 3.3.0). El temblor solo mueve la malla del cuerpo, sin cambiar su color. Sin shaders.
- **III:** todos los valores están en `charge_feedback_config.tres`, `wind_cut_config.tres`, `sheathe_indicator_config.tres` y `sheathe.tres`. `MIN_LENGTH` y `TIME_EPSILON` son constantes estructurales.
- **IV:** tipado estricto; `_process`/`_ready` delegan en métodos con nombre.
- **V:** los brazos de la V y los segmentos del indicador se crean una vez y se reutilizan; sin allocations ni búsquedas de nodos por frame.
- **VI:** solo acciones del InputMap.
- **Calidad:** suite completa en verde.
