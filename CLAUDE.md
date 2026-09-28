# fantasy-slash: manual operativo

Hack and slash roguelike en tercera persona (Godot 4.7, GDScript, PC con teclado y mouse).

**Antes de tocar código, leé [`docs/constitution.md`](docs/constitution.md).** Ahí están las reglas no negociables. Este archivo es el manual operativo: flujo, mapa, comandos y trampas conocidas.

**Antes de tocar una animación o el VFX de un golpe, leé [`docs/animation-standard.md`](docs/animation-standard.md)** (Principio VIII): capas, timing, flujo con video antes/después y herramientas de captura.

## Flujo de trabajo (Spec-Driven Development)

1. Para cada feature o cambio de comportamiento, **no escribas GDScript todavía**. Primero presentá la spec y el plan:
   - **Spec** (`docs/specs/<feature>.md`): pilar del Principio I, estructura de nodos, Resources y datos, interfaz pública, lógica interna, criterios de aceptación numerados.
   - **Plan**: pasos ordenados que mantengan el proyecto funcionando.
2. Terminá preguntando exactamente: **"¿Aprobas la especificación y el plan?"**. Solo con aprobación explícita se implementa, sin desviarse de la spec.
3. Si algo es ambiguo (por ejemplo "más lento" o "100 % de crítico"), preguntá antes de especificar.
4. Si el cambio contradice la constitución, proponé la enmienda (MAJOR/MINOR/PATCH) dentro de la spec.
5. Al cerrar: suite completa en verde, smoke test, checklist de review de la constitución en la spec y estado **Implementada**. Si un test viejo tenía valores fijos, adaptalo sin cambiar lo que verifica y anotalo en la spec.
6. Respondé en **español**. Código, identificadores y comentarios en **inglés**.

**Próximo criterio de aceptación libre: AC1091.** Los rangos usados o reservados por cada spec están en [`docs/ac-registry.md`](docs/ac-registry.md). Al cerrar cada spec, actualizá este número y agregá su rango al registro.

## Mapa del proyecto

| Carpeta | Contenido |
| --- | --- |
| `data/classes/<clase>/` | Todo lo de cada clase: `<clase>.tres` (`CharacterClassData`), `<clase>_stats.tres` (`PlayerStats`), habilidades, arma (`WeaponData`) y `*_swing_config.tres` (barrido). |
| `data/player/` | Solo lo común a todas las clases: `player_tuning`, `camera_config`, `hit_feedback_config`, `weapon_trail_config`. |
| `data/upgrades/` | Cartas de mejora y `upgrade_catalog.tres` (11 cartas; dash, salto, arco e invencibilidad son fijos por diseño). |
| `data/combat/combat_rules.tres` | Topes y pisos globales (crítico, daño crítico, arco, piso de recarga del dash). |
| `data/ui/stat_display_table.tres` | Qué stats muestra la pausa, en qué columna y con qué formato. |
| `resources/` | Scripts `class_name X extends Resource` (datos, sin lógica de nodos). |
| `components/` | Comportamiento reutilizable (ataque, barrido, estela, stats, habilidades). |
| `entities/player/weapons/` | Escenas adaptadoras de armas: `Model` + marcadores `TrailBase`/`TrailTip`. |
| `assets/icons/status/` | Íconos SVG de buffs y debuffs (UI 2D), con su `SOURCE.md` (créditos CC BY 3.0). |
| `assets/models/<categoría>/<asset>/` | Assets importados con su `SOURCE.md`. Siempre usados vía escena adaptadora. |
| `materials/` | `StandardMaterial3D` compartidos (`materials/weapons/` para las armas). |
| `docs/specs/` | Historial de features: una spec por cambio, con sus ACs y notas. |
| `test/` | GdUnit4, en espejo de la estructura del código. |

## Dónde se ajusta cada cosa

Índice completo en [`docs/where-to-tune.md`](docs/where-to-tune.md): stats, dash, combos, animación, habilidades, VFX, enemigos, bosses, UI… Leé solo la viñeta del sistema que vas a tocar.

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
- **En una sesión en la nube (Linux)**:
  - Se baja `Godot_v4.7.2-stable_linux.x86_64` de los releases de godotengine.
  - `addons/gdUnit4/bin/` no está en el repo (`.gitignore` excluye `bin/`): se copia de gdUnit4 v6.2.0 (`godot-gdunit-labs/gdunit4`) a la copia de trabajo.
  - Pasá `-c` a `GdUnitCmdTool` para que no corte cada suite en la primera falla.
  - Para capturas, el renderer de compatibilidad ignora `GeometryInstance3D.transparency`: usá Forward+ con Vulkan por software (`mesa-vulkan-drivers` extraído con `dpkg-deb -x`, `VK_ICD_FILENAMES` apuntando a `lvp_icd.json`) bajo `xvfb-run`.
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

## Specs

Historial de features en [`docs/specs/`](docs/specs/), con la lista de las recientes en [`docs/specs/README.md`](docs/specs/README.md).
