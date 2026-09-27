# fantasy-slash: manual operativo

Hack and slash roguelike en tercera persona (Godot 4.7, GDScript, PC con teclado y mouse).

**Antes de tocar código, leé [`docs/constitution.md`](docs/constitution.md).** Ahí están las reglas no negociables. Este archivo es el manual operativo: flujo, mapa, comandos y trampas conocidas.

## Flujo de trabajo (Spec-Driven Development)

1. Para cada feature o cambio de comportamiento, **no escribas GDScript todavía**. Primero presentá la spec y el plan:
   - **Spec** (`docs/specs/<feature>.md`): pilar del Principio I, estructura de nodos, Resources y datos, interfaz pública, lógica interna, criterios de aceptación numerados.
   - **Plan**: pasos ordenados que mantengan el proyecto funcionando.
2. Terminá preguntando exactamente: **"¿Aprobas la especificación y el plan?"**. Solo con aprobación explícita se implementa, sin desviarse de la spec.
3. Si algo es ambiguo (por ejemplo "más lento" o "100 % de crítico"), preguntá antes de especificar.
4. Si el cambio contradice la constitución, proponé la enmienda (MAJOR/MINOR/PATCH) dentro de la spec.
5. Al cerrar: suite completa en verde, smoke test, checklist de review de la constitución en la spec y estado **Implementada**. Si un test viejo tenía valores fijos, adaptalo sin cambiar lo que verifica y anotalo en la spec.
6. Respondé en **español**. Código, identificadores y comentarios en **inglés**.

**Próximo criterio de aceptación libre: AC694.** (AC639–AC660 y AC678–AC682 reservados por `class-combat-identity.md`; AC661–AC670 por `sheath-socket-hand-grip.md`; AC671–AC677 por `sheath-in-left-hand.md`; AC683–AC688 por `katana-hand-proportions.md`.) Actualizá este número al cerrar cada spec.

## Mapa del proyecto

| Carpeta | Contenido |
|---|---|
| `data/classes/<clase>/` | Todo lo de cada clase: `<clase>.tres` (`CharacterClassData`), `<clase>_stats.tres` (`PlayerStats`), habilidades, arma (`WeaponData`) y `*_swing_config.tres` (barrido). |
| `data/player/` | Solo lo común a todas las clases: `player_tuning`, `camera_config`, `hit_feedback_config`, `weapon_trail_config`. |
| `data/upgrades/` | Cartas de mejora y `upgrade_catalog.tres` (10 cartas; dash, salto, arco e invencibilidad son fijos por diseño). |
| `data/combat/combat_rules.tres` | Topes y pisos globales (crítico, daño crítico, arco, piso de recarga del dash). |
| `data/ui/stat_display_table.tres` | Qué stats muestra la pausa, en qué columna y con qué formato. |
| `resources/` | Scripts `class_name X extends Resource` (datos, sin lógica de nodos). |
| `components/` | Comportamiento reutilizable (ataque, barrido, estela, stats, habilidades). |
| `entities/player/weapons/` | Escenas adaptadoras de armas: `Model` + marcadores `TrailBase`/`TrailTip`. |
| `assets/models/<categoría>/<asset>/` | Assets importados con su `SOURCE.md`. Siempre usados vía escena adaptadora. |
| `materials/` | `StandardMaterial3D` compartidos (`materials/weapons/` para las armas). |
| `docs/specs/` | Historial de features: una spec por cambio, con sus ACs y notas. |
| `test/` | GdUnit4, en espejo de la estructura del código. |

## Dónde se ajusta cada cosa

- **Stats de una clase** (daño, rango del hitbox, velocidad…): `data/classes/<clase>/<clase>_stats.tres`.
- **Dash**: distancia (`dash_distance`) y velocidad (`dash_speed`, interno: sin carta ni fila en la pausa) en `<clase>_stats.tres`. La duración sale de `distancia / velocidad` (ver `dash-speed.md`). La invulnerabilidad dura exactamente lo que el dash y se corta con él; no hay stat de iframes (ver `dash-iframes.md`).
- **Largo visual del arma**: `transform` de `Model` en `entities/player/weapons/<arma>.tscn`, y mové `TrailTip` a la punta. Regla (verificada por AC211): `attack_range = hilt_offset + |punta z| × cos(blade_tilt) + 0.4` (0.4 es el radio del enemigo).
- **Cuerpo del jugador**: el humanoide `LowPolyHumanoid` (`assets/models/characters/low_poly_humanoid/`, script con mallas y animaciones por código), usado vía `entities/player/humanoid.tscn` (escala ×1.333 para medir 1.8 m, material `player_material.tres`). Qué clip suena lo decide `PlayerAnimator` (`data/player/player_animation_config.tres`: umbral de carrera, mezcla del arma a la mano y `attack_exit_blend`, la mezcla lenta del último cuadro de un golpe a la locomoción). El arma de la clase sigue la mano derecha con `WeaponMount` (`WeaponData.grip_position`/`grip_rotation`) salvo durante las habilidades.
- **Ataque básico = combo** `attack_1` → `attack_2` → `attack_3` (un golpe por toque, buffer, multiplicadores de daño y empuje, velocidad de referencia): `data/player/attack_combo_config.tres`. El daño cae al abrirse `hit_window` del clip, con el sector lógico de siempre. Compromiso del golpe (solo el dash y el salto lo cortan, ver `jump-cancels-strike.md`), estocada, hit lag local (pausa del clip y congelamiento del enemigo), shake por golpe y apuntado (`aim_mode`): en el mismo `attack_combo_config.tres`; temblor del enemigo en `data/player/hitstop_config.tres` (ver `bdo-combat-feel.md`). En tests, `test/helpers/combo_driver.gd` avanza los clips a mano (ver `humanoid-player-model.md`).
- **Barrido del arma** (curva, inclinación, pose; hoy solo el corte del dash del Giro) y recuperación tras una habilidad: `SwordSwingConfig` de la clase.
- **Estela del arma**: `data/player/weapon_trail_config.tres` y `materials/weapon_trail_material.tres`.
- **Daño crítico**: `crit_damage` guarda el **bonus** (1.0 = +100 % = ×2).
- **Habilidades de carga** (*hold*, p. ej. Envainar): el behavior devuelve `is_charged() = true`. La carga no tiene cooldown y se suelta con `AbilityComponent.release_charge()`, que llama `Player` al levantar la tecla. `CHARGE_TIME` y su piso viven en `AbilityData`. Los hitos de carga (cada segundo y al completar) se emiten con `charge_milestone_reached`; el shake y el temblor del cuerpo los hace `ChargeFeedbackComponent` (`data/player/charge_feedback_config.tres`).
- **Debuffs y buffs**: `data/debuffs/*.tres` (`DebuffData`: daño por tick o reducción de armadura, con tope de stacks) y `data/buffs/*.tres` (`BuffData`: stacks que se pierden de a uno, con modificadores por stack). Los buffs los lleva `BuffComponent` en el jugador. Qué acción aprovecha un modificador lo decide la habilidad (p. ej. Conmoción solo durante el Giro).
- **Segundos restantes y reloj** (habilidades, dash, buffs, debuffs): el reloj translúcido se configura en `data/ui/cooldown_clock_config.tres` (`CooldownClock`). El formato (`S.S` bajo 10 s, redondeo hacia arriba) está en `data/ui/cooldown_text_config.tres` y los strings salen de la tabla de `CooldownText`. Los tamaños de cada vista están en su config de `data/ui/`.
- **Funda del arma**: `WeaponData.sheath`; cuelga de la articulación `sheath_joint` (la katana: `wrist_l`, la funda va en la mano izquierda, ver `sheath-in-left-hand.md`) con `sheath_position`/`sheath_rotation` como agarre. El ángulo lo da el brazo izquierdo de cada pose del perfil del Samurái (`LEFT_SHEATH_ARM` por defecto; `wrist_l` X más negativo sube la punta). La mano derecha, al cargar Envainar, toma el `Hilt` de `katana.tscn` (`right_grip` en el clip). La pose de carga es el clip `sheathe_charge` (`SheatheConfig.charge_body_clip`). Si movés el agarre o esa pose, actualizá el primer cuadro de `sheathe_slash` en `player.tscn` (AC675 lo verifica).
- **Ataques enemigos** (preparación, golpe, recuperación, alcance, arco, giro, si el empuje los interrumpe, pose de las manos): `data/enemies/attacks/*.tres` (`EnemyAttackData`), referenciados desde `EnemyStats.attacks` junto con el comportamiento (`EnemyStats.behavior`, p. ej. `components/enemies/melee_behavior.tscn`). `attack_interval` es la pausa entre la recuperación y el próximo ataque. Reposo y vaivén de las manos: `data/enemies/enemy_hands_config.tres`; su tamaño, en el `SphereMesh_hand` de `enemy.tscn`.
- **Tipos de enemigo y mezcla por oleada**: cada tipo es `data/enemies/<tipo>_stats.tres` (Bruto `grunt`, Embestidor `charger`, Saltador `leaper`, Hostigador `harasser`, Escudero `shieldbearer`) con su comportamiento (`components/enemies/<tipo>_behavior.tscn`), su ataque (`data/enemies/attacks/`), sus manos (`data/enemies/hands/`) y, si hace falta, su config (`data/enemies/configs/`: órbita del Hostigador, guardia del Escudero). Peso, oleada de aparición y máximo por oleada en `data/enemies/spawn/<tipo>_spawn.tres`, listados en `WaveConfig.enemy_types` (el primero, el Bruto, es el respaldo). Cada tipo tiene su `EnemyPool` en `arena.tscn` (`spawn_entry`) enlazado en `WaveManager.pools`.
- **IA de grupo** (turnos de ataque, anillo alrededor del jugador, separación, aparición desde el piso): `data/enemies/group_ai_config.tres` (`GroupAIConfig`), usado por el nodo `AttackCoordinator` de `arena.tscn`, que los pools pasan a sus enemigos. Los bosses no piden turno (`EnemyStats.ignores_attack_tokens`). Sin coordinador, como en los tests unitarios, los enemigos atacan como antes. Agujero: `materials/vfx/spawn_marker_material.tres`.
- **Bosses con repertorio** (`BossBehavior`: el Verdugo; `TitanBehavior`: el Titán, con armadura y manos rompibles en `TitanConfig`; `ColmenaBehavior`: la Colmena, con escudo, esbirros y distancia en `ColmenaConfig`; los esbirros los crea `WaveManager` desde los pools de tipos al recibir `Enemy.summon_requested`): movimientos y fase 2 en `data/enemies/configs/<boss>_boss.tres` (`BossConfig`: `ComboMoveData`, `ShockwaveMoveData`, `GrabMoveData` y `BossPhaseData`), con sus golpes en `data/enemies/attacks/<boss>_*.tres`. Cada desafío se suma en `WaveConfig.boss_challenges` y necesita su `BossPool*` en `arena.tscn` enlazado en `WaveManager.boss_pools`. La sujeción del jugador es `Player.begin_hold()`. Anillo de la onda: `materials/vfx/shockwave_material.tres`.
- **Avisos de ataque en el piso** (sector, franja o círculo rojo anaranjado con relleno que crece, destello y polvo): `data/enemies/telegraph_config.tres` y `materials/vfx/telegraph_material.tres`. El nodo es `GroundTelegraph` en `enemy.tscn`; cada comportamiento llama a `show_*`, `follow`/`move_center`, `flash` y `clear`, y declara sus arcos en `get_telegraph_arcs()` (las mallas de sector se construyen al cargar).
- **Ritmo de los enemigos** (dificultad): los `.tres` de ataques describen el ritmo más rápido. `data/enemies/enemy_pace_config.tres` estira las preparaciones (×1.8 a nivel 1 → ×1.2 a nivel 25) y la pausa entre ataques (×2.5 → ×1.4), y cada nivel de Rage lo acerca a ×1. El descanso de un turno entre ataques (1.5 s → 0.5 s) está en `group_ai_config.tres` (`rest_*`). La vida y la defensa de los bosses se calcularon para peleas de ~90 s (ver `boss-health-tuning.md`). Se aplica en `WaveManager._place()` con `Enemy.apply_pace()`, así que los enemigos de los tests conservan el ritmo de los datos. Los atacantes simultáneos dependen del Rage (`GroupAIConfig.rage_levels_per_extra_attacker`).
- **Rage** (enemigos cuando no quedan mejoras): cuánto crece cada stat por nivel de rage y sus topes en `data/enemies/rage/rage_config.tres`; ícono y aura en `data/debuffs/rage.tres`, `materials/debuff_rage_material.tres` y `materials/vfx/rage_aura_material.tres`.

## Comandos

La shell a veces no puede escribir dentro de `Documentos` (probablemente Windows Controlled Folder Access). Import y tests se corren sobre una copia en el scratchpad de la sesión:

```bash
G=/d/user/Documentos/godot/Godot_v4.7.2-stable_win64.exe
tar --exclude=./.godot --exclude='./*.exe' -cf - . | (cd "$DEST" && tar -xf -)
"$G" --headless --path "$DEST" --import
"$G" --headless --path "$DEST" -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test --ignoreHeadlessMode
"$G" --headless --path "$DEST" --quit-after 300
"$G" --headless --path "$DEST" res://levels/arena/arena.tscn --quit-after 300
```

- Para capturas visuales: una escena temporal con un script `extends Node` en la copia (no `-s`, porque con `-s` no cargan los autoloads como `Session`), corriendo sin `--headless` y guardando `get_viewport().get_texture().get_image()`.
- No hay Python en la máquina: usá sed/awk o las herramientas de edición.
- Las herramientas del MCP `godot` que generan scripts fallan (el proyecto exige tipado estricto).

## Trampas conocidas

- **El editor abierto pisa archivos.** Si Godot tiene recursos en memoria y el usuario guarda, re-escribe versiones viejas (recreó archivos movidos y borró un `attack_range`). Después de mover o reescribir recursos, pedí recargar el proyecto (Proyecto → Recargar proyecto actual, sin guardar). Si un archivo "cambió en disco", tomalo como estado actual y revisá que tenga sentido.
- **El editor agrega `uid=`** a escenas y recursos al guardar: conservalos al editar.
- **Godot no escribe los valores iguales al default** (0 para `float`). Si falta una línea en un `.tres`, ese stat vale 0.
- **GdUnit muestra los strings fallidos como diff** entre esperado y obtenido: "(15 % → 430 %)" puede ser "(5 % → 30 %)".
- **Orphans en tests**: `AbilityComponent.equip()` libera la habilidad anterior con `queue_free`; equipá una sola habilidad por test.
- **`Transform3D` en `.tscn`** se escribe por filas de la base. `Transform3D(s,0,0, 0,0,-s, 0,s,0, ox,oy,oz)` lleva −Y del modelo a −Z (los `.obj`). Para un modelo con la hoja en +Y (la katana) es `Transform3D(s,0,0, 0,0,s, 0,-s,0, …)`.
- **Al agregar assets o scripts**, la copia del scratchpad genera los `.import`/`.uid` que faltan: copialos de vuelta al proyecto (el sync de la copia los borra).
- Los `.obj` con líneas `Ka` en su `.mtl` generan warnings al importar: se eliminan y se anota en `SOURCE.md`.

## Specs recientes (para contexto)

`jump-cancels-strike`, `sheath-in-left-hand`, `sheath-socket-hand-grip`, `class-combat-identity`, `bdo-combat-feel`, `humanoid-player-model`, `berserker-air-slash`, `spin-dash-slash`, `dash-iframes`, `enemy-level-pace`, `boss-health-tuning`, `boss-colmena` (reemplaza a los Gemelos), `enemy-pace`, `enemy-ground-telegraph`, `boss-titan` (reemplaza al Coloso), `boss-verdugo`, `enemy-group-ai`, `enemy-types`, `enemy-attack-telegraph`, `dash-speed`, `tsubame-gaeshi`, `debuff-stacks-display`, `sheathe-dash-cancel`, `ability-slot-frame`, `cooldown-clock`, `enemy-rage`, `cooldown-timers`, `nuki`, `zanshin`, `spin-tornado`, `spin-golden-upgrades`, `wind-step`, `wind-cut-v`, `endless-without-upgrades`, `sheathe-feel`, `samurai`, `weapon-models`, `hoplite-sword`, `weapon-reach`, `weapon-trail`, `berserker-heavy-sweep`, `class-sweep-timing`, `stats-rework`. Las specs reemplazadas se marcan como tales en su encabezado (p. ej. `attack-indicator`).
