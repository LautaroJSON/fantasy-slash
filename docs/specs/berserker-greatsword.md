# Feature: mandoble nuevo del Berserker, de la familia de caballero

- **Estado:** Implementada (2026-09-28). ACs: AC1006–AC1013. El falchion se borró (propuesta de §2.3).
- **Constitución:** `docs/constitution.md` v4.22.0 → **enmienda PATCH a 4.22.1** (ver §7).
- **Pilar (Principio I):** **combate.** El Berserker se define por el peso de su arma: golpes lentos, alcance de 3 m y barridos amplios. Hoy el falchion es un sable curvo de pack que no comunica ese peso. Una losa de acero enorme lo dice de un vistazo y hace legible el alcance. Además, compartir la estética con la espada y el escudo del Guerrero hace que las armas se lean como un mismo mundo.
- **Referencia del responsable (2026-09-27):** un mandoble tipo "Matadragones":
  - hoja recta, muy ancha y gruesa, con los filos casi paralelos;
  - punta en corte oblicuo, algo corrida hacia un lado;
  - la cara de la hoja oscura y un bisel claro en cada filo;
  - guarda de bloque, apenas más ancha que la hoja;
  - mango largo, a dos manos, encintado, y un pomo chico.
- **Pedido:** que parezca de la **misma familia** que la espada y el escudo del Guerrero (`warrior-sword-and-shield.md`).
- **Dependencias:**
  - `warrior-sword-and-shield.md` (juego de caballero, generador y materiales);
  - `class-combat-identity.md` (perfil del Berserker; AC653 y AC678–AC680: la mano izquierda en el `OffHand` en cada impacto);
  - `weapon-reach.md` (AC211) y `weapon-models.md` (AC204).

## 1. Estado actual

- `data/classes/berserker/greatsword.tres` → `entities/player/weapons/greatsword.tscn` → `falchion.obj` (pack de terceros) con tres materiales `falchion_*`.
- En el espacio del arma:
  - la hoja y la guarda van de z = −0.13 a la punta en z = −2.21, con 55 cm de guarda;
  - el mango va de −0.15 a +0.14 (29 cm) y el pomo llega a +0.27;
  - el puño derecho cae en z = +0.133 (`grip_position` (0, −0.04, −0.1)) y la mano izquierda en `OffHand` (z = −0.1);
  - la estela va de `TrailBase` (−0.77) a `TrailTip` (−2.21).
- `attack_range` 3.0 por AC211: `0.4 + 2.21 × cos 0.1 + 0.4`.

## 2. Diseño

### 2.1 Qué lo hace "de la familia"

| Rasgo del juego de caballero | En el mandoble |
|---|---|
| Acero oscuro con canto de acero claro (el escudo) | La cara de la hoja en **acero oscuro** y los **biseles de los filos en acero claro**, como la hoja negra con borde plateado de la referencia |
| Latón en guarda, remaches y pomo | **Guarda de bloque en latón** cuyos extremos terminan en la misma punta de lanza que la guarda de la espada; **pomo de disco en latón**; **anillos de latón** en el mango |
| La cruz de Santiago (escudo) | **Una cruz de Santiago chica en latón** en relieve, en las dos caras de la hoja, junto a la guarda (como una marca de forja) |
| Cuero con anillos de latón (empuñadura de la espada) | Mango largo de cuero con anillos de latón en los extremos y en el medio, entre las dos manos |
| Low poly de normales planas, generado por script | Mismo generador (`build_knight_meshes.gd`) y **los mismos cuatro materiales** `knight_*`: ningún material nuevo |

### 2.2 Forma (referencia)

Espacio del arma (el `Model` en identidad), como la espada: la hoja apunta a −Z, el ancho va en X y el espesor en Y.

| Parte | Medida | Forma |
|---|---|---|
| Punta | z = −2.21 (sin cambios) | Corte oblicuo: el filo +X sigue recto hasta 30 cm antes de la punta, el filo −X corta en diagonal, y la punta queda 6 cm hacia −X del eje |
| Hoja | ≈ 1.95 m de la guarda a la punta, **30 cm de ancho** | Filos paralelos. Sección hexagonal: una losa central de **3 cm de espesor** (cara de acero oscuro) y un bisel de **4 cm por filo** que cierra hasta ≈ 1 mm (acero claro). Mantiene el filo |
| Marca de forja | 18 cm de alto, a 8 cm de la guarda | Cruz de Santiago de latón, relieve de 3 mm, en las dos caras |
| Guarda | **36 cm de ancho**, 7 cm de alto, 6 cm de espesor | Bloque de latón con los bordes biselados; los extremos se ensanchan y cierran en punta de lanza, como la guarda de la espada |
| Mango | **42 cm**, de z = +0.23 a −0.19 | Cuero octogonal de 4.2 cm, con anillos de latón en los dos extremos y uno en el medio, entre las dos manos (puño derecho en +0.133, `OffHand` en −0.1) |
| Pomo | 8 cm de diámetro | Disco de latón biselado, como el de la espada pero más grande |
| Largo total | ≈ 2.5 m | — |

- **El alcance no cambia:** la punta sigue en −2.21, `attack_range` sigue en 3.0 y AC211 se cumple igual.
- **La estela** sigue en `TrailBase` −0.77 y `TrailTip` −2.21. `OffHand` sigue en −0.1 y `grip_position` no cambia, así que las poses del Berserker toman el arma en el mismo lugar.

### 2.3 Archivos

```
assets/models/weapons/knight_set/
  knight_greatsword.res           nueva malla (4 superficies: acero oscuro, acero, latón, cuero)
  tools/build_knight_meshes.gd    + build_greatsword() y sus constantes
  SOURCE.md                       + sección "Mandoble"
entities/player/weapons/greatsword.tscn   Model → knight_greatsword.res con los materiales knight_*
```

- `greatsword.tscn` conserva su ruta y su uid: `greatsword.tres` y `berserker.tres` no cambian.
- **Decisión pendiente, el falchion:** propongo **borrarlo** (`assets/models/weapons/falchion/`, `materials/weapons/falchion_*`), como la hoplita: queda sin uso. Si preferís guardarlo en reserva, como la Spartan sword, se deja con una escena propia `falchion.tscn`.

### 2.4 Poses del Berserker

- Las poses **no se reescriben**: el arma se toma igual (mismo `grip_position` y mismo `OffHand`).
- **Riesgo:** la hoja pasa de ≈ 20 cm a 30 cm de ancho y es más gruesa. En reposo y en la carrera el mandoble va apoyado en el hombro derecho, y un filo puede atravesar la cabeza o el hombro, aunque el eje no lo haga (AC653 solo mide el eje).
  - AC1011 mide los **dos filos**.
  - Si algún cuadro falla, se retoca la muñeca de esa pose (girar la hoja de canto contra el hombro) y se anota.
  - Hoja de capturas de reposo, carrera y los 3 golpes. Te la muestro.

## 3. Resources y datos

- Las medidas son constantes del generador (datos del asset, como las de la espada).
- Sin Resources nuevos. `greatsword.tres`, `greatsword_swing_config.tres` y `berserker_stats.tres` no cambian.

## 4. Interfaz pública

Sin cambios. El generador suma `static func build_greatsword() -> ArrayMesh`.

## 5. Criterios de aceptación (AC1006–AC1013)

- **AC1006** `greatsword.tscn` tiene un solo `MeshInstance3D` (`Model`, con `knight_greatsword.res`) cuyas cuatro superficies usan `knight_dark_steel`, `knight_steel`, `knight_brass` y `knight_leather`. Tiene `TrailBase` en z = −0.77, `TrailTip` en z = −2.21 (±0.03) y `OffHand` en z = −0.1.
- **AC1007** La misma familia: los materiales del mandoble son exactamente los del juego de caballero (ningún material propio), y el latón incluye una cruz en cada cara de la hoja: dos grupos de vértices de latón, uno en +Y y otro en −Y de la losa, de 15 a 22 cm de alto, entre 3 y 30 cm delante de la guarda.
- **AC1008** La hoja:
  - ancho de 0.28 a 0.32 m, constante (±1 cm) desde la guarda hasta 30 cm antes de la punta;
  - espesor en el centro de 2.5 a 3.5 cm;
  - filo: en cada borde el espesor es ≤ 2 mm;
  - los biseles de acero claro ocupan una franja de 3 a 5 cm en cada filo;
  - la punta está corrida ≥ 4 cm hacia −X del eje de la hoja.
- **AC1009** La empuñadura:
  - el mango de cuero mide de 0.38 a 0.46 m, y el puño derecho (z = +0.133) y el `OffHand` quedan dentro de él;
  - la guarda de latón mide de 0.33 a 0.39 m de ancho;
  - el pomo es de latón y es la parte más trasera del arma;
  - el largo total va de 2.4 a 2.6 m.
- **AC1010** El generador reproduce `knight_greatsword.res` (vértices y normales ±0.1 mm), junto con la espada y el escudo (amplía AC745).
- **AC1011** La hoja no atraviesa el cuerpo por los filos: en cada clip del Berserker, muestreado cada 1/30 s, los segmentos de los dos filos (de la guarda a 30 cm antes de la punta) no entran en el torso ni en la cabeza, con el mismo volumen que AC653.
- **AC1012** Alcance intacto: `attack_range` del Berserker sigue en 3.0 y AC211 se cumple para el Berserker con la malla nueva.
- **AC1013** Limpieza y regresión:
  - si se borra el falchion: no existen `assets/models/weapons/falchion/` ni `materials/weapons/falchion_*`, y nada fuera de `docs/` los referencia;
  - la tabla de colores de la constitución nombra el mandoble generado;
  - pasan `weapon_model_test` (AC204 reescrito), `class_combat_identity_test` (AC653, AC678–AC680), `berserker_run_test` (AC185 adaptado), `weapon_reach_test` (AC211 del Berserker), `combat_feel_test` y `attack_component_test`, salvo los fallos previos registrados (AC211 del Samurái, AC212 y AC221);
  - import y smoke test del arena sin errores ni warnings.

**Próximo libre después de esta spec: AC1014.**

## 6. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC1006–AC1013 en `CLAUDE.md` y la enmienda 4.22.1 en la constitución.
2. **Malla:**
   - `build_greatsword()` en el generador y `knight_greatsword.res`;
   - hoja de capturas del mandoble solo (frente, canto, detalle de guarda y marca de forja) y junto a la espada y el escudo, al lado de la referencia. **Te la muestro antes de seguir.**
3. **Escena:** `greatsword.tscn` pasa a la malla nueva con los materiales `knight_*`. El Berserker juega con el arma nueva.
4. **Poses:**
   - el test de AC1011 marca los cuadros donde un filo atraviesa la cabeza o el hombro; se retocan esas muñecas;
   - hoja de capturas de reposo, carrera y los 3 golpes. **Te la muestro.**
5. **Limpieza:** según tu decisión sobre el falchion; AC204 reescrito y `berserker_run_test` adaptado.
6. **Tests:** AC1006–AC1010 en `weapon_model_test`; AC1011–AC1013 en `test/entities/player/berserker_greatsword_test.gd`; solo esas suites y las de AC1013.
7. **Cierre:** notas en esta spec, `SOURCE.md`, constitución, `CLAUDE.md` (mapa y specs recientes).

## 7. Constitución: enmienda PATCH 4.22.1

Principio II, tabla de colores:

- la fila "Arma del jugador (mandoble del Berserker) | Modelo `falchion.obj`" pasa a "Malla generada `knight_greatsword.res` | Colores de sus materiales en `materials/weapons/` (no reservados)".

Es PATCH porque la regla de modelos generados (4.13.0) ya lo permite: solo cambia el registro. Se numeró 4.22.1 porque otras sesiones llevaron la constitución a 4.22.0 mientras tanto.

## 8. Riesgos

- **La hoja ancha sobre el hombro:** el principal. AC1011 lo mide, y las capturas lo revisan.
- **Más peso visual en pantalla:** una losa de 30 cm oscura puede tapar enemigos detrás del Berserker desde la cámara del juego. Se revisa en la captura con esa cámara; si molesta, se baja el ancho a 26 cm (sigue dentro del estilo).
- **El corte oblicuo de la punta** no cambia `TrailTip` ni el alcance: la punta sigue en z = −2.21, solo corrida en X.

## 9. Checklist de review de la constitución (se completa al cerrar)

- [x] I. Pilar declarado (combate).
- [x] II. Malla generada en `knight_set/` con su generador, escena adaptadora, materiales `.tres` compartidos, sin shaders; tabla de colores actualizada (4.22.1).
- [x] III. Sin valores de gameplay nuevos; `attack_range` en su `.tres`.
- [x] IV. Tipado estático, identificadores en inglés.
- [x] V. La malla se carga una vez con la escena.
- [x] VI. Sin input nuevo.
- [x] VII. Tiempos y poses del combo sin cambios, salvo retoques de muñeca anotados.

## 10. Notas de implementación (2026-09-28)

- **Numeración:** la spec se propuso con AC757–AC764 y la enmienda 4.13.1. Mientras tanto, otras sesiones usaron esos números (`sprint-stamina.md`) y llevaron la constitución a 4.22.0, así que pasó a **AC1006–AC1013** y a **4.22.1**.
- **Malla** (`build_greatsword()` en `build_knight_meshes.gd`, detalle en el `SOURCE.md`):
  - **punta:** la geometría de §2.2 estaba mal escrita. Como en la referencia, es el filo **+X** el que corta en diagonal (en los últimos 36 cm), y la punta queda **12 cm hacia −X**, cerca del otro filo. La primera versión (6 cm y 30 cm) se veía casi simétrica;
  - el pomo de la espada se generalizó en `_disc_pommel()`: la espada y el escudo salen byte a byte iguales;
  - la guarda tiene sección de ocho lados (bordes biselados), y sus extremos acampanados sobresalen 1.5 cm hacia la hoja.
- **Poses:** un solo retoque. En el remate (`attack_3`), la hoja ancha rozaba la cabeza con el filo −X, cerca de la guarda, a mitad de la subida (0.30–0.37 s). La pose alzada gira la muñeca Y de −22° a −40° (la hoja queda más de canto). AC1011 pasa en todos los clips, y la hoja de capturas se lee igual.
- **Tests:**
  - `berserker_greatsword_test` (3 casos: AC1011–AC1013) y `weapon_model_test` (22 casos, con AC1006–AC1010 y AC745 ampliado), en verde;
  - regresión de AC1013: `class_combat_identity_test` (25), `combat_feel_test` (30), en verde;
  - smoke test del arena sin errores ni warnings.
- **Tests adaptados:**
  - AC204 → `test_ac204_the_greatsword_is_the_knight_model_with_shared_materials`;
  - AC206 comprueba los materiales del mandoble en lugar de los del falchion;
  - `berserker_run_test` AC185 usa `knight_greatsword.res`.
- **Fallos previos y ajenos:**
  - AC211 del Samurái, AC212 y AC221 (ya registrados); AC211 del Berserker pasa, lo verifica AC1012;
  - `attack_component_test` AC8: los stats del Guerrero cambiaron en el working tree por otra sesión (daño 20, vida 200, robo de vida 0.1), y el test espera los viejos.
- **Constitución:** además de la fila de la tabla, el ejemplo de "Scaffolding" pasó de `falchion/falchion.obj` a `katana/katana.glb`.
