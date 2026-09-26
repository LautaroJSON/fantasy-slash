# Feature: Indicador visual del área de ataque

- **Estado:** Reemplazada (2026-09-25) por la estela del arma de `weapon-trail.md`. Antes: Implementada (93 tests GdUnit4 en verde)
- **Constitución:** `docs/constitution.md` v2.1.0 (sin enmiendas ni excepciones)
- **Pilar (Principio I):** Combate. El jugador entiende qué cubre cada golpe (alcance y ancho) y cómo cambia con las mejoras de Rango y Arco de ataque. Así puede posicionarse mejor.
- **Dependencias:** `combat-mvp.md` y `combat-feedback.md` (Implementadas).

## 1. Objetivo

En cada swing, **acierte o no**, se dibuja en el suelo un **arco fino y translúcido** en el borde del área que cubre el golpe:
- a la distancia `ATTACK_RANGE` del jugador;
- abarcando `ATTACK_ARC` grados, centrado en la dirección del golpe.

Es una aproximación discreta, no la hitbox en sí:
- solo se marca el borde exterior;
- dura lo mismo que un swing (0.25 s) y se desvanece;
- queda donde se hizo el golpe, como una estela, aunque el jugador se siga moviendo.

**Por qué segmentos y no un sector relleno:** no existe una primitiva de Godot con forma de sector circular. Generar esa malla por código violaría el Principio II. El arco se aproxima con segmentos finos de `BoxMesh` (primitiva) unidos por sus extremos, y con 9 segmentos ya se ve curvo.

## 2. Estructura

### 2.1 Archivos nuevos

```
res://
├── resources/attack_indicator_config.gd     # AttackIndicatorConfig
├── data/ui/attack_indicator_config.tres
├── materials/attack_indicator_material.tres # celeste pálido, unshaded, translúcido
└── components/attack_indicator.gd           # AttackIndicator (Node3D)
```

### 2.2 Datos (Principio III)

| Resource | Campos y valores iniciales |
|---|---|
| `AttackIndicatorConfig` | `segment_count 9` · `line_width 0.06` m · `line_thickness 0.02` m · `ground_offset 0.05` m (altura sobre los pies, evita z-fighting con el piso) · `duration 0.25` s · `start_transparency 0.5` (0 = opaco; arranca a medias para ser discreto) |
| `attack_indicator_material.tres` | `Color(0.55, 0.85, 1.0)` celeste pálido (no usa colores reservados) · `shading_mode` unshaded · `transparency` alpha · sin sombras |

No hay valores nuevos de gameplay: el radio y el ancho salen de los stats efectivos `ATTACK_RANGE` y `ATTACK_ARC`, así que las mejoras se reflejan solas.

### 2.3 Escena

`player.tscn` agrega:
```
Player
└── AttackIndicator (Node3D, top_level = true) — attack_indicator.gd
    └── (segment_count × MeshInstance3D, creados una vez en _ready, con un BoxMesh unitario compartido)
```

`top_level` hace que el arco no siga al jugador después del golpe: queda donde se hizo el swing.

## 3. Interfaz pública

### 3.1 `AttackIndicator` (Node3D)
- `@export attack: AttackComponent, visual: Node3D, stats: StatsComponent, config: AttackIndicatorConfig, material: StandardMaterial3D`
- En `_ready`:
  - crea los `segment_count` segmentos, un `BoxMesh` 1×1×1 compartido con `material` (Principio V: nada se instancia por golpe);
  - se conecta a `attack.attacked`;
  - arranca oculto.
- `show_swing() -> void`:
  - se ubica en los pies del jugador (+`ground_offset`), con el yaw de `visual`;
  - distribuye los segmentos sobre el arco actual (`ATTACK_RANGE`, `ATTACK_ARC`);
  - reinicia el fundido y se muestra.

  Si un swing llega antes de que termine el fundido anterior, simplemente reinicia.
- `advance(delta: float) -> void`: avanza el fundido (`transparency` por segmento, de `start_transparency` a 1). Al llegar a `duration` se oculta y desactiva `_process`. Lo llama `_process` y también los tests.
- `get_segment_count() -> int` · `get_segment(index: int) -> MeshInstance3D` (para tests) · `is_showing() -> bool`

### 3.2 Geometría (función pura, testeable)
Con `r = ATTACK_RANGE`, `A = ATTACK_ARC` en radianes, `N = segment_count`, para el segmento `i`:
- ángulo del centro `θᵢ = −A/2 + A·(i + 0.5)/N`, con 0 = frente (−Z local)
- posición local `(r·sin θᵢ, 0, −r·cos θᵢ)`, `rotation.y = −θᵢ` (tangente al arco)
- escala `(2r·sin(A/(2N)), line_thickness, line_width)`: la cuerda, así los segmentos se tocan por los extremos

Con A = 360° el arco se cierra en un círculo completo.

### 3.3 Cambios en código existente
Ninguno. El indicador solo escucha la señal `attacked`, que `AttackComponent` ya emite en cada swing, acierte o no.

## 4. Lógica de estado

```
[oculto] --attacked--> [visible, transparency = start] --advance(duration)--> [oculto]
                            ^                 |
                            └── attacked ─────┘ (reinicia)
```

## 5. Criterios de aceptación

- **AC39** Tras un swing sin enemigos cerca (golpe al aire), el indicador es visible y tiene `segment_count` segmentos. El centro de cada uno está a distancia XZ = `ATTACK_RANGE` (±0.01) del punto del swing.
- **AC40** Los segmentos cubren el arco: el primero y el último quedan a ±(A/2 − A/(2N)) de la dirección del golpe, que es la del enemigo auto-apuntado cuando lo hay. Segmentos consecutivos se tocan: la cuerda es igual a la distancia entre centros (±0.01).
- **AC41** Tras mejoras de Rango (+0.9) y Arco (+30°), el swing siguiente dibuja el arco a 2.9 m y 150°.
- **AC42** Al inicio del fundido `transparency == start_transparency`. A mitad está entre el inicio y 1. Tras `duration` el indicador está oculto.
- **AC43** El arco queda en el mundo: si el jugador se mueve después del swing, la posición del indicador no cambia.
- **AC44** Un segundo swing durante el fundido reinicia la transparencia a `start_transparency` y reubica el arco.
- **AC45** Regresión: la suite completa sigue en verde.
  - *Nota:* al cerrar esta feature apareció un test inestable preexistente (AC19 de `combat-mvp`). Si el primer frame tardaba, la física recuperaba varios pasos y los enemigos avanzaban antes de la medición. Se corrigió pausando el árbol mientras se espera ese frame en `arena_waves_test.gd`. La suite pasó dos corridas seguidas.

*Manual:* el arco se ve discreto (fino y translúcido), no tapa a los enemigos y se lee el cambio al mejorar Rango o Arco.

## 6. Plan de implementación

1. **Datos:** `AttackIndicatorConfig` + `.tres` + material.
2. **Tests AC39-AC44** usando `player.tscn`, con y sin enemigo.
3. **`AttackIndicator`:** creación de segmentos, `show_swing`, `advance` y geometría de §3.2.
4. **Integración:** nodo en `player.tscn` con sus exports.
5. **Cierre:** suite completa (AC45), smoke test en la arena, checklist de la constitución, spec **Implementada**. **Avisar.**

## 7. Fuera de alcance

- Sector relleno o "barrido" animado (requeriría una malla no primitiva).
- Indicador del ataque de los enemigos (telegraph).
- Opción para desactivar el indicador desde un menú.
