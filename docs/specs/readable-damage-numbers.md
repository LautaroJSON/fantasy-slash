# Números de daño legibles con bosses altos

**Estado:** Implementada · **Constitución:** 4.21.0 (sin enmienda: mismo `TextMesh`, mismos colores) · **ACs:** AC996–AC1005

## 1. Pilar (Principio I)

**Combate:** el feedback del daño tiene que leerse. Hoy los números y los textos de Aflicción nacen sobre la cabeza (`spawn_height × body_scale`): 8.4 m en el Titán, 6.2 m en la Colmena. Contra un boss quedan fuera de cuadro y el jugador pierde la lectura del daño, del crítico y de sus Aflicciones justo en la pelea más importante.

## 2. Qué cambia (estilo Genshin)

1. **Números del golpe en el punto de impacto.** Un golpe del combo, o de una habilidad con `shows_hit_impact` (Envainar y Giro), hace nacer el número donde la hoja cruzó al enemigo (el mismo punto del VFX de impacto, `hit-impact-vfx.md` §4), `contact_rise` metros más arriba.
2. **Ancla visible para lo demás:** golpes de habilidades sin impacto (Tajo aéreo, Estocada, Golpe veloz), ticks de estados (veneno, sangrado), estallidos y nombres de Aflicción. Nacen sobre el eje del enemigo, a `min(spawn_height × body_scale, anchor_max_height)`. Con 3 m, los enemigos comunes no cambian (Bruto 2.4 m, Escudero 2.88 m) y en los bosses el texto queda a la altura del torso.
3. **Abanico:** el desvío aleatorio (`spread`) se reemplaza por una secuencia de posiciones laterales, a lo largo del eje derecho de la cámara: 0, +1, −1, +2, −2… × `fan_step`, hasta `fan_slots` posiciones, y vuelve a empezar. Cada posición sube además `fan_rise_step × |slot|`. Un combo rápido reparte sus números a los lados en vez de apilarlos. El contador es del pool (compartido por todos los enemigos).
4. **Tamaño fijo en pantalla:** los materiales de números (normal, crítico y los 5 de Aflicción) activan `fixed_size`. Un número mide lo mismo en pantalla a 3 m o a 15 m. `pixel_size` se reajusta para que, a la distancia habitual de la cámara, se vea como hoy (se verifica con capturas). Escalas del crítico, pop, subida y fundido no cambian.

**Valores por defecto** (no respondidos en la consulta, ajustables en datos): las habilidades sin impacto usan el ancla visible, y `anchor_max_height = 3.0`.

## 3. Estructura y datos

- `DamageNumberConfig`: **se quita** `spread`. **Se agregan** `contact_rise` (0.3 m), `anchor_max_height` (3.0 m), `fan_step` (0.35 m), `fan_slots` (5) y `fan_rise_step` (0.12 m).
- `materials/damage_number_material.tres`, `damage_number_crit_material.tres` y `materials/afflictions/*_damage_number_material.tres`: `fixed_size = true`. `pixel_size` del `.tres` se recalcula (valor inicial ≈ 0.006 / distancia habitual de cámara, ajustado con capturas).
- `HitImpactVfxHost.contact_point(enemy: Enemy) -> Vector3` (nuevo, público): el punto de impacto con la hoja actual. `show_impact` lo usa, así el VFX y el número comparten el mismo cálculo.
- `Player`: `hit_impact_vfx` pasa a ser público (hoy `_hit_impact_vfx`).
- `DamageNumberPool` separa sus fuentes:
  - `attack.enemy_hit` → punto de contacto.
  - `basic_ability` / `ultimate_ability.enemy_hit` → punto de contacto si `get_data().shows_hit_impact`, si no, ancla.
  - `air_slash.enemy_hit`, `burst_hit`, `triggered`, `enemy_debuff_ticked` → ancla.
  - En todos los casos se suma el desplazamiento del abanico.

## 4. Interfaz

```gdscript
# DamageNumberPool
func contact_spawn_point(enemy: Enemy) -> Vector3     # impact point + contact_rise
func anchor_spawn_point(enemy: Enemy) -> Vector3      # axis at min(head, anchor_max_height)
func next_fan_offset() -> Vector3                     # advances the fan counter
static func fan_slot(index: int, slots: int) -> int   # 0, 1, -1, 2, -2, …
```

La cámara se consulta una vez por número (`get_viewport().get_camera_3d()`; sin cámara, `Vector3.RIGHT`), nunca por cuadro.

## 5. Criterios de aceptación

- **AC996** Un golpe del combo a un Titán hace nacer el número a la altura del punto de contacto + `contact_rise` (±0.01, sin contar el abanico), no sobre la cabeza.
- **AC997** Un golpe de Envainar o del Giro nace en el punto de contacto. Uno de Estocada o del Tajo aéreo nace en el ancla.
- **AC998** El ancla está a `spawn_height × body_scale` para un Bruto y a `anchor_max_height` para el Titán, sobre su eje.
- **AC999** Los ticks de estado, los estallidos y los nombres de Aflicción de un Titán nacen en el ancla.
- **AC1000** `fan_slot` da 0, 1, −1, 2, −2 y vuelve a 0 con 5 posiciones. Números consecutivos se desplazan `slot × fan_step` sobre el eje derecho de la cámara y suben `|slot| × fan_rise_step`.
- **AC1001** Con la cámara mirando en otra dirección, el desplazamiento del abanico sigue su eje derecho (horizontal).
- **AC1002** Los 7 materiales de números tienen `fixed_size`, billboard y `no_depth_test`.
- **AC1003** Un mismo número a 4 m y a 12 m de la cámara proyecta la misma altura en pantalla (±2 %).
- **AC1004** `DamageNumberConfig` ya no tiene `spread` y todos sus campos nuevos son > 0 en el `.tres`.
- **AC1005** Smoke y capturas: Bruto, Verdugo y Titán golpeados desde la cámara de juego, con los números dentro de cuadro.

**Tests viejos que cambian (anotado al cerrar):**
- **AC32** (`damage_number_pool_test.gd`): verificaba la altura `spawn_height` y el `spread`. Pasa a verificar el punto de contacto; el texto, el crítico y la escala siguen igual.
- **AC150** (`boss_body_test.gd`): "los números sobre un cuerpo grande aparecen a `spawn_height × body_scale`" queda **reemplazado** por AC996 (en el punto de contacto) y AC998 (ancla con tope).

## 6. Plan

1. `HitImpactVfxHost.contact_point` (refactor de `show_impact`, sin cambiar comportamiento) y `Player.hit_impact_vfx` público.
2. Config: sacar `spread` y sumar los campos nuevos.
3. `DamageNumberPool`: fuentes separadas, contacto, ancla y abanico. Adaptar AC32 y AC150.
4. `fixed_size` en los 7 materiales y reajuste de `pixel_size` con capturas.
5. Tests AC996–AC1004, suites vecinas (números, boss_body, afflictions) y smoke con capturas (AC1005).
6. Cierre: checklist, **Implementada**, CLAUDE.md (próximo AC y "Dónde se ajusta"), anotar AC150 reemplazado en `boss-challenge.md`.

## 7. Checklist de review

- [x] **Identidad (I):** combate, lectura del daño contra bosses.
- [x] **Arte (II):** mismo `TextMesh` y mismos colores; `fixed_size` es un flag de `StandardMaterial3D`, sin shaders.
- [x] **Datos (III):** alturas, abanico y subida en `DamageNumberConfig`; se quitó `spread`.
- [x] **GDScript (IV):** tipado estricto; sin lógica en callbacks.
- [x] **Performance (V):** la cámara se consulta una vez por número; sin RNG ni allocations nuevas; el pool no cambia.
- [x] **Input (VI):** sin input nuevo.
- [x] **Combate (VII):** no toca tiempos ni hit lag.
- [x] **Calidad:** 85 casos en verde (`test/effects`, `boss_body_test`, `unique_upgrades_test`, `affliction_data_test`, `test/components/vfx`); smoke del proyecto y de la arena sin errores.

## 8. Notas de cierre

- **AC1003** se verificó con una escena de captura: el mismo número a 4 m y a 12 m mide 15 px de alto en los dos casos (1152×648). Con `pixel_size = 0.0009` (antes 0.006), un número a unos 6.5 m (5 m de brazo de cámara más el enemigo delante) se ve como antes.
- **AC1005**, capturas desde la cámara de juego con el Guerrero y "Escarcha" forzada:
  - Bruto: sin cambios visibles.
  - Verdugo: números dentro de cuadro (antes nacían a 4.8 m, en el borde superior).
  - Titán: el golpe nace a la altura del impacto y el nombre a 3 m (antes a 8.4 m, fuera de cuadro).
- **Tests viejos:** AC32 (`damage_number_pool_test.gd`) pasó a verificar el punto de contacto, con el mismo texto, crítico y escala. AC150 (`boss_body_test.gd`) quedó reemplazado por AC996 en el mismo archivo. Ver la nota en `boss-challenge.md`.
- El número de un golpe puede superponerse al cuerpo del jugador cuando el enemigo está pegado y centrado: los dos son blancos. Sube rápido (1.6 m/s) y el abanico reparte los siguientes a los lados. Si molesta, se ajusta `contact_rise` o se hace que el abanico no use el centro.
