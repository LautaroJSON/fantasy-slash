# Constitución de fantasy-slash

> Reglas no negociables del proyecto. Cualquier persona o IA que trabaje en este repo **lee este documento antes de tocar código**.
> Toda especificación, plan, review y línea de GDScript debe cumplirlo. Ante un conflicto entre este documento y una decisión ad hoc, gana este documento (ver *Governance*).

---

## Principios centrales

### I. Identidad de género

El juego es un **hack and slash roguelike en tercera persona para PC, jugado con teclado y mouse o mando**. Toda mecánica, sistema o feature nueva debe poder responder **"sí"** al menos a una de estas preguntas antes de especificarse:

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
- **Mallas planas procedurales para avisos enemigos** (desde 4.5.0): los avisos de ataque enemigo en el piso pueden usar sectores circulares construidos como `ArrayMesh` **una vez al cargar** (cuando el pool crea el enemigo), con material `.tres` compartido y sin texturas. Círculos y franjas siguen siendo primitivas (`CylinderMesh`, `BoxMesh`).
- **Personaje procedural** (desde 4.9.0): el cuerpo del jugador puede ser `LowPolyHumanoid`, un asset de script que vive en `assets/models/characters/low_poly_humanoid/` con su `SOURCE.md`. Construye sus mallas (`ArrayMesh` de normales planas) y su `AnimationPlayer` **una vez**, en `_ready`, y se usa solo vía su escena adaptadora (`entities/player/humanoid.tscn`), con materiales `.tres` compartidos. Sus poses y tiempos de animación son datos del asset (como los keyframes de un `.glb`); los valores de gameplay que dependen de ellos viven en Resources. Puede tener **perfiles de animación** (uno por clase, desde 4.10.1): todas sus librerías se construyen una vez al cargar, y elegir un perfil solo selecciona una librería ya construida.
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
- **Convención de color obligatoria:**
  | Elemento | Malla base | Color (`albedo_color`) |
  |---|---|---|
  | Jugador (cuerpo: torso, cabeza, manos y pies flotantes, una sola silueta) | Humanoide low-poly (`LowPolyHumanoid`) | **Blanco**: `Color(1, 1, 1)` |
  | Arma del jugador (espada y escudo del Guerrero) | Mallas generadas `knight_sword.res` y `knight_shield.res` | Colores de sus materiales en `materials/weapons/` (no reservados) |
  | Arma del jugador (mandoble del Berserker) | Malla generada `knight_greatsword.res` | Colores de sus materiales en `materials/weapons/` (no reservados) |
  | Arma del jugador (katana del Samurái, con funda) | Modelo `katana.glb` (mallas derivadas) | Textura de paleta de su material en `materials/weapons/` (no reservada) |
  | Estela del arma (ataques y habilidades, todas las armas) | Ribbon procedural (`ImmediateMesh`) | **Blanco translúcido**: `Color(1, 1, 1)`, unshaded, alpha ≤ 0.5 en la cabeza y 0 en la cola |
  | Corte de viento (VFX de Envainar y del Tajo aéreo del Berserker): paredes en V, chispas y destello | `BoxMesh` / `SphereMesh`, partículas | **Blanco**: `Color(1, 1, 1)`, unshaded, blend aditivo, alpha ≤ 0.5 |
  | Corte del dash (VFX del Giro cancelado con un dash): estela horizontal, chispas y destello | `BoxMesh` / `SphereMesh`, partículas | **Blanco**: `Color(1, 1, 1)`, unshaded, blend aditivo, alpha ≤ 0.5 |
  | Corte circular (VFX de la Estocada mejorada de Contragolpe): cinta horizontal alrededor del Guerrero | Cinta procedural (`ImmediateMesh`) | **Blanco translúcido**: `Color(1, 1, 1)`, unshaded, alpha ≤ 0.5 en la cabeza y 0 en la cola |
  | VFX del dash: imágenes residuales (copias del cuerpo) y líneas de velocidad | Mallas del humanoide / `BoxMesh` | **Blanco**: `Color(1, 1, 1)`, unshaded; residuos alpha ≤ 0.35, líneas aditivas alpha ≤ 0.5 |
  | Área de una habilidad del jugador (relleno en el piso: rectángulo) | `BoxMesh` plano | **Blanco**: `Color(1, 1, 1)`, unshaded, alpha ≤ 0.3 en reposo y ≤ 0.5 en un destello |
  | Impacto de golpe (combo básico, Envainar y Giro): fragmento de luz con halo, destello y chispas donde la hoja cruza al enemigo; el crítico es más grande y cruzado | `SphereMesh` (elipsoides), partículas `BoxMesh` | **Blanco**: `Color(1, 1, 1)`, unshaded, blend aditivo, alpha ≤ 0.5, sin prueba de profundidad (se dibuja por encima) |
  | Enemigos | `CapsuleMesh` | **Gris**: `Color(0.5, 0.5, 0.5)` |
  | Manos de enemigos (las dos esferas que anticipan y dan el golpe) | `SphereMesh` | **Gris**: `Color(0.5, 0.5, 0.5)` (mismo `enemy_material.tres` que el cuerpo) |
  | Números de daño flotantes (normal) | `TextMesh` | **Blanco**: `Color(1, 1, 1)` |
  | Números de daño flotantes (crítico) | `TextMesh` | **Blanco**: `Color(1, 1, 1)` (se distingue por el sufijo "!" y el tamaño) |
  | Textos flotantes de Aflicción: su nombre cada vez que se aplica o se refresca, y los números de daño de las que hacen daño (Veneno, Sangrado, Estallido) | `TextMesh` | El color de la barra de su Aflicción (no reservado); los de daño en el tiempo, en cursiva |
  | Nivel de enemigo (junto a su barra de vida) | `TextMesh` | **Blanco**: `Color(1, 1, 1)` |
- Los colores de esta tabla quedan **reservados** para los elementos listados (salvo las armas, que se distinguen por su silueta). Ningún otro elemento (escenario, props, proyectiles, otra UI 3D) puede usarlos, para que jugador, arma y enemigos se identifiquen siempre de un vistazo. El blanco se comparte únicamente entre el cuerpo del jugador, los textos flotantes (números de daño normales y críticos, y nivel de enemigo), la estela del arma, el corte de viento de Envainar, el corte del dash del Giro, el corte circular de la Estocada mejorada (desde 4.23.0), los VFX del dash, el impacto de golpe, las chispas del bloqueo del escudo (desde 4.22.0) y el área de las habilidades en el piso, que no se confunden: uno es un cuerpo opaco, otros son texto, la estela, los cortes, los VFX del dash, el impacto de golpe y las chispas del bloqueo son translúcidos y se desvanecen en décimas de segundo, y el área es un relleno plano en el piso, muy transparente. El gris se comparte solo entre el cuerpo del enemigo y sus manos, que forman una misma silueta.
- Colores **no reservados** en uso, a modo de registro: celeste pálido para las cartas de mejora de habilidad (desde 4.20.0 ya no marca el área de las habilidades, que es blanca), rojo para la carta de bloqueo, dorado para las cartas de mejora única (y, desde 4.0.1, el brillo de la katana y el marco del HUD con "Envainar: mejorado"), rojo oscuro para el ícono de sangrado, violeta `Color(0.55, 0.35, 0.8)` para el ícono de Debilitar, verde lima `Color(0.55, 0.85, 0.25)` para el ícono de Conmoción en el HUD, tierra `Color(0.62, 0.52, 0.4)` para el polvo del corte de viento, del dash y del Giro y para el anillo de la onda de choque de los bosses (`TorusMesh` plano, unshaded, alpha ≤ 0.6), y rojo `Color(0.9, 0.1, 0.1)` para el ícono de Rage y su aura (cápsula unshaded translúcida, alpha ≤ 0.3, más grande que el cuerpo gris del enemigo), negro translúcido `Color(0.05, 0.05, 0.05)` (alpha ≤ 0.7, unshaded) para el agujero de aparición de los enemigos (`CylinderMesh` plano sobre el piso), rojo anaranjado `Color(1.0, 0.3, 0.1)` (unshaded, alpha ≤ 0.5, destello hasta 0.8) para los avisos de ataque enemigo en el piso, y miel `Color(0.95, 0.78, 0.25)` para el aura de escudo de la Colmena (cápsula unshaded translúcida, alpha ≤ 0.3, más grande que el cuerpo) y su ícono "Escudo", amarillo `Color(1.0, 0.9, 0.2)` para la barra de estamina del HUD (una barra en la esquina, no se confunde con el dorado de las cartas ni con la miel de la Colmena; ver `sprint-stamina.md`), y acero, acero oscuro, latón y cuero para la espada y el escudo del Guerrero (el latón no se confunde con el dorado: es un arma opaca en la mano del jugador; ver `warrior-sword-and-shield.md`). Desde 4.16.0, los íconos de estado (UI 2D, ver `status-icons.md`): el color de cada estado vive en su `icon_color` (ya no en materiales de ícono) y tiñe el fondo (oscurecido) y el glifo (aclarado); marco rojo `Color(0.85, 0.2, 0.15)` para los debuffs y verde `Color(0.3, 0.8, 0.35)` para los buffs; y la casilla "+" de desborde con fondo oscuro, borde negro y un "+" gris claro `Color(0.85, 0.85, 0.85)`. Desde 4.17.0, las Aflicciones (ver `affliction.md`): verde veneno `Color(0.25, 0.6, 0.2)`, naranja explosión `Color(1.0, 0.55, 0.15)` para Estallido (desde 4.18.1; antes azul), cian escarcha `Color(0.45, 0.9, 0.95)` y gris claro `Color(0.7, 0.7, 0.72)` para Corrosión (desde 4.18.1; antes el violeta de Debilitar; distinto del gris reservado de los enemigos), y carmesí `Color(0.75, 0.1, 0.25)` para Sangrado (desde 4.19.1; distinto del rojo de la barra de vida y del de Rage), en sus barras (`QuadMesh` unshaded bajo la barra de vida y `ColorRect` en la del boss) y como `icon_color` de sus estados; el destello de una barra al llenarse `Color(0.85, 1.0, 0.9)` (no es el blanco reservado); y violeta `Color(0.45, 0.25, 0.7)` para el tier de cartas de Aflicción. Desde 4.22.0 (ver `warrior-abilities-rework.md`): el tierra registrado también colorea el polvo y el anillo de la Carga de escudo; amarillo estrella `Color(1.0, 0.95, 0.55)` para el ícono de Aturdido; magenta `Color(0.85, 0.3, 0.6)` para el ícono de Retado; y azul `Color(0.35, 0.6, 1.0)` para el ícono de Triunfo.
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
- **Render:** materiales compartidos (ver Principio II), sin luces dinámicas ni sombras innecesarias.

**Rationale:** las allocations por frame provocan picos del recolector y stutter. Instanciar y liberar en combate genera hitches justo cuando hay más acción. La física innecesaria es el costo oculto que más escala con la cantidad de enemigos.

### VI. Input: teclado y mouse, o mando

- El juego se controla con **teclado y mouse** o con **mando** (layout Xbox; otros mandos vía el mapeo SDL de Godot). No hay controles táctiles, salvo los **botones de acción del HUD** (ver excepciones).
- Todo input pasa por el **InputMap** con acciones nombradas (`move_forward`, `attack`, `dash`…). **Toda acción de juego tiene binding en los dos esquemas.** Prohibido leer teclas o botones físicos directamente en la lógica de juego.
- **Toda pantalla de UI se puede usar con mando:** foco inicial al mostrarse, foco visible, `ui_accept` para confirmar y `ui_cancel` para volver donde haya "volver".
- Los textos de teclas y botones que muestra la UI (prompts) salen de datos (`InputPromptConfig`), nunca de literales en escenas o scripts.
- Excepciones:
  - El movimiento relativo del mouse para la cámara (`InputEventMouseMotion`), que el InputMap no puede representar. Se lee solo dentro del nodo de cámara.
  - `InputDeviceMonitor` clasifica los eventos **por tipo** (teclado/mouse o mando) solo para elegir qué prompts mostrar. No lee botones concretos ni decide gameplay.
  - **Botones táctiles del HUD** (desde 4.14.0): un botón de acción del HUD puede aceptar toques de pantalla (`InputEventScreenTouch`). Un toque aprieta **su acción del InputMap** (`Input.action_press`/`action_release`) y nada más: la lógica de juego sigue leyendo solo acciones. Qué botones son táctiles es un dato del botón (`touch_action`). Moverse, la cámara y el ataque táctiles necesitan su propia spec.

**Rationale:** el combate de un hack and slash se juega cómodo con mando. Mantener todo en el InputMap y los prompts en datos hace que sumar el mando no duplique la lógica de juego.

### VII. Sensación del combate

El combate cuerpo a cuerpo tiene peso: cada golpe compromete, avanza e impacta (desde 4.10.0, ver `bdo-combat-feel.md`).

- **Compromiso:** un golpe del ataque básico no permite moverse libremente hasta su *cancel point* (la apertura de su ventana de combo). En la recuperación, el movimiento se limita a un desplazamiento lento sin girar (o la corta, según datos). El dash y el salto (desde el piso) cortan el golpe en cualquier momento (el salto desde 4.12.0, ver `jump-cancels-strike.md`).
- **Estocada:** los golpes desplazan al jugador con una distancia de datos atada al tiempo del clip (root motion por datos), que se frena ante un enemigo delante.
- **Hit lag local:** el impacto se comunica pausando el clip del atacante y congelando y sacudiendo a los golpeados, con duración por golpe. **Prohibido modificar `Engine.time_scale`** como feedback de impacto. Los bosses solo tiemblan, para que el combo no los congele en cadena. **Las habilidades canalizadas** (p. ej. el Giro) comunican el impacto con el temblor de los golpeados y la sacudida de cámara, **sin pausar al jugador**, para no desfasar sus golpes periódicos. Una pausa durante un dash (p. ej. el Corte del Giro) detiene solo el clip: el dash conserva su recorrido, su duración y su invulnerabilidad (desde 4.20.0). Los golpes de las habilidades no canalizadas (p. ej. la Carga de escudo) pausan el clip del jugador, congelan y sacuden a los golpeados y sacuden la cámara, con valores por golpe en su config (`StrikeFeel`, desde 4.22.0).
- **Tiempo congelado** (desde 4.23.0): un remate excepcional, definido en datos (hoy solo la Estocada mejorada de Contragolpe, ver `parry-riposte-rework.md`), puede congelar a todos los enemigos activos (bosses incluidos) durante una fracción de segundo, sin tocar `Engine.time_scale`: el jugador, la cámara y los VFX siguen animándose. Sigue prohibido modificar `Engine.time_scale`.
- **Estela:** durante una habilidad, la estela del arma se ve solo mientras la hoja barre, si la habilidad lo declara (p. ej. la Carga no la muestra; el Contragolpe, solo en la estocada; desde 4.22.0).
- **Apuntado:** por defecto, el golpe apunta al enemigo más cercano y lo sigue durante la anticipación. La cámara solo mira, y el input de movimiento no desvía el golpe salvo que los datos lo indiquen.
- Todos estos valores viven en `AttackComboConfig`, `AttackComboStep` y `HitstopConfig` (Principio III). Los tiempos del golpe (inicio y fin del daño, *cancel point* y fin) viven en `AttackComboStep`; los eventos del clip del humanoide están en los mismos tiempos y un test los compara (desde 4.10.1).

**Rationale:** en un hack and slash, el peso de cada golpe hace que pelear sea una decisión: golpear al aire tiene costo, y encadenar o cortar el combo es expresivo. Un hit lag local mantiene el resto del mundo vivo y legible.

---

## Technology Stack

| Área | Decisión |
|---|---|
| Motor | **Godot 4.x** (actualmente 4.7) |
| Lenguaje | **GDScript** con tipado estático (Principio IV). Sin C# ni GDExtension en el prototipo. |
| Renderer | **Forward+** |
| Física | Jolt Physics (3D) |
| Plataforma | **PC (Windows)** |
| Input | **Teclado y mouse, o mando**, vía InputMap (Principio VI) |
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
   - [ ] **Input (VI):** solo acciones del InputMap, con bindings de teclado/mouse y de mando. Pantallas nuevas navegables con mando. Prompts desde datos.
   - [ ] **Combate (VII):** golpes comprometidos con cancel point; sin `Engine.time_scale` para feedback de impacto; auto-apuntado al enemigo más cercano salvo que los datos indiquen otra cosa.
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

- **4.23.0** (2026-09-28): Principio VII: tiempo congelado (un remate excepcional congela a todos los enemigos activos sin tocar `Engine.time_scale`). Principio II: fila del corte circular de la Estocada mejorada (blanco translúcido) en la tabla de colores (ver `parry-riposte-rework.md`).
- **4.22.1** (2026-09-28): Principio II: tabla de colores: el mandoble del Berserker pasa a ser la malla generada `knight_greatsword.res`, de la familia de la espada y el escudo del Guerrero; el ejemplo de "Scaffolding" apunta a la katana (el falchion se borró; ver `berserker-greatsword.md`).
- **4.22.0** (2026-09-27): Principio II: chispas del bloqueo del escudo en la lista de blancos compartidos, y colores de Aturdido, Retado y Triunfo y del polvo de la Carga en el registro. Principio III: estado aturdido (`STUN`), bloqueo frontal con el atacante del golpe y buffs globales que vencen con todos sus stacks. Principio VII: hit lag de los golpes de habilidad no canalizados y estela solo mientras la hoja barre (ver `warrior-abilities-rework.md`).
- **4.21.0** (2026-09-27): Principio II: fila nueva en la tabla de colores para el impacto de golpe (fragmento de luz, halo, destello y chispas en blanco aditivo, alpha ≤ 0.5, dibujado por encima), que comparte el blanco con los demás VFX translúcidos; el crítico usa el mismo blanco (ver `hit-impact-vfx.md`).
- **4.20.2** (2026-09-27): Principio II: la fila de textos flotantes de Aflicción cubre el nombre de todas las Aflicciones al aplicarse (ver `affliction-name-popup.md` §7).
- **4.20.1** (2026-09-27): Principio II: la fila del área de las habilidades cubre solo el rectángulo; el Giro ya no dibuja su disco (ver `spin-visual-rework.md` §12).
- **4.20.0** (2026-09-27): Principio II: el área de las habilidades del jugador se marca con un relleno blanco muy transparente en el piso (fila nueva en la tabla de colores; el celeste pálido queda solo para las cartas de mejora de habilidad) y el polvo del Giro usa el tierra registrado. Principio VII: las habilidades canalizadas no pausan al jugador en el impacto, y una pausa durante un dash detiene solo el clip (ver `spin-visual-rework.md`).
- **4.19.1** (2026-09-27): Principio II: se registra el carmesí de la Aflicción Sangrado (barra, ícono y número; ver `affliction-bleed.md`).
- **4.19.0** (2026-09-27): Principio II: la fila de los números de daño de Aflicción pasa a cubrir también el nombre flotante de las Aflicciones que no hacen daño, en el color de su barra (ver `affliction-name-popup.md`).
- **4.18.1** (2026-09-27): Principio II: en el registro de colores de las Aflicciones, Corrosión pasa a gris claro `Color(0.7, 0.7, 0.72)` y Estallido a naranja `Color(1.0, 0.55, 0.15)` (ver `frost-freeze.md`).
- **4.18.0** (2026-09-27): Principio II: los números de daño críticos pasan a blanco (el ámbar `Color(1, 0.55, 0.1)` deja de estar reservado) y los de las Aflicciones toman el color de su barra; los de daño en el tiempo van en cursiva (ver `affliction-damage-colors.md`).
- **4.17.0** (2026-09-27): Principio III: Aflicciones (carga por golpe, cartas por fuente con niveles, stat mejorable, resistencia general, tope por run), el estado `SLOW`, stacks mejorables y acumulables y daño por tick fijo. Principio II: colores de las barras de Aflicción y del tier violeta de cartas (ver `affliction.md`).
- **4.16.0** (2026-09-27): Principio II: íconos de estado SVG en la UI 2D (`assets/icons/`, con `SOURCE.md`), un estándar único para buffs y debuffs de jugador, bosses y enemigos; desaparecen los íconos 3D de los enemigos y la fila de su tiempo restante en la tabla de colores (ver `status-icons.md`).
- **4.15.0** (2026-09-27): Principio II: VFX de imágenes residuales del jugador (copias de las mallas del cuerpo, con pool) y fila de los VFX del dash en la tabla de colores (blanco translúcido); el polvo del dash usa el tierra registrado (ver `dash-feel.md`).
- **4.14.0** (2026-09-27): Principio VI: los botones de acción del HUD pueden ser táctiles y disparan su acción del InputMap (ver `dash-button.md`).
- **4.13.1** (2026-09-27): Principio II: se registra el amarillo de la barra de estamina del HUD como color no reservado (ver `sprint-stamina.md`).
- **4.13.0** (2026-09-27): Principio II: se permiten modelos generados por script (mallas estáticas originales, generadas offline en la carpeta del asset y verificadas por un test); la espada y el escudo del Guerrero reemplazan a la hoplita en la tabla de colores (ver `warrior-sword-and-shield.md`).
- **4.12.1** (2026-09-27): Principio II: la reproporción de una malla derivada incluye redondear un extremo reubicando sus vértices, y puede servir para distinguir una parte de otra (ver `katana-sheath-shape.md`).
- **4.12.0** (2026-09-27): Principio VII: el salto (desde el piso) corta el golpe del ataque básico en cualquier momento, como el dash (ver `jump-cancels-strike.md`).

- **4.11.0** (2026-09-27): Principio II: las mallas derivadas pueden reproporcionar regiones del modelo para encajar con el cuerpo del jugador; su generador vive en la carpeta del asset (ver `katana-hand-proportions.md`).

- **4.10.1** (2026-09-26): Principio II: el personaje procedural puede tener perfiles de animación por clase, todos construidos una vez al cargar. Principio VII: los tiempos del golpe viven en `AttackComboStep` y un test los compara con los eventos del clip. Se corrige la versión del pie (ver `class-combat-identity.md`).

- **4.10.0** (2026-09-26): se agrega el Principio VII, *Sensación del combate*: golpes comprometidos con cancel point, estocada por datos, hit lag local (prohibido `Engine.time_scale` como feedback de impacto) y auto-apuntado al enemigo más cercano; se suma al checklist de review (ver `bdo-combat-feel.md`).

- **4.9.0** (2026-09-26): Principio II: se permite un personaje procedural (`LowPolyHumanoid`, mallas y animaciones construidas una vez al cargar, escena adaptadora y materiales `.tres`) como cuerpo del jugador; la fila del jugador en la tabla de colores pasa a ese humanoide, sigue en blanco (ver `humanoid-player-model.md`).

- **4.8.0** (2026-09-26): Principio II: el corte de viento de la tabla de colores también es el VFX del impacto del Tajo aéreo del Berserker (mismo efecto y colores; ver `berserker-air-slash.md`).

- **4.7.0** (2026-09-26): Principio II: se agrega a la tabla de colores el corte del dash del Giro (estela horizontal, chispas y destello en blanco aditivo, alpha ≤ 0.5), que comparte el blanco con la estela del arma y el corte de viento (ver `spin-dash-slash.md`).

- **4.6.1** (2026-09-26): Principio III: los iframes dejan de ser un stat propio; la invulnerabilidad del dash dura lo que el dash (`DASH_DISTANCE / DASH_SPEED`). El ejemplo del piso del cooldown pasa a "supera la duración del dash" (ver `dash-iframes.md`).

- **4.6.0** (2026-09-26): Principio II: se registra el miel del aura de escudo de la Colmena y de su ícono como color no reservado (ver `boss-colmena.md`).

- **4.5.0** (2026-09-26): Principio II: se permiten mallas planas procedurales (`ArrayMesh`, construidas al cargar) para los avisos de ataque enemigo en el piso, y se registra el rojo anaranjado de esos avisos como color no reservado (ver `enemy-ground-telegraph.md`).

- **4.4.0** (2026-09-26): Principio II: el tierra no reservado del polvo del corte de viento también colorea el anillo de la onda de choque de los bosses (`TorusMesh` plano, alpha ≤ 0.6; ver `boss-verdugo.md`).

- **4.3.0** (2026-09-26): Principio II: se registra como color no reservado el negro translúcido del agujero de aparición de los enemigos (`CylinderMesh` plano, alpha ≤ 0.7; ver `enemy-group-ai.md`).

- **4.2.0** (2026-09-26): Principio II: se agregan a la tabla de colores las manos de los enemigos (`SphereMesh` gris, mismo material que el cuerpo), que comparten el gris con la cápsula del enemigo (ver `enemy-attack-telegraph.md`).

- **4.1.0** (2026-09-26): Principio II: la fila del tiempo restante de debuff pasa a cubrir también el número de stacks sobre el ícono (`TextMesh` blanco, ver `debuff-stacks-display.md`).

- **4.0.1** (2026-09-26): Principio II: el dorado no reservado de las cartas de mejora única se registra también para el brillo de la katana y el marco del HUD de "Envainar: mejorado" (ver `tsubame-gaeshi.md`).

- **4.0.0** (2026-09-25): Principio VI redefinido: el juego se controla con teclado y mouse **o mando**; toda acción tiene binding en los dos esquemas, toda pantalla se usa con mando y los prompts salen de datos. Nueva excepción: `InputDeviceMonitor` (clasifica eventos por tipo). Principio I y Technology Stack actualizados. Specs revisadas: ninguna contradice el nuevo principio (ver `gamepad-support.md`).

- **3.7.0** (2026-09-25): Principio III: la lista de `DebuffData` de una entidad también guarda buffs (efecto `STAT_BOOST`) y estados permanentes. Principio II: se registra el rojo del ícono y del aura de Rage como color no reservado (ver `enemy-rage.md`).

- **3.6.0** (2026-09-25): Principio II: se agrega a la tabla de colores el tiempo restante de debuff sobre los enemigos (`TextMesh` blanco), que comparte el blanco con los demás textos flotantes (ver `cooldown-timers.md`).

- **3.5.0** (2026-09-25): Principio III: `DebuffData` declara su efecto (daño por tick o reducción de armadura) y su tope de stacks; se agrega la viñeta **Buffs** (`BuffData`, lista por jugador). Principio II: se registran el violeta del ícono de Debilitar y el verde lima del ícono de Conmoción como colores no reservados (ver `spin-golden-upgrades.md`).

- **3.4.0** (2026-09-25): Principio II: se permiten partículas (`CPUParticles3D`) y luces breves (`OmniLight3D`) solo para VFX. El corte de viento de Envainar pasa a ser una V vertical (paredes, chispas y destello en blanco aditivo, alpha ≤ 0.5), y se registra el tierra del polvo como color no reservado (ver `wind-cut-v.md`).

- **3.3.0** (2026-09-25): Principio II: se agrega a la tabla de colores el corte de viento de Envainar (dos `BoxMesh` planos, blanco translúcido, alpha ≤ 0.5), que comparte el blanco con la estela del arma (ver `sheathe-feel.md`).

- **3.2.0** (2026-09-25): Principio II: se permiten texturas de imagen en modelos importados, referenciadas solo desde materiales `.tres` compartidos, y mallas estáticas derivadas de un modelo cuando hay que separar partes. Se agrega la katana del Samurái a la tabla de colores (ver `samurai.md`).

- **3.1.2** (2026-09-25): Principio III: el ejemplo de stats del jugador apunta a `data/classes/warrior/warrior_stats.tres` (los datos de cada clase viven en `data/classes/<clase>/`).

- **3.1.1** (2026-09-25): Principio III: se aclara que un stat puede quedar fijo por diseño (sin carta en el catálogo) y sigue siendo un stat en `.tres` (ver `stats-rework.md`).

- **3.1.0** (2026-09-25): Principio II: se permiten mallas procedurales (`ImmediateMesh`) solo para VFX. La estela de viento del Giro se reemplaza por la estela estándar del arma (ribbon blanco translúcido, alpha ≤ 0.5), usada en todos los ataques y habilidades (ver `weapon-trail.md`).

- **3.0.1** (2026-09-25): tabla de colores del Principio II: la espada del Guerrero pasa a ser el modelo `hoplite_sword.obj`. La Spartan sword queda disponible como escena propia (`spartan_sword.tscn`). Sin cambios de reglas (ver `hoplite-sword.md`).

- **3.0.0** (2026-09-25): Principio II redefinido: primitivas por defecto y assets importados permitidos (`.obj`, glTF preferido; a futuro texturas y audio) con reglas de scaffolding (`assets/<tipo>/<categoría>/<asset>/`), escena adaptadora, materiales `.tres` compartidos y `SOURCE.md`. Las armas del jugador pasan a ser modelos (Spartan sword y Falchion) y el negro y el gris oscuro dejan de estar reservados. Se elimina la cláusula "el Principio II no admite excepciones". Specs revisadas: `berserker.md`, `combat-mvp.md` (ver `weapon-models.md`).
- **2.6.0** (2026-09-25): Principio II: se agrega a la tabla de colores la estela de viento del Giro, blanco translúcido (transparencia ≥ 0.75, unshaded), compartiendo el blanco con el cuerpo del jugador y los textos flotantes.
- **2.5.0** (2026-09-25): Principio II: se agrega a la tabla de colores el mandoble del Berserker, gris oscuro `Color(0.2, 0.2, 0.22)`, reservado. Cada clase tiene un arma fija con su propio color.
- **2.4.0** (2026-09-25): Principio II: los números de daño tienen dos variantes en la tabla de colores; los críticos usan ámbar `Color(1, 0.55, 0.1)`, reservado para ellos.
- **2.3.0** (2026-09-25): Principio II: se agrega a la tabla de colores que el nivel de enemigo (`TextMesh`, junto a su barra de vida) usa blanco, compartido con el cuerpo del jugador y los números de daño.
- **2.2.1** (2026-09-25): Principio III: se aclara que toda carta de mejora declara su tope en datos (`max_stacks` / `max_level`) y sale del pool al alcanzarlo.
- **2.2.0** (2026-09-25): Principio III: se agrega la subsección "Mejoras únicas de habilidad" (niveles explícitos, `max_level = 1` = no mejorable, valores por nivel en `.tres`) y el concepto de debuffs como datos en una lista por entidad. Principio II: se registran los colores no reservados en uso.
- **2.1.0** (2026-09-25): Principio II: se agrega a la tabla de colores que los números de daño flotantes (`TextMesh`) usan blanco, compartido solo con el cuerpo del jugador.
- **2.0.0** (2026-09-24): se elimina el target Android. El Principio V se redefine como performance general. Se agrega el Principio VI (solo teclado y mouse). Principio II: la espada del jugador pasa a ser negra. Principio III: todos los stats de gameplay del jugador son mejorables y nada se hardcodea. Stack: PC, Forward+.
- **1.0.0** (2026-09-24): versión inicial.

---

**Version**: 4.23.0 | **Ratified**: 2026-09-24 | **Last Amended**: 2026-09-28
