# Feature: Indicador del área de la Estocada + teclas de habilidad

- **Estado:** Implementada (2026-09-25, 124 tests GdUnit4 en verde, smoke test headless sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v2.1.0 (sin enmiendas ni excepciones)
- **Pilar (Principio I):** Combate. El jugador ve qué cubre la Estocada (largo y ancho), dónde va a pegar mientras la castea y cómo crece con sus mejoras.
- **Dependencias:** `ability-system.md`, `attack-indicator.md` (Implementadas).

## 1. Objetivo

- Al **pulsar** la habilidad se dibuja en el suelo el **contorno del rectángulo** del hitbox de la Estocada: `HIT_RANGE` de largo por `HIT_WIDTH` de ancho, desde los pies del jugador hacia la dirección del golpe (ya orientada al enemigo auto-apuntado).
- Mientras dura el casteo se mantiene visible con `start_transparency` y funciona como aviso. Al caer el golpe se desvanece en `fade_duration` y se oculta.
- Queda fijo en el mundo, como la estela del ataque básico.
- Mismo lenguaje visual que el indicador del ataque básico: líneas finas de `BoxMesh` (Principio II) con `materials/attack_indicator_material.tres` (celeste pálido, no usa colores reservados).
- **Teclas** (enmienda de `ability-system.md`): `ability_basic` = **E**, `dash` = **click derecho**, `ability_ultimate` = **R**.

## 2. Estructura

### 2.1 Archivos nuevos

```
res://
├── resources/ability_indicator_config.gd                # AbilityIndicatorConfig
├── data/abilities/thrust/thrust_indicator_config.tres
└── components/abilities/ability_rect_indicator.gd       # AbilityRectIndicator (Node3D, top_level)
```

### 2.2 Datos (Principio III)

| Resource | Campos y valores iniciales |
|---|---|
| `AbilityIndicatorConfig` | `line_width 0.06` m · `line_thickness 0.02` m · `ground_offset 0.05` m · `fade_duration 0.25` s · `start_transparency 0.5` |

El largo y el ancho salen de los stats efectivos `HIT_RANGE` y `HIT_WIDTH`, así que las mejoras se reflejan solas.

### 2.3 Escena

```
ThrustAbility (thrust_ability.tscn)
└── Indicator : AbilityRectIndicator (top_level)
```

El indicador pertenece a la habilidad: cada habilidad futura trae el suyo.

## 3. Interfaz pública

- `AbilityRectIndicator`:
  - `show_rect(origin, yaw, length, width)` coloca 4 segmentos (lado izquierdo, lado derecho, borde lejano, borde cercano), los muestra con `start_transparency` y los deja quietos hasta `start_fade()`.
  - `start_fade()` y `advance(delta)` hacen el fundido hacia la transparencia 1 y ocultan el indicador al terminar.
  - También expone `is_showing()`, `get_segment_count()`, `get_segment(i)` y `get_transparency()`.
- `ThrustAbility`: `begin()` llama a `show_rect(...)` después de girar hacia el enemigo. `release()` llama a `start_fade()`. Expone `get_indicator()`.
- `AbilityComponent.get_behavior()`.
- Textos: la ranura básica del HUD muestra "E". El menú inicial dice "Se lanza con E".

## 4. Criterios de aceptación

- **AC61** Al pulsar, el indicador es visible y tiene 4 segmentos. Los lados miden `HIT_RANGE` y los bordes cubren `HIT_WIDTH`. El centro del borde lejano está a `HIT_RANGE` del origen, en la dirección del enemigo apuntado (±0.01).
- **AC62** Con mejoras de alcance (+1) y ancho (+0.4), el rectángulo mide 4.5 × 1.4.
- **AC63** Durante el casteo, la transparencia es `start_transparency`. Tras el golpe se desvanece (a mitad del fundido está entre el inicio y 1) y, pasado `fade_duration`, está oculto.
- **AC64** El indicador queda fijo en el mundo: si el jugador se mueve después, su posición no cambia.
- **AC65** InputMap: E = habilidad básica, click derecho = dash, R = ultimate, sin bindings compartidos (reemplaza a AC58).
- **AC66** Regresión: la suite completa sigue en verde.
  - *Nota:* el enum de los segmentos se llama `Edge` y no `Side`, porque `Side` es un enum global del motor y GDScript no los distingue en los parámetros tipados.

### Review de la constitución (cierre)
- **I:** Combate. El indicador comunica el hitbox.
- **II:** solo `BoxMesh` con el material `.tres` compartido del indicador de ataque. No se genera ninguna malla por código.
- **III:** los valores visuales están en `thrust_indicator_config.tres`. El largo y el ancho salen de los stats efectivos.
- **IV:** tipado completo y `_process` delgado.
- **V:** los 4 segmentos se crean una vez y se reutilizan, y el proceso se apaga cuando el indicador está oculto.
- **VI:** solo acciones del InputMap.

## 5. Fuera de alcance

- Indicador para habilidades con otras formas de hitbox.
