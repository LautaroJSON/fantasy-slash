# Feature: salto más alto y altura mínima del Tajo aéreo

- **Estado:** Propuesta (pendiente de aprobación). ACs reservados: AC599–AC603. AC590–AC598 los tiene `samurai-air-strike.md`, en curso en paralelo.
- **Constitución:** `docs/constitution.md` v4.8.0 (sin enmienda).
- **Pilares (Principio I):**
  - **Combate:** saltar más alto da más tiempo en el aire para posicionarse y para los golpes aéreos.
  - Con la altura mínima, el tajo aéreo del Berserker es una decisión (saltar y cargar desde arriba) y no algo que salga sin querer con un salto corto.
- **Dependencias:** `berserker-air-slash.md` (Implementada).
- **Tests:** solo los de esta spec y los que tocan el salto (ver §5). La suite completa no se corre salvo que el usuario la pida.

## 1. Objetivo

### 1.1 Salto

- **`jump_velocity`** pasa de **4.5 a 6.0 m/s** en las tres clases (`warrior_stats`, `berserker_stats` y `samurai_stats`).
- Con la gravedad por defecto (9.8 m/s²), la altura máxima sube de ~1.03 m a **~1.84 m**, y el tiempo en el aire de ~0.92 s a **~1.22 s**.
- Sigue siendo un stat fijo por diseño, sin carta.

### 1.2 Altura mínima del tajo aéreo

- El Berserker solo puede **empezar** el tajo aéreo con los pies a **`min_height` (1.0 m) o más** sobre el piso desde el que saltó. Es un dato nuevo de `AirSlashConfig`.
- **Por debajo de esa altura:** el click izquierdo hace el **barrido normal**, igual que en el piso.
- **Si se mantiene el click mientras sube:** al cruzar 1 m, el tajo aéreo empieza solo (el barrido en curso se corta, porque el tajo toma la espada).
- Con el salto nuevo, el jugador pasa ~0.83 s por encima de 1 m en cada salto.
- Todo lo demás del tajo sigue igual: una vez por salto, carga, picada e impacto.

## 2. Diseño

- **Datos:**
  - `jump_velocity = 6.0` en los tres `<clase>_stats.tres`;
  - `AirSlashConfig`: `+ @export var min_height: float` (grupo Hover);
  - `air_slash_config.tres`: `min_height = 1.0`.
- **`AirSlashComponent`**
  - `+ get_height_above_ground() -> float`: `body.global_position.y − _ground_y`. `_ground_y` ya lo guarda `track_floor()`.
  - `try_start()` suma la condición `get_height_above_ground() >= _config.min_height`.
- **`Player`:** sin cambios. `_handle_air_slash()` ya reintenta cada cuadro mientras se mantiene el click, y si el tajo no empieza, `_handle_attack()` hace el barrido normal.

## 3. Criterios de aceptación

- **AC599** Los tres `<clase>_stats.tres` tienen `jump_velocity = 6.0`, y `air_slash_config.tres` tiene `min_height = 1.0`.
- **AC600** Un salto desde el piso sale a 6.0 m/s y llega a 1.84 m de altura (±0.1 m).
- **AC601** Berserker a 0.5 m sobre el piso: `try_start()` es falso, y apretar `attack` hace el barrido normal (`attacked`) sin tajo aéreo.
- **AC602** Berserker a 1.2 m: apretar `attack` empieza el tajo aéreo.
- **AC603** Berserker que salta desde el piso con `attack` mantenido: el tajo aéreo empieza al cruzar `min_height` (la altura al empezar está entre 1.0 y 1.2 m) y no antes.

## 4. Tests que pueden necesitar adaptación

- `air_slash_test.gd` levanta al jugador 2 m, así que ya cumple la altura mínima. Si algún test que se apoya en el salto asumía 4.5 m/s o su altura, se adapta leyendo el dato y se anota acá.

## 5. Plan

1. Reservar AC599–AC603 en `CLAUDE.md` (próximo libre → AC604).
2. Datos: `jump_velocity` en los tres stats, `min_height` en `AirSlashConfig` y su `.tres`.
3. `AirSlashComponent.get_height_above_ground()` y la condición en `try_start()`.
4. Tests AC599–AC603, más `air_slash_test`, `player_physics_test`, `movement_component_test`, `samurai_run_test` y `sheathe_test` (los que usan el salto). No se corre la suite completa.
5. Smoke test, review de la constitución, estado Implementada y `CLAUDE.md`.
