# Feature: Sistema de clases (Guerrero)

- **Estado:** Implementada (2026-09-25, 260 tests GdUnit4 en verde, smoke test headless del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v2.4.0 (sin enmiendas ni excepciones)
- **Pilares (Principio I):**
  - **Progresión:** la clase define los stats base y el pool de habilidades de la run, así que cada clase abre builds distintas.
  - **Combate:** cada clase es un arma con su propio estilo de pelea.
- **Dependencias:** `ability-system.md`, `sandbox-mode.md` (Implementadas).

## 1. Objetivo

- **Clase = tipo de arma.** La relación es 1:1 y fija para siempre: el Guerrero es la espada. Ninguna clase cambia de arma, ni dentro de la run ni en el futuro. No existe un sistema de "equipar arma": elegir la clase *es* elegir el arma.
- Cada clase define sus **stats base** (alcance, arco y velocidad de ataque dependen del arma) y su **pool de habilidades**.
- La espada, el ataque actual y las habilidades existentes (Estocada, Golpe Veloz) pasan a ser el **Guerrero**.
- Flujo: **Jugar → Modo → Clase → Arena → elegir habilidad (solo del pool de la clase)**. La pantalla de clase se muestra aunque haya una sola.

## 2. Estructura

### 2.1 Datos (Principio III)

| Resource | Campos |
|---|---|
| `CharacterClassData` (`resources/character_class_data.gd`) | `title`, `description`, `base_stats: PlayerStats`, `abilities: AbilityCatalog` |
| `ClassCatalog` (`resources/class_catalog.gd`) | `classes: Array[CharacterClassData]` |

```
data/classes/
├── class_catalog.tres           # classes = [warrior]
└── warrior/
    ├── warrior.tres             # "Guerrero", base_stats = data/classes/warrior/warrior_stats.tres
    └── warrior_abilities.tres   # Estocada + Golpe Veloz (reemplaza data/abilities/ability_catalog.tres)
```

- El arma del Guerrero es la espada que ya vive en `player.tscn` (`SwordPivot`, `SwordSwing`, `AttackComponent`). Cuando exista la 2.ª clase, su spec agrega a `CharacterClassData` la escena de **su** arma (campo fijo por clase) y la espada se mueve a su propia escena.
  - **Hecho (2026-09-25, `berserker.md`):** `CharacterClassData.weapon: WeaponData`; la espada vive en `entities/player/weapons/sword.tscn`.

### 2.2 Escenas

```
MainMenu (main_menu.tscn)
└── Center/Layout
    ├── MainPanel
    ├── ModePanel      # elegir modo ahora abre ClassPanel
    └── ClassPanel     # NUEVO
        ├── ClassTitle          "Clase"
        ├── Classes             # una carta por clase del catálogo
        │   └── ClassCardTemplate (oculto, se duplica)
        └── ClassBackButton     "Volver" → ModePanel

Player (player.tscn)  # + default_class = warrior.tres
Arena  (arena.tscn)   # WaveManager pierde ability_catalog
```

## 3. Interfaz pública

- **`GameSession`:** `character_class: CharacterClassData` (null = no elegida). Sobrevive a "Reintentar", igual que el modo.
- **`MainMenu`:** `class_catalog: ClassCatalog`; señal `class_chosen(character_class)`; `choose_mode(mode)` guarda el modo y muestra las clases (ya no carga la arena); `show_classes()`, `is_showing_classes()`, `get_offered_classes()`; `choose_class(c)` guarda la clase y carga la arena.
- **`StatsComponent.set_base_stats(stats)`:** reemplaza la base, recalcula y emite `stats_changed`.
- **`Player`:** `default_class: CharacterClassData`; `get_character_class()` = `Session.character_class` o, si es null, `default_class` (arena cargada sin menú: tests, F6). En `_ready` aplica los stats base de la clase antes de configurar la vida.
- **`WaveManager.offer_abilities()`:** ofrece `player.get_character_class().abilities.get_for_slot(BASIC)`.

## 4. Criterios de aceptación

- **AC176** `warrior.tres`: `base_stats` es `player_stats.tres` y `abilities` contiene exactamente Estocada y Golpe Veloz. `class_catalog.tres` contiene al Guerrero.
- **AC177** Elegir un modo lo guarda en `Session` y muestra `ClassPanel` sin cargar la arena. "Volver" en `ClassPanel` vuelve a `ModePanel`.
- **AC178** `ClassPanel` muestra una carta por clase del catálogo (hoy 1: Guerrero) con título y descripción.
- **AC179** `choose_class(warrior)` guarda la clase en `Session`, emite `class_chosen` y conserva el modo.
- **AC180** Arena sin clase en `Session`: el jugador usa el Guerrero (`default_class`), con stats base de `player_stats.tres`, y el `AbilityPicker` ofrece Estocada y Golpe Veloz.
- **AC181** Arena con una clase de prueba en `Session` (otros `base_stats`, pool de una sola habilidad): `StatsComponent` usa esos stats, la vida inicial es su `MAX_HEALTH` y el `AbilityPicker` ofrece solo esa habilidad.
- **AC182** Las mejoras del personaje se suman sobre la base de la clase (+DAMAGE sobre la clase de prueba = base de la clase + amount).
- **AC183** Regresión: la suite completa sigue en verde.

### Review de la constitución (cierre)
- **I:** sirve a Progresión y Combate, como declara la spec.
- **II:** sin arte nuevo. El menú de clases es UI 2D con `Button`, igual que el de modos.
- **III:** stats base y pool de habilidades viven en `warrior.tres` / `warrior_abilities.tres`. Ningún Resource se muta: `StatsComponent.set_base_stats` solo cambia la referencia. Los tests crean su clase de prueba con `duplicate()`.
- **IV:** tipado estático completo. `_ready` delgado (`_apply_character_class()`).
- **V:** la clase se lee una vez al cargar la arena y una vez al ofrecer habilidades; nada por frame.
- **VI:** sin input nuevo.

## 5. Plan de implementación

1. Resources `CharacterClassData`, `ClassCatalog` y sus `.tres`.
2. `StatsComponent.set_base_stats`, `Player.default_class` / `get_character_class`.
3. `WaveManager` lee el pool de la clase; se quita `ability_catalog` y se borra `data/abilities/ability_catalog.tres`.
4. `GameSession.character_class` y `ClassPanel` en `MainMenu`.
5. Tests AC176–AC182, suite completa (AC183), smoke test, checklist de la constitución, spec **Implementada**.

## 6. Fuera de alcance

- Una segunda clase y mover la espada a una escena de arma propia (se hace junto con la 2.ª clase).
- Cambiar de arma: no está previsto nunca.
- Pool de ultimates por clase, mostrar la clase en pausa/HUD, mejoras de personaje exclusivas por clase.
