# Feature: re-work visual del Giro

- **Estado:** Propuesta (2026-09-27). ACs **AC861–AC880**, reservados en `CLAUDE.md`. Se dejan libres AC801–AC860 para `warrior-abilities-rework.md`, que se escribe en paralelo en otra sesión.
- **Constitución:** `docs/constitution.md` v4.15.x. Propone una enmienda **MINOR** (§7).
- **Pilar (Principio I):** **combate.** El Giro es la habilidad del Berserker, pero hoy no se lee:
  - el cuerpo gira quieto en `idle`;
  - el mandoble flota lejos de la mano;
  - no se ve dónde llega el daño ni cuándo cae cada golpe.

  Con el cuerpo sosteniendo el arma, un área visible y un pulso por vuelta, el jugador sabe qué golpea y cuándo.
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
   - el arma queda en una pose fija del espacio del `Visual`, a la altura de la cadera y hacia la derecha;
   - la mano derecha sigue al hombro, y la izquierda no toma el mango (`left_grip` 0 en `idle`).
3. **El Corte del Giro flota.** `cast_cut_by_dash()` llama `SwordSwing.play(220°, 0.2 s)`. El cuerpo hace el clip `dash` con el arma al hombro, mientras el mandoble barre solo.
4. **No se ve el área.** El radio real es `HIT_RANGE` = 3.5 m más el radio del enemigo. La punta del mandoble llega a unos 2.8 m, así que se golpea a enemigos que la hoja no toca.
5. **No se ve el golpe.** El daño cae al **completar** cada vuelta (`_hit_completed_turns`). Nada marca ese momento: no hay *hit lag*, temblor del enemigo, sacudida de cámara, chispas ni pulso. Solo aparecen los números de daño y la sacudida de la barra de vida.
6. **Desfase de datos (fuera de alcance, §8).** La descripción de `spin.tres` dice "3 s", "Radio: 2.5 m" y "Enfriamiento: 9 s". Los valores efectivos son 4 s (`cast_duration`), 3.5 m (`hit_range`) y 9 s (`cooldown` 8 con piso `min_cooldown` 9).

## 2. Diseño

### 2.1 Clip `spin` del Berserker (el cuerpo gira con el arma)

Es un clip nuevo en `berserker_profile.gd`: **en loop, 0.5 s**, con dos pasos de arrastre de pies. El giro en sí lo sigue dando `SpinAbility` rotando el `Visual`, igual que hoy. El clip solo pone la pose y el pisoteo.

| t (s) | Pose | Qué pasa |
|---|---|---|
| 0.0 | **Giro, pie izquierdo apoyado** | Mandoble a **dos manos** (`_two_hands`, `left_grip` 1), brazos casi estirados hacia la derecha y un poco adelante. La hoja queda **horizontal, a la altura de la cintura (~1.0 m)** y apunta hacia afuera. El torso se inclina hacia el giro, con el peso bajo (`hips_pos` −0.18), y la cabeza mira por encima de la hoja. |
| 0.25 | **Giro, pie derecho apoyado** | La misma pose de brazos y torso, con las piernas cruzadas en el pisoteo (el pie de afuera empuja). La cadera sube 2 cm. |
| 0.5 | = t 0.0 | Loop. |

- **Sentido.** El `Visual` gira con yaw creciente (antihorario visto desde arriba). Con la hoja a la derecha, el filo va **adelante** en el giro.
- **La hoja no toca el piso** (se mide como AC751, para el mandoble) y **no atraviesa el torso**.
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
- `DashSlashVfx` (chispas y destello al final del dash) no cambia.

### 2.4 VFX nuevos: `SpinVortexVfx`

Es un nodo nuevo, hijo de `SpinAbility`: `top_level`, creado una vez en `_ready` y reutilizado (Principio V). Sigue al jugador cada cuadro (`follow(visual)`, una asignación sin *allocations*).

1. **Anillo de alcance en el piso.**
   - Es un anillo plano y fino (`TorusMesh` aplanado) de radio `HIT_RANGE`, con el celeste pálido de los indicadores de área (color no reservado), unshaded y translúcido.
   - Aparece con el Giro (fade in de `ring_fade_in`), se reescala si `HIT_RANGE` cambia con una mejora, y se desvanece al terminar (`ring_fade_out`).
   - Muestra **el área real** del daño.
2. **Pulso por vuelta.**
   - Al completar una vuelta (el instante del daño), el anillo **destella**: sube su opacidad hasta `pulse_alpha` y crece de `pulse_start_scale` a 1 en `pulse_duration`.
   - Pulsa aunque no haya enemigos: marca el ritmo del daño.
3. **Polvo bajo la hoja.**
   - Son `CPUParticles3D` con el material de polvo existente (`wind_dust_material.tres`, color tierra), que emiten sin parar desde un punto en el piso bajo la punta del mandoble.
   - Como el `Visual` gira, el polvo dibuja un remolino. Se apagan al terminar (dejan de emitir; las vivas terminan solas).
4. **Chispas de impacto.**
   - Hay un pool de `impact_pool_size` ráfagas one-shot (`CPUParticles3D` de `SphereMesh`, blanco aditivo, el material de `wind_cut_additive_material.tres`).
   - Por cada enemigo golpeado (vuelta o corte) se dispara una en la altura del pecho del enemigo, en la dirección tangente al giro.
   - Si el pool está lleno, se reutiliza la más vieja.

Todos los números viven en `SpinVortexConfig` (`data/abilities/spin/spin_vortex_config.tres`).

### 2.5 Feedback de impacto

- **Por vuelta que golpea al menos un enemigo:**
  - la cámara se sacude con `SpinConfig.turn_shake`;
  - cada enemigo golpeado tiembla y se congela (`Enemy.apply_hitlag`) `turn_hitlag` segundos, con la amplitud y la frecuencia del `HitstopConfig` de la clase (`berserker_hitstop.tres`). Los bosses solo tiemblan, igual que en el combo.
- **Por enemigo cortado en el Corte del Giro:** lo mismo, con `dash_slash_hitlag` y `dash_slash_shake`.
- **El jugador no se pausa.** El Giro es canalizado: pausar el clip o la rotación desfasaría las vueltas del daño (AC196/AC197). La excepción queda en la enmienda del Principio VII (§7).
- Lo hace `SpinAbility` al golpear, con referencias que ya tiene `AbilityComponent`: la cámara y el `HitstopConfig` se agregan como `@export` del componente. Es un mecanismo **solo del Giro**. El mecanismo genérico para todas las habilidades lo decide `warrior-abilities-rework.md` (§9, pregunta 2).

## 3. Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `resources/spin_config.gd` / `spin_config.tres` | **−** `blade_position`, `blade_rotation`, `dash_slash_arc_degrees`, `dash_slash_sweep_duration`. **+** `body_clip` (`&"spin"`), `dash_slash_body_clip` (`&"spin_dash_slash"`), `turn_hitlag` (0.06 s), `turn_shake` (0.15), `dash_slash_hitlag` (0.1 s), `dash_slash_shake` (0.35) |
| `resources/spin_vortex_config.gd` (nuevo) / `data/abilities/spin/spin_vortex_config.tres` | Anillo: `ring_thickness` 0.05 m, `ring_alpha` 0.25, `ring_fade_in` 0.15 s, `ring_fade_out` 0.25 s. Pulso: `pulse_alpha` 0.6, `pulse_start_scale` 0.85, `pulse_duration` 0.2 s. Polvo: `dust_amount` 24, `dust_lifetime` 0.5 s, `dust_size` 0.3, `dust_rise_speed` 0.8. Chispas: `impact_pool_size` 8, `spark_amount` 12, `spark_lifetime` 0.25 s, `spark_speed_min`/`max` 3 / 6, `spark_size` 0.05, `spark_height` 1.0 m |
| `materials/vfx/spin_ring_material.tres` (nuevo) | unshaded, transparencia alpha, celeste pálido (el mismo color que `attack_indicator_material.tres`) |
| `components/player_animator.gd` | Mezcla de salida también para clips de habilidad en loop (§2.1); clip del dash desde `Player.get_dash_clip()` (§2.3) |
| `entities/player/player.tscn` | `camera` y `hitstop` en `BasicAbility` y `UltimateAbility` |

Los valores iniciales son el punto de partida y se ajustan con capturas.

## 4. Estructura

```
SpinAbility (spin_ability.tscn)
├── DashSlash : DashSlashVfx            (sin cambios)
└── Vortex : SpinVortexVfx (Node3D, top_level)   config + ring/dust/glow materials
      ├── Ring : MeshInstance3D (TorusMesh)
      ├── Dust : CPUParticles3D
      └── 8 × Impact : CPUParticles3D (one-shot, pool)
```

## 5. Interfaz pública

- **`SpinVortexVfx`** (`components/abilities/spin_vortex_vfx.gd`):
  - `begin(visual: Node3D, radius: float)`, `follow(visual: Node3D, blade_tip: Vector3)`, `set_radius(radius: float)`;
  - `pulse()`, `burst(at: Vector3, direction: Vector3)`, `finish()`, `advance(delta: float)`;
  - para tests: `is_showing()`, `get_ring_radius()`, `get_ring_alpha()`, `get_impact_count()`, `get_active_impacts()`.
- **`AbilityBehavior`:** `get_dash_clip(ability) -> StringName` y `extends_trail(ability) -> bool`.
- **`AbilityComponent`:**
  - `@export var camera: ThirdPersonCamera` y `@export var hitstop: HitstopConfig`;
  - `get_dash_clip()`, `is_trailing()`, `notify_trail_changed()`;
  - `signal trail_changed`.
- **`Player`:** `get_dash_clip() -> StringName`.
- **`SpinAbility`:**
  - `get_body_clip()`, `holds_weapon_in_hand()`, `get_dash_clip()`, `extends_trail()`, `get_vortex()`;
  - llama `vortex.pulse()` en cada vuelta completada, y `burst()`, `camera.shake()` y `enemy.apply_hitlag()` al golpear.

## 6. Criterios de aceptación

- **AC861** El perfil del Berserker tiene `spin` (loop) y `spin_dash_slash` (sin loop). En todo cuadro de `spin`, `left_grip` es 1.
- **AC862** Mientras se castea el Giro, el humanoide reproduce `spin` y `Player.is_weapon_in_hand_cast()` es verdadero. Con `weapon_mount_blend` cumplido, el pivot del arma coincide con `WeaponMount.get_hand_pose()` (tolerancia 1 mm).
- **AC863** Durante el Giro, `SwordSwing` no está activo y `SpinConfig` no tiene `blade_position`, `blade_rotation`, `dash_slash_arc_degrees` ni `dash_slash_sweep_duration`.
- **AC864** En `spin`, muestreado cada 0.05 s: la hoja (base y punta del mandoble) queda entre 0.6 m y 1.4 m de altura, apunta hacia afuera (la punta está más lejos del eje del cuerpo que la mano) y no atraviesa el torso (mismo criterio que AC751).
- **AC865** Al terminar el Giro sin dash, la locomoción entra con `attack_exit_blend`. Sin moverse, el cuerpo termina en `idle`.
- **AC866** Si un dash corta el Giro, el humanoide reproduce `spin_dash_slash` estirado a la duración del dash, y el arma sigue la mano. Sin el Giro, el dash reproduce `DashData.clip` como hoy.
- **AC867** El último cuadro de `spin_dash_slash` es el primero de `sprint` (misma comparación que AC786).
- **AC868** La estela se enciende durante el Giro y durante el Corte del Giro, y se apaga cuando termina el corte.
- **AC869** El anillo del vórtice está oculto en reposo. Al empezar el Giro se muestra con radio `HIT_RANGE`, sigue al jugador y se desvanece al terminar en `ring_fade_out`. Con la mejora de radio, el anillo toma el nuevo `HIT_RANGE`.
- **AC870** Cada vuelta completada lanza exactamente un pulso, con o sin enemigos. Un Giro de 4 s con `TICK_INTERVAL` 0.8 pulsa 5 veces.
- **AC871** El polvo emite solo mientras se castea el Giro.
- **AC872** Cada enemigo golpeado (vuelta o corte) dispara una ráfaga de chispas. Con más golpes que `impact_pool_size` en una vuelta, se reutilizan las del pool: la cantidad de nodos no cambia.
- **AC873** Una vuelta que golpea sacude la cámara con `turn_shake`. Una que no golpea, no la sacude.
- **AC874** Un enemigo golpeado por una vuelta recibe `apply_hitlag(turn_hitlag, …)`, y uno cortado por el Corte del Giro, `apply_hitlag(dash_slash_hitlag, …)`, con la cámara sacudida por `dash_slash_shake`.
- **AC875** El clip del jugador y la rotación del `Visual` no se pausan al golpear. Las vueltas y el daño siguen los tiempos de AC196/AC197.
- **AC876** Regresión: `spin_test`, `spin_dash_slash_test`, `spin_golden_upgrades_test`, `spin_tornado_test`, `weapon_trail_test` y `player_animator_test` en verde. Los tests que verificaban `blade_position` o el barrido de `SwordSwing` se adaptan a la mano, sin cambiar lo que verifican.
- **AC877** Regresión: la suite completa en verde, y el smoke test del menú y de la arena sin errores ni warnings.

AC878–AC880 quedan de reserva para ajustes que salgan de las capturas.

## 7. Enmienda de la constitución (MINOR → 4.16.0)

- **Principio II, tabla de colores:** se agrega la fila **"Impactos del Giro (chispas por enemigo golpeado)"**: `SphereMesh`, partículas, **blanco** `Color(1, 1, 1)`, unshaded, blend aditivo, alpha ≤ 0.5. También se suma a la lista de elementos que comparten el blanco (translúcidos, décimas de segundo).
- **Principio II, registro de colores no reservados:** el anillo de alcance del Giro usa el celeste pálido de los indicadores de área.
- **Principio VII, hit lag local:** se agrega "**Las habilidades canalizadas** (p. ej. el Giro) comunican el impacto con el temblor de los golpeados y la sacudida de cámara, **sin pausar al jugador**, para no desfasar sus golpes periódicos."

## 8. Fuera de alcance

- La descripción desfasada de `spin.tres` (§1.6). Se puede corregir en esta spec si querés (§9, pregunta 3).
- El Tajo aéreo del Berserker (también tiene el cuerpo en `idle` y el arma suelta): va en otra spec.
- La Estocada y Swift Strike: los reemplaza `warrior-abilities-rework.md`.
- El feedback de impacto de Envainar.

## 9. Preguntas abiertas

1. **Pausa del jugador:** la propuesta es **no pausar** al jugador en el Giro (§2.5). ¿Querés además una micro-pausa solo en el Corte del Giro, que no es canalizado?
2. **Mecanismo genérico:** el feedback de impacto queda local al Giro para no chocar con la sesión del Guerrero, que tiene el mandato de un mecanismo genérico. ¿Lo dejo así y después se unifica, o esta spec construye el genérico y se lo avisamos a la otra sesión?
3. **Descripción:** ¿corrijo el texto de `spin.tres` a los valores reales (4 s, 3.5 m, 9 s), o los valores estaban mal y hay que corregir los datos?

## 10. Plan

1. **Datos y enmienda:** `SpinConfig` (quitar y agregar campos), `SpinVortexConfig` y su `.tres`, el material del anillo, y la enmienda 4.16.0 en `constitution.md`. Reservar AC861–AC880 en `CLAUDE.md`.
2. **Clips:**
   - `spin` y `spin_dash_slash` en `berserker_profile.gd`;
   - hoja de capturas (humanoide aislado, 4 ángulos, cada 0.05 s) para ajustar brazos y hoja hasta cumplir AC864 y AC867.
3. **Arma en la mano:**
   - `get_body_clip` y `holds_weapon_in_hand` en `SpinAbility`;
   - sacar `SwordSwing` de `begin`, `release` y `cancel_cast`;
   - mezcla de salida de clips en loop en `PlayerAnimator`.
   - Tests AC861–AC865 y adaptar `spin_test`.
4. **Corte del Giro:**
   - `get_dash_clip` en `AbilityBehavior`, `AbilityComponent` y `Player`, y `PlayerAnimator._play_dash`;
   - `extends_trail`/`trail_changed` y `WeaponTrail`;
   - sacar `sword_swing.play` del corte.
   - Tests AC866–AC868 y adaptar `spin_dash_slash_test` y `weapon_trail_test`.
5. **Vórtice:** `SpinVortexVfx` (anillo, pulso, polvo, pool de chispas) en `spin_ability.tscn`, conectado desde `SpinAbility`. Tests AC869–AC872.
6. **Feedback de impacto:**
   - `camera` y `hitstop` en `AbilityComponent` y `player.tscn`;
   - sacudida de cámara y `apply_hitlag` en `SpinAbility._strike` y en el corte.
   - Tests AC873–AC875.
7. **Cierre:**
   - suite completa, import y smoke test del menú y de la arena;
   - capturas del Giro en la arena;
   - checklist de la constitución en esta spec, estado **Implementada** y el próximo AC libre en `CLAUDE.md`.

   **Nota:** en esta sesión en la nube no está el Godot de Windows. Si no puedo instalar un Godot 4.7.2 para Linux acá, los pasos 2 y 7 (capturas, suite y smoke test) se corren en tu máquina.
