# Feature: nombre flotante de las Aflicciones sin daño

- **Estado:** Propuesta (2026-09-27). ACs reservados: **AC951–AC960** (se usan AC951–AC955).
- **Constitución:** `docs/constitution.md` v4.18.1 → **enmienda MINOR a 4.19.0** (Principio II: tabla de colores, ver §5).
- **Pilar (Principio I):** **combate** (legibilidad). Hoy, cuando se llena la barra de Escarcha o de Corrosión no aparece nada sobre el enemigo: solo cambia su ícono. Un texto flotante con el nombre, en el color de la Aflicción, confirma el disparo en el mismo lugar donde el jugador mira los números.
- **Dependencias:** `affliction.md`, `affliction-damage-colors.md` (números de color, pool de números), `frost-freeze.md` (colores de Corrosión y Escarcha).

## 1. Diseño

- **Cuándo:** cada vez que se dispara una Aflicción **que no hace daño**. Hoy son **Escarcha** ("Escarcha", cian) y **Corrosión** ("Corrosión", gris claro). Veneno y Estallido siguen mostrando sus números de daño, como hasta ahora.
- **Qué:** el `title` de la Aflicción, con el mismo estilo que un número normal (tamaño, subida, duración y desvanecido), sin "!" y en el color de su barra. En un boss con Escarcha (lentitud) también dice "Escarcha".
- **Dónde:** sobre la cabeza del enemigo, igual que un número (`DamageNumberPool`, mismo pool: no se crean nodos).
- **Datos:**
  - `AfflictionData.damage_number_material` pasa a ser el material de **su texto flotante**: los números del Estallido o el nombre de una Aflicción sin daño. `frost.tres` y `corrosion.tres` (de `data/afflictions/`) usan `materials/afflictions/frost_damage_number_material.tres` y `corrosion_damage_number_material.tres`, con el color de su barra.
  - `AfflictionData.deals_damage() -> bool` (puro): tiene estallido, o su estado es de daño en el tiempo.
- **Lógica:** `DamageNumberPool` se conecta a `AfflictionLoadout.triggered(enemy, type)`; si `type.deals_damage()` es falso, llama `spawn_text(type.title, posición, type.damage_number_material)`. `DamageNumber.show_text(text, at, tint)` usa el estilo normal con la fuente recta.

## 2. Criterios de aceptación (AC951–AC955)

- **AC951** Al dispararse Escarcha sobre un enemigo aparece un texto flotante "Escarcha" con `frost_damage_number_material.tres` (cian de su barra), tamaño y duración de un número normal, sin "!" y sin cursiva.
- **AC952** Lo mismo con Corrosión: "Corrosión" en gris claro.
- **AC953** Veneno y Estallido no muestran su nombre: siguen mostrando solo sus números.
- **AC954** Datos: `deals_damage()` es verdadero en Veneno y Estallido y falso en Escarcha y Corrosión; el color de cada material de texto es el de su barra.
- **AC955** El texto usa el pool existente: disparar muchas Aflicciones no crea nodos nuevos.

## 3. Tests

- `test/effects/damage_number_pool_test.gd` (ampliado): AC951–AC953, AC955.
- `test/resources/affliction_data_test.gd` (ampliado): AC954.

## 4. Plan

1. Materiales y `deals_damage()`. Test AC954.
2. `DamageNumber.show_text` y `DamageNumberPool` conectado a `triggered`. Tests AC951–AC953, AC955.
3. Cierre: enmienda 4.19.0, `CLAUDE.md`, tests de la spec y de las suites tocadas, estado **Implementada**.

## 5. Enmienda de la constitución (MINOR 4.18.1 → 4.19.0)

Principio II, tabla de colores: la fila "Números de daño de Aflicción (Veneno, Estallido)" pasa a "Textos flotantes de Aflicción: números de daño (Veneno, Estallido) y nombre de las que no hacen daño (Escarcha, Corrosión)", con el color de la barra de su Aflicción (no reservado).

## 6. Notas de implementación

(Se completa al implementar.)
