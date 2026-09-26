# Rage: buff de los enemigos sin mejoras disponibles

- **Estado:** Implementada (2026-09-25, 417 tests GdUnit4 en verde, 0 orphans; import y smoke test de la arena sin errores; captura del aura revisada)
- **Constitución:** `docs/constitution.md` **v3.6.0** → **v3.7.0** (enmienda MINOR, ver abajo)
- **Pilar (Principio I):** Supervivencia. Cuando el jugador agotó todas las mejoras, su poder deja de crecer, pero la presión tiene que seguir subiendo para que la run termine. Los enemigos ya están en su nivel máximo (25), así que crecen con *rage*.
- **Tipo:** feature.
- **Dependencias:** `endless-without-upgrades.md`, `enemy-levels.md`, `unique-ability-upgrades.md` (debuffs), `cooldown-timers.md` (tiempos de los íconos).

## Objetivo

A partir de la primera oleada que empieza sin oferta de cartas (ver `endless-without-upgrades.md`), todos los enemigos que aparecen, jefes incluidos, entran con el buff **Rage**:

- Suben su vida máxima, daño, defensa y velocidad de movimiento según el **nivel de rage**, que sube 1 por oleada.
- El buff entra en la **misma lista** que los debuffs del enemigo (`DebuffComponent`). Se ve con un ícono rojo, sin tiempo porque es permanente, junto a los de sangrado o Debilitar.
- Se ve un **aura roja** translúcida alrededor del cuerpo mientras dura.

El nivel del enemigo sigue topado en 25 (`max_enemy_level`). El rage se suma sobre los stats de ese nivel.

`BuffData`/`BuffComponent` (buffs del jugador, con stacks que expiran y barra en el HUD) no cambian. Rage es un estado del enemigo y vive con sus debuffs, como pediste.

## Cálculo del rage

**Nivel de rage** `r`:

- `r = 0` antes de agotar las mejoras.
- Si la primera oleada sin cartas es la `W` (la que empieza al limpiar la oleada `W − 1` sin oferta), entonces `r = oleada − W + 1`: 1 en `W`, 2 en `W + 1`, etc.

**Stats:** cada stat toma el valor que ya tiene el enemigo en su nivel (`base`) y le aplica un crecimiento por nivel de rage. Se reutiliza `EnemyStatGrowth` (PERCENT sobre `base` o FLAT, con tope opcional). El rage **nunca baja** un stat: si `base` ya supera el tope, se queda igual.

```
valor = max(base, growth.scale(base, r + 1))
```

Valores propuestos (`data/enemies/rage/rage_config.tres`), por nivel de rage:

| Stat | Modo | Por nivel | Tope del valor final |
|---|---|---|---|
| Vida máxima | PERCENT | +15 % de `base` | sin tope |
| Daño | PERCENT | +8 % de `base` | sin tope |
| Defensa | FLAT | +0.5 | 20 |
| Velocidad de movimiento | FLAT | +0.1 m/s | 5.4 (por debajo de la clase más lenta, el Berserker con 5.5) |

Ejemplo con un Grunt de nivel 25 (232 vida, 27.2 daño, 5 defensa, 5.0 velocidad):

| `r` | Vida | Daño | Defensa | Velocidad |
|---|---|---|---|---|
| 1 | 266.8 | 29.4 | 5.5 | 5.1 |
| 5 | 406 | 38.1 | 7.5 | 5.4 (tope) |
| 10 | 580 | 48.96 | 10 | 5.4 |
| 30 | 1276 | 92.5 | 20 (tope) | 5.4 |

## Estructura de nodos

`entities/enemy/enemy.tscn`:

```
Enemy (CharacterBody3D)
├── Body (MeshInstance3D, CapsuleMesh gris)
│   └── RageAura (MeshInstance3D, CapsuleMesh, rage_aura_material)   ← nuevo, script StatusAura
├── HealthComponent
├── DebuffComponent
└── HealthBar
    └── DebuffIcons
```

- `RageAura` es hija de `Body`, así que se escala con el cuerpo (jefes incluidos). Su `CapsuleMesh` es un poco más grande que el cuerpo (radio 0.55, alto 2.1, en `enemy.tscn`), sin sombras y oculta por defecto.
- No se instancia nada en runtime: el aura existe en cada enemigo del pool y solo se muestra u oculta (Principio V).

## Resources y datos

- **`DebuffData`** (`resources/debuff_data.gd`):
  - Nuevo valor de `Effect`: `STAT_BOOST`. Mejora stats del dueño. El dueño los aplica al recibirlo; `DebuffComponent` solo lo lista, sin ticks ni reducción de armadura.
  - Nuevo `@export var permanent: bool`: el estado no expira con el tiempo; solo se quita con `clear()`, que se llama al activar o desactivar la entidad. Con `permanent` el ícono no muestra tiempo.
  - El comentario de la clase pasa a decir "estado de una entidad (debuff o buff)". **No se renombra** la clase ni el componente, para no tocar sangrado, Debilitar ni sus tests. Es solo una decisión de nombre y se puede hacer aparte si la querés.
- **`data/debuffs/rage.tres`** (`DebuffData`): `id = &"rage"`, `effect = STAT_BOOST`, `permanent = true`, `max_stacks = 1`, `icon_material = rage_icon_material`.
- **`RageConfig`** (nuevo, `resources/rage_config.gd`):
  - `@export var status: DebuffData` (el `rage.tres`).
  - `@export var growth: Array[EnemyStatGrowth]` (la tabla de arriba).
  - `func write_raged(rage_level: int, out: EnemyStats) -> void`: función pura que reescribe en `out` los stats de `growth` con la fórmula de arriba. Con `rage_level <= 0` no hace nada.
- **`data/enemies/rage/rage_config.tres`**: la instancia con los valores propuestos.
- **Materiales** (Principio II, compartidos):
  - `materials/vfx/rage_aura_material.tres`: `StandardMaterial3D` unshaded, `Color(0.9, 0.1, 0.1, 0.3)`, transparencia alpha, sin sombras.
  - `materials/debuff_rage_material.tres`: ícono, unshaded, `Color(0.9, 0.1, 0.1)`.

## Interfaz pública

- `RunState`:
  - `var rage_start_wave: int = 0` (0 = sin rage).
  - `func start_rage() -> void`: si todavía no hay rage, `rage_start_wave = wave + 1`. Se llama antes de avanzar de oleada; si se llama de nuevo, no hace nada.
  - `func get_rage_level() -> int`: 0 sin rage o antes de `rage_start_wave`; si no, `wave − rage_start_wave + 1`.
- `Enemy.enrage(config: RageConfig, rage_level: int) -> void`: aplica `write_raged` sobre sus stats de nivel, vuelve a hacer `health.setup` con la vida y la defensa nuevas (vida llena) y agrega `config.status` a `debuffs` con `potency = rage_level`. Con `rage_level <= 0` no hace nada.
- `WaveManager`: `@export var rage: RageConfig` (asignado en `arena.tscn`).
- `StatusAura` (nuevo, `components/status_aura.gd`, `extends MeshInstance3D`): `@export var debuffs: DebuffComponent` y `@export var status: DebuffData`. Se muestra si `debuffs.has_debuff(status.id)`. Se actualiza solo con la señal `changed`, sin `_process`.

## Lógica interna

1. `WaveManager._on_all_dead()`, rama de oferta vacía: `run_state.start_rage()` y después `_advance_wave.call_deferred()`. En el sandbox nunca se llega a esta rama, así que no hay rage.
2. `WaveManager._spawn_from()`: lee `run_state.get_rage_level()` una vez por oleada. Después de `enemy.activate(...)`, si el nivel es mayor que 0, llama `enemy.enrage(rage, rage_level)`.
3. `Enemy.activate()` ya llama `debuffs.clear()` y reescribe los stats de nivel. Un enemigo del pool reutilizado sin rage vuelve limpio: sin buff, sin aura y con sus stats de nivel.
4. `DebuffComponent`:
   - `advance()` no hace expirar los estados `permanent`.
   - `get_remaining()` devuelve 0 para ellos (el ícono muestra `""` porque `CooldownText` usa el paso 0).
   - `get_defense_reduction()` ya ignora todo lo que no sea `ARMOR_REDUCTION`.
5. `StatusAura` escucha `debuffs.changed` y hace `visible = debuffs.has_debuff(status.id)`.

## Enmienda a la constitución (MINOR → 3.7.0)

- **Principio III, viñeta Debuffs:** pasa a llamarse **Estados de entidades (debuffs y buffs)**. La lista de `DebuffData` de una entidad también guarda buffs (efecto `STAT_BOOST`, p. ej. Rage) y estados permanentes (`permanent`), que solo se quitan al reiniciar la entidad. Los buffs del jugador siguen en `BuffData`.
- **Principio II, colores no reservados:** se registra el rojo translúcido del aura de Rage y el rojo de su ícono. El aura es una `CapsuleMesh` unshaded con alpha ≤ 0.3, más grande que el cuerpo gris, así que no se confunde con él.

## Criterios de aceptación

**Cálculo** (`test/resources/rage_config_test.gd`, con `rage_config.tres` y el Grunt a nivel 25):

- **AC333:** `write_raged(0, out)` deja `out` sin cambios.
- **AC334:** `write_raged(1, out)`: vida ×1.15, daño ×1.08, defensa +0.5 y velocidad +0.1 sobre los stats de nivel. Los stats que no están en `growth` (intervalo, rango, fricción) no cambian.
- **AC335:** con `r = 30`, la defensa queda en 20 y la velocidad en 5.4 (topes).
- **AC336:** un stat que ya supera su tope no baja (p. ej. un `EnemyStatGrowth` FLAT con tope menor que `base`).

**RunState** (`test/systems/run_state_test.gd`):

- **AC337:** sin `start_rage()`, `get_rage_level()` es 0.
- **AC338:** con `start_rage()` en la oleada 114: nivel 0 en la 114, 1 en la 115 y 3 en la 117. Un segundo `start_rage()` en la 116 no cambia el inicio.

**Estado permanente** (`test/components/debuff_component_test.gd` o el test de debuffs existente):

- **AC339:** con `rage.tres` aplicado, `advance(1000.0)` no lo quita; `get_defense_reduction()` sigue en 0; `clear()` lo quita.
- **AC340:** el ícono de rage aparece en `DebuffIcons` con texto de tiempo vacío, y convive con un sangrado (dos íconos).

**Run** (`test/levels/arena_waves_test.gd`, con el pool de cartas vaciado):

- **AC341:** con cartas disponibles, los enemigos de la oleada 2 no tienen rage y su aura está oculta.
- **AC342:** al limpiar la oleada 1 sin cartas, los enemigos de la oleada 2 tienen `rage` (potency 1), el aura visible y vida máxima, daño, defensa y velocidad iguales a `write_raged(1, …)` sobre sus stats de nivel. Arrancan con la vida llena.
- **AC343:** al limpiar también la oleada 2, los enemigos de la oleada 3 tienen rage 2.
- **AC344:** un enemigo con rage que muere y se reutiliza en una run sin rage (`activate` sin `enrage`) vuelve sin buff, sin aura y con sus stats de nivel.
- **AC345:** la suite completa sigue en verde y el smoke test de la arena no muestra errores.

## Plan de implementación

1. `DebuffData`: `STAT_BOOST` y `permanent`. `DebuffComponent`: los permanentes no expiran. Tests AC339 y AC340.
2. `RageConfig`, `rage_config.tres`, `rage.tres` y los dos materiales. Tests AC333 a AC336.
3. `RunState.start_rage()` y `get_rage_level()`. Tests AC337 y AC338.
4. `Enemy.enrage()`, `StatusAura` y el nodo `RageAura` en `enemy.tscn`.
5. `WaveManager`: `@export rage`, `start_rage()` en la rama de oferta vacía y `enrage` en `_spawn_from`. Asignar `rage` en `arena.tscn`. Tests AC341 a AC344.
6. Enmienda de la constitución (3.7.0).
7. Suite completa y smoke test sobre la copia del scratchpad. Captura visual del aura en una escena temporal. Review con el checklist, spec **Implementada** y próximo AC libre (AC346) en `CLAUDE.md`.

## Review (checklist de la constitución)

- [x] **I.** Sirve a Supervivencia: la presión sigue subiendo después de agotar las mejoras.
- [x] **II.** Aura (`CapsuleMesh`) e ícono (`BoxMesh`) son primitivas con materiales `.tres` compartidos, sin shaders. El rojo se registró como color no reservado (3.7.0).
- [x] **III.** Todos los valores del rage viven en `rage_config.tres` y `rage.tres`. `RageConfig.write_raged` es puro y solo escribe en el duplicado de stats de cada enemigo.
- [x] **IV.** Tipado estático; `StatusAura` no tiene `_process`, reacciona a `changed`.
- [x] **V.** Sin allocations por frame: el aura existe en cada enemigo del pool y solo se muestra u oculta. Los estados permanentes no mantienen `DebuffComponent` procesando.
- [x] **VI.** Sin input nuevo.

## Notas

- **ACs renumerados:** la spec se aprobó con AC271–AC283, pero sesiones en paralelo (`wind-cut-v`, `wind-step`, `cooldown-timers`, `cooldown-clock`) tomaron hasta AC332. Quedaron en AC333–AC345, con el mismo contenido.
- **Constitución:** la enmienda se aprobó como 3.6.0, pero `cooldown-timers.md` ya había usado esa versión. Quedó como **3.7.0**.
- `cooldown-clock.md` (en paralelo) planea `DebuffComponent.get_remaining_ratio`. Para los estados permanentes debería devolver 0, igual que `get_remaining`.
- Ningún test viejo se modificó.
