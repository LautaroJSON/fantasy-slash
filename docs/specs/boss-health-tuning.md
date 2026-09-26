# Vida y defensa de los bosses para peleas de ~1:30

- **Estado:** Implementada (2026-09-26), junto con `enemy-level-pace.md`. Se corrieron solo los suites tocados (`boss_health_tuning_test`, `test/entities/enemy` completo, `boss_challenge_run_test`, `arena_waves_test`, `boss_hud_bar_test`, `cooldown_hud_test`): todos en verde, 0 orphans. Smoke test de la arena sin errores. La suite completa no se corrió.
- **Constitución:** `docs/constitution.md` **v4.6.0**, sin enmienda
- **Pilar (Principio I):** Supervivencia + Progresión. Las peleas de boss duran lo mismo (~90 s) en cualquier punto de la run: no se vuelven un trámite al principio ni una esponja de daño después. Las cartas de daño se notan contra el boss, porque la defensa ya no se come los golpes chicos.
- **Tipo:** balance (datos). Solo cambian `titan_stats.tres`, `verdugo_stats.tres` y `colmena_stats.tres`.
- **Dependencias:** `boss-verdugo.md`, `boss-titan.md`, `boss-colmena.md`, `enemy-levels.md`.

## Cálculo

**DPS de referencia (promedio de las tres clases, sin cartas):**

| Clase | Ataque básico | Habilidad | DPS |
|---|---|---|---|
| Guerrero | 15 × 1.2 × 1.05 = 18.9 | Estocada ≈ +2.5 | ≈ 21 |
| Berserker | 25 × 0.6 × 1.05 = 15.75 | Giro ≈ +26 | ≈ 38 |
| Samurái | 14 × 1.6 × 1.15 = 25.8 | Envainar (sin atacar mientras carga) | ≈ 23 |
| **Promedio** | | | **≈ 27** |

**Crecimiento con las cartas:**
- Una carta por oleada; se asume que la mitad son ofensivas y que cada una suma ≈ +10 % de DPS. Resultado: **DPS(oleada) ≈ 27 × (1 + 0.05 × (oleada − 1))**.
- Las oleadas de boss son la 4, la 8, la 12…, y en ellas el nivel es oleada ÷ 2. En función del nivel queda **DPS(nivel) ≈ 27 × (1.05 + 0.1 × (nivel − 1))**.

**Vida efectiva para 90 s pegando el 60 % del tiempo:**
- `vida efectiva = DPS × 90 × 0.6` → **1 531 a nivel 1, +9.5 % de esa base por nivel**.
- Oleada 4: ≈ 1 680. Oleada 8: ≈ 1 970. Oleada 20: ≈ 2 840.

**Defensa:** resta un valor fijo por golpe, así que castiga a las clases de golpes chicos. Pasa a ser ≈ 10 % del golpe promedio: base **2**, +0.25 por nivel, tope 8. Como se come ~10 % del daño, la vida se baja un 10 % para compensar.

**Multiplicador de cada boss** (cuánto más le cuesta al jugador bajarle la vida):
- **Verdugo × 1:** sin armadura ni escudo.
- **Titán × 1.5:** armadura del 70 %. Se asume que la mitad del daño entra en las manos apoyadas o durante el aturdimiento.
- **Colmena × 2.2** (era × 2.8; se bajó al aprobarse `enemy-level-pace`, que alarga la exposición a 10 s / 7 s): solo se le pega expuesta. Se asume un ciclo de ~22 s: 2.25 s de invocación + ~14 s matando esbirros + 6 s expuesta, pegando el 80 % de esa ventana. Queda ≈ 24 s de daño útil en 90 s.

## Valores nuevos

| Boss | Vida base (nivel 1) | Crecimiento de vida | Defensa base | Crecimiento de defensa (tope) |
|---|---|---|---|---|
| **Verdugo** | 900 → **1 380** | +20 % → **+9.5 %** por nivel | 6 → **2** | +0.5 (tope 12) → **+0.25 (tope 8)** |
| **Titán** | 1 400 → **920** | +20 % → **+9.5 %** | 8 → **2** | +0.5 (tope 14) → **+0.25 (tope 8)** |
| **Colmena** | 700 → **630** | +20 % → **+9.5 %** | 4 → **2** | +0.5 (tope 9) → **+0.25 (tope 8)** |

**Resultado por oleada** (vida / defensa):

| Oleada (nivel) | Verdugo | Titán | Colmena |
|---|---|---|---|
| 4 (2) | 1 511 / 2.25 | 1 007 / 2.25 | 690 / 2.25 |
| 8 (4) | 1 773 / 2.75 | 1 182 / 2.75 | 810 / 2.75 |
| 12 (6) | 2 036 / 3.25 | 1 357 / 3.25 | 929 / 3.25 |
| 20 (10) | 2 560 / 4.25 | 1 707 / 4.25 | 1 169 / 4.25 |
| 52+ (25) | 4 526 / 8 | 3 018 / 8 | 2 066 / 8 |

**Qué no cambia:**
- El daño, la velocidad y el resto de los stats de los bosses.
- La vida de las manos del Titán sigue siendo el 30 % de la suya (302 en la oleada 4).
- El Rage sigue sumando encima.

## Límites de la estimación

- **Diferencia entre clases:** la vida es una sola. Con el Berserker (DPS ≈ 38) la pelea dura ~1:05; con el Guerrero (≈ 21), ~1:55. Si molesta, la vida se puede adaptar a la clase en otra spec.
- **Colmena:** su duración depende también de cuánto se tarda en matar a los esbirros, cuya vida crece +20 % por nivel (más rápido que el DPS del jugador). En oleadas altas su pelea se alarga. Si pasa, se ajusta el tamaño de las tandas o la vida de los esbirros invocados.
- **Todo es una estimación:** las cartas que salen, la puntería y el esquive cambian mucho la duración real. Los valores quedan en los `.tres` para ajustarlos jugando.

## Criterios de aceptación (AC552–AC555, reservados)

- **AC552** (`test/resources/boss_health_tuning_test.gd`): con `write_scaled`, la vida y la defensa de los tres bosses en los niveles 2, 4, 10 y 25 coinciden con la tabla (tolerancia 1 punto de vida y 0.01 de defensa).
- **AC553:** la vida efectiva de cada boss en la oleada 4 (vida ÷ (1 − defensa ÷ golpe promedio de 20) × multiplicador del boss) queda en 1 680 ± 5 %, que son los 90 s de referencia.
- **AC554:** daño, velocidad, intervalo y cuerpo de los tres bosses no cambian.
- **AC555:** tests existentes que dependían de los números viejos, adaptados sin cambiar lo que verifican:
  - `titan_test` (golpe de referencia, vida de las manos y armadura);
  - `colmena_test` (golpe de referencia);
  - `boss_hud_bar_test` (vida del Titán en la barra, "1007 / 1007", y el golpe del 10 %);
  - `cooldown_hud_test` y `boss_body_test` si usan valores fijos.

## Plan de implementación

1. Reservar AC552–AC555 en `CLAUDE.md` (próximo libre → AC556).
2. Cambiar vida base, crecimiento de vida y defensa (base, crecimiento y tope) en los tres `.tres`.
3. Tests AC552–AC554 y adaptar los tests con números fijos (AC555).
4. Correr los suites de bosses (`titan_test`, `verdugo_test`, `colmena_test`, `boss_body_test`, `boss_challenge_run_test`, `boss_hud_bar_test`, `cooldown_hud_test`) y el nuevo. Smoke test.
5. Checklist, spec **Implementada** y `CLAUDE.md`.

## Review (checklist de la constitución)

- [x] **I.** Supervivencia y Progresión, como se explica arriba.
- [x] **II.** Sin cambios visuales.
- [x] **III.** Solo datos en `.tres`.
- [x] **IV–VI.** Sin código nuevo de gameplay.

## Notas de implementación

- **ACs renumerados:** la spec se aprobó con AC546–AC549, pero la spec `dash-iframes` de otra sesión los tomó antes. Quedaron en **AC552–AC555**, con el mismo contenido.
- **Colmena:** vida base **630** (multiplicador × 2.2 en vez de × 2.8), por la exposición más larga de `enemy-level-pace`.
- **Tests adaptados (AC555):**
  - `titan_test`: golpe de referencia 102, manos de 276 y golpe para romper una mano (`BREAK_HIT` = 290), que no baja al Titán de su umbral de fase 2.
  - `colmena_test`: golpe de referencia 102.
  - `boss_hud_bar_test`: el Titán de nivel 2 muestra "1008 / 1008" y el golpe del 10 % es de 338.05.
