# Constitución de fantasy-slash

> Reglas no negociables del proyecto. Cualquier persona o IA que trabaje en este repo **lee este documento antes de tocar código**.
> Toda especificación, plan, review y línea de GDScript debe cumplirlo. Ante un conflicto entre este documento y una decisión ad hoc, gana este documento (ver *Governance*).

---

## Principios centrales

### I. Identidad de género

El juego es un **hack and slash roguelike en tercera persona para PC y Android, jugado con teclado y mouse, mando o pantalla táctil**. Toda mecánica, sistema o feature nueva debe poder responder **"sí"** al menos a una de estas preguntas antes de especificarse:

1. **Combate:** ¿hace más interesante, legible o expresivo el acto de pelear (atacar, esquivar, posicionarse, encadenar)?
2. **Supervivencia:** ¿crea presión, riesgo o decisiones tácticas dentro de una run (salud, recursos, oleadas, amenazas)?
3. **Progresión:** ¿alimenta el crecimiento del jugador dentro de la run (mejoras, builds, sinergias) o entre runs (meta-progresión)?

- La spec de cada feature declara explícitamente a cuál de los tres pilares sirve y cómo.
- Una feature que no sirve a ninguno se rechaza o se pospone, aunque sea "fácil" o "divertida en aislamiento".
- Las runs son la unidad de juego: una mecánica no debe romper el ciclo *empezar run → pelear → mejorar → morir → volver a empezar*.

**Rationale:** en un prototipo el mayor riesgo es la dispersión. Anclar cada decisión al loop central evita invertir tiempo en sistemas que no mejoran lo que define al juego.

### II. Arte: primitivas por defecto, assets importados con reglas

**Por defecto, toda representación visual se construye con primitivas geométricas de Godot y `StandardMaterial3D`.** Lo que no tiene un asset importado aprobado (enemigos, UI 3D, indicadores…) se hace así.

- Mallas primitivas: `CapsuleMesh`, `BoxMesh` (y, si hace falta, otras `PrimitiveMesh` nativas como `SphereMesh`, `CylinderMesh`, `PlaneMesh`).
- **Mallas procedurales solo para VFX** (desde 3.1.0): efectos visuales que siguen una trayectoria (p. ej. la estela del arma) pueden construirse con `ImmediateMesh` desde buffers preasignados (Principio V), con material `.tres` compartido y sin texturas. No se usan para entidades ni escenario.
- **Mallas planas procedurales para avisos enemigos** (desde 4.5.0): los avisos de ataque enemigo en el piso pueden usar sectores circulares construidos como `ArrayMesh` **una vez al cargar** (cuando el pool crea el enemigo), con material `.tres` compartido y sin texturas. Círculos y franjas siguen siendo primitivas (`CylinderMesh`, `BoxMesh`). Desde 4.24.0 la regla también cubre los **VFX de habilidades del jugador**: mallas planas `ArrayMesh` construidas una vez al cargar el nodo del VFX, con material `.tres` compartido y sin texturas (hoy la media luna del corte de Envainar, ver `sheathe-visual-rework.md`).
- **Personaje procedural** (desde 4.9.0): el cuerpo del jugador puede ser `LowPolyHumanoid`, un asset de script que vive en `assets/models/characters/low_poly_humanoid/` con su `SOURCE.md`. Construye sus mallas (`ArrayMesh` de normales planas) y su `AnimationPlayer` **una vez**, en `_ready`, y se usa solo vía su escena adaptadora (`entities/player/humanoid.tscn`), con materiales `.tres` compartidos. Sus poses y tiempos de animación son datos del asset (como los keyframes de un `.glb`); los valores de gameplay que dependen de ellos viven en Resources. Puede tener **perfiles de animación** (uno por clase, desde 4.10.1): todas sus librerías se construyen una vez al cargar, y elegir un perfil solo selecciona una librería ya construida. Desde 4.27.0, al construirlas puede **hornear** sus clips (claves densas por cúbica monótona, superposición y el brazo del arma resuelto por IK sobre los arcos del perfil) y sumar una capa en vivo de resortes y pies clavados que mueve solo lo que el motor no mezcla (Principio VIII y [estándar de animación](animation-standard.md)).
- **Partículas y luces breves solo para VFX** (desde 3.4.0): `CPUParticles3D` con mallas primitivas y material `.tres` compartido, sin texturas, con sus parámetros en un Resource; y `OmniLight3D` que se enciende y apaga en décimas de segundo. No se usan para entidades ni escenario.
- **Imágenes residuales del jugador** (desde 4.15.0): un VFX puede mostrar copias de las mallas del cuerpo del humanoide (las mismas `ArrayMesh`), con un material `.tres` translúcido compartido y un pool creado una vez al cargar. Duran décimas de segundo y no son entidades (ver `dash-feel.md`).
- **Íconos de estado** (desde 4.16.0): los buffs y debuffs se muestran con íconos SVG monocromos importados en `assets/icons/<categoría>/`, con su `SOURCE.md` (origen, licencia y crédito) y sin fondo propio. Solo se usan en la UI 2D (`StatusIconView`) y se referencian desde los Resources de estado (`DebuffData.icon`, `BuffData.icon`), sin escena adaptadora. Se tiñen con el color del estado (`icon_color`), nunca en blanco puro (ver `status-icons.md`).
- Materiales: `StandardMaterial3D` con color plano (`albedo_color`). Excepción (desde 3.2.0): el material de un modelo importado puede usar como `albedo_texture` una textura que viva en la carpeta de ese asset.
- **Assets importados permitidos** (desde 3.0.0), en formatos que Godot importa de forma nativa: modelos `.obj` para mallas estáticas y **`.glb`/`.gltf` como formato preferido** cuando hay jerarquía o animación (`.fbx`/`.blend` se convierten a glTF antes de entrar al repo), y **texturas de imagen** (`.png`) de un modelo importado (desde 3.2.0), e íconos SVG de UI (desde 4.16.0). A futuro, también audio. Reglas obligatorias:
  - **Scaffolding:** los archivos fuente viven en `assets/<tipo>/<categoría>/<asset>/` (p. ej. `assets/models/weapons/katana/katana.glb`), con nombres en `snake_case`. Nunca junto a scripts (`combat/`, `components/`…).
  - **Escena adaptadora:** cada asset se usa desde una escena propia del juego (p. ej. `entities/player/weapons/sword.tscn`) que normaliza pivot, rotación y escala a la convención del juego. Scripts y Resources referencian esa escena, nunca el archivo crudo.
  - **Materiales:** `.tres` compartidos en `materials/<categoría>/`, aplicados con `surface_material_override`. No se usan los materiales embebidos por el importador. Una textura se referencia **solo** desde esos `.tres` y el importador descarta las imágenes embebidas del glTF (`gltf/embedded_image_handling`).
  - **Mallas derivadas:** si el archivo fuente no permite mostrar por separado una parte que el juego necesita (p. ej. una malla skinned con hoja y funda), se puede derivar una malla estática por parte (`.res` en la carpeta del asset). Una malla derivada también puede reproporcionar regiones del modelo (estirar o escalar un mango, una guarda, o redondear un extremo reubicando sus vértices) para que encaje con el cuerpo del jugador o se distinga de otra parte, sin agregar ni quitar vértices ni cambiar UV o materiales (desde 4.11.0; redondear y distinguir, desde 4.12.1). El procedimiento queda documentado en su `SOURCE.md`, y el script que la genera vive en la carpeta del asset.
  - **Modelos generados** (desde 4.13.0): un arma o accesorio del jugador sin archivo fuente puede ser una malla estática original, low poly y de normales planas, generada **offline** por un script que vive en `tools/` de la carpeta del asset y guardada como `.res` en esa carpeta. Sus medidas son constantes del script, su `SOURCE.md` registra el origen (original, con las referencias usadas) y cómo regenerarla, y un test verifica que el script reproduzca las mallas del repo. Se usa como cualquier asset: vía escena adaptadora y con materiales `.tres` compartidos. Nunca se genera en runtime.
  - **Origen y licencia:** cada asset de terceros tiene un `SOURCE.md` en su carpeta con su origen y su licencia.
  - **Gameplay:** hitboxes y rangos siguen siendo datos (Principio III). El modelo es solo visual y su tamaño se alinea con esos datos.
- **Prohibido:** shaders personalizados, y assets fuera de `assets/` o usados sin escena adaptadora.
- **Convención de color obligatoria:** jugador en blanco, enemigos en gris, y cada color reservado solo para los elementos que lo tienen asignado, así jugador, arma y enemigos se identifican siempre de un vistazo. La tabla de colores reservados, qué elementos comparten el blanco y el gris, y el registro de colores no reservados en uso están en el anexo [`color-registry.md`](color-registry.md), que es parte de esta constitución. Todo color nuevo se registra ahí.
- Los detalles que comunican gameplay (el frente del personaje, una hitbox visible en debug) también son primitivas.
- Los materiales se definen como recursos `.tres` compartidos (p. ej. `materials/player_material.tres`, `materials/weapons/spartan_iron_material.tres`, `materials/enemy_material.tres`), no como sub-recursos duplicados en cada escena.

**Rationale:** el prototipo valida *mecánicas*, no estética. Las primitivas eliminan dependencias externas, mantienen el repo liviano y hacen trivial iterar tamaños y hitboxes, por eso siguen siendo el default. Los assets importados entran de forma ordenada: carpeta fija, escena adaptadora y materiales compartidos, así el resto del juego no depende del formato ni de la escala del archivo fuente. La convención de color garantiza legibilidad en combate con cualquier cantidad de enemigos en pantalla.

### III. Separación datos/comportamiento vía Resources

**Todo stat, mejora o valor tuneable vive en un Resource personalizado**, nunca como literal dentro de un script de comportamiento. **Nada hardcodeado.**

- Cada tipo de dato configurable es una clase `class_name X extends Resource` con campos `@export` tipados (p. ej. `PlayerStats`, `EnemyStats`, `UpgradeData`, `WaveConfig`).
- Los valores concretos viven en instancias `.tres` (p. ej. `data/classes/warrior/warrior_stats.tres`, `data/enemies/grunt_stats.tres`, `data/upgrades/*.tres`).
- Los scripts de comportamiento (Nodes) reciben sus datos por `@export var stats: PlayerStats` y **leen** de ellos. No declaran valores de diseño propios, ni siquiera como valor por defecto de un `@export`.
- **Stats de gameplay del jugador = mejorables.** Todo valor que define cómo juega el personaje (daño, defensa, vida, velocidad de movimiento, salto, dash, cooldowns, rango y arco de ataque…) es un stat con **valor inicial en `.tres`** y **puede subir con mejoras**. La invulnerabilidad del dash no es un stat propio: dura lo que el dash (`DASH_DISTANCE / DASH_SPEED`), así que sigue dependiendo de stats en `.tres`. Los topes y pisos que protegen reglas de diseño (p. ej. "el cooldown del dash siempre supera la duración del dash") también son datos.
- **Stats fijos por diseño** (desde 3.1.1): un stat puede no tener carta en el catálogo de mejoras (p. ej. dash, salto, arco). Sigue siendo un stat en `.tres`, leído por los componentes y soportado por el sistema de mejoras; qué stats tienen carta es una decisión de diseño que se registra en la spec.
- **Qué cuenta como literal prohibido:** velocidades, daños, vidas, cooldowns, rangos, probabilidades, multiplicadores, tiempos de juego, cantidades de spawn, costos… cualquier número que un diseñador querría ajustar.
- **Qué está permitido en código:** identidades matemáticas y del motor (`0`, `1`, `-1`, `Vector3.UP`, `PI`, `Vector3.ZERO`), índices, y constantes estructurales no tuneables (nombres de acciones, nombres de estados).
- **Los Resources son de solo lectura en runtime.** Un `.tres` cargado es compartido por todas las instancias que lo referencian. El estado mutable (vida actual, cooldown restante, mejoras adquiridas en la run) vive en el Node o en un Resource creado con `duplicate()` explícitamente documentado.
- Un Resource contiene **datos y, como máximo, cálculos puros derivados de sus propios campos**. Nunca referencias a nodos, `get_tree()`, señales de gameplay ni efectos secundarios.

#### Mejoras únicas de habilidad

- Una **mejora única de habilidad** cambia *cómo funciona* una habilidad (agrega una regla o un efecto), no solo un número. Ejemplos: reiniciar el cooldown al matar, ejecutar enemigos con poca vida, aplicar un debuff.
- Es un Resource (`AbilityUniqueUpgradeData`) que pertenece a **una sola habilidad** y aparece en la oferta de cartas solo mientras esa habilidad está equipada.
- **Niveles explícitos:** cada mejora única declara `max_level`. `max_level = 1` significa **no mejorable**, para efectos binarios donde "más fuerte" no tiene sentido (p. ej. "Reset"). Los valores de cada nivel viven en arrays del `.tres` (`level_values`, `level_descriptions`), nunca como literales en el código. La spec de cada mejora justifica si es mejorable o no.
- Una mejora única en su nivel máximo **sale del pool** de cartas.
- **Toda carta de mejora declara su tope en datos:** las de stats con `max_stacks` y las únicas con `max_level`. Una carta en su tope sale del pool y no puede aplicarse de nuevo. Cuando un stat tiene piso o techo, el tope se elige para no desperdiciar copias más allá de ese límite.
- El código de la habilidad identifica cada mejora única por un id constante (`StringName`, constante estructural permitida) y lee sus valores del Resource.
- **Estados de entidades (debuffs y buffs)** (buffs desde 3.7.0): todo estado sobre una entidad (sangrado, veneno, lentitud, Rage…) es un Resource de datos (`DebuffData`: efecto —daño por tick, reducción de armadura o mejora de stats—, duración, intervalo de tick, tope de stacks, si es permanente, material del ícono). Cada entidad guarda una **lista** de estados activos, debuffs y buffs juntos, así que agregar un tipo nuevo es un `.tres` nuevo y no una reescritura. Un estado **permanente** no expira con el tiempo y solo se quita al reiniciar la entidad (pool). En un buff de stats (`STAT_BOOST`), la entidad aplica los stats al recibirlo, leyéndolos de su Resource (p. ej. `RageConfig`). Los íconos de estado se construyen con primitivas (Principio II). Los buffs del jugador siguen en `BuffData` (abajo). Desde 4.17.0, el efecto también puede ser **lentitud** (`SLOW`: la entidad se mueve y actúa más lento); los stacks pueden ser **mejorables** (una instancia cuya fuerza crece y que reinicia su duración) o **acumulables** (instancias que se encadenan sin sumar fuerza), y el daño por tick puede ser un % de la vida o un valor fijo que calcula quien lo aplica. Desde 4.22.0, el efecto también puede ser **aturdido** (`STUN`): la entidad se queda quieta y, si no resiste el control, cancela su preparación; la duración la pasa quien lo aplica y la escala el enemigo (`stun_duration_scale`: los bosses se aturden menos y su ataque solo se pausa).
- **Aflicciones** (desde 4.17.0): los golpes del jugador pueden cargar una barra por tipo de Aflicción en el enemigo; al llenarse, se vacía y dispara un efecto (un estado o un daño en área). La carga por golpe es fija por carta y fuente (básicos o habilidad), escalada por la fuente, por el stat mejorable "Acumulación de Aflicción" del jugador y por la resistencia general del enemigo; umbral, vaciado, tope de tipos por run y resistencias son datos (`AfflictionConfig`, `EnemyStats`). Cada tipo es un Resource (`AfflictionData`) y cada carta un `AfflictionUpgradeData` con niveles en el `.tres`. Agregar un tipo es un `.tres` nuevo, no código nuevo.
- **Buffs** (desde 3.5.0): todo estado temporal positivo del jugador es un Resource de datos (`BuffData`: tope de stacks, duración por stack, modificadores por stack, color del ícono). El jugador guarda una **lista** de buffs activos. Qué acción aprovecha cada modificador (p. ej. solo durante el Giro) lo decide la mejora que lo otorga y queda registrado en su spec. Desde 4.22.0, un buff puede ser **global** (sus modificadores de movimiento y daño se suman a los stats del jugador en todo momento) y puede **vencer con todos sus stacks juntos**.
- **Bloqueo frontal** (desde 4.22.0): el daño que un enemigo le hace al jugador trae a su atacante, y un `ShieldGuard` levantado reduce el que llega dentro de un arco al frente. El arco y la reducción son datos de quien lo levanta (una habilidad). Los agarres no se bloquean (ver `warrior-abilities-rework.md`).

**Rationale:** un roguelike vive de tunear números y combinar mejoras. Con los datos en `.tres` se balancea desde el inspector sin tocar lógica, y las mejoras se vuelven contenido (un archivo nuevo, no código nuevo). La lógica de comportamiento queda genérica y testeable con distintos datasets.

### IV. Convenciones de GDScript

Se sigue la [guía de estilo oficial de GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), con estas reglas obligatorias:

- **Nombres:**
  - `snake_case`: variables, funciones, señales, archivos (`.gd`, `.tscn`, `.tres`).
  - `PascalCase`: `class_name` y nombres de nodos en el árbol de escena.
  - `CONSTANT_CASE`: constantes y valores de enums.
  - Prefijo `_` para miembros privados. Señales en pasado (`died`, `health_changed`, `upgrade_selected`).
  - Identificadores y comentarios de código en **inglés**. Documentación del proyecto en **español**.
- **Tipado estático explícito:**
  - Toda firma de función tipa **todos** sus parámetros y su valor de retorno (`func take_damage(amount: float) -> void`).
  - Toda variable miembro, `@export` y `@onready` lleva tipo explícito. Las referencias a nodos usan su `class_name` concreto, no `Node` genérico.
  - Se permite `:=` en variables locales solo cuando el tipo es evidente en la misma línea (`var dir := Vector3.ZERO`).
- **Funciones de ciclo de vida delgadas:** `_ready`, `_process`, `_physics_process`, `_input` y `_unhandled_input` **solo orquestan**. Llaman a métodos con nombre que describen la intención y no contienen lógica de negocio.

  ```gdscript
  func _physics_process(delta: float) -> void:
	  _apply_gravity(delta)
	  _update_movement(delta)
	  _update_attack_cooldown(delta)
  ```

  Si una de estas funciones necesita un `if` con lógica propia, un bucle o más de unas pocas líneas, esa lógica se extrae a un método con nombre.

**Rationale:** las convenciones uniformes hacen el código predecible para humanos e IAs. El tipado estático detecta errores en el editor, habilita autocompletado y mejora el rendimiento del intérprete. Los callbacks delgados hacen que el flujo de cada frame se lea de un vistazo y que cada paso sea testeable por separado.

### V. Disciplina de performance

Cada frame se diseña para escalar con la cantidad de enemigos en pantalla, que en un hack and slash roguelike siempre tiende a crecer.

- **Cero allocations evitables por frame:** en `_process` / `_physics_process` no se crean `Array`, `Dictionary`, objetos ni `String` concatenados, y no se llama a `load()`. Los buffers reutilizables se declaran como miembros y se limpian (`clear()`), no se recrean.
- **Referencias cacheadas:** nodos vía `@onready` o `@export`. Prohibido `get_node()` / `$Path` / `find_child()` / `get_nodes_in_group()` dentro de callbacks por frame.
- **Object pooling obligatorio** para toda entidad que se instancie con frecuencia (enemigos, proyectiles, efectos de impacto, pickups, números de daño):
  - Se pre-instancian al cargar el nivel o la run. En runtime se **activan y desactivan** (visibilidad, `process_mode`, colisiones deshabilitadas); no se hace `instantiate()` / `queue_free()` en cada spawn.
  - El pool resetea el estado de la entidad al reutilizarla.
- **Física mínima necesaria:**
  - Cada cuerpo o área declara capas y máscaras de colisión explícitas y mínimas; nada colisiona "contra todo" por defecto.
  - Formas simples (`CapsuleShape3D`, `BoxShape3D`, `SphereShape3D`). Prohibidas las formas trimesh o convex en entidades dinámicas.
  - `Area3D` con `monitoring`/`monitorable` desactivados cuando no se usan.
  - No se usan cuerpos físicos donde basta un cálculo de distancia. Raycasts y queries por frame, solo si son imprescindibles.
- **Render:** materiales compartidos (ver Principio II), sin luces dinámicas ni sombras innecesarias. Android usa el renderer Mobile; un ajuste de calidad para móvil se decide con mediciones en el dispositivo, no por las dudas.

**Rationale:** las allocations por frame provocan picos del recolector y stutter. Instanciar y liberar en combate genera hitches justo cuando hay más acción. La física innecesaria es el costo oculto que más escala con la cantidad de enemigos.

### VI. Input: teclado y mouse, mando o pantalla táctil

- El juego se controla con **teclado y mouse**, con **mando** (layout Xbox; otros mandos vía el mapeo SDL de Godot) o con **pantalla táctil** (Android, en horizontal).
- Todo input pasa por el **InputMap** con acciones nombradas (`move_forward`, `attack`, `dash`…). **Toda acción de juego tiene binding de teclado/mouse y de mando, y un control táctil** que la dispara como `InputEventAction` (salvo `camera_*`, que en táctil es el arrastre de la mitad derecha). Prohibido leer teclas o botones físicos directamente en la lógica de juego.
- Los bindings de mouse de acciones de juego se limitan al mouse real (`device = InputEvent.DEVICE_ID_MOUSE`, nunca `-1`): un toque genera clics de mouse emulados con `device = -1`, que de otro modo dispararían esas acciones.
- **Toda pantalla de UI se puede usar con mando y al tacto:** foco inicial al mostrarse, foco visible, `ui_accept` para confirmar, `ui_cancel` para volver donde haya "volver", y botones de al menos 44 px de alto en la resolución base.
- Los textos de teclas y botones que muestra la UI (prompts, también los de los botones táctiles) salen de datos (`InputPromptConfig`), nunca de literales en escenas o scripts.
- Excepciones:
  - El movimiento relativo del mouse para la cámara (`InputEventMouseMotion`), que el InputMap no puede representar. Se lee solo dentro del nodo de cámara, que ignora el movimiento emulado desde un toque.
  - `InputDeviceMonitor` clasifica los eventos **por tipo** (teclado/mouse, mando o táctil) solo para elegir qué prompts y qué HUD mostrar. No lee botones concretos ni decide gameplay.
  - `TouchControls` lee `InputEventScreenTouch`/`InputEventScreenDrag` **por posición** (en una pantalla táctil no hay botones físicos que mapear) y los traduce a acciones del InputMap y a un giro de cámara.
  - **Botones táctiles del HUD** (desde 4.14.0): un botón de acción del HUD puede aceptar toques de pantalla (`InputEventScreenTouch`). Un toque aprieta **su acción del InputMap** (`Input.action_press`/`action_release`) y nada más: la lógica de juego sigue leyendo solo acciones. Qué botones son táctiles es un dato del botón (`touch_action`). Fuera de `TouchControls`, son los únicos nodos que leen eventos táctiles.
  - La captura del mouse pasa por `PointerMode`, que no captura en móvil.

**Rationale:** el combate de un hack and slash se juega cómodo con mando, y en el teléfono con dos pulgares. Mantener todo en el InputMap y los prompts en datos hace que sumar un esquema de control no duplique la lógica de juego: los controles táctiles son una fuente más de las mismas acciones.

### VII. Sensación del combate

El combate cuerpo a cuerpo tiene peso: cada golpe compromete, avanza e impacta (desde 4.10.0, ver `bdo-combat-feel.md`).

- **Compromiso:** un golpe del ataque básico no permite moverse libremente hasta su *cancel point* (la apertura de su ventana de combo). En la recuperación, el movimiento se limita a un desplazamiento lento sin girar (o la corta, según datos). El dash y el salto (desde el piso) cortan el golpe en cualquier momento (el salto desde 4.12.0, ver `jump-cancels-strike.md`).
- **Estocada:** los golpes desplazan al jugador con una distancia de datos atada al tiempo del clip (root motion por datos), que se frena ante un enemigo delante.
- **Hit lag local:** el impacto se comunica pausando el clip del atacante y congelando y sacudiendo a los golpeados, con duración por golpe. **Prohibido modificar `Engine.time_scale`** como feedback de impacto. Los bosses solo tiemblan, para que el combo no los congele en cadena. **Las habilidades canalizadas** (p. ej. el Giro) comunican el impacto con el temblor de los golpeados y la sacudida de cámara, **sin pausar al jugador**, para no desfasar sus golpes periódicos. Una pausa durante un dash (p. ej. el Corte del Giro) detiene solo el clip: el dash conserva su recorrido, su duración y su invulnerabilidad (desde 4.20.0). Los golpes de las habilidades no canalizadas (p. ej. la Carga de escudo) pausan el clip del jugador, congelan y sacuden a los golpeados y sacuden la cámara, con valores por golpe en su config (`StrikeFeel`, desde 4.22.0).
- **Tiempo congelado** (desde 4.23.0): un remate excepcional, definido en datos (hoy solo la Estocada mejorada de Contragolpe, ver `parry-riposte-rework.md`), puede congelar a todos los enemigos activos (bosses incluidos) durante una fracción de segundo, sin tocar `Engine.time_scale`: el jugador, la cámara y los VFX siguen animándose. Sigue prohibido modificar `Engine.time_scale`.
- **Tiempo lento** (desde 5.1.0): un esquive perfecto (un golpe enemigo que alcanza al jugador durante los primeros instantes de su dash, definido en datos; ver `perfect-dodge.md`) puede ralentizar a todos los enemigos activos, bosses incluidos, a una fracción de su velocidad durante una fracción de segundo, sin tocar `Engine.time_scale`: el jugador, la cámara, los VFX y la UI siguen a velocidad normal. Sigue prohibido modificar `Engine.time_scale`.
- **Estela:** durante una habilidad, la estela del arma se ve solo mientras la hoja barre, si la habilidad lo declara (p. ej. la Carga no la muestra; el Contragolpe, solo en la estocada; desde 4.22.0).
- **Apuntado:** por defecto, el golpe apunta al enemigo más cercano y lo sigue durante la anticipación. La cámara solo mira, y el input de movimiento no desvía el golpe salvo que los datos lo indiquen.
- Todos estos valores viven en `AttackComboConfig`, `AttackComboStep` y `HitstopConfig` (Principio III). Los tiempos del golpe (inicio y fin del daño, *cancel point* y fin) viven en `AttackComboStep`; los eventos del clip del humanoide están en los mismos tiempos y un test los compara (desde 4.10.1).

**Rationale:** en un hack and slash, el peso de cada golpe hace que pelear sea una decisión: golpear al aire tiene costo, y encadenar o cortar el combo es expresivo. Un hit lag local mantiene el resto del mundo vivo y legible.

### VIII. Animación

Toda animación del jugador se diseña, se construye y se verifica según el **[estándar de animación](animation-standard.md)** (desde 4.27.0). Ese documento es el manual: arquitectura, timing, poses, flujo de trabajo, herramientas y checklist. Estas son sus reglas no negociables:

- **Tres capas con dueño:**
  - las **poses clave del cuerpo** y los **arcos del arma** (`SlashArc`) son datos del perfil de la clase y se **hornean** en los clips al cargar: el cuerpo con cúbica monótona y superposición, y el brazo del arma con IK de dos huesos;
  - la **capa en vivo** (`HumanoidMotion`) solo agrega movimiento secundario (resortes) y pies clavados.
- **Nada en vivo pisa lo que el motor mezcla.** Una pose que tiene que verse al cancelar un golpe (dash, salto, daño o habilidad) vive dentro del clip. Si se calcula, se hornea.
- **Combos que fluyen:** cada golpe empieza donde terminó el anterior (péndulo), los pies alternan, el ritmo varía entre golpes y cada golpe termina sosteniendo su remate en vez de volver a la guardia.
- **Timing de acción:** carga legible con tensión, golpe de 2 a 3 cuadros, follow-through largo que se pasa apenas y se asienta, y estocada como impulso en los cuadros del golpe. Los eventos del clip siguen en los tiempos del `AttackComboStep` (Principio VII).
- **Verificación visual obligatoria:** todo cambio de animación se revisa con **video antes/después** (a velocidad real y al 30 %) de la herramienta de captura y con **escenarios de cancelación** medidos, además de sus tests y el smoke test.
- **VFX de golpe:** siguen el lenguaje compartido del estándar (cintas con sección en cruz, niveles 1–3 por fuerza del golpe y tablas deterministas), dentro de los colores del Principio II.

**Rationale:** la calidad de una animación no se ve en una pose suelta ni en un número: se ve en el movimiento y en cómo se corta. Fijar la arquitectura en capas evita los parches que se pelean con el motor, y fijar el flujo (video y escenarios) hace que cada cambio se juzgue en movimiento.

---

## Technology Stack

| Área | Decisión |
|---|---|
| Motor | **Godot 4.x** (actualmente 4.7) |
| Lenguaje | **GDScript** con tipado estático (Principio IV). Sin C# ni GDExtension en el prototipo. |
| Renderer | **Forward+** (PC), **Mobile** (Android) |
| Física | Jolt Physics (3D) |
| Plataforma | **PC (Windows)** y **Android** (arm64-v8a, horizontal) |
| Input | **Teclado y mouse, mando o pantalla táctil**, vía InputMap (Principio VI) |
| Arte | Primitivas de Godot + `StandardMaterial3D` por defecto; assets importados en `assets/` con escena adaptadora (Principio II) |
| Datos | Resources personalizados en `.tres` (Principio III) |
| Tests | GdUnit4 |

---

## Development Workflow

1. **Spec antes que código:** cada feature se describe en `docs/specs/<feature>.md` (incluye a qué pilar del Principio I sirve) junto con su plan de implementación. Requiere **aprobación explícita** del responsable antes de escribir GDScript.
2. **Implementación** estrictamente según la spec aprobada. Si la spec resulta incorrecta, se detiene el código, se corrige la spec y se vuelve a aprobar.
3. **Review obligatoria** antes de dar cualquier tarea por terminada. El revisor (humano o IA) verifica **todos** estos puntos:
   - [ ] **Identidad (I):** la feature sirve a combate, supervivencia o progresión, tal como declara su spec.
   - [ ] **Arte (II):** primitivas por defecto. Todo asset importado vive en `assets/<tipo>/<categoría>/<asset>/`, tiene `SOURCE.md` y se usa vía escena adaptadora. Sin shaders personalizados. Jugador en blanco, enemigos en gris, colores reservados respetados. Materiales compartidos como `.tres`.
   - [ ] **Datos (III):** ningún valor tuneable quedó como literal en un script de comportamiento. Los nuevos stats y mejoras están en Resources `.tres`, los stats del jugador son mejorables y ningún Resource compartido se muta en runtime. Las mejoras únicas declaran `max_level` y guardan sus valores por nivel en datos.
   - [ ] **GDScript (IV):** nombres según convención. Todas las firmas y variables miembro tipadas. `_ready` / `_process` / `_physics_process` delgados y delegando en métodos con nombre.
   - [ ] **Performance (V):** sin allocations ni búsquedas de nodos por frame. Las entidades frecuentes usan pool. Capas y máscaras de colisión mínimas y explícitas.
   - [ ] **Input (VI):** solo acciones del InputMap, con bindings de teclado/mouse y de mando y control táctil. Los bindings de mouse de juego usan `device = DEVICE_ID_MOUSE`, nunca `-1`. Pantallas nuevas navegables con mando y usables al tacto (botones de 44 px de alto o más). Prompts desde datos.
   - [ ] **Combate (VII):** golpes comprometidos con cancel point; sin `Engine.time_scale` para feedback de impacto; auto-apuntado al enemigo más cercano salvo que los datos indiquen otra cosa.
   - [ ] **Animación (VIII):** se cumple el checklist del [estándar de animación](animation-standard.md) (§9). Hay video antes/después y escenarios de cancelación medidos, y nada en vivo pisa articulaciones que el motor mezcla.
   - [ ] **Calidad:** el proyecto abre sin errores ni warnings de tipado nuevos. Los tests de los criterios de aceptación de la spec están en verde y la suite completa sigue en verde.
4. **Cierre:** la spec se marca como *Implementada* y cualquier violación justificada (ver *Governance*) queda registrada en ella.

---

## Governance

- **Supremacía:** esta constitución tiene prioridad sobre cualquier decisión ad hoc, preferencia puntual, spec o plan. Una spec que la contradiga no puede aprobarse.
- **Violaciones:** cualquier desvío de un principio debe **justificarse explícitamente antes de implementarse**, en la spec de la feature. La justificación indica el principio afectado, el motivo, la alternativa conforme descartada y por qué, y el alcance y la fecha de revisión de la excepción. Sin justificación aprobada, no se implementa.
- **Enmiendas:** los cambios a este documento se proponen explícitamente, se aprueban y se reflejan con versionado semántico:
  - **MAJOR:** se elimina o se redefine un principio.
  - **MINOR:** se agrega un principio o sección nueva.
  - **PATCH:** aclaraciones, redacción y correcciones sin cambio de significado.
- Tras una enmienda **MAJOR**, las specs aprobadas previamente deben revisarse contra la nueva versión.
- Cada spec declara la versión de la constitución contra la que fue aprobada.

### Historial

Las versiones y enmiendas están en [`constitution-history.md`](constitution-history.md). Cada enmienda agrega su entrada allí y actualiza la versión de abajo.

---

**Version**: 5.1.0 | **Ratified**: 2026-09-24 | **Last Amended**: 2026-09-29
