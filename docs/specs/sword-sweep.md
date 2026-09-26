# Feature: Barrido horizontal de la espada en el ataque básico

- **Estado:** Implementada (2026-09-25, 151 tests GdUnit4 en verde, smoke test headless limpio)
- **Constitución:** `docs/constitution.md` v2.1.0 (sin enmiendas ni excepciones)
  - *Revisión (2026-09-25):* `swing_duration` pasó de `PlayerTuning` a `SwordSwingConfig` (por clase) y se escala con la velocidad de ataque. Ver `class-sweep-timing.md`.
- **Pilar (Principio I):** Combate. El movimiento de la espada coincide con la zona que golpea, así el golpe se lee de un vistazo.
- **Dependencias:** `combat-mvp.md`, `attack-indicator.md` (Implementadas). Reemplaza la animación `swing` (tajo vertical) de `combat-mvp`.

## 1. Objetivo

- El hitbox del ataque básico es un abanico horizontal (`ATTACK_ARC`, `ATTACK_RANGE`). La espada ahora **barre en horizontal** cubriendo exactamente ese arco, mejoras de Arco incluidas.
- El barrido **alterna de lado** en cada golpe: al mantener el click se ve como un combo.
- La espada mantiene su largo (1.2 m). El arco del suelo sigue marcando el alcance real.
- El hitbox, el daño y el momento del impacto no cambian.

## 2. Diseño

- `SwordSwing` (nodo en `player.tscn`) mueve `Visual/SwordPivot` por código:
  - El yaw va de `±ATTACK_ARC/2` a `∓ATTACK_ARC/2` durante `min(swing_duration, intervalo)`, con easing (rápido al inicio).
  - La hoja va horizontal (`blade_tilt`), con la empuñadura a `hilt_offset` del centro del cuerpo.
  - Después vuelve a la pose de reposo de la escena en `recover_duration`.
- Las habilidades siguen usando el `AnimationPlayer`. Si empieza una animación de habilidad, el barrido se cancela sin tocar la espada.
- Se elimina la animación `swing` de `player.tscn`. `AttackComponent` usa `sword_swing` en lugar de `swing_player`.

## 3. Datos (Principio III)

| Resource | Valores |
|---|---|
| `SwordSwingConfig` (`data/classes/warrior/sword_swing_config.tres`) | `pivot_height 1.1` m · `hilt_offset 0.35` m · `blade_tilt -0.15` rad · `sweep_ease 0.4` · `recover_duration 0.12` s |

## 4. Criterios de aceptación

- **AC89** El barrido arranca en `±ATTACK_ARC/2` y termina en `∓ATTACK_ARC/2` (±1°), con la hoja horizontal (`blade_tilt`).
- **AC90** Los golpes consecutivos alternan el lado de inicio.
- **AC91** Con +30° de Arco, el barrido cubre 150°.
- **AC92** Después del barrido y la recuperación, la espada vuelve a la pose de reposo (±0.01).
- **AC93** Una habilidad lanzada durante el barrido lo cancela y reproduce su animación.
- **AC94** Regresión: la suite completa en verde.

### Review de la constitución (cierre)
- **I:** Combate. La legibilidad del golpe mejora.
- **II:** la misma espada negra de `BoxMesh`. Solo se mueve, sin assets nuevos.
- **III:** la pose y los tiempos del barrido viven en `.tres`. El arco sale del stat efectivo. La pose de reposo se toma de la escena y no se duplica.
- **IV:** tipado completo. `_process` delega en `advance`.
- **V:** sin allocations por frame, y el proceso se apaga en reposo.
- **VI:** sin inputs nuevos.

## 5. Fuera de alcance

- Cambiar el largo de la espada o el hitbox.
- Retrasar el impacto hasta que la hoja pase por el enemigo.
