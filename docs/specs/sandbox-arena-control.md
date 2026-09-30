# Feature: Sandbox con control de la arena y pausa por pestañas

- **Estado:** Implementada (2026-09-29). Suites de la spec en verde: `sandbox_arena_control_test` (21), `pause_menu_tabs_test` (14), `sandbox_run_test`, `pause_menu_test`, `unique_upgrade_run_test` y `touch_ui_sizes_test`. Smoke tests de la arena en Normal y en Sandbox (jefe, 10 Brutos inmortales muñecos, pausa y pestañas) sin errores. Las pestañas se revisaron en capturas.
- **Constitución:** `docs/constitution.md` (sin enmiendas: ver §9)
- **Pilar (Principio I):** Progresión, como herramienta. Permite probar una build contra cualquier enemigo o jefe, a cualquier nivel, sin jugar hasta una oleada avanzada. La pausa por pestañas hace legible la build (stats, buffs y mejoras agrupadas) en los dos modos.
- **Dependencias:** `sandbox-mode.md` (la reemplaza en §2 "Oleadas sin cartas"), `enemy-levels.md`, `boss-challenge.md`, `fodder-minion.md`, `boss-hud-bar.md`, `readable-damage-numbers.md`.
- **ACs:** AC1326–AC1360 (reservados).

## 1. Resumen

1. **Sandbox sin oleadas.** La arena solo tiene lo que el jugador invoca desde la pausa: **tipo** (los 6 enemigos normales y los 4 jefes), **cantidad** y **nivel** (1 a `WaveConfig.max_enemy_level`).
2. **Opciones del grupo invocado:** **Inmortal** (la vida no baja de 1, pero los números de daño salen completos), **Muñeco** (no se mueve ni ataca, solo mira al jugador) y **Reaparecer al morir** (el mismo grupo vuelve cuando lo limpiás).
3. **Pausa por pestañas**, en los dos modos:
   - **Personaje:** stats, buffs activos y Aflicciones.
   - **Mejoras**, en cuatro secciones (Ofensivo, Defensivo, Habilidad, Aflicción). En Normal son de solo lectura y muestran lo tomado. En Sandbox se editan con − y +, como hoy.
   - **Enemigos:** solo en Sandbox.
4. El modo **Normal** conserva su juego: solo cambia la organización de la pausa.

## 2. Flujo del sandbox

```
Elegir habilidad → se invoca el grupo de Session (por defecto: 1 Bruto, nivel 1, Reaparecer)
Pausa → pestaña Enemigos → ajustar → [Invocar] → cierra la pausa y reemplaza el grupo
                                    → [Limpiar arena] → retira a todos los enemigos (la pausa sigue abierta)
Grupo limpiado → con Reaparecer: vuelve el mismo grupo tras SandboxConfig.respawn_delay
               → sin Reaparecer: la arena queda vacía
```

- La configuración elegida vive en `Session` (`SandboxSpawnRequest`), así **Reintentar** la conserva. Las mejoras no se conservan (igual que hoy).
- **Invocar** retira primero a los enemigos activos (con los esbirros de la Colmena incluidos) y los devuelve a su pool sin contarlos como bajas. Después activa el grupo nuevo.
- Los enemigos aparecen donde aparecería una oleada (`_pick_spawn_position`: el anillo alrededor del jugador y separados entre sí), con su spawn-in normal, que se ve al reanudar.
- **Nivel:** el enemigo se activa con `activate(at, player, level)`, así que escala igual que en una oleada. La pestaña muestra al lado la oleada equivalente, la primera en la que aparece ese nivel: `(level − 1) × waves_per_enemy_level + 1`. Rage queda en 0 y el ritmo (`apply_pace`) es el de ese nivel sin Rage.
- **Jefes:** el HUD muestra su barra (`boss_wave_started`) y la etiqueta de oleada muestra su título. La Colmena invoca esbirros como siempre, salvo como Muñeco. Los esbirros heredan Inmortal, pero no Muñeco (de lo contrario no habría nada que probar contra la invocación).
- Las oleadas, la horda, las cartas, los portales y el cambio de stage no corren en Sandbox. `RunState.wave` queda en 1 y las bajas se siguen contando.

## 3. Opciones del grupo

### Inmortal
- Se usa `HealthComponent.death_protected`, igual que para el jugador en Sandbox: la vida nunca baja de `CombatRules.protected_min_health` (1). Nunca muere, no da bajas y no dispara efectos "al matar".
- **Números de daño completos:** hoy `DamageNumberPool._full_damage` devuelve 0 cuando el golpe no aplicó daño, así que un enemigo en 1 de vida no muestra números. Contra un enemigo con `death_protected`, se muestra `last_full_damage` aunque `applied` sea 0. Rige para básicos, habilidades, estallidos de Aflicción y ticks de debuffs: el tick pasa a informar el daño previo al piso.
- Consecuencias que se aceptan (quedan anotadas): el robo de vida usa el daño aplicado, así que en 1 de vida no cura; un jefe en 1 de vida queda en su última fase; las ejecuciones no lo matan.

### Muñeco
- Un flag de `Enemy` (`dummy`). Mientras está activo, `_update_behaviour` no llama al comportamiento: el enemigo se queda en su lugar (`stand_still`) y gira hacia el jugador (`turn_towards`, con `SandboxConfig.dummy_turn_speed`). No se mueve, no ataca y no invoca.
- El empuje del jugador (knockback), el hit lag, los debuffs, las Aflicciones y el tiempo congelado o dilatado siguen funcionando, porque son efectos del jugador sobre él.
- `activate()` limpia `dummy` y `death_protected`, porque el pool reutiliza enemigos. Las opciones se aplican después de activar.

### Reaparecer al morir
- Con `all_dead` en Sandbox y Reaparecer activo, `WaveManager` espera `SandboxConfig.respawn_delay` y vuelve a invocar la misma petición.
- Con Inmortal, el grupo nunca se limpia y la opción no hace nada (no se desactiva en la UI).

## 4. Pausa por pestañas

```
PauseMenu (Control)
├─ Dim, ModeLabel                       (igual que hoy)
└─ Center/Panel/Margin/Layout
   ├─ Title "PAUSA", RunLabel
   ├─ Tabs (TabContainer)               ← nuevo
   │  ├─ Personaje (VBox)
   │  │  ├─ StatColumns + BottomGrid    (los grids de hoy, movidos)
   │  │  ├─ BuffsLabel                  ← nuevo: "Buffs activos" + una línea por buff
   │  │  └─ AfflictionsLabel            (movido)
   │  ├─ Mejoras (UpgradePanel)         ← SandboxUpgradePanel renombrado y ampliado
   │  └─ Enemigos (SandboxEnemyPanel)   ← nuevo, oculto en Normal
   ├─ TabHint (Label)                   ← "Q / E" o "LB / RB", desde InputPromptConfig
   └─ Buttons (Reanudar, Menú principal)
```

- **Cambiar de pestaña:** acciones nuevas del InputMap, `pause_tab_prev` y `pause_tab_next` (Q/E en teclado, LB/RB en mando). Al tacto o con el mouse, se toca el encabezado de la pestaña, que tiene al menos 44 px de alto. Al abrir la pausa se muestra la última pestaña usada (estado de `PauseMenu`) y el foco va a "Reanudar". Al cambiar de pestaña, el foco va al primer control de esa pestaña o, si no tiene, a "Reanudar".
- **Personaje:**
  - Los stats y las Aflicciones se muestran igual que hoy.
  - **Buffs activos:** una línea por `BuffComponent.get_active()` con título, stacks y segundos restantes (`PauseMenuConfig.buff_entry_format`, p. ej. "Filo del viento ×3 · 4.2 s"). Si no hay ninguno, se muestra `PauseMenuConfig.no_buffs_text`. Se leen al abrir la pausa, que congela el tiempo.
  - En Sandbox, RunLabel muestra solo las bajas, porque la oleada no avanza.
- **Mejoras (`UpgradePanel`):**
  - Cuatro secciones con título, en este orden: **Ofensivo**, **Defensivo**, **Habilidad** y **Aflicción**, dentro de un `ScrollContainer` de alto máximo `PauseMenuConfig.upgrades_max_height`. Se desplaza con el stick o las flechas (el foco sigue al control) y arrastrando al tacto.
  - **Sandbox (`editable = true`):** todas las cartas del pool, con − y +, el contador de copias sobre el tope y "Reiniciar mejoras". Es el comportamiento de hoy, repartido en secciones.
  - **Normal (`editable = false`):** solo las cartas tomadas, con su valor (base → actual) y sus copias, sin botones. Una sección vacía muestra `PauseMenuConfig.empty_group_text`.
  - **Grupo de cada carta:** `UpgradeCard.get_group()`. `UpgradeData` lo lee de un campo nuevo, `group`. Las cartas de habilidad (stats y únicas) son siempre Habilidad y las de Aflicción son siempre Aflicción (identidad estructural por tipo).
  - Asignación de las 11 cartas del catálogo:
    - **Ofensivo:** Daño, Bono de daño, Crítico, Daño crítico, Velocidad de ataque y Rango.
    - **Defensivo:** Vida, Defensa, Robo de vida y Velocidad.
    - **Aflicción:** Acumulación de Aflicción.
- **Enemigos (`SandboxEnemyPanel`, solo Sandbox):**
  - **Tipo:** un `OptionButton` con los normales (Bruto, Embestidor, Hostigador, Saltador, Escudero, Esbirro), un separador y los jefes (Titán, Colmena, Verdugo, The King).
  - **Cantidad** [− n +]: de 1 a `max_regular_count`, o a `max_boss_count` si es un jefe. Al cambiar de tipo, la cantidad se recorta al tope nuevo.
  - **Nivel** [− n +]: de 1 a `WaveConfig.max_enemy_level`, con "≈ oleada N" al lado.
  - Tres `CheckButton`: Inmortal, Muñeco y Reaparecer al morir.
  - "Activos: N" (`EnemyRegistry.alive_count()`), [Invocar] y [Limpiar arena].
  - Cada cambio se escribe en `Session.sandbox_request`. Nada se invoca hasta tocar Invocar.

## 5. Datos (Resources)

- **`resources/sandbox_config.gd` → `data/sandbox/sandbox_config.tres`** (`SandboxConfig`):
  - `max_regular_count: int = 10` (tope por tipo normal)
  - `max_boss_count: int = 3`
  - `respawn_delay: float = 1.0` (segundos)
  - `dummy_turn_speed: float = 240` (grados por segundo, como `windup_turn_speed` de los ataques)
  - `default_entry: int = 0` (índice en la lista: Bruto), `default_count: int = 1`, `default_level: int = 1`
  - `default_immortal: bool = false`, `default_dummy: bool = false`, `default_respawn: bool = true`
- **`resources/pause_menu_config.gd` → `data/ui/pause_menu_config.tres`** (`PauseMenuConfig`): `group_titles: Array[String]` (por `UpgradeCard.Group`), `empty_group_text`, `buffs_title`, `buff_entry_format`, `no_buffs_text`, `upgrades_max_height: float`, `sandbox_run_format`, `wave_hint_format`, `alive_format` y `tab_hint_format`.
- **`UpgradeCard`:** `enum Group { OFFENSE, DEFENSE, ABILITY, AFFLICTION }` y `get_group() -> Group`, virtual. `UpgradeData` suma `@export var group: UpgradeCard.Group`, con valor en los 11 `.tres` de `data/upgrades/`.
- **`EnemyStats.display_name`:** se completa en los normales: Bruto, Embestidor, Hostigador, Saltador, Escudero y Esbirro (hoy vacío; los jefes ya lo tienen).
- **`InputPromptConfig`:** entradas para `pause_tab_prev` y `pause_tab_next` en teclado, mando y táctil (el táctil, vacío: se tocan las pestañas).
- **`project.godot`:** las acciones `pause_tab_prev` (Q y LB) y `pause_tab_next` (E y RB).

## 6. Interfaz pública y lógica

- **`SandboxSpawnRequest`** (`systems/sandbox_spawn_request.gd`, `RefCounted`: estado de sesión, no un Resource): `entry: int`, `count: int`, `level: int`, `immortal: bool`, `dummy: bool`, `respawn: bool`, y `static func from_config(config: SandboxConfig) -> SandboxSpawnRequest`.
- **`GameSession`:** `var sandbox_request: SandboxSpawnRequest` (null hasta la primera arena en Sandbox) y `func get_sandbox_request(config: SandboxConfig) -> SandboxSpawnRequest`, que lo crea desde la config la primera vez.
- **`SandboxRoster`** (`systems/sandbox_roster.gd`, `RefCounted`): la lista ordenada de lo que se puede invocar, construida una vez desde `WaveManager.pools`, `horde_pool` y `boss_pools`. Cada entrada tiene su nombre (`display_name` o el título del desafío), su pool, si es jefe (`is_boss`) y su tope.
- **`EnemyPool.grow_to(count: int) -> void`:** crea los enemigos que falten hasta `count`. En Sandbox lo llama la arena **al cargar**, con el tope de cada entrada. En combate no se instancia nada (Principio V).
- **`Enemy`:**
  - `var dummy: bool`, que `activate()` pone en false (junto con `health.death_protected`).
  - `func set_sandbox_options(immortal: bool, dummy: bool) -> void`.
  - `_update_behaviour` desvía a `_hold_as_dummy(delta)` antes de actualizar el comportamiento (después del empuje, que sigue).
- **`WaveManager`:**
  - `func spawn_sandbox(request: SandboxSpawnRequest) -> void`: limpia, adquiere `count` enemigos del pool de la entrada, los coloca con `_place_at_level` (el nivel pedido, Rage 0), aplica las opciones y, si es jefe, fija el desafío, conecta `summon_requested` y emite `boss_wave_started`.
  - `func clear_arena() -> void`: desactiva a todos los enemigos de `registry.get_active()` sin emitir `killed`.
  - `func get_roster() -> SandboxRoster`.
  - `_on_ability_chosen`: en Sandbox, `spawn_sandbox(Session.get_sandbox_request(sandbox_config))` en lugar de `start_wave()`.
  - `_on_all_dead`: en Sandbox, con `respawn`, programa la reinvocación (`_sandbox_respawn_left`, que avanza en `_physics_process` como el refuerzo de la horda). Sin `respawn`, no hace nada.
  - Nuevo export: `sandbox_config: SandboxConfig`.
  - `_place` se divide en `_place_at_level(enemy, at, level, rage_level)`, que usan las oleadas y el sandbox.
- **`DamageNumberPool._full_damage`:** si `applied <= 0` y el enemigo tiene `death_protected`, usa `last_full_damage`. El tick de debuff pasa a informar el daño previo al piso (`DebuffComponent` → `EnemyRegistry.enemy_debuff_ticked`).
- **`UpgradePanel`** (renombre de `SandboxUpgradePanel`, `ui/upgrade_panel.gd/.tscn`): `setup(player, cards, editable)`. La señal `upgrades_changed` y la API de consulta de hoy se conservan. Suma `get_group_row_count(group)` y `get_section_title(group)`.
- **`SandboxEnemyPanel`** (`ui/sandbox_enemy_panel.gd/.tscn`): `setup(roster, request, wave_config, registry)`, las señales `spawn_requested` y `clear_requested`, y para los tests `select_entry(i)`, `step_count(delta)`, `step_level(delta)`, `get_count()`, `get_level()` y `get_wave_hint_text()`.
- **`PauseMenu`:**
  - Exports nuevos: `config: PauseMenuConfig` y `sandbox_config: SandboxConfig`.
  - `select_tab(i)`, `get_tab()`, `get_tab_count_visible()` y `get_buffs_text()`.
  - `_handle_pause_input` suma las dos acciones de pestaña.
  - "Invocar" llama a `wave_manager.spawn_sandbox()` y después a `close()`.
- **`Arena._apply_mode`:** en Sandbox, además del `death_protected` del jugador, agranda los pools (`grow_to`) según el roster.

## 7. Criterios de aceptación

**Sandbox: invocación**
- **AC1326** En Sandbox, al elegir la habilidad se invoca la petición por defecto de `SandboxConfig`: 1 Bruto de nivel 1. No arranca ninguna oleada ni la horda.
- **AC1327** `spawn_sandbox` con Escudero, cantidad 4 y nivel 9 deja exactamente 4 Escuderos activos, todos de nivel 9 y con la vida máxima escalada de ese nivel.
- **AC1328** Invocar un grupo nuevo retira el anterior: los enemigos vuelven a su pool, `run_state.kills` no cambia y solo quedan los del grupo nuevo.
- **AC1329** `clear_arena` deja 0 enemigos activos sin sumar bajas.
- **AC1330** En Sandbox, cada tipo normal admite `max_regular_count` enemigos y cada jefe `max_boss_count`: los pools crecen al cargar la arena. En Normal, los pools tienen el tamaño de siempre.
- **AC1331** Invocar un jefe emite `boss_wave_started` con los jefes invocados y fija el título del desafío en `RunState`.
- **AC1332** Con Reaparecer, limpiar el grupo lo vuelve a invocar igual (tipo, cantidad, nivel y opciones) después de `respawn_delay`, y no antes. Sin Reaparecer, la arena queda vacía.
- **AC1333** En Sandbox, limpiar un grupo no abre cartas, no avanza `RunState.wave` y no emite `stage_cleared`. *(Reemplaza a AC110.)*
- **AC1334** Reintentar conserva la petición de `Session`: la arena recargada invoca el mismo grupo.

**Opciones**
- **AC1335** Inmortal: un golpe mayor que la vida deja al enemigo en `protected_min_health`, sin `killed`.
- **AC1336** Inmortal: contra un enemigo que ya está en el piso, un golpe básico, uno de habilidad, un estallido de Aflicción y un tick de debuff generan números con el daño completo (`last_full_damage` o el daño previo al piso), no 0.
- **AC1337** Muñeco: durante 2 s con el jugador a 10 m, el enemigo no se desplaza (salvo por gravedad), no empieza ningún ataque (`is_attacking()` siempre en false) y queda girado hacia el jugador.
- **AC1338** Muñeco: el empuje del jugador lo sigue desplazando. Al terminar el empuje, se vuelve a quedar quieto.
- **AC1339** Una Colmena Muñeco no invoca esbirros. Una Colmena normal invocada en Sandbox con Inmortal invoca esbirros inmortales pero no muñecos.
- **AC1340** `activate()` limpia Inmortal y Muñeco: un enemigo del pool reutilizado en Normal muere y ataca como siempre.

**Pestaña Enemigos**
- **AC1341** La pestaña Enemigos solo existe en Sandbox. Lista 6 normales y 4 jefes, en el orden de §4, con sus nombres.
- **AC1342** Cantidad: el − se desactiva en 1 y el + en el tope del tipo. Al pasar de Bruto (8) a Titán, la cantidad se recorta a `max_boss_count`.
- **AC1343** Nivel: de 1 a `max_enemy_level`. El texto de oleada equivalente de nivel 5 con `waves_per_enemy_level = 2` dice oleada 9.
- **AC1344** Cambiar un control escribe `Session.sandbox_request`, pero no invoca nada. "Invocar" invoca y cierra la pausa. "Limpiar arena" limpia sin cerrarla.
- **AC1345** "Activos: N" muestra `alive_count()` al abrir la pausa y después de Limpiar.

**Pausa por pestañas**
- **AC1346** En Normal hay 2 pestañas (Personaje y Mejoras). En Sandbox hay 3.
- **AC1347** `pause_tab_next` y `pause_tab_prev` recorren las pestañas visibles de forma circular. Tienen binding de teclado y de mando en el InputMap.
- **AC1348** La pausa se reabre en la última pestaña usada, con el foco en "Reanudar". Al cambiar de pestaña, el foco va al primer control de la pestaña o a "Reanudar".
- **AC1349** La pestaña Personaje muestra los stats (misma cantidad de filas y mismos valores que hoy) y las Aflicciones.
- **AC1350** Buffs activos: con un buff de 3 stacks, la línea muestra su título, "×3" y el tiempo restante con el formato de `PauseMenuConfig`. Sin buffs, se muestra `no_buffs_text`.
- **AC1351** El prompt de las pestañas sale de `InputPromptConfig` y cambia con el dispositivo (teclado o mando).
- **AC1352** Los encabezados de las pestañas y los botones nuevos miden al menos 44 px de alto.

**Pestaña Mejoras**
- **AC1353** Cada carta del catálogo cae en su grupo de §4, las de habilidad en Habilidad y las de Aflicción en Aflicción. Las secciones salen en el orden Ofensivo, Defensivo, Habilidad y Aflicción, con los títulos de `PauseMenuConfig`.
- **AC1354** Sandbox: la pestaña lista todo el pool, repartido en las cuatro secciones (la suma de filas es el tamaño del pool). − y +, los topes y "Reiniciar mejoras" funcionan como en AC113–AC115.
- **AC1355** Normal: solo se listan las cartas tomadas, con sus copias y su valor, sin botones. Con Daño ×2 y nada más, Ofensivo tiene 1 fila y las demás secciones muestran `empty_group_text`.
- **AC1356** Un cambio en la pestaña Mejoras actualiza al instante los valores de la pestaña Personaje.

**Regresión y cierre**
- **AC1357** Normal: las oleadas, las cartas, la horda y los jefes se comportan como antes (tests de oleadas, horda y desafíos en verde sin cambiar lo que verifican).
- **AC1358** Normal: los pools no crecen y ningún enemigo queda con `dummy` o `death_protected`.
- **AC1359** Smoke test en la arena, en Normal y en Sandbox, sin errores ni warnings nuevos, con invocación de un jefe y de 10 Brutos.
- **AC1360** Regresión: los tests de las specs tocadas en verde (`sandbox_run_test`, `pause_menu_test`, `main_menu_test`, `arena_waves_test`, `arena_horde_test`, `boss_challenge_run_test`, `touch_ui_sizes_test`, `input_prompts_test` y los nuevos).

*Notas de implementación:*
- `sandbox_run_test`: AC110 pasa a ser `test_ac1333_…` (la oleada no avanza y no hay `stage_cleared`). `pause_menu_test` (AC112) verifica las 2 pestañas y el panel de solo lectura en lugar del panel de sandbox oculto. Se conserva lo que verifican.
- Valores fijos adaptados: AC26 (`pause_menu_test`) y AC113/AC115 (`sandbox_run_test`) esperaban "19.0" y "15.0", pero el daño base del Guerrero ya era 20 en `HEAD`, así que fallaban antes de esta spec. Ahora leen `warrior_stats.tres`.
- `SandboxUpgradePanel` pasa a llamarse `UpgradePanel`: se actualizaron sus referencias (`unique_upgrade_run_test`, `touch_ui_sizes_test`, que ahora también revisa `sandbox_enemy_panel.tscn`).
- `EnemyPool` recupera los enemigos devueltos con la señal nueva `Enemy.returned` (`Enemy.return_to_pool()`), que no emite `killed`. `WaveManager.bosses_cleared` le avisa al HUD que suelte las barras de jefe al limpiar.
- El tick de un debuff ya informaba el daño previo al piso (`DebuffComponent.ticked` emite el monto antes de aplicarlo), así que no cambió.
- La barra de jefe del HUD admite 2 jefes (`boss_bar_config.max_bars`): un tercer jefe invocado no tiene barra, igual que en un desafío.
- Muñeco: gira a `dummy_turn_speed` en grados por segundo, igual que `windup_turn_speed`.
- Cantidad y Nivel comparten fila, y `upgrades_max_height` es 290: con las primeras medidas, las pestañas Mejoras y Enemigos no entraban en la ventana de 1152 × 648 (se vio en la captura). `test_ac1359_every_tab_fits_the_window` lo cubre.
- Fallas conocidas fuera de esta spec en las suites vecinas: `arena_waves_test` AC22 y AC23 (valores fijos de daño y vida viejos), `boss_hud_bar_test` AC159 y AC160 (vida del Titán cambiada en otra línea de trabajo, sin commitear) y `boss_challenge_run_test` AC155 (Contragolpe ahora tiene niveles). Las cinco fallas vienen de datos que esta spec no toca: se revisó la causa de cada una, pero no se volvieron a correr sobre `HEAD`. Por eso AC1357 y AC1360 quedan verificados con esas cinco excepciones.

## 8. Plan

1. **Datos base:** `UpgradeCard.Group`, `UpgradeData.group` en los 11 `.tres`, `display_name` de los 6 normales, `SandboxConfig`, `PauseMenuConfig`, acciones de pestaña en el InputMap y en `InputPromptConfig`. El juego no cambia. Tests de datos (AC1353, parte de AC1347).
2. **Enemigo:** `dummy`, `set_sandbox_options`, la limpieza en `activate()` y `_full_damage` junto al tick previo al piso. Tests con enemigos sueltos (AC1335–AC1338, AC1340).
3. **`EnemyPool.grow_to`, `SandboxRoster`, `SandboxSpawnRequest` y `Session`.** Tests unitarios (AC1330, parte de AC1341).
4. **`WaveManager`:** `spawn_sandbox`, `clear_arena`, `_place_at_level`, la reaparición y el cambio en `_on_ability_chosen` y `_on_all_dead`. `Arena._apply_mode` hace crecer los pools. Tests de run (AC1326–AC1334, AC1339). Las oleadas de Normal no cambian (AC1357 y AC1358 con los tests existentes).
5. **`UpgradePanel`:** renombre, secciones y modo solo lectura. Tests (AC1353–AC1356).
6. **`SandboxEnemyPanel`.** Tests (AC1341–AC1345).
7. **`PauseMenu` con `TabContainer`:** mover los nodos, sumar la pestaña Personaje con los buffs, el cambio de pestaña, el foco y el prompt. Se adaptan `pause_menu_test` y `sandbox_run_test` (AC1346–AC1352).
8. **Cierre:** tests de las specs tocadas (con `godot-tester`), smoke test en Normal y Sandbox, captura de la pausa en las tres pestañas para revisarla a ojo, checklist de la constitución, estado Implementada, registro de ACs y próximo AC libre en `CLAUDE.md`.

**Advertencia de convivencia:** el árbol de trabajo tiene cambios sin commitear de otra línea de trabajo (el King, los modelos de enemigos, las oleadas) en `wave_manager.gd`, `enemy.gd`, `health_component.gd`, `arena.tscn` y los tests de oleadas. Esta feature toca esos mismos archivos. Conviene commitear o cerrar ese trabajo antes de empezar, o implementar encima de él sabiendo que el diff va a mezclar las dos cosas.

## 9. Constitución (revisión de cierre)

- **I:** Progresión, como herramienta. El ciclo de runs del modo Normal no cambia.
- **II:** solo UI 2D, sin assets nuevos.
- **III:** los topes, la demora de reaparición, el giro del muñeco, los valores por defecto, los textos con formato y los grupos de las cartas están en `.tres`. La petición es estado de sesión en un `RefCounted` del autoload, y ningún Resource se muta. El grupo de las cartas de habilidad y de Aflicción sale de su tipo (identidad estructural).
- **IV:** tipado completo, callbacks delgados (`_update_behaviour` solo desvía a `_hold_as_dummy`).
- **V:** los pools crecen al cargar la arena en Sandbox y nunca en combate. La reaparición es un contador por frame, sin allocations. La pausa construye sus filas al abrir, solo si cambió el pool.
- **VI:** pestañas con acciones del InputMap (teclado y mando) y encabezados táctiles de al menos 44 px. Foco inicial y visible, `ui_cancel` cierra la pausa. Los prompts salen de `InputPromptConfig`.
- **VII:** sin cambios. El Muñeco sigue recibiendo el hit lag y el empuje.
- **VIII:** no aplica (no hay animación nueva).

## 10. Fuera de alcance

- Medidor de DPS o de daño total (se puede pedir como spec aparte).
- Mezclar varios tipos en un mismo grupo invocado.
- Elegir el nivel de Rage o el stage.
- Guardar builds del sandbox entre sesiones.
