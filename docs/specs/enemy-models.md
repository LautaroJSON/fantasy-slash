# Modelos y animaciones propios para los enemigos

- **Estado:** Propuesta (2026-09-28). Pendiente de aprobación. No se escribió código.
- **Constitución:** `docs/constitution.md` **v5.0.0** → **v6.0.0** (enmienda **MAJOR**, ver *Enmienda*).
- **Criterios de aceptación:** reserva propuesta **AC1191–AC1230**. Se reservan en `CLAUDE.md` y `docs/ac-registry.md` al aprobar (otras sesiones toman números en paralelo).
- **Pilar (Principio I):** Combate.
  - Un enemigo que se lee de un vistazo (forma, color, postura) permite reaccionar a tiempo. Hoy los tipos "se distinguen poco a la distancia" (nota de `enemy-types.md`) y los avisos dependen de dos esferas.
  - Las animaciones de aviso, golpe y recuperación **cuentan lo que el enemigo está por hacer**, y refuerzan el sector rojo del piso sin reemplazarlo.
- **Tipo:** feature de arte y animación. **No cambia ningún valor de gameplay.**
- **Dependencias:** `enemy-attack-telegraph.md` (`EnemyHands`, `EnemyAttackData`), `enemy-types.md`, `boss-verdugo.md`, `boss-titan.md`, `boss-colmena.md`, `enemy-rage.md`, `enemy-pace.md`, y el estándar `docs/animation-standard.md` (Principio VIII). El Esbirro depende de `fodder-minion.md` (en propuesta): su modelo entra recién cuando ese tipo exista.

## Decisiones que asumí (para vetar al aprobar)

1. **Camino A:** modelos construidos por código con primitivas y mallas de normales planas (como `LowPolyHumanoid`). Sin Blender ni `.glb`.
2. **Concepto "La Plaga":** soldados y bestias fusionados con quitina, resina y armadura oxidada. Cada tipo tiene un **tono dominante propio** y un punto de brillo que marca su peligro.
3. **Manos flotantes:** se conservan como en el jugador (torso, cabeza, manos y pies flotantes, estilo Rayman). Son el canal por el que los comportamientos ya avisan y golpean, y no se toca.
4. **Colmena:** su cuerpo es **ciruela y malva**, no miel. La miel `Color(0.95, 0.78, 0.25)` sigue reservada al aura del escudo, y el cambio evita mover ese color.
5. **Muerte:** sin clip. El enemigo se desactiva al morir y ese momento le corresponde a `kill-feedback.md`.
6. **Sin capa en vivo** (resortes, pies clavados) en esta spec. Todo va horneado en clips.

## Objetivo

1. Un **modelo distinto por cada tipo**: Bruto, Embestidor, Saltador, Hostigador, Escudero, Esbirro, Verdugo, Titán y Colmena.
2. **Animaciones propias:** caminar, aviso, golpe, poses de estado (aturdido, en el aire, guardia baja, transición, expuesta) y reacción al golpe.
3. **Color propio por tipo**, y ninguno en gris ni en un color de señal.
4. **Efectos propios de modelo**, chicos y baratos (polvo, vapor, esporas, destellos).
5. Los tiempos, hitboxes, rangos y datos de todos los enemigos **no cambian**.

## Diseño por tipo

Todos miran hacia −Z. La altura y el radio de partida son los de la cápsula actual (1.8 m × 0.4 m a `body_scale` 1). Los adornos (cuernos, hojas) pueden sobresalir, pero el cuerpo no cambia de tamaño real. Las paletas son de partida y se ajustan jugando.

| Tipo | Silueta | Paleta (dominante / acento / brillo) | Clips propios | Efectos |
|---|---|---|---|---|
| **Bruto** | Humanoide encorvado, hombros anchos, brazos largos, brote de resina en la espalda | Verde musgo / cuero / brote ámbar tenue | `walk` arrastrado; aviso: torso atrás y mano alzada; golpe: manotazo | Esporas leves al caminar |
| **Embestidor** | Bajo y en cuña, cabeza gacha, colmillos, placas de hueso en el lomo | Marrón cuero / hueso / ojos brillantes | Aviso: rasca el piso, baja la cabeza; golpe: cuerpo estirado en la carga; `stunned`: cabeza clavada, patas temblando | Polvo al rascar, estela de polvo en la carga, vapor al quedar aturdido |
| **Saltador** | Patas traseras enormes, torso chico, agachado parece un resorte | Turquesa pantanoso / vientre claro / manchas de resina | Aviso: se comprime y vibra; `airborne`: cuerpo estirado; golpe: aplastamiento al caer | Salpicadura de resina al aterrizar |
| **Hostigador** | El más alto y flaco, un brazo termina en hoja de quitina (su "mano adelante") | Violeta oscuro / hueso / filo lavanda pálido | `strafe_l` y `strafe_r` al orbitar; aviso: tirón atrás de 0.3 s; golpe: cuerpo casi horizontal | Destello en la punta de la hoja durante la estocada |
| **Escudero** | Ancho y alto, caparazón frente al pecho que hace de escudo | Azul acero / hueso / interior rosado | Guardia alta en `idle` y `walk`; golpe: embestida del caparazón; `guard_down`: el caparazón se abre y muestra el interior blando | Chispas al bloquear de frente, destello al abrirse |
| **Esbirro** | Chico (`body_scale` 0.7), redondo, muchas patitas, un manotazo grande y avisado | Rosado pálido / manchas oscuras (distinto de los demás, se lee como masa) | `walk` a trompicones; aviso exagerado y lento | Ninguno continuo (hasta 16 vivos) |
| **Verdugo** | Alto y ancho, capucha rota, **hoja enorme** en la mano derecha | Negro carbón / acero oscuro / brillo en el pecho (solo fase 2) | `slash_a`, `slash_b`, `slash_c`, `slash_d` (tajo), `shockwave` (hoja al piso), `grab` (mano libre abierta), `transition` (la capucha se rasga) | Estela de la hoja, chispas al clavarla |
| **Titán** | Gigante (`body_scale` 3.5), torso de piedra agrietada, manos flotantes enormes | Piedra pizarra / quitina oscura / grietas lima ácido | `slam`, `sweep`, `stomp` (aviso y golpe de cada uno), `stunned` (cuerpo caído), `transition` | Polvo y escombros en cada impacto, grietas que se encienden cuando la mano apoyada es punto débil |
| **Colmena** | Abdomen enorme con celdas hexagonales, torso chico, brazos finos alzados | Ciruela / malva / celdas lila claro | `summon` (las celdas se abren y sueltan larvas), `pulse` (temblor hacia afuera), `exposed` (abdomen pulsando), `transition` | Las celdas se iluminan al invocar |

### Reglas de diseño

- **Silueta primero:** vista desde la cámara del juego (unos 35° de inclinación, 12 m), cada tipo se identifica solo por la forma, sin leer el color.
- **El brillo es un aviso, no decoración:** los "puntos de brillo" se encienden durante el aviso (`set_alert`) y se apagan al recuperar. Cambian entre dos materiales compartidos (apagado y encendido), sin materiales por instancia y sin shaders.
- **Lo que se ve tiene que coincidir con lo que pasa:** el golpe visual empieza cuando empieza `active_time`, y la guardia baja del Escudero se ve abierta mientras el daño es completo.
- **Colores:** ningún cuerpo ni acento usa blanco, gris, el rojo anaranjado de los avisos, el rojo de Rage, la miel del escudo ni el tierra del polvo (ver `color-registry.md`).

## Arquitectura

El código respeta la separación actual: los comportamientos siguen llamando a `EnemyHands`, y el modelo **escucha**.

```
Enemy (CharacterBody3D)
├─ CollisionShape3D                (sin cambios)
├─ Body (Node3D)                   ← antes MeshInstance3D; origen en el centro de la cápsula
│  ├─ Fallback (MeshInstance3D)    ← la cápsula gris de siempre; se libera si stats.model != null
│  ├─ Model                        ← instancia de stats.model, en (0, −0.9, 0) (los pies quedan en Y=0)
│  ├─ RageAura, ShieldAura         (sin cambios)
├─ Hands
│  ├─ LeftHand, RightHand          ← mesh y material los pone el modelo (puño, garra, hoja…)
```

```
<Tipo>Model (Node3D, script que extiende EnemyModel)
├─ Flinch (Node3D)                 pivote de la reacción al golpe
│  └─ Hips (Node3D)                cadera y pivote de todo el cuerpo
│     ├─ Torso, Head y articulaciones propias (Shell, Blade, Cells, Tail…), cada una con su malla
│     └─ pies o patas flotantes
├─ Motion (AnimationPlayer)        clips del cuerpo, en `Hips` y debajo
├─ Overlay (AnimationPlayer)       solo la reacción al golpe, en `Flinch`
└─ Fx (Node3D)                     partículas primitivas (CPUParticles3D)
```

- **Se construye una vez.** Las mallas (`ArrayMesh` de normales planas), los materiales y las librerías de clips se crean la primera vez que se carga un tipo y se **comparten** entre todas las instancias del pool (Principio V). El nodo de cada enemigo solo cuelga las mallas ya creadas.
- **Ubicación:** `assets/models/enemies/` con `SOURCE.md` (origen: original, generado por código), `mesh_kit.gd` (utilidades comunes: caja, cuña, cono, prisma y loft con caras planas) y `enemy_model.gd` (base). Cada tipo tiene su carpeta con el script del modelo y su perfil de clips. La escena adaptadora de cada tipo vive en `entities/enemy/models/<id>_model.tscn`.
- **Sin caso especial en los comportamientos:** el único cambio en ellos es pasar el nombre de la pose donde ya llaman a `play_pose`.

### Contrato con el gameplay (no cambia)

- Cápsula de colisión, `body_scale`, `hit_padding`, hitboxes, tiempos, `EnemyHands` (posiciones, oscilación, tamaño, temblor, ocultar una mano), spawn desde el piso, hit lag y el hundimiento del Titán al aturdirse: todo sigue igual.
- `Enemy.get_body()` pasa a devolver `Node3D` (solo se le lee y escribe `position`).
- `EnemyHands.get_hand_radius()` deja de leer el `SphereMesh` y usa `EnemyHandsConfig.hand_radius` (0.2 por defecto, el radio de hoy). El punto débil del Titán sigue calculándose igual.

## Interfaz pública

- **`EnemyStats.model: PackedScene`** (nuevo, vacío = cápsula gris de hoy). `Enemy._ready` lo instancia una vez, lo cuelga de `Body` y le pide las mallas de las manos.
- **`EnemyHandsConfig`** suma `hand_radius: float` y `hand_rotation: Vector3` (grados, para la mano derecha; la izquierda espeja Y y Z). Sirve para orientar puños, garras y hojas.
- **`EnemyAttackData.model_clip: StringName`** (`&"attack"` por defecto). El aviso reproduce `<model_clip>_windup` y el golpe `<model_clip>_strike`. Si el modelo no los tiene, usa `windup` y `strike`.
- **`EnemyHands`** emite `windup_started(clip, duration)`, `strike_started(clip, duration)`, `pose_started(pose, duration)` y `rested()`. `play_pose` gana un parámetro `pose: StringName`, con `&"pose"` por defecto:
  - Embestidor aturdido: `&"stunned"`.
  - Saltador en el aire: `&"airborne"`.
  - Escudero con la guardia baja: `&"guard_down"`.
  - Transición de fase de un boss: `&"transition"`.
  - Titán aturdido: `&"stunned"`.
  - Colmena expuesta: `&"exposed"`.
- **`EnemyModel`** (base):
  - `play(clip, blend, seconds)`: reproduce un clip estirado a `seconds` (`speed_scale = largo / seconds`).
  - `has_clip(name)`.
  - `set_locomotion(local_velocity: Vector3)`: `idle` si está quieto, `walk` si va hacia adelante y `strafe_l`/`strafe_r` si el movimiento lateral domina y el modelo los tiene. La velocidad de la animación sigue la velocidad real.
  - `on_windup`, `on_strike`, `on_pose` y `on_rest`.
  - `on_hit()`: reproduce la reacción en `Overlay`.
  - `set_alert(on)`: enciende o apaga los brillos.
  - `reset()`: vuelve al estado inicial.
  - `get_hand_mesh(left)` y `get_hand_material()`.
- **`Enemy`** conecta las señales de `EnemyHands` al modelo, le pasa su velocidad local cada cuadro, llama `on_hit()` desde `notify_hit`, y `reset()` desde `activate` y `deactivate`.

## Clips (Principio VIII)

- **Nombres fijos** de todos: `idle` (loop), `walk` (loop), `windup`, `strike`, `recover`. Los de estado (`stunned`, `airborne`, `guard_down`, `transition`, `exposed`) y los propios de un tipo salen de la tabla de arriba.
- `windup` y `strike` **no se repiten**: quedan sosteniendo su última pose hasta que llega la siguiente fase o `return_to_rest`. Así el cuerpo no vuelve a neutro entre el golpe y la recuperación.
- **Duración nominal 1.0 s**, estirada al tiempo real. El ritmo de cada nivel (`enemy-pace`) y el ritmo de Rage ya escalan la duración que llega desde `windup()`.
- **Estándar de animación:** poses clave horneadas con cúbica monótona, superposición escalonada (cadera lidera, torso y cabeza siguen), anticipación clara (un cambio de silueta grande al inicio del aviso), sostén en el impacto y follow-through. Ver `docs/animation-standard.md`; esa doc pasa a incluir a los enemigos en su alcance.
- **La reacción al golpe** vive en `Overlay` y solo toca `Flinch` (una sacudida corta de escala e inclinación). No interrumpe los clips del cuerpo, así que no tapa un aviso.
- Ninguna pista de ningún clip apunta a `CollisionShape3D`, `Enemy` ni `HealthComponent`.

## Presupuestos (Principio V)

| | Enemigo común | Boss |
|---|---|---|
| Triángulos | ≤ 800 | ≤ 6.000 |
| `MeshInstance3D` (sin contar las manos) | ≤ 8 | ≤ 16 |
| Materiales | ≤ 3 por tipo, todos `.tres` compartidos en `materials/enemies/` | ≤ 4 |
| Partículas continuas | ≤ 1 emisor, ≤ 8 partículas | ≤ 2 emisores, ≤ 16 |
| Sombras | `cast_shadow` apagado en todas las partes | ídem |

Se fusionan en una sola malla las partes que comparten articulación y material. Los emisores de partículas solo se encienden desde un clip. Un enemigo inactivo no anima ni emite.

## Enmienda a la constitución (MAJOR → 6.0.0)

Sube la versión porque se redefine la convención de color del Principio II.

1. **Principio II, enemigos:** la regla "enemigos en gris, cápsula más dos esferas" se reemplaza por: los enemigos tienen **modelo y paleta propios por tipo**, con materiales `.tres` compartidos en `materials/enemies/` y sin texturas. Jamás son blancos (el blanco sigue siendo del jugador) ni usan un color reservado. Los tipos se distinguen por silueta primero y por tono dominante después.
2. **Principio II, modelos:** se amplía "Personaje procedural" a los enemigos: un modelo de enemigo puede ser un asset de script (`EnemyModel`) que construye sus mallas y clips **una vez**, comparte todo entre instancias y se usa solo vía su escena adaptadora.
3. **Principio II, partículas:** los modelos pueden llevar `CPUParticles3D` con material `.tres` compartido y sus parámetros en un Resource, encendidos solo desde un clip.
4. **`color-registry.md`:** las filas "Enemigos" y "Manos de enemigos" pasan a apuntar a las paletas por tipo, que se registran como colores no reservados. Se agrega la lista de colores que un cuerpo enemigo no puede usar (blanco, gris `Color(0.5, 0.5, 0.5)`, rojo anaranjado, rojo de Rage, miel, tierra).
5. **Principio VIII y `animation-standard.md`:** el alcance incluye a los enemigos.
6. **`constitution-history.md`:** entrada 6.0.0 con la razón de la enmienda.

## Criterios de aceptación (AC1191–AC1230, reservados)

**Infraestructura** (`test/entities/enemy/enemy_model_test.gd`):
- **AC1191:** con `stats.model` asignado, `Body` contiene el modelo y se libera `Fallback`. Sin modelo, el enemigo es idéntico al actual (cápsula gris).
- **AC1192:** la cápsula de colisión, `body_scale`, `hit_padding` y la posición de reposo de `Body` y `Hands` no cambian con un modelo.
- **AC1193:** `play_windup`, `play_strike`, `play_pose` y `return_to_rest` emiten `windup_started`, `strike_started`, `pose_started` y `rested` con su duración, y las posiciones de las manos son las mismas que antes.
- **AC1194:** el clip de aviso dura lo que la preparación real (con ritmo de nivel y Rage): `largo / speed_scale` = duración ± 1 %.
- **AC1195:** un ataque con `model_clip = &"slash_b"` reproduce `slash_b_windup` y `slash_b_strike`. Si falta, usa `windup` y `strike`.
- **AC1196:** velocidad 0 → `idle`; velocidad > 0 hacia adelante → `walk`, con `speed_scale` proporcional; lateral → `strafe_l`/`strafe_r` si existen y, si no, `walk`.
- **AC1197:** un golpe reproduce la reacción en `Overlay` y no cambia el clip ni el tiempo de `Motion`. Las pistas de `Overlay` solo tocan `Flinch`.
- **AC1198:** `deactivate` + `activate` en pleno ataque devuelve el modelo a `idle`, con brillos apagados, manos en reposo y `Flinch` en identidad, en todos los tipos.
- **AC1199:** `get_hand_radius` = `hand_radius` × escala global. Con el valor por defecto reproduce el de hoy (el punto débil del Titán no cambia).
- **AC1200:** cada `play_pose` de los comportamientos pasa su nombre (`stunned`, `airborne`, `guard_down`, `transition`, `exposed`) y el modelo lo reproduce.

**Modelos** (`test/assets/enemy_models_test.gd`, parametrizado por tipo):
- **AC1201:** cada modelo se construye y tiene `Flinch`, `Hips`, `Torso`, `Head` y los clips `idle`, `walk`, `windup`, `strike` y `recover`. Todo `model_clip` de sus `EnemyAttackData` y `BossMoveData` y toda pose que emiten sus comportamientos tienen clip.
- **AC1202:** cabe en los presupuestos de triángulos, `MeshInstance3D`, materiales y partículas.
- **AC1203:** la caja del modelo mide entre 0.9 y 1.3 veces la altura de la cápsula del tipo, y su ancho no pasa de 1.5 veces su diámetro.
- **AC1204:** dos instancias del mismo tipo comparten mallas, materiales y librerías, y todas las partes tienen `cast_shadow` apagado.
- **AC1205:** ningún material de enemigo es blanco, gris ni está a menos del umbral de tono (±20° con saturación > 0.3) de un color reservado.
- **AC1206:** los seis tipos comunes tienen tonos dominantes a más de 30° entre sí.
- **AC1207:** `idle` y `walk` hacen loop. `windup`, `strike` y los de estado no, y sostienen su última pose. Todos duran 1.0 s nominal.
- **AC1208:** ninguna pista apunta fuera del modelo (no toca `CollisionShape3D`, `Enemy` ni `HealthComponent`).

**Por tipo** (`test/entities/enemy/<tipo>_model_test.gd`):
- **AC1209 Bruto:** en `windup` la mano y el torso retroceden respecto de `idle`, y en `strike` avanzan.
- **AC1210 Embestidor:** en `stunned` la cabeza queda más baja que en `idle`, y el aturdimiento por pared la reproduce durante `wall_stun_time`.
- **AC1211 Saltador:** en `windup` la cadera baja a menos de 0.85 de escala en Y, y en `airborne` sube a más de 1.1.
- **AC1212 Hostigador:** la mano derecha tiene la hoja y apunta hacia adelante con `hand_rotation`. Existen `strafe_l` y `strafe_r`.
- **AC1213 Escudero:** en `idle` y `walk` el caparazón cubre el frente. En `guard_down` queda abierto y `set_alert` enciende el interior mientras el daño es completo.
- **AC1214 Esbirro:** ≤ 300 triángulos, sin partículas continuas. (Se cumple al implementar `fodder-minion`.)
- **AC1215 Verdugo:** tiene `slash_a` a `slash_d`, `shockwave`, `grab` y `transition`. En fase 2 se enciende el brillo del pecho.
- **AC1216 Titán:** tiene `slam`, `sweep`, `stomp`, `stunned` y `transition`. Al aturdirse se enciende el brillo de las grietas, y con una mano rota el modelo no muestra esa mano.
- **AC1217 Colmena:** tiene `summon`, `pulse`, `exposed` y `transition`. Las celdas se abren durante `summon`, y el aura de escudo sigue mostrándose sobre el modelo.
- **AC1218:** las manos (mallas) de cada tipo respetan `hand_scale` y `hand_radius` de su `EnemyHandsConfig`.

**Efectos y cierre:**
- **AC1219:** los emisores de un modelo solo emiten desde un clip y quedan apagados en un enemigo inactivo.
- **AC1220:** en la arena, oleadas 1 a 8 con semilla fija y todos los tipos con modelo corren sin errores ni orphans.
- **AC1221:** los tests de comportamiento existentes de enemigos (`test/entities/enemy`) pasan sin cambiar lo que verifican. Se adaptan solo los que leen `get_body()` como `MeshInstance3D`, y se anota abajo.
- **AC1222:** `color-registry.md`, `constitution.md` (6.0.0), `constitution-history.md` y `animation-standard.md` están actualizados.

AC1223–AC1230 quedan de reserva.

## Plan de implementación

Cada bloque termina con tests dirigidos (`godot-tester`) y, si tiene arte, con hojas de captura (`godot-capture`): aviso, golpe y recuperación a velocidad real y al 30 %, desde la cámara del juego y de cerca. **Hay pausa de revisión después del piloto.**

1. **Reservas y enmienda:** reservar AC1191–AC1230 (próximo libre AC1231), y escribir la enmienda 6.0.0 y sus anexos.
2. **Infraestructura:** `MeshKit`, `EnemyModel`, `EnemyStats.model`, `Body` como `Node3D` con `Fallback`, `EnemyHandsConfig.hand_radius` y `hand_rotation`, señales de `EnemyHands`, `model_clip` y los nombres de pose en los comportamientos. Con todos los tipos sin modelo, nada cambia. Tests AC1191–AC1200.
3. **Piloto: Bruto.** Modelo, paleta, clips y efectos. Validar la lectura desde la cámara y el costo en celular. **Pausa: reviso con vos antes de seguir.** Tests AC1201–AC1209.
4. **Comunes:** Escudero, Embestidor, Saltador y Hostigador, uno por uno con su captura. Tests AC1210–AC1213.
5. **Esbirro**, una vez implementada `fodder-minion`. Test AC1214.
6. **Bosses:** Verdugo, Titán y Colmena. Tests AC1215–AC1217.
7. **Efectos, ajuste de paletas y cierre:** AC1218–AC1222, medición en el dispositivo Android, `where-to-tune.md`, `docs/specs/README.md`, `CLAUDE.md`. Estado **Implementada**.

## Riesgos y notas

- **Conflictos con otras sesiones:** `enemy.gd`, `enemy.tscn`, `enemy_hands.gd`, `enemy_stats.gd` y `EnemyAttackData` también los tocan `fodder-minion` y `early-power-curve`. Releer cada archivo antes de editarlo.
- **Calidad del arte:** las primitivas producen un estilo facetado y geométrico. El piloto sirve para decidir si el resultado alcanza o si algún boss justifica más adelante un modelo hecho en un DCC.
- **Rendimiento:** con 16 Esbirros y varios tipos a la vez, lo que puede doler es la cantidad de `MeshInstance3D` y de `AnimationPlayer`, no los triángulos. Los presupuestos y el punto 7 del plan lo cubren.
- **Aura de Rage y de escudo:** siguen siendo cápsulas translúcidas. Con cuerpos que no son cápsulas se ven como una burbuja. Si no convence, se les da una escala por tipo (`aura_scale`) en una spec chica.
- **Muerte y VFX de kill:** fuera de esta spec, quedan en `kill-feedback.md`.

## Review (checklist de la constitución)

- [ ] **I.** Combate: lectura de avisos y silueta.
- [ ] **II.** Enmienda 6.0.0 escrita: modelos, paletas, partículas y colores registrados.
- [ ] **III.** Datos en `.tres`: `model`, `hand_radius`, `hand_rotation` y `model_clip`. Las medidas del modelo son datos del asset, como las poses del humanoide.
- [ ] **IV.** Tipado estático.
- [ ] **V.** Todo se construye una vez y se comparte. Presupuestos verificados por test y medición en el dispositivo.
- [ ] **VI.** Sin input nuevo.
- [ ] **VII.** Los tiempos de gameplay no cambian.
- [ ] **VIII.** Clips horneados con el estándar. Video antes y después por bloque.
