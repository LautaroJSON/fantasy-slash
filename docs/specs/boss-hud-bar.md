# Feature: Barra de vida de jefes fija en el HUD

- **Estado:** Implementada (2026-09-25, 244 tests GdUnit4 en verde, smoke tests headless del menú y de la arena limpios)
- **Constitución:** `docs/constitution.md` **v2.4.0** (sin enmienda: es UI 2D; los colores copian los de la barra 3D y los de `DebuffData.icon_material`)
- **Pilar (Principio I):** Combate. La vida del jefe se lee sin pelear contra la cámara: en el Coloso, la barra 3D quedaba a 5.5 m.
- **Dependencias:** `boss-challenge.md`, `crit-feedback.md`, `enemy-levels.md`, `combat-feedback.md`.

## 1. Objetivo

- Los enemigos con `EnemyStats.hud_health_bar = true` (Coloso y Gemelo) **no muestran su barra 3D**, ni la etiqueta de nivel ni los íconos de debuff sobre el cuerpo.
- Su vida se muestra en el **HUD, arriba al centro**, con una barra por jefe apilada: 1 para el Coloso, 2 para los Gemelos.
- Cada barra muestra:
  - el título `Coloso  lv. 2`;
  - la vida `384 / 480`;
  - la estela que se drena, con los mismos tiempos que la barra 3D;
  - la vibración con críticos o golpes de ≥ 1/3 de la vida, con el mismo umbral, duración y frecuencia;
  - los íconos de debuff, del color de `DebuffData.icon_material.albedo_color`.
- Cuando un jefe muere, su barra desaparece. En oleadas normales no hay barras de jefe.

## 2. Datos (Principio III)

- `EnemyStats`: + `display_name: String`, `hud_health_bar: bool`. Coloso: `"Coloso"`, `true`. Gemelo: `"Gemelo"`, `true`. Grunt: `""`, `false`.
- `BossBarConfig` (nuevo), en `data/ui/boss_bar_config.tres`:

| Campo | Valor |
|---|---|
| `max_bars` | 2 |
| `bar_size` | `Vector2(520, 18)` px |
| `spacing` | 6 px |
| `title_format` | `"%s  lv. %d"` |
| `health_format` | `"%d / %d"` |
| `fill_color` | `Color(0.85, 0.1, 0.1)` |
| `trail_color` | `Color(0.45, 0.03, 0.03)` |
| `background_color` | `Color(0.12, 0.08, 0.08)` |
| `shake_amplitude_px` | 6 |
| `debuff_icon_size_px` | 14 |
| `debuff_spacing_px` | 4 |
| `max_debuff_icons` | 4 |
| `health_bar_config` | → `enemy_health_bar_config.tres`: estela, umbral y vibración compartidos con la barra 3D |

## 3. Lógica compartida

- **`HealthTrail`** (`RefCounted`): estado de la estela, extraído de `EnemyHealthBar`.
  - `fill_ratio`, `trail_ratio` y `hold_left`.
  - `reset()`.
  - `on_health(current, maximum, config) -> bool`: devuelve `true` si el relleno bajó.
  - `advance(delta, config) -> bool`: devuelve `true` si la estela cambió.
- **`ShakeState`** (`RefCounted`): `start(duration)`, `advance(delta, config) -> float` (offset normalizado × decaimiento), `is_active()` y `stop()`.
- La barra 3D y la del HUD usan las dos clases, y el umbral sigue en `EnemyHealthBar.should_shake`.

## 4. Nodos e interfaz

- **`Enemy`:**
  - `signal hit_notified(applied, is_crit)`.
  - `notify_hit(applied, is_crit)`: reenvía el golpe a la barra 3D y emite la señal.
  - Si `hud_health_bar` está activo, llama `health_bar.set_suppressed(true)` una vez.
- **`EnemyHealthBar`:** `set_suppressed(value)`. Suprimida, nunca se muestra ni procesa.
- **`EnemyHitFeedback`:** llama `enemy.notify_hit(...)`.
- **`WaveManager`:** `signal boss_wave_started(bosses: Array[Enemy])`, emitida por `start_boss_wave`.
- **`BossHealthBar`** (`ui/boss_health_bar.tscn`): `setup(config)`, `track(enemy)`, `release()`, `get_tracked()`, `get_fill_ratio()`, `get_trail_ratio()`, `is_shaking()`, `get_bar_offset()`, `get_title_text()`, `get_health_text()`, `get_visible_debuff_count()`, `get_debuff_color(index)` y `advance(delta)`.
- **`BossBarStack`** (`VBoxContainer` en `hud.tscn`, arriba al centro, junto al `SandboxLabel`): pre-crea `max_bars` barras en `_ready`, con `show_bosses(bosses)`, `clear()` y `get_bar(index)`.
- **`Hud`:** `@export var wave_manager` y `@export var boss_bar_config`. Reenvía `boss_wave_started` al stack y lo vacía cuando `run_state` deja de estar en un desafío.

## 5. Criterios de aceptación

- **AC158** La barra 3D de un Coloso nunca se ve, ni siquiera tras un golpe. La de un grunt se comporta como antes.
- **AC159** Coloso: 1 barra visible con `Coloso  lv. 2` y `480 / 480`. Gemelos: 2 barras visibles.
- **AC160** Un golpe baja el relleno al instante. La estela se mantiene `trail_hold_time` y después se drena hasta el relleno.
- **AC161** Un crítico hace vibrar la barra del HUD. Al terminar, el desplazamiento vuelve a 0.
- **AC162** Un sangrado muestra 1 ícono del color de `bleed.tres`, que desaparece cuando se limpia el debuff.
- **AC163** Cuando un Gemelo muere, su barra se oculta y la otra sigue. Tras limpiar el desafío, no queda ninguna barra.
- **AC164** En una oleada normal no hay barras de jefe.
- **AC165** Regresión: la suite completa en verde. Los AC28–AC31 y AC141–AC144 pasan sin cambios.

### Notas de implementación

- **`BossHealthBar`:** es un `VBoxContainer` con `TitleLabel`, `BarFrame` y `DebuffIcons`. La barra (`BarFrame/Bar`) es hija de un `Control` que no la acomoda, así la vibración puede moverla en `position.x` sin que el contenedor la pise.
- **`BossBarStack`:** pre-instancia las barras de `ui/boss_health_bar.tscn` en `_ready`. `Hud` lo vacía en `_on_run_changed` cuando la oleada no es de jefe.
- **HUD:** `SandboxLabel` pasó a `TopCenter` (un `VBoxContainer` centrado arriba) junto a `BossBars`.
- **Tests existentes ajustados:** `sandbox_run_test.gd` (AC116) y `pause_menu_test.gd` (AC112) buscaban el label por su ruta vieja. Ahora lo buscan por nombre único (`%SandboxLabel`); verifican lo mismo que antes.
- **Tests nuevos:** `test/ui/boss_hud_bar_test.gd` (AC158–AC164).

### Review de la constitución (cierre, v2.4.0)
- **I:** Combate (legibilidad), como declara la spec.
- **II:** solo UI 2D. Los colores copian los materiales de la barra 3D y el `albedo_color` de cada `DebuffData.icon_material`, sin colores reservados nuevos. Los jefes siguen siendo cápsulas grises.
- **III:** tamaños, formatos, colores, amplitud e íconos viven en `BossBarConfig`. La estela y la vibración (tiempos y umbral) se comparten desde `HealthBarConfig`. `display_name` y `hud_health_bar` están en `EnemyStats`.
- **IV:** tipado completo y `_process` delgado (`advance`). La estela y la vibración se extrajeron a `HealthTrail` y `ShakeState` para no duplicar lógica.
- **V:** las barras y los íconos se crean una vez. `_process` solo corre con la barra visible y no alloca, y los textos se arman solo cuando cambia la vida o el objetivo.
- **VI:** sin inputs nuevos.
