# Feature: Tajo aéreo del Berserker

- **Estado:** Implementada (2026-09-26; `air_slash_test` 14/14, 0 orphans; regresión AC589 sin fallos nuevos, ver §9; smoke test sin errores ni warnings; suite completa no corrida, a pedido del usuario). ACs: AC578–AC589.
- **Constitución:** `docs/constitution.md` v4.7.0 → **v4.8.0** (enmienda MINOR aplicada, §7).
- **Pilares (Principio I):**
  - **Combate:** el salto del Berserker pasa a ser un ataque. Suspendido en el aire, el jugador elige cuánto cargar y dónde caer, con un aviso en el piso. El golpe es un riesgo, porque suspendido no puede esquivar, y a la vez un premio, porque un golpe cargado pega fuerte en una franja. Se inspira en la ultimate de Vendetta en Overwatch.
  - **Progresión:** el daño sale del ataque básico, así que las cartas de daño, bonus, crítico y robo de vida del personaje lo mejoran.
- **Dependencias:** `berserker.md`, `sword-sweep.md`, `wind-cut-v.md` y `thrust-indicator.md` (Implementadas).
- **Tests:** solo los de esta spec y los de specs directamente tocadas (ver §8). La suite completa no se corre salvo que el usuario la pida.

## 1. Objetivo

### 1.1 Comportamiento

- **Solo el Berserker:** su clase declara un `AirSlashConfig`. El Guerrero y el Samurái no tienen uno y siguen atacando normal en el aire.
- **Empezar:** en el aire (sin tocar el piso), apretar o mantener el **click izquierdo** (`attack`) no hace el barrido normal, sino que empieza el tajo aéreo. Se puede **una vez por salto**: se habilita de nuevo al tocar el piso. No hay otro enfriamiento.
- **Suspensión:**
  - Mientras se mantiene el click, hasta `hover_duration` (**2 s**), el Berserker queda **suspendido**: la velocidad vertical es 0 y la gravedad no actúa.
  - Se mueve **muy lento**: `MOVE_SPEED × hover_move_speed_factor` (0.15), y gira hacia donde se mueve.
  - **Pose:** la espada va arriba de la cabeza y hacia atrás (`raise_position` / `raise_rotation`).
  - **Aviso en el piso:** un rectángulo marca la franja que va a golpear (misma pieza que la Estocada, `AbilityRectIndicator`), siguiendo la posición y el frente del jugador.
- **Carga:** el daño crece con el tiempo suspendido, de **×1.5** del ataque básico al soltar enseguida a **×3.5** a los 2 s. El crecimiento es lineal: `lerp(min_damage_factor, max_damage_factor, tiempo / hover_duration)`.
- **Soltar** el click, o llegar a los 2 s, arranca la **picada**:
  - cae a `dive_speed` (**20 m/s**), sin moverse de costado;
  - la espada hace el **tajo descendente**: pasa de la pose alzada a la de golpe (`slam_position` / `slam_rotation`) en `slam_duration`, con la estela del arma.
- **Impacto al tocar el piso:**
  - cada enemigo dentro de la **franja al frente** (`hit_length` 4 m × `hit_width` 2 m, desde los pies del jugador, más el radio del enemigo) recibe el golpe;
  - empuje hacia afuera a `knockback_speed`;
  - **corte de viento** en V a lo largo de la franja (el mismo efecto que Envainar, con su propio config y la altura escalada por la carga);
  - sacudida de cámara.

  Si no toca el piso en `max_dive_duration` (1 s, por ejemplo al caer al vacío), el golpe se aplica igual en ese momento.
- **Daño por enemigo:** es el del ataque básico, `DamageMath.outgoing(DAMAGE, DAMAGE_BONUS, crítico, CRIT_DAMAGE)`, multiplicado por el factor de carga.
  - Un solo tiro de crítico con `CRIT_CHANCE`, como el barrido.
  - Roba vida con `LIFESTEAL` sobre el total aplicado.
- **Aterrizaje:** después del golpe, `landing_lock` (**0.25 s**) sin moverse ni actuar, mientras la espada vuelve al reposo.
- **Mientras dura (suspensión, picada y aterrizaje)** no se puede atacar, saltar, dashear ni usar habilidades. Recibe daño normal, sin invulnerabilidad.
- **Agarre de un boss** (`begin_hold`) durante la suspensión o la picada: el tajo se cancela sin golpe, el aviso se apaga, la espada vuelve al reposo y cae con gravedad normal.

### 1.2 Nombre

- Propuesto: **"Tajo aéreo"**. Alternativas: "Caída del Verdugo", "Juicio".

## 2. Estructura

### 2.1 Datos (Principio III)

| Archivo | Contenido |
|---|---|
| `resources/air_slash_config.gd` (nuevo) | `hover_duration`, `hover_move_speed_factor`, `min_damage_factor`, `max_damage_factor`, `dive_speed`, `max_dive_duration`, `hit_length`, `hit_width`, `knockback_speed`, `landing_lock`, `raise_position`, `raise_rotation`, `slam_position`, `slam_rotation`, `slam_duration`, `impact_shake`, `indicator: AbilityIndicatorConfig` y `wind_cut: WindCutConfig` |
| `data/classes/berserker/air_slash_config.tres` (nuevo) | 2 s · 0.15 · ×1.5 → ×3.5 · 20 m/s · 1 s · 4 × 2 m · empuje 5 m/s · 0.25 s · pose alzada `(0, 1.9, 0.35)` / `(1.2, 0, 0)` rad · pose de golpe `(0, 0.9, -0.5)` / `(-1.3, 0, 0)` rad · 0.12 s · shake 0.4 |
| `data/classes/berserker/air_slash_indicator_config.tres` (nuevo) | copia de los valores de `thrust_indicator_config.tres` |
| `data/classes/berserker/air_slash_wind_cut_config.tres` (nuevo) | copia de `wind_cut_config.tres`, con altura máxima 1.6 m |
| `resources/character_class_data.gd` | `+ @export var air_slash: AirSlashConfig` (null = sin tajo aéreo) |
| `data/classes/berserker/berserker.tres` | `air_slash = air_slash_config.tres` |

- **Stats fijos por diseño (Principio III, 3.1.1):** la duración, los factores, el tamaño de la franja y las velocidades del tajo no tienen carta. El daño sí sube con las cartas del personaje (daño, bonus, crítico, robo de vida).
- Las poses son valores de partida. Se ajustan mirando las capturas durante la implementación.

### 2.2 Nodos

```
Player (player.tscn)
└── AirSlash : AirSlashComponent (Node)        body, visual, stats, health, movement, sword_swing,
      │                                          registry (lo asigna Player), camera
      ├── Indicator : AbilityRectIndicator (top_level)   material del indicador (celeste pálido)
      └── WindCut : WindCutVfx (top_level)                wind_cut_additive / wind_dust materials
```

## 3. Interfaz pública

- **`AirSlashComponent`**
  - `enum Phase { IDLE, HOVER, DIVE, LANDING }`.
  - `setup(config: AirSlashConfig)`: lo llama `Player` al aplicar la clase. Con null queda deshabilitado.
  - `try_start() -> bool`: habilitado, en el aire, en IDLE y sin haberlo usado en este salto. Empieza la suspensión: pose alzada y aviso visible.
  - `release()`: de HOVER a DIVE, congela la carga y arranca el tajo de la espada.
  - `cancel()`: vuelve a IDLE sin golpe (agarre).
  - `is_active() -> bool`: fase distinta de IDLE.
  - `controls_motion() -> bool`: HOVER, DIVE o LANDING.
  - `move_body(delta, wish_direction)`: mueve el cuerpo según la fase, avanza los tiempos y dispara la picada, el impacto y el fin del aterrizaje. Lo llama `Player` por cada paso de física.
  - `get_phase()`, `get_charge_ratio()` (0–1), `get_damage_factor()` e `is_used_this_jump()`.
  - `get_indicator()` y `get_wind_cut()`.
  - `strike_with_roll(crit_roll)`: el golpe con tiro inyectado, para tests.
  - `signal struck(hit_count: int, total_damage: float, was_crit: bool)`.
- **`SwordSwing.swing_to(target_position, target_rotation, duration)`** (nuevo): lleva el arma de la pose actual a la pose objetivo en fase SWING (la estela emite) y después vuelve al reposo como siempre. Es el tajo descendente.
- **`Player`**
  - `_handle_air_slash()` corre antes que `_handle_attack()`:
    - si el tajo está en IDLE, se aprieta `attack`, no está en el piso, no está casteando ni dasheando y `try_start()` tiene éxito, ese cuadro no hay barrido;
    - si está en HOVER y `attack` no está apretado, `release()`.
  - `is_casting()` también es verdadero con `air_slash.is_active()`. Eso bloquea el salto, el ataque y el movimiento normal.
  - `_can_dash()` es falso con el tajo activo, y `_handle_abilities()` no lanza habilidades con el tajo activo.
  - `_handle_movement()`: si `air_slash.controls_motion()`, llama `air_slash.move_body()`.
  - `begin_hold()` llama `air_slash.cancel()`.

## 4. Lógica interna

- **HOVER:**
  - `velocity = horizontal lenta + (0, 0, 0)` y `move_and_slide()`;
  - gira el `Visual` como `MovementComponent`;
  - acumula el tiempo;
  - el aviso sigue al jugador: `show_rect(pies proyectados al piso, yaw, hit_length, hit_width)`, reutilizando `AbilityRectIndicator`.

  A los `hover_duration` segundos pasa sola a DIVE.
- **DIVE:** `velocity = (0, −dive_speed, 0)`. Al quedar `is_on_floor()`, o al pasar `max_dive_duration`, golpea (`_strike`), dispara el corte de viento en los pies (yaw del `Visual`, largo `hit_length`, factor = carga), sacude la cámara, desvanece el aviso y pasa a LANDING.
- **LANDING:** `movement.hold(delta)` durante `landing_lock`. Después pasa a IDLE.
- **"Una vez por salto":** `_used_this_jump` se pone en true en `try_start()`, y se limpia en `move_body`/`advance` al estar en IDLE y en el piso.
- **Rendimiento (Principio V):** `_hit_buffer` es un miembro que se reutiliza. El aviso y el corte de viento se crean una vez. Por frame solo hay asignaciones.

## 5. Criterios de aceptación

- **AC578** `air_slash_config.tres` tiene los valores de §2.1. `berserker.tres` lo referencia, y `warrior.tres` y `samurai.tres` tienen `air_slash` null.
- **AC579** Berserker en el aire, al apretar `attack`:
  - entra en HOVER y no hay barrido normal (`attacked` no se emite);
  - la velocidad vertical queda en 0 y la altura no cambia (±0.02 m) durante 1 s;
  - la espada está en la pose alzada y el aviso se ve.
- **AC580** Suspendido con input de movimiento, la velocidad horizontal es `MOVE_SPEED × 0.15` (±5 %).
- **AC581** Carga:
  - soltar enseguida da factor 1.5;
  - soltar a 1 s da 2.5;
  - mantener 2 s pasa solo a DIVE con 3.5.

  Al tocar el piso, un enemigo en la franja pierde `outgoing(...) × factor` (sin crítico en el test).
- **AC582** Un enemigo dentro de la franja (al frente, a menos de `hit_length` más su radio y dentro de `hit_width / 2` más su radio) recibe el golpe. Uno detrás o al costado, fuera de la franja, no.
- **AC583** Con tiro de crítico favorable, el daño es × (1 + CRIT_DAMAGE) y se reporta `was_crit`. Con `LIFESTEAL`, cura el total aplicado × LIFESTEAL. Los enemigos golpeados se alejan a `knockback_speed`.
- **AC584** Una vez por salto: después de aterrizar, apretar `attack` en el piso hace el barrido normal, y en el mismo salto no se puede empezar otro tajo aéreo. Después de un nuevo salto, sí.
- **AC585** Durante HOVER, DIVE y LANDING no se puede dashear, saltar, atacar ni lanzar una habilidad. En LANDING el jugador queda quieto `landing_lock` segundos.
- **AC586** Guerrero y Samurái en el aire: `attack` hace el barrido normal y no hay tajo aéreo.
- **AC587** Efectos:
  - al soltar, `SwordSwing.is_swinging()` y la estela emite;
  - al impactar, el corte de viento se reproduce en los pies, con la altura escalada por la carga;
  - la cámara recibe una sacudida de `impact_shake`;
  - el aviso se desvanece.
  - Tras dos tajos, el aviso y el corte de viento son los mismos nodos.
- **AC588** `begin_hold` durante HOVER: el tajo vuelve a IDLE sin golpe, el aviso se apaga y el jugador cae con gravedad.
- **AC589** Regresión: pasan los tests de `attack_component_test`, `sword_swing_test`, `spin_test`, `spin_dash_slash_test` y `dash_cancel_test`, y import y smoke test no dan errores ni warnings.

## 6. Tests que pueden necesitar adaptación

- Si algún test de clase o de ataque asumía que el Berserker hace el barrido normal en el aire, se adapta y se anota acá.

## 7. Enmienda propuesta: constitución v4.8.0 (MINOR)

- **Principio II, tabla de colores:** la fila del corte de viento pasa a decir "Corte de viento (VFX de Envainar y del Tajo aéreo del Berserker)". Mismo efecto y mismos colores.
- El aviso en el piso usa el celeste pálido no reservado de los indicadores de área, ya registrado. No hay colores nuevos.

## 8. Plan

1. **Reservar ACs:** AC578–AC589 en `CLAUDE.md` (próximo libre → AC590).
2. **Datos:** `AirSlashConfig` y sus `.tres`, y `CharacterClassData.air_slash` en `berserker.tres`.
3. **Espada:** `SwordSwing.swing_to()` y su test.
4. **Componente:** `AirSlashComponent` (fases, suspensión, picada, golpe, aterrizaje, aviso y corte de viento) y su nodo en `player.tscn`.
5. **Integración en `Player`:** `_handle_air_slash`, bloqueos, movimiento y `begin_hold`.
6. **Tests:** AC578–AC588 en `test/components/air_slash_test.gd`, y AC589 con los archivos listados. No se corre la suite completa.
7. **Cierre:**
   - Capturas de la pose alzada, la picada y el impacto, para ajustar las poses.
   - Enmienda v4.8.0.
   - Smoke test.
   - Review de la constitución, estado Implementada y `CLAUDE.md`.

## 9. Notas de implementación

- **Configs en los nodos:** el aviso y el corte de viento llevan su config en los nodos `AirSlash/Indicator` y `AirSlash/WindCut` de `player.tscn` (`air_slash_indicator_config.tres` y `air_slash_wind_cut_config.tres`). Se sacaron de `AirSlashConfig` para no referenciarlos dos veces.
- **`MovementComponent.hover_move()`** (nuevo): movimiento horizontal con aceleración y giro, pero sin gravedad ni velocidad vertical. Lo usa la suspensión.
- **Piso:** `AirSlashComponent` guarda la altura del piso y habilita otro tajo en su propio `_physics_process` (`track_floor()`), solo en IDLE y apoyado. El aviso se dibuja a esa altura, sin raycasts.
- **Números de daño y feedback:** `DamageNumberPool` y `EnemyHitFeedback` también escuchan `player.air_slash.enemy_hit`. El golpe emite `attack_performed` en `Player`, igual que el barrido.
- **Poses ajustadas con capturas:**
  - pose alzada `(0, 1.8, 0.25)` / `(2.3, 0, 0)` rad: con 1.2 rad la hoja apuntaba arriba y adelante, y con más de π/2 queda arriba y atrás;
  - el destello del corte de viento del tajo baja de 1.4 m a 0.8 m.
  - Al impactar, la estela del arma dibuja el arco de la picada desde arriba hasta el frente.
- **Regresión AC589:** pasan `attack_component_test`, `sword_swing_test`, `spin_dash_slash_test`, `dash_cancel_test`, `damage_number_pool_test`, `enemy_hit_feedback_test` y `movement_component_test`. En `spin_test` fallan AC188, un fallo previo ajeno ya registrado, y AC192. AC192 falla por la misma causa (el Giro con `base_damage` 100 mata al grunt de 40 en el primer golpe) y antes no se veía porque GdUnit corta el archivo en el primer fallo. Esta spec no toca el Giro.

## 10. Review de la constitución (cierre)

- [x] **I:** Combate (salto como ataque con riesgo, carga y elección del lugar, con aviso) y Progresión (el daño sale del ataque básico), como declara la spec.
- [x] **II:** el aviso reutiliza `AbilityRectIndicator` (celeste pálido, ya registrado) y el impacto reutiliza `WindCutVfx` con sus materiales compartidos (enmienda v4.8.0). Sin shaders, texturas ni colores nuevos.
- [x] **III:** todos los valores del tajo viven en `air_slash_config.tres` y sus configs de efecto. `CharacterClassData.air_slash` es un dato de la clase. Stats fijos por diseño declarados en §2.1.
- [x] **IV:** tipado completo. `AirSlashComponent._physics_process` solo delega en `track_floor()`, y `Player._physics_process` suma una llamada con nombre (`_handle_air_slash`).
- [x] **V:** aviso y corte de viento creados una vez y reutilizados (AC587). `_hit_buffer` es un miembro que se limpia. Sin raycasts ni búsquedas por frame.
- [x] **VI:** solo la acción `attack` del InputMap (click izquierdo o su binding de mando).
- [x] **Calidad:** tests de la spec en verde, import y smoke test sin errores ni warnings, y regresión sin fallos nuevos.
