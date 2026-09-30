# Feature: Iluminación de los stages y cielo panorámico

- **Estado:** **Implementada** (2026-09-29), con la verificación manual del responsable pendiente (AC1389–AC1393). Cielo: OpenGameArt "Cloudy Skyboxes" `Panorama_Sky_04` (CC0, `assets/skies/sbs_cloudy_sky_04/`); el FreeStylized Sky 05 elegido al principio se descartó por poco realista y sus archivos se borraron.
- **Constitución:** escrita contra **v6.3.0**; la enmienda **MINOR** se aplicó como **6.4.0**: cielo panorámico como imagen, en el Principio II "Escenarios (stages)", y aclaración de los modos de material del motor permitidos (ver §7).
- **Criterios de aceptación:** reserva **AC1376–AC1395** (ya anotada en `ac-registry.md` y `CLAUDE.md`).
- **Pilar (Principio I):** Combate (legibilidad).
  - Hoy todo se ve "muy claro": pasto, flores, personajes y sombras tienen casi el mismo brillo, así que un enemigo o un aviso no se separan del fondo.
  - Con luz y sombra bien contrastadas (sol cálido, sombras frías, un contorno de luz en los personajes), los cuerpos se leen como volúmenes y se despegan del piso. El combate se lee mejor y el mundo gana el aspecto "light fantasy" de las referencias.
- **Tipo:** feature visual (render de los stages y materiales).
- **Dependencias:** `stages.md` (`StageMap`, Mar de Flores y Arena), `enemy-models.md` (materiales de enemigos), `humanoid-player-model.md` (material del jugador), `docs/color-registry.md`.

## Decisiones del responsable (2026-09-29)

| Pregunta | Decisión |
|---|---|
| Camino para la iluminación | **Opción A:** ajuste de luces, materiales del motor y post-procesado, **sin shaders propios**. Referencia: la iluminación de Genshin Impact. |
| Climas | **No.** Un solo clima: **de día**, como ahora. |
| Cielo | **Panorama estático** (una imagen 360°), no nubes 3D. Puede girar muy lento. |
| Imagen del cielo | Elegir entre las candidatas de §4 **al empezar la implementación**. |

## 1. Diagnóstico: por qué se ve "muy claro"

1. **Luz ambiente fuerte y neutra.** El cielo procedural aporta ambiente con energía 1.0, y rellena las sombras casi al mismo brillo que lo iluminado: no hay contraste luz/sombra.
2. **Tonemap Filmic y paleta pálida.** Los verdes del terreno y del pasto son claros y poco saturados; el tonemap los aplana más.
3. **Sombreado "realista" suave.** El `StandardMaterial3D` hace una transición gradual de luz a sombra, con brillo especular. El look de Genshin es lo contrario: luz y sombra en **dos tonos marcados**, sombras de color frío (azuladas) y un **borde de luz** en las siluetas.
4. **Sin separación de planos.** La niebla es muy leve y del mismo tono en todas las direcciones, así que no hay profundidad atmosférica.

## 2. Objetivo: la iluminación "estilo Genshin" sin shaders propios

Godot trae en su material estándar y en el `Environment` casi todas las piezas de ese look:

| Ingrediente | Cómo se logra (todo del motor) |
|---|---|
| Luz y sombra en dos tonos | `BaseMaterial3D.diffuse_mode = DIFFUSE_TOON` en los materiales de escenario, personajes y armas |
| Sin brillo plástico | `specular_mode = SPECULAR_TOON` (brillo chico y duro) o `SPECULAR_DISABLED` en el escenario |
| Borde de luz en las siluetas | `rim_enabled`, `rim` y `rim_tint` en los materiales del jugador, las armas y los enemigos |
| Sol cálido, sombras frías | Sol dorado (`light_color` cálido, más energía) y ambiente del cielo **más bajo y azulado** (`ambient_light_energy`, `ambient_light_sky_contribution`; el panorama azul tiñe las sombras) |
| Colores ricos, no lavados | Tonemap **AgX**, `tonemap_exposure`, y `adjustment_enabled` con saturación y contraste un poco arriba |
| Brillo suave del cielo y los emisivos | `glow_enabled` con intensidad baja y `glow_bloom` leve |
| Profundidad atmosférica | Niebla de distancia azulada con `fog_sun_scatter` cálido (más clara hacia el sol) y `fog_aerial_perspective` |
| Paleta del piso | Verdes del terreno y del pasto **más oscuros y saturados** que hoy, para que los personajes resalten |

Todo esto funciona en el renderer **Mobile** de Android (a diferencia de SSAO, SSIL, SDFGI y la niebla volumétrica, que no se usan).

## 3. Arquitectura

### 3.1 Luz por stage en datos (`StageLighting`)

Hoy la luz del Mar de Flores la escribe el generador del mapa (constantes de `build_mar_de_flores.gd`) y la de la Arena está dentro de su escena. Pasa a un Resource por stage, aplicado por el `StageMap`:

- **`StageLighting`** (nuevo, `resources/stage_lighting.gd`), en `data/stages/<id>/<id>_lighting.tres`:
  - `environment: Environment`: cielo, ambiente, tonemap, ajustes, glow y niebla. Es un `.tres` escrito a mano, que el generador **deja de escribir**.
  - Sol: `sun_color`, `sun_energy`, `sun_pitch_deg`, `sun_yaw_deg`, `sun_shadow_blur`, `sun_shadow_max_distance`.
  - `sky_rotation_speed_deg` (grados por minuto; 0 = quieto) y `sky_yaw_offset_deg` (alinea la zona clara del panorama con el sol).
- **`StageMap`** suma `@export var lighting: StageLighting`, `@export var world_environment: WorldEnvironment` y `@export var sun: DirectionalLight3D`, y en `_ready` aplica el Resource a esos nodos. En `_process` (delgado) gira el cielo si la velocidad no es 0: cambia `Environment.sky_rotation.y`, sin allocations. El `Environment` se **duplica** al aplicarlo (Principio III: no se muta un Resource compartido).
- `build_mar_de_flores.gd` deja de generar `mar_de_flores_environment.tres` y las constantes de sol y niebla. Asigna `lighting` y las referencias de nodos en la escena.
- **Arena:** recibe su `arena_lighting.tres` con los valores de hoy, así se ve igual (AC1386). Si más adelante se quiere mejorar su luz, es solo cambiar ese `.tres`.

### 3.2 Cielo panorámico

- El `Environment` del Mar de Flores usa `PanoramaSkyMaterial` con la imagen elegida, en lugar del `ProceduralSkyMaterial`.
- La imagen vive en `assets/skies/<id>/<id>.png` (equirectangular 2:1) con su `SOURCE.md`, y solo la referencia el `Environment` del stage (ese `.tres` hace de adaptador, §7).
- Se sacan las **nubes 3D**: el `MultiMesh` `Clouds`, `scatter/clouds.res`, `cloud_puff.tres`, `cloud_material.tres` y `MarDeFloresBuilder.clouds()`. Las montañas y el castillo 3D se quedan: el cielo va detrás.
- El cielo también ilumina: el ambiente sale del panorama (`ambient_light_source = SKY`), así que un cielo azul enfría las sombras solo.

### 3.3 Materiales

- **Escenario** (`materials/environment/*.tres`, terreno, ruinas, castillo, props y vegetación): `diffuse_mode = TOON` y `specular_mode = DISABLED`. El agua conserva su brillo (`SPECULAR_SCHLICK_GGX`).
- **Jugador y armas** (`materials/player_material.tres`, `materials/weapons/*.tres`) y **enemigos** (`materials/enemies/*.tres`): `diffuse_mode = TOON`, `specular_mode = TOON` y borde de luz (`rim_enabled`, `rim` y `rim_tint` en datos del `.tres`). Los emisivos y los VFX (unshaded) no cambian.
- **Paleta del piso:** en `MarDeFloresBuilder` se oscurecen y saturan `MEADOW`, `OUTSIDE` y el tinte del pasto (`grass_material`), y se regenera el mapa. Los valores finales salen de las capturas comparadas (§6).
- **Colores:** ningún `albedo_color` cambia de tono, así que la tabla de colores reservados y las paletas de enemigos siguen valiendo. El borde de luz de los enemigos no puede ser blanco puro (reservado del jugador): se usa un tinte (`rim_tint`) hacia el color propio del material.

## 4. Candidatas de cielo

Hoja de miniaturas: [`stage-lighting-sky/sky_candidates.png`](stage-lighting-sky/sky_candidates.png) (enviada al responsable el 2026-09-29). En las miniaturas los panoramas se ven como una esfera.

| Candidata | Look | Licencia | Notas |
|---|---|---|---|
| **FreeStylized Sky 05** (recomendada) | Día, azul intenso, cúmulos blancos grandes estilo anime. Lo más cercano a Genshin y a las referencias. | "Royalty Free: free to use for all commercial and non-commercial purposes" (no es CC0) | 2K gratis (2048 × 1024; en pantalla puede verse algo suave); 4K y 8K pagos. Hecho con IA más pintura a mano, según el sitio. |
| FreeStylized Sky 10 | Día, cielo despejado con nubes bajas en el horizonte. Más calmo. | Igual | Igual |
| FreeStylized Sky 09 / 08 | Día cálido, nubes con bordes dorados (media tarde). | Igual | Más "atardecer": se aleja del "de día como está". |
| Sketchfab "FREE - SkyBox Anime Sky" (Paul) | Cielo anime con un paisaje pintado (montañas, costa) adentro. | CC BY (hay que acreditar) | 6K. El paisaje pintado choca con el terreno y las montañas 3D: no recomendado. |
| OpenGameArt "Cloudy Skyboxes" (Screaming Brain Studios) | Nubes fotorrealistas. | CC0 | 2048 × 1024. No es light fantasy: solo como respaldo si la licencia de FreeStylized no sirve. |

Fuentes: [FreeStylized, skyboxes](https://freestylized.com/all-skybox/), [Sketchfab, Anime Sky](https://sketchfab.com/3d-models/free-skybox-anime-sky-56a60c1d1e8b44eabff138374f996d8f), [OpenGameArt, Cloudy Skyboxes](https://opengameart.org/content/cloudy-skyboxes-0).

**Antes de bajar la elegida:** confirmar con el responsable que la licencia de FreeStylized permite guardar el archivo en el repo del proyecto (el sitio no publica una página de licencia aparte; si el repo es público y no queda claro, se pregunta o se usa el respaldo CC0). El `SOURCE.md` registra la URL, la licencia textual, la resolución y la fecha.

## 5. Criterios de aceptación (AC1376–AC1395)

**Luz en datos**
- **AC1376** Al cargar un stage, `StageMap` aplica su `StageLighting`: el `WorldEnvironment` usa una copia de `lighting.environment` y el sol tiene el color, la energía, la orientación y las sombras del Resource.
- **AC1377** El `Environment` aplicado es una copia: el `.tres` compartido no cambia al girar el cielo.
- **AC1378** Con `sky_rotation_speed_deg` > 0, `sky_rotation.y` avanza esa cantidad por minuto; con 0, no cambia.
- **AC1379** `build_mar_de_flores.gd` ya no escribe el `Environment` ni valores de sol: la escena generada referencia `mar_de_flores_lighting.tres`.
- **AC1380** La Arena tiene `arena_lighting.tres` con los valores de su luz de hoy (mismo color de fondo, ambiente y sol).

**Cielo**
- **AC1381** El `Environment` del Mar de Flores usa `PanoramaSkyMaterial` con la imagen de `assets/skies/<id>/`, y el ambiente sale del cielo.
- **AC1382** La imagen es equirectangular 2:1 y su carpeta tiene `SOURCE.md` con origen, licencia y fecha.
- **AC1383** No quedan nubes 3D: ni nodo `Clouds` en la escena ni `clouds.res`, `cloud_puff.tres`, `cloud_material.tres` o `MarDeFloresBuilder.clouds()`.

**Look**
- **AC1384** Tonemap AgX, glow activo y ajustes de color activos con saturación > 1, todo en el `.tres` del stage.
- **AC1385** Todos los materiales de `materials/environment/` salvo el agua tienen `diffuse_mode = TOON` y `specular_mode = DISABLED`.
- **AC1386** Los materiales del jugador, de las armas y de los enemigos tienen `diffuse_mode = TOON`, `specular_mode = TOON` y borde de luz activo; ningún `albedo_color` cambió de tono (±2°) respecto de antes de esta spec.
- **AC1387** Ningún borde de luz de un enemigo es blanco puro (`rim_tint` > 0).
- **AC1388** Los verdes del terreno y del pasto del Mar de Flores quedan más oscuros que hoy (valor HSV menor) y al menos igual de saturados.

**Verificación visual y rendimiento (manuales)**
- **AC1389** Capturas antes/después de las mismas vistas que AC1320 de `stages.md` (juego, ruinas hacia el castillo, arroyo, panorámica, arboleda) y del jugador y enemigos de cerca: las sombras se leen en dos tonos, los personajes se despegan del piso y el cielo se ve como el panorama elegido.
- **AC1390** Captura de un aviso de ataque sobre las flores con la luz nueva: se lee completo.
- **AC1391** Video del juego real en el Mar de Flores (primera oleada) con la luz nueva.
- **AC1392** En el teléfono de pruebas, el Mar de Flores no pierde más del 10 % de cuadros por segundo respecto de antes de esta spec (Mobile renderer).
- **AC1393** La Arena se ve igual que antes (captura comparada).
- **AC1394** Smoke test sin errores ni warnings nuevos.
- **AC1395** Suites de la spec en verde y las de `stages` (`stage_run_test`, `mar_de_flores_test`, `stage_data_test`) siguen en verde (tests viejos adaptados anotados en §9).

## 6. Cómo se ajustan los números

Los valores concretos (energías, ángulo del sol, saturación, exposición, verdes nuevos, borde de luz) se eligen **mirando capturas**, no se fijan de antemano. Flujo:

1. Aplicar la arquitectura (§3) con los valores de hoy: el juego se ve igual.
2. Cambiar a la vez panorama, tonemap, ambiente y sol y capturar las 5 vistas.
3. Activar el toon en el escenario y capturar.
4. Activar el toon y el borde de luz en personajes y enemigos y capturar de cerca.
5. Ajustar la paleta del piso, regenerar el mapa y capturar.

Cada paso con captura antes/después para el responsable. Los valores finales quedan en los `.tres` y en esta spec (§9).

Punto de partida sugerido: sol `Color(1.0, 0.9, 0.75)`, energía 1.6, pitch −40°; ambiente del cielo 0.45; AgX con exposición 1.0; saturación 1.2, contraste 1.08; glow 0.3; niebla `Color(0.62, 0.75, 0.95)` con dispersión solar `Color(1.0, 0.85, 0.6)`.

## 7. Enmienda a la constitución (MINOR)

Principio II, viñeta "Escenarios (stages)", se agrega:

> Un stage puede usar como cielo una **imagen panorámica** (equirectangular) en `assets/skies/<id>/` con su `SOURCE.md`, referenciada solo desde el `Environment` de su `StageLighting`. Sus píxeles no cuentan para la tabla de colores (es fondo, no un elemento del mundo). La luz de cada stage (sol, ambiente, tonemap, ajustes, glow y niebla) vive en un `StageLighting` por stage.

Y una aclaración de materiales:

> Los materiales `StandardMaterial3D` pueden usar los modos del motor `DIFFUSE_TOON`, `SPECULAR_TOON`/`SPECULAR_DISABLED` y el borde de luz (`rim`). No son shaders propios. El borde de luz de un enemigo nunca es blanco puro.

`color-registry.md`: nota de que el cielo panorámico queda fuera de la tabla, y regla del borde de luz.

## 8. Plan de implementación

1. **Elegir el cielo** con el responsable (§4) y confirmar la licencia. Bajarlo a `assets/skies/<id>/` con `SOURCE.md`.
2. **Enmienda** en `constitution.md`, `constitution-history.md` y `color-registry.md`. Revisar la versión vigente y el contador de ACs (otras sesiones trabajan en paralelo).
3. **`StageLighting` y `StageMap`** (aplicar luz y girar el cielo), `arena_lighting.tres` con los valores de hoy y `mar_de_flores_lighting.tres` con los de hoy. Cambiar `build_mar_de_flores.gd` para que referencie el `.tres` y no genere el `Environment`; sacar las nubes 3D del builder y del mapa. Regenerar el mapa **sin `--headless`**. Tests AC1376–AC1383. Captura: el juego se ve igual salvo el cielo.
4. **Panorama, tonemap, ambiente, sol, ajustes, glow y niebla** en `mar_de_flores_lighting.tres`: capturas antes/después.
5. **Toon y especular en el escenario** (AC1385): capturas.
6. **Toon y borde de luz en jugador, armas y enemigos** (AC1386–AC1387): capturas de cerca. Coordinar con quien tenga abiertos los materiales de enemigos (`enemy-models`).
7. **Paleta del piso** en el builder y regenerar (AC1388): capturas.
8. **Cierre:** video (AC1391), aviso sobre flores (AC1390), Arena igual (AC1393), smoke test, suites, `where-to-tune.md` (viñeta "Stages": luz por stage), `specs/README.md`, checklist de la constitución y estado **Implementada**. El responsable mide en el teléfono (AC1392).

## 9. Notas de implementación

**Paso 3 (2026-09-29): hecho.**
- Cielo elegido en este paso: FreeStylized Sky 05 (después reemplazado, ver "Cambio de cielo"). Constitución en 6.4.0.
- `StageLighting` (`resources/stage_lighting.gd`) suma `sun_shadows` (bool) además de los campos de §3.1, porque la Arena no tiene sombras y el Mar de Flores sí.
- El `Environment` vive dentro del `.tres` de cada `StageLighting` (sub-recurso), no en un archivo aparte. `mar_de_flores_environment.tres` se borró.
- `mar_de_flores_lighting.tres` conserva los valores de hoy (Filmic, glow 0.4, niebla, sol `Color(1, 0.95, 0.85)` energía 1.25, −48°/−35°) con el panorama en lugar del cielo procedural; el cielo gira 1°/min. Los valores nuevos vienen en el paso 4.
- **Hallazgo:** el sol de la Arena estaba escrito con una `Transform3D` que, leída por filas, **apunta hacia arriba** (+Y): nunca iluminó el piso (por eso el piso se ve casi negro). `arena_lighting.tres` lo reproduce con pitch +42.72° y yaw −42.88° para cumplir AC1380 y AC1393 (la Arena se ve igual). Si se quiere una Arena bien iluminada, es cambiar esos dos números (fuera de alcance, §10).
- Las nubes 3D y el `Environment` del generador se sacaron; el mapa se regeneró sin `--headless` (solo cambió `mar_de_flores_stage.tscn`; el resto de los `.res` se reproduce idéntico).
- Tests: `test/levels/stage_lighting_test.gd` (AC1376–AC1383). Con ellos y `stage_run_test` (19), `mar_de_flores_test` (11), `stage_data_test` (5) en verde y smoke test sin errores.
- Capturas del paso 3: Mar de Flores igual salvo el cielo; Arena igual que antes.

**Paso 4 (2026-09-29): hecho, sin capturas (las verifica el responsable a mano).** `mar_de_flores_lighting.tres` pasa a los valores de partida de §6: tonemap AgX (exposición 1.0), ambiente del cielo 0.45, sol `Color(1, 0.9, 0.75)` energía 1.6 y pitch −40° (yaw −35°; después −30°, ver "Cambio de cielo"), ajustes de color con saturación 1.2 y contraste 1.08, glow 0.3 con bloom 0.05, niebla `Color(0.62, 0.75, 0.95)` con `fog_sun_scatter` 0.25 (el motor tiñe la dispersión con el color del sol, así que no lleva color propio). Test AC1384 en `stage_lighting_test.gd` (9 tests en verde; `mar_de_flores_test` 11 en verde). Los valores finales se ajustan según lo que vea el responsable.

**Cambio de cielo (2026-09-29).** A pedido del responsable (quería un cielo más realista) el panorama pasa a `Panorama_Sky_04` del pack "Cloudy Skyboxes" de Screaming Brain Studios (CC0). Como la imagen trae el sol pintado (azimut +91.4°, ~27° de elevación), `sky_yaw_offset_deg = -123.6` lo alinea con el sol del juego (yaw −35°) y el pitch del sol baja a −30°. El cielo deja de girar (`sky_rotation_speed_deg = 0`): un sol pintado que gira no coincidiría con la luz. Si el sol pintado queda del lado equivocado, el signo del offset es el que hay que invertir (+123.6).

**Paso 5 (2026-09-29): hecho, sin capturas (las verifica el responsable).** Los 19 materiales de `materials/environment/` (todos menos `water_material.tres`) tienen `diffuse_mode = TOON` y `specular_mode = DISABLED`; el agua conserva su brillo. Test AC1385 en `stage_lighting_test.gd` (10 en verde, más `mar_de_flores_test` 11 y `stage_run_test` 19).

**Paso 6 (2026-09-29): hecho, sin capturas (las verifica el responsable).** `diffuse_mode = TOON`, `specular_mode = TOON` y borde de luz (`rim_enabled`, `rim = 0.6`) en `materials/player_material.tres`, `materials/enemy_material.tres` (la cápsula sin modelo), los materiales lit de `materials/weapons/` y los `StandardMaterial3D` no emisivos de `materials/enemies/` (cuerpo, acento, capa, cuero y sobrevesta del Rey). `rim_tint`: 0.0 en el jugador (borde blanco, reservado del jugador) y 0.5 en armas y enemigos (borde teñido hacia el color propio, nunca blanco puro). Sin cambio: los `glow` (emisivos), los `overlay` del brillo de la katana (unshaded) y el acero y el oro del Rey (`ShaderMaterial` `king_metal`, propio). Ningún `albedo_color` cambió. Tests en `test/assets/character_look_test.gd` (AC1386–AC1387, 3 en verde); `enemy_models_test` (salvo AC1203), `king_model_test` (13), `humanoid_model_test` (5), `katana_visual_test` (9) y `weapon_model_test` (17) en verde. **Fallas previas, ya presentes en el último commit y ajenas a esta spec:** `enemy_models_test` AC1203 (el Titán es más ancho que 1.5× la cápsula), `warrior_sword_and_shield_test` AC751 (la punta de la espada roza el piso en el dash y el sprint) y AC755 y `berserker_greatsword_test` AC1013 (buscan `knight_sword.res`, `knight_shield.res` y `knight_greatsword.res` en `constitution.md`, pero esa tabla se movió a `color-registry.md` en la 4.27.1).

**Paso 7 (2026-09-29): hecho, sin capturas (las verifica el responsable).** Paleta del piso más oscura y saturada: `MEADOW` `(0.47, 0.68, 0.31)` → `(0.34, 0.56, 0.20)`, `OUTSIDE` `(0.40, 0.60, 0.28)` → `(0.28, 0.50, 0.17)`, `grass_material` `(0.62, 0.86, 0.40)` → `(0.45, 0.72, 0.26)` y, para que el suelo de afuera de los muros no quede más claro que el prado, `far_ground_material` `(0.42, 0.60, 0.30)` → `(0.30, 0.50, 0.20)`. Mapa regenerado sin `--headless`: solo cambió `terrain.res` (la escena difiere solo en ids, no se copió). Test AC1388 en `stage_lighting_test.gd` (11 en verde; `mar_de_flores_test` 11 y `stage_run_test` 19 en verde). Los verdes siguen a más de 20° de tono del aviso y de Rage (AC1317). El `HILL_GREEN` de las colinas lejanas no se tocó.

**Ajuste tras capturas (2026-09-29).** El jugador se veía quemado, con un halo blanco. Se comparó A (estado de los pasos 4–6), B (umbral de glow 1.4 y sol 1.25) y C (B más `rim = 0.3` y sin especular en el jugador): B casi no cambiaba nada y C lo resolvía, o sea que la causa era el borde blanco (`rim = 0.6`) más el especular toon sobre un cuerpo de albedo blanco puro. Quedó: `player_material.tres` con `specular_mode = DISABLED` y `rim = 0.3` (esto **enmienda AC1386**: el jugador no lleva `SPECULAR_TOON`; armas y enemigos sí), `glow_hdr_threshold = 1.4` y `sun_energy = 1.25` en `mar_de_flores_lighting.tres`. Con enemigos en fila y el jugador en las capturas: los enemigos ganan volumen; **el Bruto (verde) se confunde con el pasto más oscuro** (cuerpo `(0.28, 0.42, 0.2)` contra prado `(0.34, 0.56, 0.2)`); el responsable eligió aclarar el prado (sin tocar la paleta de enemigos): `MEADOW` `(0.38, 0.60, 0.22)`, `OUTSIDE` `(0.33, 0.55, 0.20)`, `grass_material` `(0.50, 0.78, 0.30)` y `far_ground_material` `(0.35, 0.55, 0.23)`, todavía más oscuros y al menos igual de saturados que antes de la spec (AC1388). El cambio se nota poco en las capturas: el Bruto sigue siendo una silueta verde oscura de bajo contraste sobre el prado; si molesta jugando, el siguiente paso es un borde de luz más claro solo en el Bruto.

**Cierre (2026-09-29).**
- **Valores finales:** ver `data/stages/mar_de_flores/mar_de_flores_lighting.tres` (AgX, ambiente 0.45, sol `Color(1, 0.9, 0.75)` energía 1.25 pitch −30° yaw −35°, saturación 1.2, contraste 1.08, glow 0.3 con umbral 1.4, niebla azulada con dispersión solar 0.25, cielo `Panorama_Sky_04` con `sky_yaw_offset_deg` −123.6 y sin giro) y `data/stages/arena/arena_lighting.tres` (la luz de siempre).
- **Tests de la spec:** `test/levels/stage_lighting_test.gd` (AC1376–AC1385 y AC1388) y `test/assets/character_look_test.gd` (AC1386–AC1387). Suites de `stages` (`stage_run_test`, `mar_de_flores_test`, `stage_data_test`) en verde; no hizo falta adaptar ningún test viejo. Solo se corrieron suites dirigidas (pedido del responsable), no la suite completa.
- **Verificación visual hecha por el asistente** (capturas de juego con jugador y los seis enemigos): el jugador ya no se quema, los enemigos ganan volumen, la Arena queda igual. Pendiente conocido: el Bruto verde tiene poco contraste con el prado.
- **Pendiente del responsable (manual):** AC1389 (capturas de las vistas de AC1320), AC1390 (aviso de ataque sobre las flores), AC1391 (video de la primera oleada), AC1392 (fps en el teléfono, máx. −10 %) y AC1393 (Arena igual: la captura comparada del paso 3 ya coincide).
- **Fallas previas ajenas a esta spec** (también en el último commit): `enemy_models_test` AC1203, `warrior_sword_and_shield_test` AC751 y AC755, `berserker_greatsword_test` AC1013.
- **Checklist de la constitución:** Identidad (I) combate/legibilidad; Arte (II) sin shaders propios (solo modos del motor), cielo con `SOURCE.md` y licencia CC0, jugador blanco, borde de enemigos teñido; Datos (III) la luz vive en `StageLighting` `.tres` y el `Environment` se duplica al aplicarlo; GDScript (IV) tipado, `_ready`/`_process` delgados; Performance (V) sin allocations por frame y `_process` apagado si el cielo no gira; Input (VI), Combate (VII) y Animación (VIII) no aplican.

## 10. Fuera de alcance

- Shaders propios: cel shading con rampas pintadas, contornos negros, cielo animado con capas de nubes (estilo Genshin completo). Piden enmendar "sin shaders propios".
- Ciclo día/noche y climas.
- Iluminación nueva para la Arena (solo se muda a `StageLighting`).
