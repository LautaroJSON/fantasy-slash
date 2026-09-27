# Feature: color del daño de las Aflicciones y crítico blanco

- **Estado:** Propuesta (2026-09-27). Pendiente de aprobación y de las decisiones D1–D2 (§3). ACs reservados: **AC931–AC940** (se usan AC931–AC938).
- **Constitución:** `docs/constitution.md` v4.17.0 → **enmienda MINOR a 4.18.0** (Principio II: tabla de colores, ver §7).
- **Pilar (Principio I):** **combate** (legibilidad). El daño de una Aflicción aparece con el color de su barra, así que el jugador distingue de un vistazo qué parte del daño viene del Veneno o del Estallido y cuál de sus golpes, sin leer números. El crítico sigue diferenciándose por el "!" y el tamaño.
- **Dependencias:** `affliction.md` (Veneno, Estallido, colores de las barras), `damage-numbers` (pool de números, AC de números y críticos), `cooldown-timers.md` (ticks de estados vía `EnemyRegistry.enemy_debuff_ticked`).

## 1. Estado actual

1. Todos los números normales son **blancos** (`damage_number_material.tres`), incluidos los ticks de estados (Sangrado, Veneno) y el daño del Estallido.
2. Los críticos (combo, habilidades y Tajo aéreo) son **ámbar** `Color(1, 0.55, 0.1)` (`damage_number_crit_material.tres`, color reservado), con el sufijo "!" (`crit_suffix`), más grandes (`crit_scale`, con *pop*) y duran más.
3. `DebuffComponent.ticked(target, amount)` no dice qué estado hizo el daño, y `AfflictionLoadout.burst_hit(enemy, applied)` no dice de qué Aflicción viene.

## 2. Aflicciones que hacen daño

| Aflicción | Daño | Cómo llega al número | Color propuesto del número |
|---|---|---|---|
| **Veneno** | Ticks del estado `poison` (30 % del daño por segundo) | `DebuffComponent.ticked` → `EnemyRegistry.enemy_debuff_ticked` | Verde veneno `Color(0.25, 0.6, 0.2)` (el de su barra) |
| **Estallido** | Daño en área al llenarse | `AfflictionLoadout.burst_hit` | Azul eléctrico `Color(0.3, 0.5, 1.0)` (el de su barra) |
| Escarcha | — (lentitud) | — | — |
| Corrosión | — (defensa) | — | — |

Sangrado (Lacerante) no es una Aflicción: sus ticks siguen blancos.

## 3. Decisiones

- **D1 — ¿Qué críticos pasan a blanco?** Hoy hay críticos del combo, de las habilidades (Giro, Envainar) y del Tajo aéreo, y todos usan el ámbar. **Recomendado:** todos pasan a blanco (una sola regla: el crítico se distingue por "!", tamaño y *pop*, no por color). Alternativa: solo los del combo; las habilidades seguirían en ámbar.
- **D2 — Tono exacto del número.** **Recomendado:** el mismo color de la barra, para que barra, ícono y número se asocien. El verde veneno es oscuro; si en el juego cuesta leerlo, se aclara en su material (dato) sin tocar código. Alternativa: una versión aclarada desde el principio (verde `Color(0.45, 0.8, 0.35)`, azul `Color(0.5, 0.68, 1.0)`).

## 4. Diseño

### 4.1 Datos

- `damage_number_crit_material.tres`: `albedo_color` pasa a `Color(1, 1, 1)`. Se conserva como material propio (un cambio futuro de color del crítico sigue siendo un dato). `crit_suffix`, `crit_scale`, `crit_pop_scale`, `crit_lifetime` y `crit_rise_speed` no cambian.
- `DebuffData`: `+ damage_number_material: StandardMaterial3D`. Nulo = número blanco normal. `poison.tres` usa `materials/afflictions/poison_damage_number_material.tres`.
- `AfflictionData`: `+ damage_number_material: StandardMaterial3D` (el del daño del Estallido). `burst.tres` usa `materials/afflictions/burst_damage_number_material.tres`.
- Materiales nuevos: copias de `damage_number_material.tres` (unshaded, *billboard*, sin depth test, `render_priority` 10) con el `albedo_color` de §2.

### 4.2 Interfaz

```gdscript
# DebuffComponent
signal ticked(target: Node3D, amount: float, data: DebuffData)        # + data
# EnemyRegistry
signal enemy_debuff_ticked(enemy: Enemy, amount: float, data: DebuffData)  # + data
# AfflictionLoadout
signal burst_hit(enemy: Enemy, applied: float, type: AfflictionData)  # + type
# DamageNumberPool
func spawn(amount: float, is_crit: bool, at: Vector3, tint: StandardMaterial3D = null) -> void
# DamageNumber
func show_damage(amount: float, is_crit: bool, at: Vector3, tint: StandardMaterial3D = null) -> void
```

### 4.3 Lógica

- `DamageNumber.show_damage`: un número normal usa `tint` si no es nulo, si no el material blanco; el tamaño, la vida y la subida son los de un número normal. Un crítico ignora `tint` (las Aflicciones nunca son críticas).
- `DamageNumberPool`: los ticks pasan `data.damage_number_material` y el Estallido `type.damage_number_material`. Los golpes (combo, habilidades, Tajo aéreo) no pasan `tint`.
- Sin *allocations*: los materiales son `.tres` compartidos y el pool solo cambia `material_override` al reutilizar un número (Principio V).

## 5. Criterios de aceptación (AC931–AC938)

- **AC931** Un crítico del combo muestra el número en blanco `Color(1, 1, 1)` (material `damage_number_crit_material.tres`), con "!", `crit_pop_scale` al aparecer, `crit_scale` al final y `crit_lifetime`: todo igual que antes salvo el color.
- **AC932** (según D1) Los críticos de las habilidades y del Tajo aéreo también son blancos, con "!" y el tamaño de crítico.
- **AC933** Un tick de Veneno muestra su número con `poison_damage_number_material.tres` (verde de la barra), tamaño normal y sin "!".
- **AC934** El daño del Estallido muestra su número con `burst_damage_number_material.tres` (azul de la barra), tamaño normal y sin "!", en cada enemigo alcanzado.
- **AC935** Un golpe normal y un tick de Sangrado siguen en blanco normal.
- **AC936** Datos: el `albedo_color` de `poison_damage_number_material.tres` es el del `bar_material` de Veneno y el de `burst_damage_number_material.tres` el de Estallido; `frost.tres`, `corrosion.tres`, `bleed.tres`, `weaken.tres`, `rage.tres` y `shield.tres` no tienen material de número.
- **AC937** El pool no crea materiales ni nodos al mostrar números de color: 50 números seguidos (normales, críticos, Veneno y Estallido) reutilizan los `pool_size` números creados en `_ready`.
- **AC938** `EnemyRegistry.enemy_debuff_ticked` y `DebuffComponent.ticked` informan el `DebuffData` del tick.

## 6. Tests

- `test/effects/damage_number_pool_test.gd` (ampliado): AC931–AC935, AC937.
- `test/resources/affliction_data_test.gd` (ampliado): AC936.
- `test/components/affliction_status_test.gd` (ampliado): AC938.
- Tests viejos que verifican el ámbar del crítico o la firma de `ticked`/`enemy_debuff_ticked`/`burst_hit` (`damage_number_pool_test`, `unique_upgrades_test`, `boss_body_test`, `affliction_loadout_test`) se adaptan sin cambiar lo que verifican y se anotan en §9.

## 7. Enmienda de la constitución (MINOR 4.17.0 → 4.18.0)

**Principio II**, tabla de colores:
- La fila "Números de daño flotantes (crítico)" pasa de ámbar a **Blanco**: `Color(1, 1, 1)`; se distingue por el sufijo "!" y el tamaño.
- Fila nueva: "Números de daño de Aflicción (Veneno, Estallido)" | `TextMesh` | el color de la barra de su Aflicción (no reservado).
- El ámbar `Color(1, 0.55, 0.1)` deja de estar reservado. El párrafo del blanco compartido suma los números críticos.

**Historial:** `4.18.0 (fecha de cierre): Principio II: los números de daño críticos pasan a blanco (el ámbar deja de estar reservado) y los de las Aflicciones toman el color de su barra (ver affliction-damage-colors.md).`

## 8. Plan

1. Materiales y campos de datos (`DebuffData`, `AfflictionData`, `.tres`). Test AC936.
2. Señales con el dato (`ticked`, `enemy_debuff_ticked`, `burst_hit`) y adaptación de sus oyentes y tests. Test AC938.
3. `DamageNumber`/`DamageNumberPool` con `tint`, y crítico blanco. Tests AC931–AC935, AC937.
4. Cierre: enmienda 4.18.0, `CLAUDE.md` (próximo AC libre), tests de la spec y de las suites tocadas, smoke test, checklist y estado **Implementada**.

## 9. Notas de implementación

(Se completa al implementar.)

## 10. Checklist de review (constitución)

- [ ] Identidad (I) · [ ] Arte (II) · [ ] Datos (III) · [ ] GDScript (IV) · [ ] Performance (V) · [ ] Input (VI) · [ ] Combate (VII) · [ ] Calidad
