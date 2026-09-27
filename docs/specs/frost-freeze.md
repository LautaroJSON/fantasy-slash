# Feature: Escarcha congela (bosses: lentitud) y colores nuevos de Corrosión y Estallido

- **Estado:** **Implementada** (2026-09-27). Aprobada por el responsable ("implementa") con las decisiones de §2. ACs: AC941–AC946 (reservados AC941–AC950). Constitución enmendada a 4.18.1 (aplicada).
- **Constitución:** `docs/constitution.md` v4.18.0 → **enmienda PATCH a 4.18.1** (Principio II: registro de colores no reservados, ver §6).
- **Pilar (Principio I):** **combate.** Congelar a un enemigo común abre una ventana corta para castigar o reposicionarse; en un boss, una lentitud larga estira sus preparaciones sin anularlo. Los colores nuevos hacen que Estallido se lea como una explosión y Corrosión como desgaste.
- **Dependencias:** `affliction.md` (Escarcha, `SLOW`, colores), `affliction-damage-colors.md` (número del Estallido).

## 1. Estado actual

- Escarcha aplica `frost.tres` (`SLOW`, potencia 0.4, 3 s) a cualquier enemigo: se mueve y actúa al 60 % (movimiento, preparaciones, golpe, recuperación, pausa entre ataques y giro; no la gravedad ni el empuje).
- Corrosión es violeta `Color(0.55, 0.35, 0.8)`; Estallido, azul `Color(0.3, 0.5, 1.0)`.

## 2. Decisiones (del responsable, 2026-09-27)

1. **Comunes:** Escarcha los **congela 1.5 s** (quietos, con el ataque en curso pausado; se los puede golpear y empujar).
2. **Bosses:** Escarcha los **ralentiza un 40 % durante 5 s**, en movimiento y tiempos de ataque (como hoy).
3. **Bosses = Verdugo, Titán y Colmena**; el Escudero y los demás tipos se congelan.
4. Sin VFX de hielo en el cuerpo (otra spec); alcanza con el ícono del estado.
5. **Colores:** Corrosión gris claro `Color(0.7, 0.7, 0.72)` (el gris exacto de los enemigos, `Color(0.5, 0.5, 0.5)`, está reservado). Estallido naranja explosión `Color(1.0, 0.55, 0.15)` (el ámbar quedó libre en 4.18.0; se distingue del rojo anaranjado de los avisos enemigos `Color(1.0, 0.3, 0.1)`).

## 3. Diseño

- **`EnemyStats.resists_control: bool`**: `true` en Verdugo, Titán y Colmena. Un enemigo que resiste el control recibe la versión "resistida" de un efecto de control. Queda disponible para el aturdimiento del re-work del Guerrero.
- **`AfflictionData`**: `+ resisted_debuff: DebuffData` y `+ resisted_effect_value: float`: estado y potencia que se aplican **en lugar** de `debuff`/`effect_value` a los enemigos con `resists_control` (nulo = el mismo estado para todos).
- **Escarcha** (`data/afflictions/frost.tres`): `debuff = frost.tres` (`SLOW`, **1.5 s**), `effect_value = 1.0` (velocidad 0: congelado); `resisted_debuff = frost_chill.tres` (`SLOW`, **5 s**, mismo `id` `frost`, mismo ícono y color), `resisted_effect_value = 0.4`.
- **`AfflictionLoadout._trigger`**: elige `resisted_debuff`/`resisted_effect_value` cuando el enemigo tiene `resists_control` y el tipo los define.
- **Congelado:** con la escala de velocidad en 0, `Enemy` ya se queda quieto sin avanzar su comportamiento (hook de `affliction.md` §4.7): no se mueve, no gira y su preparación se pausa; la gravedad y el empuje siguen.
- **Colores:** `corrosion_material.tres` y el `icon_color` de `corrosion.tres` pasan a gris claro; `burst_material.tres` y `burst_damage_number_material.tres` a naranja.

## 4. Criterios de aceptación (AC941–AC946)

- **AC941** `resists_control` es `true` en Verdugo, Titán y Colmena y `false` en Bruto, Embestidor, Saltador, Hostigador y Escudero.
- **AC942** Escarcha sobre un común lo congela: `get_speed_scale() = 0`, no se mueve ni avanza su comportamiento durante 1.5 s, y después vuelve a velocidad normal.
- **AC943** Escarcha sobre un boss lo ralentiza al 60 % durante 5 s (movimiento y reloj del comportamiento), sin congelarlo.
- **AC944** Un común congelado sigue recibiendo daño y empuje.
- **AC945** Colores: Corrosión `Color(0.7, 0.7, 0.72)` en su barra y en su `icon_color`; Estallido `Color(1.0, 0.55, 0.15)` en su barra y su número de daño.
- **AC946** Los estados de Escarcha (`frost.tres` y `frost_chill.tres`) comparten `id`, ícono y color, y cumplen AC905 (ícono en `assets/icons/status/`).

## 5. Tests

- `test/components/affliction_status_test.gd`: AC942–AC944 (reemplazan las comprobaciones de AC874, que verificaban el 40 % / 3 s en cualquier enemigo; se anota en §7).
- `test/resources/affliction_data_test.gd`: AC941, AC945, AC946 (AC853/AC854 se adaptan a los valores nuevos de Escarcha).
- `test/components/affliction_loadout_test.gd`: disparo de Escarcha sobre un común y sobre un boss (AC942, AC943).

## 6. Enmienda de la constitución (PATCH 4.18.0 → 4.18.1)

Principio II, registro de colores no reservados: Corrosión pasa de violeta a gris claro `Color(0.7, 0.7, 0.72)` (distinto del gris reservado de los enemigos) y Estallido de azul a naranja `Color(1.0, 0.55, 0.15)`.

Historial: `4.18.1 (2026-09-27): Principio II: Corrosión gris claro y Estallido naranja en el registro de colores de Aflicción (ver frost-freeze.md).`

## 7. Notas de implementación

- **Tests:** `affliction_status_test.gd` (AC942–AC944), `affliction_data_test.gd` (AC941, AC945, AC946) y `affliction_loadout_test.gd` (AC942 y AC943 con disparos reales de la barra). En verde junto con `status_icons_test`, `damage_number_pool_test`, las suites de Aflicción y `test/entities/enemy/` (214 tests).
- **Tests viejos adaptados:** `affliction_status_test.gd` AC874 ahora verifica la lentitud con `frost_chill.tres` (el 40 % sigue igual; el caso "un segundo disparo reinicia 3 s" pasa a AC943 con 5 s); `affliction_data_test.gd` AC853 (potencia de Escarcha 1.0 y 0.4 resistida) y AC854 (duración 1.5 s).
- **Cartas de Escarcha:** su texto dice "congela 1.5 s (a los bosses: 40 % más lento durante 5 s)".
- **Pendiente visual:** sin VFX de hielo (otra spec); el congelado se ve por el ícono y porque el enemigo queda quieto.
