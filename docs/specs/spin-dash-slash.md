# Feature: el dash cancela el Giro con un corte horizontal

- **Estado:** Implementada (2026-09-26; `spin_dash_slash_test` 11/11, `spin_test`/`dash_cancel_test` sin fallos nuevos, 0 orphans; smoke test sin errores ni warnings; suite completa no terminada a pedido del usuario, ver §9). ACs: AC567–AC577. AC552–AC566 los tienen `boss-health-tuning.md` y `enemy-level-pace.md`, en implementación en paralelo.
- **Constitución:** `docs/constitution.md` v4.6.1 → **v4.7.0** (enmienda MINOR aplicada, §7).
- **Pilares (Principio I):**
  - **Combate:** el Giro deja de ser un compromiso de 3 s. Se puede salir en cualquier momento con un dash, y esa salida es un golpe (como la Q cargada de Yone en League of Legends, pero sin levantar a los enemigos). Premia elegir cuándo cortar el Giro y hacia dónde atravesar al grupo.
  - **Progresión:** el corte cuenta como golpe del Giro, así que las cartas de daño y las doradas del Giro también lo mejoran.
- **Dependencias:** `sheathe-dash-cancel.md`, `dash-iframes.md`, `spin-golden-upgrades.md` y `spin-tornado.md` (Implementadas).

## 1. Objetivo

### 1.1 Comportamiento

- **Durante el Giro se puede dashear.** Hoy el dash está bloqueado mientras se gira.
- **El dash es el normal:** misma dirección (la del movimiento, o hacia adelante si no hay input), misma velocidad, misma distancia, invulnerable solo mientras dura (`dash-iframes.md`) y mismo enfriamiento del dash.
- **El Giro termina en ese cuadro:** la vuelta en curso no golpea, y el enfriamiento del Giro sigue corriendo desde que se lanzó.
- **Corte horizontal:** mientras dura el dash, cada enemigo que el cuerpo **cruza** recibe **un golpe**, una sola vez por dash.
  - La zona es una franja de `dash_slash_width` a lo largo del recorrido, con el mismo cálculo que el Golpe Veloz (`HitboxMath.in_rectangle` por paso, con el radio del enemigo).
  - Si una pared corta el dash, la franja termina donde termina el dash.
- **Daño:** el de una vuelta del Giro × **2**, es decir, `(BASE_DAMAGE + ATTACK_SCALING × DAMAGE) × dash_slash_damage_factor`. Las cartas de daño del Giro lo suben. Con los datos actuales: (8 + 15 % del daño) × 2.
- **Cuenta como golpe del Giro,** así que aplican todas sus mejoras doradas:
  - **Rompecorazas:** aplica 1 stack de Debilitar a los que sobreviven.
  - **Vigorizante:** cada kill da 1 stack de Conmoción, y el corte puede critear con la probabilidad de los stacks (el daño crítico es el del personaje).
  - **Tornado:** cada kill resta 1 s al enfriamiento del Giro.
- **Empuje:** hacia el costado del recorrido, del lado en que está el enemigo, como el Golpe Veloz, con `dash_slash_knockback_speed`. No los levanta.
- **Se puede cortar en cualquier momento del Giro,** incluso antes de la primera vuelta.
- **Sin Giro activo,** el dash del Berserker es el de siempre, sin corte.

### 1.2 Animación y efectos

- **Barrido del mandoble:** al empezar el corte, el `Visual` mira hacia la dirección del dash y el arma hace un barrido horizontal con `SwordSwing.play()`, de `dash_slash_arc_degrees` en `dash_slash_sweep_duration`, con la inclinación y la altura del barrido de la clase. Después vuelve al reposo como siempre.
  - La estela del arma sale sola: `WeaponTrail` emite mientras hay barrido.
- **Efecto `DashSlashVfx`** (solo visual, `top_level`, nodos creados una sola vez):
  - **Franja de corte:** una lámina horizontal y fina (`BoxMesh`) a la altura de la hoja, que se estira detrás del jugador siguiendo el dash, con el ancho de la franja de daño. Al terminar el dash se desvanece en `fade_duration`.
  - **Chispas:** una ráfaga de `CPUParticles3D` a lo largo del recorrido, que salen hacia los costados.
  - **Destello:** un destello breve en la punta, al final del dash (`SphereMesh` y `OmniLight3D` de décimas de segundo).
  - **Material:** el compartido `materials/vfx/wind_cut_additive_material.tres` (blanco, unshaded, aditivo, alpha ≤ 0.5), igual que el corte de viento de Envainar. Requiere la fila nueva de la tabla de colores (§7).

## 2. Estructura

### 2.1 Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `data/abilities/spin/spin.tres` | `dash_cancels_cast = true` |
| `resources/spin_config.gd` + `spin_config.tres` | Grupo "Dash slash": `dash_slash_damage_factor 2.0`, `dash_slash_width 2.5` (m), `dash_slash_knockback_speed 4.0` (m/s), `dash_slash_arc_degrees 220`, `dash_slash_sweep_duration 0.2` (s), `vfx: DashSlashVfxConfig` |
| `resources/dash_slash_vfx_config.gd` (nuevo) | `blade_height`, `thickness`, `start_transparency`, `fade_duration`, `spark_amount`, `spark_lifetime`, `spark_speed_min/max`, `spark_size`, `flash_radius`, `flash_duration`, `flash_energy`, `flash_range` |
| `data/abilities/spin/dash_slash_vfx_config.tres` (nuevo) | altura 1.1 m, espesor 0.03 m, transparencia inicial 0.5, fade 0.25 s, 24 chispas de 0.3 s a 3–6 m/s y 0.05 m, destello de 0.35 m en 0.15 s, energía 2 y alcance 3 m |

**Stats fijos por diseño (Principio III, 3.1.1):** el factor de daño, el ancho, el empuje y el barrido no tienen carta. El daño sube igual con las cartas de daño del Giro.

### 2.2 Nodos

```
SpinAbility (spin_ability.tscn)
└── DashSlash : DashSlashVfx (Node3D, top_level)   config + glow_material
      ├── Blade : MeshInstance3D (BoxMesh)
      ├── Sparks : CPUParticles3D
      ├── Flash : MeshInstance3D (SphereMesh)
      └── FlashLight : OmniLight3D
Player: BasicAbility / UltimateAbility  + export dash → DashComponent
```

## 3. Interfaz pública

- **`DashComponent.get_direction() -> Vector3`** (nuevo): dirección plana del dash en curso (o del último).
- **`AbilityComponent`**
  - `+ @export var dash: DashComponent`.
  - `+ cut_cast_by_dash()`: igual que `cancel_cast()` (corta el cast, `behavior.cancel_cast`, emite `cast_released`) y después llama al hook nuevo `behavior.cast_cut_by_dash(self)`. Sin cast, no hace nada.
- **`AbilityBehavior.cast_cut_by_dash(ability)`:** hook nuevo, que por defecto no hace nada. Envainar sigue usando solo `cancel_cast`, así que su comportamiento no cambia.
- **`Player._handle_dash()`:** después de un `try_dash()` exitoso llama `cut_cast_by_dash()` en lugar de `cancel_cast()` (mismo orden: cortar → `notify_dash()`). `begin_hold()` sigue usando `cancel_cast()`, así que el agarre de un boss no dispara el corte.
- **`SpinAbility`**
  - `cancel_cast()`: el arma vuelve al reposo (`sword_swing.recover()`). Es el caso del agarre.
  - `cast_cut_by_dash()`:
    - arranca el corte: guarda la posición inicial, limpia la lista de golpeados y gira el `Visual` hacia `dash.get_direction()`;
    - `sword_swing.play(arc, sweep_duration, 1.0)`;
    - `DashSlash.begin(origen, yaw)`;
    - activa su `_physics_process`.
  - `_physics_process` solo delega en `advance_dash_slash()`:
    - corta la franja entre la última posición y la actual, igual que el Golpe Veloz;
    - `DashSlash.extend_to(posición)`;
    - si el dash terminó: `DashSlash.finish()` y se apaga.

    Como el nodo es hijo del jugador, corre después de que `Player` movió el cuerpo en ese cuadro.
  - `is_dash_slashing() -> bool`, `get_dash_slash()`.
  - **Golpe:** reutiliza `_hit_enemy` con una dirección de empuje por parámetro (hacia afuera en el Giro, al costado en el corte) y con el crítico de Conmoción.
- **`DashSlashVfx`:** `begin(origin, yaw)`, `extend_to(point)`, `finish()`, `advance(delta)` e `is_playing()`. Para los tests: `get_blade()` y `get_blade_length()`.

## 4. Lógica interna

- **Orden en el cuadro del dash:**
  - `Player._handle_dash`: `try_dash` → `cut_cast_by_dash` (el Giro termina y arranca el corte) → `notify_dash`;
  - `_handle_movement`: el dash mueve el cuerpo;
  - `SpinAbility._physics_process`: corta el primer tramo.
- **Mitad del Giro:** el barrido reemplaza la pose del Giro (`hold_pose`), porque `play()` para cualquier pose.
- **Rendimiento (Principio V):** los buffers de golpes (`_hit_buffer` y `_already_hit`) son miembros que se limpian. El VFX solo cambia transformaciones y transparencia por frame.

## 5. Criterios de aceptación

- **AC567** `spin.tres` tiene `dash_cancels_cast = true`. `spin_config.tres` tiene los valores de §2.1, y `dash_slash_vfx_config.tres` también.
- **AC568** Girando, apretar dash:
  - dashea en ese cuadro y el Giro termina (`is_casting()` falso);
  - el dash recorre `DASH_DISTANCE` a `DASH_SPEED` y el jugador es invulnerable solo mientras dura;
  - el enfriamiento del Giro sigue activo y sin cambios.
- **AC569** Un enemigo en el camino del dash recibe un golpe de `hit_damage × 2`, una sola vez. Uno fuera de la franja (a más de `dash_slash_width / 2` más su radio del recorrido) no recibe nada.
- **AC570** Los enemigos cortados son empujados hacia el costado del recorrido, del lado en que están, a `dash_slash_knockback_speed`.
- **AC571** Con Rompecorazas, el corte aplica 1 stack de Debilitar. Con Vigorizante, una kill del corte da 1 stack de Conmoción. Con Tornado, una kill del corte resta 1 s al enfriamiento del Giro.
- **AC572** Con probabilidad crítica 1 (buff de test, como AC294), el corte critica con `× (1 + CRIT_DAMAGE)` y se reporta con `is_crit = true`. Sin stacks, no critica.
- **AC573** Al empezar el corte:
  - el `Visual` mira hacia la dirección del dash;
  - `SwordSwing` está barriendo (`is_swinging()`) con el arco y la duración del corte;
  - la estela del arma emite.
- **AC574** `DashSlashVfx`: la franja es visible al empezar, termina con el largo del recorrido del dash (±0.1 m), a `blade_height` y con el material compartido. Se desvanece y se oculta a los `fade_duration` después del dash. Tras dos cortes sigue teniendo los mismos nodos (Principio V).
- **AC575** Un dash del Berserker sin Giro activo no corta ni muestra el efecto. El agarre de un boss (`begin_hold`) durante el Giro tampoco dispara el corte.
- **AC576** Regresión de Envainar: los tests de `sheathe-dash-cancel` (AC355–AC366) siguen en verde. La Estocada sigue bloqueando el dash durante su cast.
- **AC577** Regresión: suite completa en verde (salvo fallos previos ajenos, si los hay, anotados), y import y smoke test sin errores ni warnings.

## 6. Tests que pueden necesitar adaptación

- Si algún test fija que el dash está bloqueado durante el Giro, se adapta a AC568 y se anota acá.

## 7. Enmienda propuesta: constitución v4.7.0 (MINOR)

- **Principio II, tabla de colores:** fila nueva "Corte del dash (VFX del Giro cancelado): lámina horizontal, chispas y destello". Mallas `BoxMesh`/`SphereMesh` y partículas, en **blanco** `Color(1, 1, 1)` unshaded, aditivo, alpha ≤ 0.5.
- La frase sobre quién comparte el blanco suma el corte del dash: es una franja translúcida que se desvanece en décimas de segundo, igual que la estela y el corte de viento.

## 8. Plan

1. **Reservar ACs:** AC567–AC577 en `CLAUDE.md` (próximo libre → AC578).
2. **Datos:** `SpinConfig` (grupo Dash slash), `DashSlashVfxConfig`, sus `.tres` y `dash_cancels_cast` en `spin.tres`.
3. **Base:**
   - `DashComponent.get_direction()`;
   - `AbilityComponent.dash` y `cut_cast_by_dash()`;
   - hook `cast_cut_by_dash`;
   - `Player._handle_dash` usa `cut_cast_by_dash`, y el export `dash` en `player.tscn`.
   - Correr la suite de Envainar (sin cambios de comportamiento).
4. **Corte:** en `SpinAbility`, corte por pasos, `_hit_enemy` con dirección de empuje y barrido. Tests AC568 a AC573 y AC575.
5. **VFX:** `DashSlashVfx` en `spin_ability.tscn`. Test AC574.
6. **Cierre:**
   - Enmienda v4.7.0.
   - Suite completa, import y smoke test (copia en el scratchpad).
   - Una captura visual del corte para revisar la animación.
   - Review de la constitución y estado Implementada.
   - `CLAUDE.md`.

## 9. Notas de implementación

- **Sin lámina (pedido del usuario después de ver las capturas):** el efecto ya no deja una lámina de luz detrás del jugador. El tajo se ve con el barrido del mandoble y su estela (`WeaponTrail`), más las chispas a lo largo del recorrido y el destello en la punta al terminar el dash. Esto reemplaza la "franja de corte" de §1.2, y AC574 pasa a verificar solo chispas, destello y reutilización de nodos. `DashSlashVfxConfig` quedó con `blade_height` (altura de chispas y destello), las chispas y el destello (`flash_start_transparency`). Se sacaron `thickness`, `start_transparency` y `fade_duration`.
- **Config del efecto:** vive solo en el nodo `DashSlash` de `spin_ability.tscn`, no en `SpinConfig`, para no referenciarlo dos veces.
- **`AbilityComponent.dash`:** ya existía (lo agregó Zanshin), así que se reutilizó.
- **Test adaptado:** `spin_test.gd` AC191 ("no puede atacar ni dashear girando") pasa a `test_ac191_moves_slowed_while_spinning_and_cannot_attack`. Sigue verificando la caminata lenta y el ataque bloqueado. El dash durante el Giro ahora lo cubre AC568.
- **Tests del corte con vida alta:** los datos del Giro se retocaron fuera de esta spec (`base_damage` 100, `attack_scaling` 0.25), y un golpe mata a un grunt de 40. Por eso los enemigos de `spin_dash_slash_test` tienen 10 000 de vida y el daño esperado se lee de los datos.
- **Suite completa:** una primera corrida, cortada por tiempo, y una segunda en segundo plano, frenada a pedido del usuario, no mostraron fallos nuevos. Los únicos fallos vistos son los previos ajenos ya registrados en `dash-iframes.md`:
  - AC188 y AC211;
  - AC285/AC298 y AC288, por Conmoción con +12 % de movimiento y el daño del Giro retocados en datos.

## 10. Review de la constitución (cierre)

- [x] **I:** Combate (salida del Giro con golpe, elegir hacia dónde cortar) y Progresión (las cartas del Giro mejoran el corte), como declara la spec.
- [x] **II:** chispas (`BoxMesh` en `CPUParticles3D`) y destello (`SphereMesh` y `OmniLight3D` breve) con el material compartido `wind_cut_additive_material.tres`, en blanco aditivo con alpha ≤ 0.5, registrados en v4.7.0. Sin shaders ni texturas.
- [x] **III:** factor de daño, ancho, empuje y barrido en `spin_config.tres`, y el efecto en `dash_slash_vfx_config.tres`. `dash_cancels_cast` en `spin.tres`. Stats fijos por diseño declarados en §2.1.
- [x] **IV:** tipado completo. `SpinAbility._physics_process` solo delega en `advance_dash_slash()`, y `DashSlashVfx._process` en `advance()`.
- [x] **V:** los nodos del efecto se crean una vez y se reutilizan (AC574). Los buffers `_hit_buffer` y `_slashed` son miembros que se limpian. Sin búsquedas de nodos por frame.
- [x] **VI:** solo la acción `dash` del InputMap.
- [x] **Calidad:** tests de la spec en verde, sin errores ni warnings nuevos. La suite completa no se terminó (ver §9).
