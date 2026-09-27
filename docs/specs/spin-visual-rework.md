# Feature: re-work visual del Giro

- **Estado:** **Implementada** (2026-09-27). `spin_visual_rework_test` 18/18 en verde. La suite completa no suma fallas nuevas: las que quedan ya fallaban antes (§11). Smoke test del menú y de la arena sin errores ni warnings nuevos. Capturas con Forward+ revisadas. ACs **AC861–AC877** (AC878–AC880 sin usar), reservados en `CLAUDE.md`. Se dejan libres AC801–AC860 para `warrior-abilities-rework.md`, que se escribe en paralelo en otra sesión.
- **Constitución:** `docs/constitution.md` v4.15.x. Enmienda **MINOR** a 4.16.0 aprobada con esta spec (§7).
- **Pilar (Principio I):** **combate.** El Giro es la habilidad del Berserker, pero hoy no se lee:
  - el cuerpo gira quieto en `idle`;
  - el mandoble flota lejos de la mano;
  - no se ve dónde llega el daño ni cuándo cae cada golpe.

  Con el cuerpo sosteniendo el arma, el área marcada en el piso y un pulso por vuelta, el jugador sabe qué golpea y cuándo.
- **Decisiones del responsable (2026-09-27):**
  - Las **chispas al golpear un enemigo** quedan fuera: las trata otra spec de feedback visual de impacto.
  - **Los límites de las habilidades pasan a ser un relleno blanco muy transparente en el piso** (opacidad ≈ 0.3), en vez de la línea celeste. Es una regla para todas las habilidades (§2.6).
  - **Pausa en el Corte del Giro:** sí (§2.5).
  - El feedback de impacto (temblor y sacudida) es **solo para el Giro**.
  - Se **corrige el texto** del Giro a los valores reales (§2.7).
- **Dependencias:**
  - `berserker.md`, `spin-buff-wind-trail.md`, `spin-dash-slash.md`, `spin-golden-upgrades.md` y `spin-tornado.md`: la mecánica del Giro no cambia;
  - `humanoid-player-model.md` (`WeaponMount`, `PlayerAnimator`);
  - `sheathe-release-animation.md` (patrón `get_body_clip()` / `holds_weapon_in_hand()`);
  - `bdo-combat-feel.md` (*hit lag*, `HitstopConfig`).

## 1. Estado actual (auditoría)

1. **Cuerpo en `idle`.** Mientras castea, `PlayerAnimator` pide `get_body_clip()`. El Giro devuelve `&""`, así que suena `CLIP_BUSY = &"idle"` (`components/player_animator.gd:46`). En el Berserker, `idle` es la guardia con el mandoble al hombro:
   - el humanoide gira entero (rota el `Visual`) en esa pose;
   - como el Giro permite caminar (`move_speed_factor` 0.8), se desliza sin mover las piernas.
2. **El mandoble flota.** `SpinAbility.begin()` llama `SwordSwing.hold_pose(blade_position (0.4, 1.1, 0), blade_rotation (0, −90°, 0))`. Con `SwordSwing` activo, `WeaponMount.is_hand_free()` es falso, así que:
   - el arma queda en una pose fija del espacio del `Visual`;
   - la mano derecha sigue al hombro, y la izquierda no toma el mango.
3. **El Corte del Giro flota.** `cast_cut_by_dash()` llama `SwordSwing.play(220°, 0.2 s)`. El cuerpo hace el clip `dash` con el arma al hombro, mientras el mandoble barre solo.
4. **No se ve el área.** El radio real es `HIT_RANGE` = 3.5 m más el radio del enemigo. La punta del mandoble llega a unos 2.8 m, así que se golpea a enemigos que la hoja no toca.
5. **No se ve el golpe.** El daño cae al **completar** cada vuelta (`_hit_completed_turns`). Nada marca ese momento: no hay temblor, sacudida ni pulso. Solo aparecen los números de daño y la sacudida de la barra.
6. **Texto desfasado.** La descripción de `spin.tres` no coincide con los valores efectivos:

   | Dato | El texto dice | El valor real es |
   |---|---|---|
   | Duración | 3 s | 4 s (`cast_duration`) |
   | Daño | "8 de daño + 15 %" | 0 + 100 % de tu daño (`base_damage` no escrito = 0; `attack_scaling` 1.0) |
   | Radio | 2.5 m | 3.5 m (`hit_range`) |
   | Enfriamiento | 9 s | 9 s (`cooldown` 8 con piso `min_cooldown` 9) |

   Tampoco nombra el ritmo: una vuelta cada 0.8 s (`tick_interval`).

## 2. Diseño

### 2.1 Clip `spin` del Berserker (el cuerpo gira con el arma)

Es un clip nuevo en `berserker_profile.gd`: **en loop, 0.5 s**, con dos pasos de arrastre de pies. El giro en sí lo sigue dando `SpinAbility` rotando el `Visual`, igual que hoy. El clip solo pone la pose y el pisoteo.

| t (s) | Pose | Qué pasa |
|---|---|---|
| 0.0 | **Giro, pie izquierdo apoyado** | Mandoble a **dos manos** (`_two_hands`, `left_grip` 1), brazos casi estirados hacia la derecha y un poco adelante. La hoja queda **horizontal, a la altura de la cintura (~1.0 m)** y apunta hacia afuera. El torso se inclina hacia el giro, con el peso bajo (`hips_pos` −0.18), y la cabeza mira por encima de la hoja. |
| 0.25 | **Giro, pie derecho apoyado** | La misma pose de brazos y torso, con las piernas cruzadas en el pisoteo (el pie de afuera empuja). La cadera sube 2 cm. |
| 0.5 | = t 0.0 | Loop. |

- **Sentido.** El `Visual` gira con yaw creciente (antihorario visto desde arriba). Con la hoja a la derecha, el filo va **adelante** en el giro.
- **La hoja no toca el piso** y **no atraviesa el torso** (mismo criterio que AC751, aplicado al mandoble).
- **Entrada:** el cambio de `idle` a `spin` usa la mezcla normal del animador.
- **Salida:** hoy `PlayerAnimator` sale de un clip de habilidad con la mezcla lenta `attack_exit_blend` (0.35 s) **solo si es de un solo disparo**. La spec la extiende a los clips en loop: al terminar el Giro, el cuerpo vuelve a la guardia (o a caminar) con esa mezcla, en vez de saltar de pose.

### 2.2 El arma en la mano

- `SpinAbility.get_body_clip()` devuelve `config.body_clip` (`&"spin"`) mientras castea.
- `SpinAbility.holds_weapon_in_hand()` devuelve `true` mientras castea.
- Se borra el uso de `SwordSwing` en el Giro:
  - `hold_pose` en `begin()`;
  - `recover()` en `release()` y `cancel_cast()`.

  `WeaponMount` mezcla el arma hacia la mano (`weapon_mount_blend`, 0.1 s) y después la sigue. El recorrido del mandoble lo da el brazo derecho del clip, como en el combo.
- Se borran `blade_position` y `blade_rotation` de `SpinConfig` y de `spin_config.tres`.

### 2.3 Corte del Giro con el cuerpo

- Es un clip nuevo en `berserker_profile.gd`: **`spin_dash_slash`**, sin loop, que se estira a la duración del dash como `dash`.
  - Arranca desde la pose de `spin` (t 0.0).
  - Barre horizontal a dos manos, de derecha a izquierda, cruzando al frente en ~40 % del clip.
  - Termina en el primer cuadro de `sprint` (`_sprint_contact(1)`), la misma regla de conexión que `dash` (AC786).
- **Quién lo pide:**
  - `AbilityBehavior` suma `get_dash_clip(ability) -> StringName` (por defecto `&""`). `SpinAbility` devuelve `config.dash_slash_body_clip` mientras `is_dash_slashing()`.
  - `AbilityComponent.get_dash_clip()` y `Player.get_dash_clip()` lo exponen. `Player` usa el de la habilidad y, si no hay, `dash.get_clip()`.
  - `PlayerAnimator._play_dash()` usa `player.get_dash_clip()` con la misma mezcla de entrada y el mismo estiramiento.
- Se borra `sword_swing.play(...)` de `cast_cut_by_dash()`. Así, `WeaponMount` sigue a la mano durante el corte.
- Se borran `dash_slash_arc_degrees` y `dash_slash_sweep_duration` de `SpinConfig`: el recorrido lo da el clip.
- **La estela durante el corte.** Hoy la enciende `SwordSwing`. Pasa a encenderla la habilidad:
  - `AbilityBehavior.extends_trail(ability) -> bool` (por defecto `false`); `SpinAbility` devuelve `is_dash_slashing()`;
  - `AbilityComponent.is_trailing()` = `is_casting() or behavior.extends_trail()`, con la señal `trail_changed`;
  - `SpinAbility` la emite al empezar y al terminar el corte;
  - `WeaponTrail` usa `is_trailing()` y escucha `trail_changed`.
- `DashSlashVfx` (la estela horizontal, las chispas y el destello al final del dash) no cambia.

### 2.4 VFX nuevos: `SpinVortexVfx`

Es un nodo nuevo, hijo de `SpinAbility`: `top_level`, creado una vez en `_ready` y reutilizado (Principio V). Sigue al jugador cada cuadro (`follow(...)`, una asignación sin *allocations*).

1. **Área en el piso.**
   - Es un **disco relleno blanco**, muy transparente (opacidad `area_alpha` 0.25), de radio `HIT_RANGE`, apenas sobre el piso. Es un `CylinderMesh` plano, unshaded y con el material compartido de los indicadores (§2.6).
   - Aparece con el Giro (fade in de `area_fade_in`), se reescala si `HIT_RANGE` cambia con una mejora y se desvanece al terminar (`area_fade_out`).
   - Muestra **el área real** del daño.
2. **Pulso por vuelta.**
   - Al completar una vuelta (el instante del daño), el disco **destella**: sube su opacidad hasta `pulse_alpha` (0.45) y crece de `pulse_start_scale` a 1 en `pulse_duration`.
   - Pulsa aunque no haya enemigos: marca el ritmo del daño.
3. **Polvo bajo la hoja.**
   - Son `CPUParticles3D` con el material de polvo existente (`wind_dust_material.tres`, color tierra), que emiten sin parar desde un punto en el piso bajo la punta del mandoble.
   - Como el `Visual` gira, el polvo dibuja un remolino. Al terminar dejan de emitir, y las partículas vivas terminan solas.

Todos los números viven en `SpinVortexConfig` (`data/abilities/spin/spin_vortex_config.tres`).

### 2.5 Feedback de impacto (solo el Giro)

- **Por vuelta que golpea al menos un enemigo:**
  - la cámara se sacude con `SpinConfig.turn_shake`;
  - cada enemigo golpeado tiembla y se congela (`Enemy.apply_hitlag`) `turn_hitlag` segundos, con la amplitud y la frecuencia del `HitstopConfig` de la clase (`berserker_hitstop.tres`). Los bosses solo tiemblan, igual que en el combo.
  - **El jugador no se pausa.** El Giro es canalizado: pausar el clip o la rotación desfasaría las vueltas del daño (AC196/AC197). La excepción queda en la enmienda del Principio VII (§7).
- **En el Corte del Giro:**
  - cada enemigo cortado tiembla y se congela `dash_slash_hitlag` segundos, y la cámara se sacude con `dash_slash_shake`;
  - **el clip del jugador se pausa** `dash_slash_hitlag` segundos al cortar al **primer** enemigo (una sola pausa por corte; no se suma);
  - **el dash sigue su curso**: el cuerpo se sigue moviendo y conserva la invulnerabilidad y la duración. Al reanudar, el clip toma la velocidad justa para terminar junto con el dash, así que la conexión con `sprint` (AC786) se mantiene.
  - Lo hace `PlayerAnimator.hold_dash_clip(duration)`.
- Lo dispara `SpinAbility` al golpear. `AbilityComponent` suma como `@export`:
  - la cámara (`ThirdPersonCamera`);
  - el `HitstopConfig` de la clase (lo asigna `Player` al aplicar la clase, igual que a `HitstopComponent`);
  - el `PlayerAnimator`.

  Es un mecanismo **solo del Giro**. El genérico para todas las habilidades lo decidirá otra spec.

### 2.6 Límites de las habilidades: relleno blanco (todas las habilidades)

Regla nueva: el área de una habilidad se marca en el piso con un **relleno blanco muy transparente** (opacidad en reposo ≤ 0.3, destello ≤ 0.5), no con un contorno celeste.

- **`materials/attack_indicator_material.tres`:** pasa de celeste `Color(0.55, 0.85, 1)` a **blanco** `Color(1, 1, 1)` (unshaded, transparencia alpha). Lo usan Envainar, el Tajo aéreo, la Estocada y Swift Strike (estas dos se van con el re-work del Guerrero), y el disco del Giro.
- **`AbilityRectIndicator`:**
  - de 4 segmentos de contorno pasa a **un solo `BoxMesh` plano** que rellena el rectángulo (largo × ancho, con `line_thickness` de alto);
  - se borran `line_width` y `Edge` de `AbilityIndicatorConfig` y de sus `.tres`;
  - `show_rect`, `resize`, `set_transparency`, `pulse` y `start_fade` no cambian de firma.
- **Transparencias nuevas** (en Godot, `transparency` = 1 − opacidad):

  | Archivo | Campo | Antes | Ahora |
  |---|---|---|---|
  | `sheathe_indicator_config.tres` | `start_transparency` | 0.6 | **0.75** (opacidad 0.25) |
  | `sheathe_indicator_config.tres` | `pulse_transparency` | 0.1 | **0.55** (opacidad 0.45) |
  | `sheathe_config.tres` | `full_charge_transparency` (carga completa) | 0.2 | **0.6** (opacidad 0.4) |
  | `air_slash_indicator_config.tres` | `start_transparency` | 0.5 | **0.75** |
  | `air_slash_indicator_config.tres` | `pulse_transparency` | — | **0.55** |
  | `thrust_indicator_config.tres` y `swift_strike_indicator_config.tres` | | | Se dejan como están: los borra el re-work del Guerrero |

- **No cambian** los avisos de ataque enemigo (rojo anaranjado): así el área del jugador (blanca) y la del enemigo (roja) no se confunden.

### 2.7 Texto del Giro

`spin.tres`, campo `description`:

```
Girás con el mandoble durante 4 s
golpeando a todos a tu alrededor
en cada vuelta (una cada 0.8 s).
Podés moverte lento.
100 % de tu daño por vuelta.
Radio: 3.5 m · Enfriamiento: 9 s
```

Las cartas del Giro cambian la duración, el ritmo, el daño y el radio. El texto describe la base, como las otras habilidades.

## 3. Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `resources/spin_config.gd` / `spin_config.tres` | **Se borran:** `blade_position`, `blade_rotation`, `dash_slash_arc_degrees`, `dash_slash_sweep_duration`. **Se agregan:** `body_clip` (`&"spin"`), `dash_slash_body_clip` (`&"spin_dash_slash"`), `turn_hitlag` (0.06 s), `turn_shake` (0.15), `dash_slash_hitlag` (0.08 s), `dash_slash_shake` (0.35) |
| `resources/spin_vortex_config.gd` (nuevo) / `data/abilities/spin/spin_vortex_config.tres` | **Área:** `area_alpha` 0.25, `area_height` 0.02 m, `ground_offset` 0.05 m, `area_fade_in` 0.15 s, `area_fade_out` 0.25 s. **Pulso:** `pulse_alpha` 0.45, `pulse_start_scale` 0.85, `pulse_duration` 0.2 s. **Polvo:** `dust_amount` 24, `dust_lifetime` 0.5 s, `dust_size` 0.3, `dust_rise_speed` 0.8 |
| `resources/ability_indicator_config.gd` y sus `.tres` | Se borra `line_width`. Transparencias de §2.6 |
| `materials/attack_indicator_material.tres` | Celeste → blanco |
| `data/abilities/spin/spin.tres` | `description` (§2.7) |
| `entities/player/player.tscn` | `camera`, `hitstop` y `animator` en `BasicAbility` y `UltimateAbility` |

Los valores iniciales son el punto de partida y se ajustan con capturas.

## 4. Estructura

```
SpinAbility (spin_ability.tscn)
├── DashSlash : DashSlashVfx            (sin cambios)
└── Vortex : SpinVortexVfx (Node3D, top_level)   config + area/dust materials
      ├── Area : MeshInstance3D (CylinderMesh plano)
      └── Dust : CPUParticles3D

AbilityRectIndicator
└── Fill : MeshInstance3D (BoxMesh plano)   (antes 4 segmentos)
```

## 5. Interfaz pública

- **`SpinVortexVfx`** (`components/abilities/spin_vortex_vfx.gd`):
  - `begin(visual: Node3D, radius: float)`, `follow(visual: Node3D)`, `set_radius(radius: float)`;
  - `pulse()`, `finish()`, `advance(delta: float)` y la señal `pulsed`;
  - para tests: `is_showing()`, `is_pulsing()`, `get_area_radius()`, `get_area_alpha()`, `is_dust_emitting()`, `get_area()`, `get_dust()`.
- **`AbilityBehavior`:** `get_dash_clip(ability) -> StringName` y `extends_trail(ability) -> bool`.
- **`AbilityComponent`:**
  - `@export var camera: ThirdPersonCamera`, `@export var hitstop: HitstopConfig` y `@export var animator: PlayerAnimator`;
  - `get_dash_clip()`, `is_trailing()`, `notify_trail_changed()`;
  - `signal trail_changed`.
- **`Player`:** `get_dash_clip() -> StringName`.
- **`PlayerAnimator`:** `hold_dash_clip(duration: float)` e `is_dash_clip_held() -> bool`.
- **`SpinAbility`:**
  - `get_body_clip()`, `holds_weapon_in_hand()`, `get_dash_clip()`, `extends_trail()`, `get_vortex()`;
  - llama `vortex.pulse()` en cada vuelta completada. Al golpear, llama `camera.shake()` y `enemy.apply_hitlag()`, y en el corte además `animator.hold_dash_clip()`.
- **`AbilityRectIndicator`:** misma interfaz. `get_fill()`, `get_length()` y `get_width()` reemplazan el acceso a los segmentos en los tests.

## 6. Criterios de aceptación

**Cuerpo y arma**
- **AC861** El perfil del Berserker tiene `spin` (loop) y `spin_dash_slash` (sin loop). En todo cuadro de `spin`, `left_grip` es 1.
- **AC862** Mientras se castea el Giro, el humanoide reproduce `spin` y `Player.is_weapon_in_hand_cast()` es verdadero. Con `weapon_mount_blend` cumplido, el pivot del arma coincide con `WeaponMount.get_hand_pose()` (tolerancia 1 mm).
- **AC863** Durante el Giro, `SwordSwing` no está activo y `SpinConfig` no tiene `blade_position`, `blade_rotation`, `dash_slash_arc_degrees` ni `dash_slash_sweep_duration`.
- **AC864** En `spin`, muestreado cada 0.05 s:
  - la hoja (base y punta del mandoble) queda entre 0.6 m y 1.4 m de altura;
  - apunta hacia afuera: la punta está más lejos del eje del cuerpo que la mano;
  - no atraviesa el torso (mismo criterio que AC751).
- **AC865** Al terminar el Giro sin dash, la locomoción entra con `attack_exit_blend`. Sin moverse, el cuerpo termina en `idle`.

**Corte del Giro**
- **AC866** Si un dash corta el Giro, el humanoide reproduce `spin_dash_slash` estirado a la duración del dash, y el arma sigue la mano. Sin el Giro, el dash reproduce `DashData.clip` como hoy.
- **AC867** El último cuadro de `spin_dash_slash` es el primero de `sprint` (misma comparación que AC786).
- **AC868** La estela se enciende durante el Giro y durante el Corte del Giro, y se apaga cuando termina el corte.

**Área, pulso y polvo**
- **AC869** El disco del área está oculto en reposo.
  - Al empezar el Giro se muestra blanco, con radio `HIT_RANGE` y opacidad `area_alpha` (≤ 0.3).
  - Sigue al jugador y se desvanece al terminar en `area_fade_out`.
  - Con la mejora de radio, el disco toma el nuevo `HIT_RANGE`.
- **AC870** Cada vuelta completada lanza exactamente un pulso, con o sin enemigos. La opacidad del pulso nunca supera 0.5. Un Giro de 4 s con `TICK_INTERVAL` 0.8 pulsa 5 veces.
- **AC871** El polvo emite solo mientras se castea el Giro.

**Feedback de impacto**
- **AC872** Una vuelta que golpea sacude la cámara con `turn_shake`, y cada enemigo golpeado recibe `apply_hitlag(turn_hitlag, …)`. Una vuelta que no golpea no sacude la cámara.
- **AC873** Durante las vueltas, el clip del jugador y la rotación del `Visual` no se pausan. Las vueltas y el daño siguen los tiempos de AC196/AC197.
- **AC874** En el Corte del Giro:
  - cada enemigo cortado recibe `apply_hitlag(dash_slash_hitlag, …)` y la cámara se sacude con `dash_slash_shake`;
  - el clip del jugador se pausa `dash_slash_hitlag` una sola vez, al primer corte (con 3 enemigos cortados, la pausa total sigue siendo `dash_slash_hitlag`).
- **AC875** La pausa del Corte del Giro no cambia el dash: misma distancia, duración e invulnerabilidad que un dash sin pausa. El clip termina en su último cuadro cuando termina el dash (tolerancia de un cuadro de física).

**Indicadores y texto**
- **AC876** `attack_indicator_material.tres` es blanco `Color(1, 1, 1)`, unshaded y translúcido. `AbilityRectIndicator` tiene un solo relleno que cubre largo × ancho. Las transparencias de Envainar y del Tajo aéreo son las de §2.6: opacidad en reposo ≤ 0.3 y destello ≤ 0.5.
- **AC877** La descripción de `spin.tres` es la de §2.7, y sus números coinciden con los datos: `cast_duration`, `tick_interval`, `attack_scaling`, `hit_range` y el enfriamiento efectivo (`max(cooldown, min_cooldown)`).

**Regresión**
- **AC878** Los tests del Giro y de los indicadores siguen en verde: `spin_test`, `spin_dash_slash_test`, `spin_golden_upgrades_test`, `spin_tornado_test`, `weapon_trail_test`, `player_animator_test`, `thrust_indicator_test`, `sheathe_feel_test`, `air_slash_test`. Los tests que verificaban `blade_position`, el barrido de `SwordSwing`, los segmentos del contorno o transparencias fijas se adaptan, sin cambiar lo que verifican.
- **AC879** La suite completa en verde, y el smoke test del menú y de la arena sin errores ni warnings.

AC880 queda de reserva para ajustes que salgan de las capturas.

## 7. Enmienda de la constitución (MINOR → 4.16.0)

**Principio II, tabla de colores:** se agrega la fila:

| Elemento | Malla base | Color (`albedo_color`) |
|---|---|---|
| Área de una habilidad del jugador (relleno en el piso: rectángulo o disco) | `BoxMesh` / `CylinderMesh` planos | **Blanco** `Color(1, 1, 1)`, unshaded, alpha ≤ 0.3 en reposo y ≤ 0.5 en un destello |

Otros cambios del Principio II:
- En la lista de elementos que comparten el blanco se agrega el área de las habilidades. No se confunde: es un relleno plano en el piso, muy transparente.
- En el registro de colores no reservados, el celeste pálido queda **solo** para las cartas de mejora de habilidad (deja de ser el color de los indicadores de área).
- Se registra el color tierra también para el polvo del Giro.

**Principio VII, hit lag local:** se agrega "**Las habilidades canalizadas** (p. ej. el Giro) comunican el impacto con el temblor de los golpeados y la sacudida de cámara, **sin pausar al jugador**, para no desfasar sus golpes periódicos. Una pausa durante un dash (p. ej. el Corte del Giro) detiene solo el clip: el dash conserva su recorrido, su duración y su invulnerabilidad."

## 8. Fuera de alcance

- **Chispas y otros VFX al golpear un enemigo:** los trata la spec de feedback visual de impacto, en otra sesión.
- **Feedback de impacto de otras habilidades** (Envainar, Tajo aéreo, las del Guerrero nuevo).
- **El cuerpo y el arma del Tajo aéreo** (también está en `idle` con el arma suelta): va en otra spec.
- **La Estocada y Swift Strike:** los reemplaza `warrior-abilities-rework.md`.

## 9. Plan

1. **Datos y enmienda:**
   - `SpinConfig` (quitar y agregar campos), `SpinVortexConfig` y su `.tres`;
   - material de indicadores en blanco, `AbilityIndicatorConfig` sin `line_width` y las transparencias de §2.6;
   - texto de `spin.tres`;
   - enmienda 4.16.0 en `constitution.md`.
2. **Indicadores:**
   - `AbilityRectIndicator` con un solo relleno;
   - adaptar `thrust_indicator_test`, `sheathe_feel_test` y `air_slash_test`.
   - Tests AC876–AC877.
3. **Clips:**
   - `spin` y `spin_dash_slash` en `berserker_profile.gd`;
   - hoja de capturas (humanoide aislado, 4 ángulos, cada 0.05 s) para ajustar brazos y hoja hasta cumplir AC864 y AC867.
4. **Arma en la mano:**
   - `get_body_clip` y `holds_weapon_in_hand` en `SpinAbility`;
   - sacar `SwordSwing` de `begin`, `release` y `cancel_cast`;
   - mezcla de salida de clips en loop en `PlayerAnimator`.
   - Tests AC861–AC865 y adaptar `spin_test`.
5. **Corte del Giro:**
   - `get_dash_clip` en `AbilityBehavior`, `AbilityComponent` y `Player`, y `PlayerAnimator._play_dash`;
   - `extends_trail`/`trail_changed` y `WeaponTrail`;
   - sacar `sword_swing.play` del corte.
   - Tests AC866–AC868 y adaptar `spin_dash_slash_test` y `weapon_trail_test`.
6. **Vórtice:** `SpinVortexVfx` (área, pulso y polvo) en `spin_ability.tscn`, conectado desde `SpinAbility`. Tests AC869–AC871.
7. **Feedback de impacto:**
   - `camera`, `hitstop` y `animator` en `AbilityComponent` y `player.tscn`, y la asignación del `HitstopConfig` de la clase en `Player`;
   - sacudida y `apply_hitlag` en las vueltas y en el corte;
   - `PlayerAnimator.hold_dash_clip`.
   - Tests AC872–AC875.
8. **Cierre:**
   - suite completa, import y smoke test del menú y de la arena;
   - capturas del Giro en la arena;
   - checklist de la constitución en esta spec, estado **Implementada** y el próximo AC libre en `CLAUDE.md`.

   **Nota:** en esta sesión en la nube no está el Godot de Windows. Voy a intentar instalar un Godot 4.7.2 para Linux. Si no se puede, los pasos 3 y 8 (capturas, suite y smoke test) se corren en tu máquina.


## 11. Notas de implementación (cierre)

**Entorno de prueba.** Se corrió en la sesión en la nube con Godot 4.7.2 para Linux. Faltaban dos cosas del repo, que se usaron solo en la copia de trabajo:
- `addons/gdUnit4/bin/`: `.gitignore` excluye `bin/`; se tomó de gdUnit4 v6.2.0.
- Los `.uid`: también están en `.gitignore`, así que el import avisa "invalid UID" en recursos que ya existían. No es de esta spec.

Las capturas se hicieron con Forward+ sobre Vulkan por software (lavapipe, bajo Xvfb). El renderer de compatibilidad ignora `GeometryInstance3D.transparency` y muestra el área opaca, así que no sirve para revisar este VFX.

**Suite completa: base y con esta spec.**

| Corrida | Tests | Con falla |
|---|---|---|
| Base (`HEAD` antes de esta spec, con `-c` para no cortar en la primera falla) | 895 | 34 |
| Con esta spec | 913 (18 nuevos) | 35 |

- **Fallas nuevas: ninguna.** Las dos que aparecen solo en la corrida con la spec son inestables también en la base (fallan en corridas alternas aisladas, con y sin los cambios):
  - `attack_component_test` AC9;
  - `hitstop_test` AC619–AC621.
- **Arreglada por esta spec:** `spin_test` AC189. Verificaba la pose fija del mandoble (`blade_position`), que esta spec reemplaza. Se adaptó: ahora verifica el arma en la mano durante el giro y después, y toma el tiempo de la vuelta de los datos.
- **Fallas previas que siguen**, por datos retocados sin actualizar sus tests. Por ejemplo, `spin.tres` tiene `tick_interval` 0.8 y `cast_duration` 4, y los tests esperan 1.0 y 3. Esos tests verifican justamente esos números, así que no se adaptaron:
  - `spin_test` (6);
  - `spin_golden_upgrades_test` (4);
  - `spin_tornado_test` (4);
  - `air_slash_test` (5);
  - `buff_component_test` (1);
  - `weapon_reach_test` (2);
  - `weapon_trail_test` AC217;
  - `dash_cancel_test` (2);
  - `warrior_sword_and_shield_test` AC751;
  - `arena_waves_test`, `berserker_run_test`, `boss_challenge_run_test` (3), `samurai_run_test` y `upgrade_ban_run_test`.

  Corregirlas (los tests o los datos) es una decisión de balance del responsable.
- **AC878/AC879:** se cumplen como "sin fallas nuevas respecto de la base". La premisa de la spec (suites en verde antes del cambio) no era cierta.

**Tests adaptados** (sin cambiar lo que verifican):
- `spin_dash_slash_test` AC567 y AC573: el barrido lo dibuja el clip `spin_dash_slash`, no `SwordSwing` con arco y duración.
- `thrust_indicator_test`, `sheathe_test` AC250 y `swift_strike_test` AC79: el área es un solo relleno; su largo, ancho y centro reemplazan a los cuatro bordes.

**Diferencias con el diseño:**
- `SpinVortexVfx.follow(visual)` no recibe la punta de la hoja. El polvo sale de `dust_offset` (datos) en el espacio del jugador, y el vórtice sigue al `Visual` solo desde `begin()` hasta `finish()`.
- Se sumó la señal `pulsed`, para contar los pulsos en AC870.
- La pose del brazo derecho del giro (`SPIN_ARM`) salió de buscar la mano en (0.45, 1.0, −0.3) m y la hoja en (0.95, 0, −0.3), en el espacio del `Visual`.
- `spin_dash_slash` reutiliza `_sweep_front_cross()` (extraída del golpe 1, mismos valores) y `_sweep_left_hold()`.

**Observado en las capturas:** al empezar el Giro, la estela dibuja el paso del mandoble del hombro a la cintura (≈ 0.1 s), igual que en los golpes del combo, que también encienden la estela desde la anticipación. Se deja así.

### Review de la constitución (cierre)
- [x] **I:** combate. El Giro se lee: el cuerpo sostiene el arma, el área muestra el alcance real y cada vuelta marca su golpe.
- [x] **II:** primitivas (`CylinderMesh` y `BoxMesh` planos, `SphereMesh` en `CPUParticles3D`) con materiales `.tres` compartidos.
  - El área es blanca, con opacidad 0.25 en reposo y 0.45 en el pulso, según la enmienda 4.16.0.
  - El polvo usa el tierra registrado.
  - Sin shaders ni texturas.
- [x] **III:** clips, *hit lag* y sacudidas en `spin_config.tres`; el área, el pulso y el polvo en `spin_vortex_config.tres`; las transparencias de los indicadores en sus `.tres`. Sin literales de diseño en los scripts, y ningún Resource se muta en runtime.
- [x] **IV:** tipado completo. `_process` y `_physics_process` solo delegan (`advance`, `advance_dash_hold` y `update`).
- [x] **V:** el vórtice y el relleno se crean una vez en `_ready`. Por cuadro solo se copia una transformación y se asignan escala y transparencia, sin *allocations* ni búsquedas de nodos.
- [x] **VI:** sin input nuevo.
- [x] **VII:**
  - las vueltas no pausan al jugador (enmienda 4.16.0);
  - el Corte pausa solo su clip, una vez, y el dash conserva su recorrido, su duración y su invulnerabilidad (AC875);
  - no se toca `Engine.time_scale`.
- [x] **Calidad:** el proyecto importa sin errores nuevos. AC861–AC877 en verde y ninguna falla nueva en la suite completa (ver arriba).
