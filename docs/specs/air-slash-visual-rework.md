# Feature: re-work visual del Tajo aéreo

- **Estado:** Propuesta (2026-09-28). ACs **AC1014–AC1030**.
- **Constitución:** `docs/constitution.md` v4.22.1. Propone una enmienda **MINOR** (§7).
- **Pilar (Principio I):** **combate.** El Tajo aéreo carga de ×0.8 a ×4 del daño en 3 s de suspensión, pero hoy nada de eso se ve:
  - el cuerpo queda en `idle` en el aire;
  - el mandoble flota fuera de la mano;
  - el único indicio de la carga es una franja fija en el piso.

  Con el cuerpo que se tensa a medida que carga y el mandoble que titila antes de caer solo, el jugador lee cuánto cargó y cuándo tiene que soltar.
- **Decisiones del responsable (2026-09-28):**
  - lo que "se estira" es **el cuerpo**: se arquea y sube el mandoble cada vez más a medida que carga. Es solo visual; el daño sigue creciendo como hoy;
  - lo que titila es **el mandoble**: parpadea blanco, cada vez más rápido, cuando la carga está por llegar al máximo;
  - al máximo **se suelta solo**, como hoy.
- **Dependencias:**
  - `berserker-air-slash.md`: la mecánica no cambia (fases, daño, franja, empuje, corte de viento);
  - `spin-visual-rework.md`: mismo patrón de clips del cuerpo con el arma en la mano;
  - `humanoid-player-model.md` (`WeaponMount`, `PlayerAnimator`).

## 1. Estado actual (auditoría)

1. **Cuerpo en `idle`.** Mientras el Tajo aéreo está activo, `Player.is_casting()` es verdadero y `PlayerAnimator` pide `get_body_clip()`, que solo consulta las habilidades de los slots. Resultado:
   - el cuerpo hace `idle` flotando, cayendo y aterrizando;
   - en el Berserker, `idle` es la guardia con el mandoble al hombro.
2. **El mandoble flota fuera de la mano.**
   - `try_start()` llama `SwordSwing.hold_pose(raise_position, raise_rotation)`, una pose fija del espacio del `Visual`;
   - `release()` llama `swing_to(slam_position, …)`.

   Con `SwordSwing` activo, `WeaponMount` suelta la mano.
3. **La carga no se ve.** La franja del piso es fija y no hay ningún indicio de la carga ni del momento en que va a caer solo (a los 3 s).
4. **La estela depende de `SwordSwing`.** Hoy se enciende solo durante el `swing_to` de la caída.

## 2. Diseño

### 2.1 Tres clips del Berserker

Van en `berserker_profile.gd`, con `_add_air_slash()`. Reutilizan las poses del "tajo de leñador" (golpe 3), que ya tiene el mandoble a dos manos sobre la cabeza y la bajada con la hoja clavada.

| Clip | Fase | Largo | Contenido |
|---|---|---|---|
| `air_slash_charge` | HOVER | 1.0 s, sin loop; **se posiciona por la carga** (§2.2) | **t 0:** el mandoble alzado a dos manos sobre la cabeza (la pose `raised` del golpe 3), con piernas de salto (las de `jump_air`). **t 1:** **tensado al máximo**: el torso arqueado atrás (≈ +12° más que la pose "tensión" del golpe 3), el mandoble más atrás y más alto detrás de la cabeza, y las rodillas recogidas como un arco. |
| `air_slash_dive` | DIVE | 0.15 s, sin loop | Desde el tensado, la hoja baja de golpe al frente (el "pisotón" del golpe 3, t 0.62) y queda adelante y abajo, lista para clavarse. Se queda en el último cuadro hasta tocar el piso. |
| `air_slash_land` | LANDING | 0.6 s (= `landing_lock`), sin loop | **Hoja clavada** (la pose `buried` del golpe 3) con la cadera baja por el aterrizaje; después vuelve a la guardia (`_stance()`). |

- En todos los cuadros de `air_slash_charge` y `air_slash_dive`, `left_grip` es 1 (las dos manos en el mango).
- En `air_slash_land` se suelta al volver a la guardia.
- La hoja no atraviesa el torso. En `air_slash_land` la punta puede tocar el piso, porque está clavada (como en el golpe 3).

### 2.2 El cuerpo sigue la carga

- `AirSlashComponent.get_body_clip()` devuelve el clip de la fase activa (`&""` en IDLE).
- `AirSlashComponent.get_body_clip_ratio()` devuelve la carga en HOVER y −1 en las otras fases.
- `Player.get_body_clip()` y `Player.is_weapon_in_hand_cast()` suman al Tajo aéreo. Mientras está activo:
  - `WeaponMount` mezcla el arma a la mano (0.1 s) y la sigue;
  - `PlayerAnimator` pide su clip.
- **Posicionado por la carga.**
  - Mientras `Player.get_body_clip_ratio()` ≥ 0, `PlayerAnimator` deja el clip quieto (`speed_scale` 0) y lo posiciona en `ratio × largo` en cada cuadro.
  - Así, el cuerpo **se tensa exactamente con la carga**: 0 % al empezar, 100 % a los 3 s.
- Se borra el uso de `SwordSwing` en el Tajo aéreo (`hold_pose`, `swing_to` y `recover`), y con él `raise_position`, `raise_rotation`, `slam_position`, `slam_rotation` y `slam_duration` de `AirSlashConfig`.
  - `SwordSwing` queda sin usuarios en el juego. Borrarlo va en otra spec.
- **Estela:**
  - `AirSlashComponent` emite `phase_changed(phase)`;
  - `WeaponTrail` suma `air_slash` como fuente: emite durante la fase **DIVE** (la bajada), igual que hoy durante el `swing_to`.

### 2.3 El mandoble titila antes de caer solo

- **Desde `blink_start_ratio` (0.8) de la carga** hasta que se suelta, el mandoble parpadea: su `Model` toma un `material_overlay` blanco aditivo y lo alterna encendido y apagado.
- **El parpadeo se acelera:** el período (encendido + apagado) baja linealmente de `blink_period_start` (0.25 s) a `blink_period_end` (0.08 s) entre `blink_start_ratio` y 1.
- **Al soltar**, a mano o solo al llegar al máximo, el parpadeo se corta y el overlay se saca. También se corta con `cancel()`.
- **Implementación:**
  - un nodo nuevo, **`WeaponChargeBlink`** (`components/weapon_charge_blink.gd`), hijo de `AirSlash`;
  - `Player` le pasa el `Model` del arma al equiparla (`set_weapon_model`);
  - `AirSlashComponent` llama `update(ratio)` cada cuadro de HOVER y `stop()` al salir;
  - no crea nada por cuadro: solo asigna o quita el overlay compartido.
- **Material:** `materials/vfx/weapon_charge_blink_material.tres`: blanco `Color(1, 1, 1)`, unshaded, blend aditivo y alpha 0.6. Es una fila nueva de la tabla de colores (§7).

### 2.4 Lo que no cambia

- Las fases y los tiempos: 3 s de suspensión, caída a 20 m/s, 0.6 s de aterrizaje.
- El daño (×0.8 → ×4), la franja blanca del piso, el empuje, el corte de viento y la sacudida al impactar.

## 3. Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `resources/air_slash_config.gd` / `data/classes/berserker/air_slash_config.tres` | **Se borran:** `raise_position`, `raise_rotation`, `slam_position`, `slam_rotation`, `slam_duration`. **Se agregan:** `charge_body_clip` (`&"air_slash_charge"`), `dive_body_clip` (`&"air_slash_dive"`), `land_body_clip` (`&"air_slash_land"`), `blink_start_ratio` (0.8), `blink_period_start` (0.25 s), `blink_period_end` (0.08 s), `blink_overlay` (material) |
| `materials/vfx/weapon_charge_blink_material.tres` (nuevo) | Blanco, unshaded, aditivo, alpha 0.6 |
| `entities/player/player.tscn` | Nodo `Blink` (`WeaponChargeBlink`) bajo `AirSlash`; `air_slash` en `WeaponTrail`; `AirSlash` ya no recibe `sword_swing` |

## 4. Interfaz pública

- **`AirSlashComponent`:**
  - `signal phase_changed(phase: Phase)`;
  - `get_body_clip() -> StringName` y `get_body_clip_ratio() -> float`;
  - `set_weapon_model(model: MeshInstance3D)`, que se lo pasa al `Blink`;
  - `get_blink() -> WeaponChargeBlink`.
- **`WeaponChargeBlink`:**
  - `setup(model: MeshInstance3D)`, `update(ratio: float)`, `stop()`;
  - `is_blinking()` e `is_lit()`.
- **`Player`:** `get_body_clip()` y `is_weapon_in_hand_cast()` incluyen al Tajo aéreo; nuevo `get_body_clip_ratio() -> float`.
- **`PlayerAnimator`:** posiciona el clip de acción por `get_body_clip_ratio()` cuando es ≥ 0.
- **`WeaponTrail`:** `@export var air_slash: AirSlashComponent` (opcional).

## 5. Criterios de aceptación

**Cuerpo y arma**
- **AC1014** El perfil del Berserker tiene `air_slash_charge`, `air_slash_dive` y `air_slash_land`, sin loop. En todo cuadro de `air_slash_charge` y `air_slash_dive`, `left_grip` es 1.
- **AC1015** En HOVER el humanoide reproduce `air_slash_charge`; en DIVE, `air_slash_dive`; en LANDING, `air_slash_land`. En las tres fases `Player.is_weapon_in_hand_cast()` es verdadero y, con la mezcla cumplida, el pivot del arma coincide con la mano (1 mm).
- **AC1016** El cuerpo sigue la carga: con la carga en 0, 0.5 y 1, la posición del clip `air_slash_charge` es 0, 0.5 y 1 × su largo (tolerancia de un cuadro de física), y no avanza solo.
- **AC1017** **Se tensa:** al 100 % de la carga la punta del mandoble está más alta y más atrás (en el espacio del `Visual`) que al 0 %, y el torso está más arqueado hacia atrás.
- **AC1018** En `air_slash_charge` y `air_slash_dive`, muestreados cada 0.05 s, la hoja no atraviesa el torso (mismo criterio que AC751).
- **AC1019** `SwordSwing` no se activa en ningún momento del Tajo aéreo, y `AirSlashConfig` no tiene `raise_*` ni `slam_*`.
- **AC1020** Al terminar LANDING, el cuerpo vuelve a la guardia (`idle`) sin salto de pose (entra con `attack_exit_blend`).

**Titileo**
- **AC1021** Por debajo de `blink_start_ratio`, el mandoble no titila: su `material_overlay` es nulo.
- **AC1022** Entre `blink_start_ratio` y 1, el overlay se alterna. El período medido baja de `blink_period_start` (±1 cuadro) al empezar a `blink_period_end` (±1 cuadro) cerca del máximo.
- **AC1023** Al soltar (a mano o solo a los 3 s) y al cancelar, el overlay vuelve a nulo en ese mismo cuadro.
- **AC1024** El material es blanco, unshaded, aditivo, con alpha ≤ 0.6, y es el mismo recurso compartido (no se duplica).

**Estela y regresión**
- **AC1025** La estela se enciende durante DIVE y se apaga después, sin `SwordSwing`.
- **AC1026** Sin cambios de mecánica: la carga, el daño, la franja, el empuje, el corte de viento y la sacudida de impacto siguen como en `berserker-air-slash.md`. Los tests de `air_slash_test` que verificaban `raise_position` o el barrido de `SwordSwing` se adaptan a la mano, sin cambiar lo que verifican.
- **AC1027** La suite completa sin fallas nuevas respecto de la base, y el smoke test sin errores ni warnings.

AC1028–AC1030 quedan de reserva para ajustes de las capturas.

## 6. Estructura

```
AirSlash : AirSlashComponent (player.tscn)
├── Indicator : AbilityRectIndicator     (sin cambios)
├── WindCut : WindCutVfx                 (sin cambios)
└── Blink : WeaponChargeBlink            (nuevo)
```

## 7. Enmienda de la constitución (MINOR → 4.23.0)

**Principio II, tabla de colores:** se agrega la fila:

| Elemento | Malla base | Color (`albedo_color`) |
|---|---|---|
| Titileo de carga del arma (Tajo aéreo: el mandoble parpadea antes de caer solo) | `material_overlay` sobre la malla del arma | **Blanco**: `Color(1, 1, 1)`, unshaded, blend aditivo, alpha ≤ 0.6 |

Además, en la lista de elementos que comparten el blanco se suma el titileo del arma. No se confunde: es un parpadeo sobre el arma, que dura décimas de segundo.

## 8. Fuera de alcance

- Borrar `SwordSwing` y `SwordSwingConfig`, que quedan sin usuarios.
- El VFX de impacto y el *hit lag* del Tajo aéreo al caer (hoy: corte de viento y sacudida).
- Cambios de balance del Tajo aéreo.

## 9. Plan

1. **Datos y enmienda:** `AirSlashConfig` (quitar `raise_*`/`slam_*`, agregar clips y titileo), el material del titileo y la enmienda 4.23.0.
2. **Clips:**
   - `air_slash_charge`, `air_slash_dive` y `air_slash_land` en `berserker_profile.gd`;
   - ajuste con la sonda de poses y capturas (AC1017 y AC1018).
3. **Cuerpo y arma:**
   - `get_body_clip`/`get_body_clip_ratio` en `AirSlashComponent` y `Player`;
   - `is_weapon_in_hand_cast` con el Tajo aéreo;
   - el posicionado por la carga en `PlayerAnimator`;
   - sacar `SwordSwing` del Tajo aéreo.
   - Tests AC1014–AC1020.
4. **Titileo:** `WeaponChargeBlink`, su nodo en `player.tscn` y `set_weapon_model` desde `Player`. Tests AC1021–AC1024.
5. **Estela:** `phase_changed` y la fuente `air_slash` en `WeaponTrail`. Test AC1025; adaptar `air_slash_test` AC579 y AC587.
6. **Cierre:**
   - tests del Tajo aéreo y relacionados;
   - capturas con Forward+ de la carga, el titileo, la caída y el aterrizaje;
   - smoke test y, si la querés, la suite completa;
   - checklist de la constitución, estado **Implementada** y el próximo AC libre en `CLAUDE.md`.
