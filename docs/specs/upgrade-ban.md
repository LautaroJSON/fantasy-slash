# Feature: Carta roja de bloqueo de mejoras

- **Estado:** Implementada (2026-09-25, 132 tests GdUnit4 en verde, smoke test headless sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v2.1.0 (sin enmiendas ni excepciones)
- **Pilar (Principio I):** Progresión. El jugador orienta su build dentro de la run: saca del sorteo las mejoras que no quiere (típicamente vida o defensa) a cambio de resignar la mejora de esa oleada.
- **Dependencias:** `combat-mvp.md` (oferta de cartas), `ability-system.md` (pool combinado).

## 1. Objetivo

- Tras superar cada **3 oleadas** (3, 6, 9…) la oferta suma una **4ª carta roja**: "Bloquear mejora".
- Elegirla **reemplaza la mejora de esa oleada** y abre un submenú con todas las mejoras disponibles del pool (personaje y habilidad equipada). Se elige **una**, que no vuelve a salir por el resto de la run.
- El submenú tiene **Volver**, que regresa a la oferta de 4 cartas.
- Tope: **10 bloqueos** por run. Alcanzado el tope, la carta roja deja de aparecer.
- Morir y reintentar recarga la escena, así que los bloqueos se reinician.

## 2. Estructura

### 2.1 Archivos nuevos

```
res://
├── resources/card_ban_rules.gd        # CardBanRules
├── data/upgrades/card_ban_rules.tres
├── ui/card_style.gd                   # CardStyle (estilos de carta reutilizables)
└── ui/upgrade_ban_picker.gd / .tscn   # UpgradeBanPicker (submenú)
```

### 2.2 Datos (Principio III)

| Resource | Campos y valores |
|---|---|
| `CardBanRules` | `every_waves 3` · `max_bans 10` · `title "Bloquear mejora"` · `description`. Método puro `is_offered(cleared_wave, bans_used)`. |
| `UpgradePickerConfig` (+) | `ban_card_color Color(0.8, 0.2, 0.2)` · `ban_card_hover_color Color(0.9, 0.3, 0.3)` · `ban_card_font_color Color(1, 1, 1)` |

El rojo es UI 2D y no es un color reservado del Principio II.

### 2.3 Estado
`RunState` guarda los bloqueos de la run: `ban(card)`, `is_banned(card)`, `get_banned()`, `ban_count()`.

## 3. Flujo

1. Se limpia la oleada N. `WaveManager` sortea 3 cartas del pool **sin las bloqueadas** y agrega la roja si `CardBanRules.is_offered(N, bans)`.
2. Si eliges la roja, `UpgradePicker` se oculta sin despausar y emite `ban_requested`. `WaveManager` abre `UpgradeBanPicker`.
3. **Volver:** `ban_cancelled` → `UpgradePicker.reopen()`, con la misma oferta.
4. **Bloquear:** `ban_chosen(card)` → `RunState.ban(card)`, después `next_wave()` y `start_wave()`.

## 4. Criterios de aceptación

- **AC67** `is_offered`: con 0 bloqueos es verdadero solo en las oleadas 3, 6 y 9 (de 1 a 9). Con 10 bloqueos siempre es falso.
- **AC68** `UpgradeOffer.without` excluye las bloqueadas. Con 10 bloqueos, 500 sorteos nunca ofrecen una bloqueada y siempre dan 3 cartas distintas.
- **AC69** Las oleadas 1 y 2 ofrecen 3 cartas sin la roja. La oleada 3 ofrece 3 + la roja, y la roja usa `ban_card_color`.
- **AC70** Elegir la roja abre el submenú con todo el pool disponible, sigue pausado y la pausa no abre. Volver reabre la oferta idéntica.
- **AC71** Bloquear una carta la registra en `RunState`, no cambia stats, avanza a la oleada 4 y la arranca. La carta ya no aparece en el submenú ni en el pool disponible.
- **AC72** Con 10 bloqueos, la roja no aparece en la oleada 3.
- **AC73** Una arena nueva arranca con 0 bloqueos.
- **AC74** Regresión: la suite completa en verde.
  - *Nota:* `UpgradePicker.show_offer` ahora recibe `with_ban`, así que se actualizó el llamado en `ability_run_test.gd`. Los estilos de carta coloreada se extrajeron a `CardStyle`, que usan ambos pickers.

### Review de la constitución (cierre)
- **I:** Progresión. Da control sobre la build a cambio de una mejora.
- **II:** no hay elementos 3D nuevos. El rojo es UI 2D y no es un color reservado.
- **III:** la frecuencia, el tope, los textos y los colores viven en `.tres`. Los bloqueos son estado de la run en `RunState` (Node) y nunca se mutan Resources.
- **IV:** tipado completo, sin lógica en callbacks de ciclo de vida.
- **V:** nada corre por frame. Los estilos se construyen una vez y las listas se arman solo al abrir un menú.
- **VI:** menús con mouse, sin inputs nuevos.

## 5. Fuera de alcance

- Desbloquear mejoras.
- Mostrar la lista de bloqueos en el menú de pausa.
- Condiciones de aparición distintas de "cada N oleadas".
