# Feature: Feedback de combate (barra de vida enemiga, números de daño, empuje)

- **Estado:** Implementada (2026-09-25, 86 tests GdUnit4 en verde)
- **Constitución:** `docs/constitution.md` v2.1.0 (enmienda de §0 aplicada).
- **Pilar (Principio I):** Combate. Hace legible cada golpe: cuánto daño hizo, si fue crítico y cuánta vida le queda al enemigo. El empuje da peso al impacto.
- **Dependencias:** `combat-mvp.md` (Implementada).

## 0. Enmienda y excepción previas

**Enmienda a la constitución → v2.1.0 (MINOR).** En la tabla de colores del Principio II se agrega una fila:

| Elemento | Malla base | Color |
|---|---|---|
| Números de daño flotantes | `TextMesh` | **Blanco**: `Color(1, 1, 1)` |

El texto de reserva pasa a decir que el blanco se comparte únicamente entre el cuerpo del jugador y los números de daño. Siguen siendo distinguibles: una cápsula frente a un texto efímero.

**Excepción al Principio III: empuje fijo, no mejorable.**
- **Principio afectado:** III. Los valores de gameplay del jugador deben ser stats mejorables.
- **Motivo:** decisión del responsable. El empuje es sensación de golpe (*game feel*), no un eje de build.
- **Alternativa descartada:** `KNOCKBACK` como stat 16 con carta de mejora.
- **Alcance:** solo `PlayerTuning.knockback_speed`. El valor vive en `.tres`, no en código.
- **Revisión:** al diseñar builds de control o al cerrar el prototipo.

## 1. Objetivo

1. **Barra de vida enemiga** sobre la cabeza, estilo LoL:
   - Aparece recién con el primer daño.
   - Al recibir un golpe, el relleno rojo baja al instante.
   - El tramo perdido queda un momento en **rojo oscuro** ("trail") y después se consume hasta alcanzar el relleno.
2. **Números de daño** flotantes, en blanco:
   - Muestran el daño aplicado.
   - Un crítico sale **más grande** (`crit_scale`). No hay negrita: ver la nota de §2.2.
   - Suben y se desvanecen.
3. **Empuje**: cada golpe del jugador hace retroceder un poco al enemigo.
4. **Cambio de regla del enemigo:** fuera de rango, su timer de ataque se **congela** en vez de reiniciarse. Así el empuje retrasa su golpe pero no lo anula. Reemplaza la regla correspondiente de `combat-mvp.md` §3.8.

## 2. Estructura

### 2.1 Archivos nuevos

```
res://
├── resources/
│   ├── health_bar_config.gd        # HealthBarConfig
│   └── damage_number_config.gd     # DamageNumberConfig
├── data/ui/
│   ├── enemy_health_bar_config.tres
│   └── damage_number_config.tres
├── materials/
│   ├── health_bar_background_material.tres  # Color(0.12, 0.08, 0.08), unshaded
│   ├── health_bar_trail_material.tres       # Color(0.45, 0.03, 0.03), rojo oscuro, unshaded
│   ├── health_bar_fill_material.tres        # Color(0.85, 0.10, 0.10), rojo, unshaded
│   └── damage_number_material.tres          # Color(1, 1, 1), unshaded, billboard
├── components/enemy_health_bar.tscn + .gd  # EnemyHealthBar
└── effects/
    ├── damage_number.gd            # DamageNumber (MeshInstance3D + TextMesh)
    └── damage_number_pool.gd       # DamageNumberPool
```

Todo es una primitiva (`QuadMesh`, `TextMesh`) con `StandardMaterial3D`. La fuente es la fuente por defecto del motor, sin archivos externos. Los materiales de la barra y de los números usan `no_depth_test`, así se ven siempre, y `render_priority` para ordenarse: fondo < trail < relleno < números.

### 2.2 Datos (Principio III)

| Resource | Campos y valores iniciales |
|---|---|
| `HealthBarConfig` | `size (1.0, 0.12)` m · `height_offset 2.2` m · `trail_hold_time 0.4` s · `trail_drain_speed 1.5` (fracción de la barra por segundo) |
| `DamageNumberConfig` | `pool_size 24` · `lifetime 0.7` s · `rise_speed 1.6` m/s · `spawn_height 2.4` m · `spread 0.35` m (desvío horizontal aleatorio) · `font_size 64` · `pixel_size 0.006` · `crit_scale 1.5` · `fade_start 0.55` (fracción de la vida en la que empieza a desvanecerse) |
| `PlayerTuning` (+campo) | `knockback_speed 5.0` m/s (excepción §0) |
| `EnemyStats` (+campo) | `knockback_friction 20.0` m/s². Retroceso ≈ 5² / (2·20) ≈ **0.6 m** en 0.25 s |


> **Nota de implementación (decisión del responsable, 2026-09-25):** la negrita se planeó con `FontVariation.variation_embolden`, pero `TextMesh` no puede triangular glifos engrosados: con cualquier embolden > 0 el "4" (y con 1.2 también 3, 8 y 9) queda sin geometría. Opciones evaluadas: negrita simulada con copias desplazadas, `Label3D` (requería otra enmienda) o sin negrita. **Se eligió sin negrita.** El crítico se distingue solo por el tamaño, y `crit_scale` pasó de 1.35 a 1.5. Un test de regresión verifica que todos los dígitos tengan geometría.

### 2.3 Escenas

**`enemy_health_bar.tscn`** (hija de `enemy.tscn`, `health` → `../HealthComponent`)
```
HealthBar (Node3D) — enemy_health_bar.gd; rota para mirar a la cámara
├── Background (MeshInstance3D)  QuadMesh 1×1, escalado a size
├── Trail (MeshInstance3D)       anclado a la izquierda
└── Fill (MeshInstance3D)        anclado a la izquierda
```

**`arena.tscn`** agrega `DamageNumberPool` (Node3D), con `player` → `Player` y los recursos de §2.2.

## 3. Interfaz pública

### 3.1 `EnemyHealthBar` (Node3D)
- `@export health: HealthComponent, config: HealthBarConfig`
- `reset() -> void`: oculta la barra, pone relleno y trail al 100 % y desactiva `_process`. Lo llama `Enemy.activate()`, así un enemigo reciclado del pool no arrastra estado.
- `advance(delta: float) -> void`: avanza la espera y el consumo del trail. Lo llama `_process` y también los tests.
- `get_fill_ratio() -> float` · `get_trail_ratio() -> float`
- Por frame, solo mientras está visible: copia `global_basis` de la cámara (mira a cámara) y avanza el trail. No hay allocations.

### 3.2 `DamageNumber` (MeshInstance3D)
- Cada instancia tiene su propio `TextMesh` (`depth 0`), creado una sola vez al armar el pool.
- `setup(config, material)`: la llama el pool una vez por instancia.
- `show_damage(amount: float, is_crit: bool, at: Vector3) -> void`:
  - texto = `roundi(amount)`
  - escala 1 o `crit_scale`
  - visible, y arranca el `_process`
- Por frame: sube `rise_speed × delta`. Desde `fade_start` sube `transparency` (propiedad por instancia, sin duplicar material) hasta 1. Al terminar `lifetime` se oculta y emite `finished(self)`.
- `advance(delta)` (la llama `_process` y también los tests) · `is_active() -> bool` · `is_crit() -> bool` · `get_text() -> String`

### 3.3 `DamageNumberPool` (Node3D)
- `@export player: Player, config: DamageNumberConfig, material: StandardMaterial3D`
- `get_last_spawned() -> DamageNumber` (para tests)
- En `_ready` crea `pool_size` instancias ocultas y se conecta a `player.attack.enemy_hit`.
- `spawn(amount: float, is_crit: bool, at: Vector3) -> void`: toma una instancia libre. Si no hay ninguna, **recicla la más antigua**, así un golpe nunca queda sin feedback.
- `active_count() -> int`

### 3.4 Cambios en código existente
| Clase | Cambio |
|---|---|
| `AttackComponent` | Nueva señal `enemy_hit(enemy: Enemy, applied: float, is_crit: bool)`, una por enemigo golpeado. Tras cada golpe llama `enemy.apply_knockback(dirección jugador→enemigo, tuning.knockback_speed)`. |
| `Player` | Expone `attack: AttackComponent`. |
| `Enemy` | `apply_knockback(direction: Vector3, speed: float) -> void`. Mientras dura el empuje: velocidad horizontal = empuje, que se frena con `knockback_friction`; no persigue ni ataca, y el timer queda en pausa. `activate()` resetea el empuje y llama `health_bar.reset()`. **El timer de ataque ya no se reinicia al salir de rango: se congela.** |

## 4. Lógica de estado

**Barra (por golpe)**
```
health_changed(current, max) → ratio = current / max
  ratio < fill:  fill = ratio (al instante) · trail se queda donde está · hold = trail_hold_time · mostrar barra
  cada frame:    si hold > 0 → hold -= delta
                 si no → trail = max(trail − drain_speed·delta, fill)
```
Un segundo golpe durante el consumo baja el relleno y reinicia la espera. El trail sigue desde donde estaba.

**Enemigo**
```
empujado (|knockback| > 0) → mover con knockback, frenar, timer en pausa
fuera de rango             → perseguir, timer en pausa (NO se reinicia)
en rango                   → quieto, timer += delta, golpea al llegar a attack_interval
```

## 5. Criterios de aceptación

**Barra de vida**
- **AC28** Al activarse, un enemigo tiene la barra oculta con relleno y trail en 1.0. Tras un golpe de 15 (vida 40), la barra es visible, relleno = 0.625 y trail = 1.0.
- **AC29** Tras ese golpe, antes de `trail_hold_time` el trail sigue en 1.0. Después se consume hasta 0.625 y nunca queda por debajo del relleno.
- **AC30** Un segundo golpe mientras el trail se consume baja el relleno a 0.25. El trail conserva el valor que tenía en ese momento y la espera se reinicia.
- **AC31** Un enemigo que muere y vuelve del pool reaparece con la barra oculta y llena.

**Números de daño**
- **AC32** Un golpe normal de 15 activa un número con texto "15", no crítico, escala 1, sobre el enemigo (y ≈ `spawn_height`).
- **AC33** Un golpe crítico (22.5) muestra "23" con escala `crit_scale`. Regresión: los dígitos 0-9 generan geometría.
- **AC34** Tras `lifetime` el número queda inactivo y vuelve al pool. Durante su vida, `transparency` es 0 antes de `fade_start` y mayor a 0 después.
- **AC35** Con el pool lleno, un golpe nuevo recicla el número más antiguo: `active_count()` nunca supera `pool_size` y ningún golpe queda sin número.

**Empuje y timer**
- **AC36** Un golpe a un enemigo a 1.5 m lo aleja en la dirección jugador→enemigo entre 0.5 y 0.75 m. Después vuelve a perseguir.
- **AC37** Timer congelado: un enemigo acumula 0.6 s en rango y es empujado fuera de rango. **No** golpea antes de 1.15 s y **sí** golpea antes de 1.6 s. Con la regla vieja de reinicio golpearía recién a ~1.9 s.
- **AC38** Regresión: AC13 (golpes a 1.0 s y 2.0 s en rango, persecución) sigue en verde.

*Manual:* la barra mira siempre a la cámara, el trail rojo oscuro se nota, los críticos se distinguen y el retroceso se siente.

## 6. Plan de implementación

1. **Enmienda:** `docs/constitution.md` → v2.1.0 (fila de color, texto de reserva e historial). Se actualiza la regla del timer en `combat-mvp.md` §3.8.
2. **Datos:** scripts `HealthBarConfig` y `DamageNumberConfig`, campos nuevos en `PlayerTuning` y `EnemyStats`, `.tres`, materiales y `FontVariation`.
3. **Empuje y timer:** tests AC36-AC37 → `Enemy.apply_knockback` y timer congelado → `AttackComponent.enemy_hit` y empuje → AC38 (suite completa).
4. **Barra:** tests AC28-AC31 → `EnemyHealthBar` + escena → integrar en `enemy.tscn` y `Enemy.activate()`.
5. **Números:** tests AC32-AC35 → `DamageNumber` + `DamageNumberPool` → integrar en `arena.tscn`.
6. **Cierre:** suite completa en verde, smoke test de la arena, checklist de la constitución, spec **Implementada**. **Avisar.**

## 7. Fuera de alcance

- Números de daño recibido por el jugador y números de curación.
- Barra de vida del jugador en 3D (ya está en el HUD).
- Flash de color o "hit stop" en el enemigo golpeado.
- Resistencia al empuje por tipo de enemigo (hay un solo tipo).
