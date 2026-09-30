# Feature: katana del Samurái generada, de la familia "wa"

- **Estado:** Implementada (2026-09-29). ACs: AC1231–AC1240.
- **Constitución:** `docs/constitution.md` v6.0.0 → **enmienda PATCH a 6.0.1** (ver §8).
- **Pilar (Principio I):** **combate.** La katana es la única arma del juego que sigue siendo un modelo de terceros con textura de paleta. Junto a la espada y el escudo del Guerrero y al mandoble del Berserker (mallas propias, normales planas) se lee como un asset ajeno. Una katana generada, con hoja curva, hamon, tsuba calada y funda con sageo, da al Samurái una silueta reconocible y a las tres armas la misma calidad.
- **Decisiones del responsable (2026-09-29):**
  - **Estética:** tsuka **negra**, funda de laca negra con franjas rojas, herrajes de oro viejo, y un **sageo gris** colgando de la funda.
  - **Tsuba:** **12 cm** de diámetro, proporcional a la mano y al cuerpo del personaje (la de hoy mide 17 cm).
  - **Hoja:** **con curvatura (sori) y kissaki.**
  - **glb original:** se **borra**.
- **Dependencias:**
  - `warrior-sword-and-shield.md` y `berserker-greatsword.md` (mismo estilo: mallas generadas por script, normales planas, materiales `.tres` de color plano);
  - `katana-hand-proportions.md` y `katana-sheath-shape.md` (AC683–AC688, AC694–AC696: se reescriben);
  - `sheath-in-left-hand.md` (AC685), `weapon-reach.md` (AC211, AC212) y `sheathe-upgrades-rework.md` (el brillo de Hosho es un `material_overlay` sobre `Model`).

## 1. Estado actual

- `katana.tscn` → `katana_blade.res` y `katana_sheath.tscn` → `katana_sheath.res`: mallas derivadas del `katana.glb` por `tools/build_katana_meshes.gd`, con **una** superficie y el material `katana_material.tres` (paleta `katana_palette.png`).
- `Model` con `Transform3D(1.1, 0, 0, 0, 0, 1.1, 0, -1.1, 0, 0, 0, 0.055)` (el eje de la hoja de la malla es +Y y va a −Z).
- Medidas en el espacio del arma: pomo en z = +0.133, tsuba (17 cm) entre −0.170 y −0.187, punta en z = −1.267 y x = +0.096 (la hoja se inclina hacia +X), hoja plana de 5.5 cm × 2.2 mm. Funda con la boca en la tsuba y el final en z = −1.282.
- Marcadores de `katana.tscn`: `TrailBase` (0, 0, −0.2), `TrailTip` (0.1, 0, −1.27), `Hilt` (0, 0, −0.0533). En `katana_sheath.tscn`: `Grip` (0, 0, −0.3032).
- El brillo de Hosho es `Model.material_overlay` (`SheatheAbility._find_blade`): funciona con cualquier material y cualquier cantidad de superficies.

## 2. Diseño

### 2.1 Un asset generado

Mallas originales, low poly y de normales planas, generadas **offline** por `tools/build_katana_meshes.gd` (se reescribe: ya no lee el glb) y guardadas como `.res`. En runtime solo se cargan. El generador reutiliza los helpers de `knight_set/tools/build_knight_meshes.gd` (`_loft`, `_quad`, `_tri`, `_box`).

```
assets/models/weapons/katana/
  SOURCE.md                    origen (original), medidas y cómo regenerar
  katana_blade.res             ArrayMesh, 6 superficies (ver §2.2)
  katana_sheath.res            ArrayMesh, 4 superficies (ver §2.3)
  tools/build_katana_meshes.gd extends SceneTree, headless; todas las medidas son constantes
entities/player/weapons/
  katana.tscn, katana_sheath.tscn   mismas rutas, uids y marcadores; Model en identidad
materials/weapons/
  katana_steel_material.tres   acero pulido (cara de la hoja)
  katana_hamon_material.tres   acero claro (franja del filo)
  katana_iron_material.tres    hierro oscuro (tsuba)
  katana_gold_material.tres    oro viejo (herrajes, seppa, menuki, boca y punta de la funda)
  katana_tsuka_material.tres   tela negra de la tsuka
  katana_tsuka_relief_material.tres  carbón (rombos de la trenza)
  katana_lacquer_material.tres laca negra de la funda
  katana_lacquer_red_material.tres   laca roja (franjas de la funda)
  katana_sageo_material.tres   gris del sageo
```

Se borran: `katana.glb` (+ `.import`), `katana_palette.png` (+ `.import`) y `katana_material.tres`.

Colores (no reservados, `StandardMaterial3D` de color plano, sin texturas):

| Material | `albedo_color` | Metálico / rugosidad |
|---|---|---|
| Acero pulido | ≈ (0.62, 0.68, 0.75) | 0.9 / 0.3 |
| Hamon | ≈ (0.93, 0.95, 0.97) | 0.9 / 0.25 |
| Hierro | ≈ (0.23, 0.24, 0.27) | 0.7 / 0.45 |
| Oro viejo | ≈ (0.79, 0.64, 0.29) | 0.9 / 0.4 |
| Tela de la tsuka | ≈ (0.07, 0.07, 0.08) | 0 / 0.9 |
| Rombos de la tsuka | ≈ (0.17, 0.17, 0.20) | 0 / 0.9 |
| Laca negra | ≈ (0.09, 0.09, 0.11) | 0.2 / 0.35 |
| Laca roja | ≈ (0.48, 0.12, 0.14) | 0.2 / 0.4 |
| Sageo | ≈ (0.61, 0.62, 0.65) | 0 / 0.85 |

### 2.2 La katana (espacio del arma, `Model` en identidad)

La hoja apunta a −Z, el filo va a −X y el lomo (mune) a +X; la punta se curva hacia +X. Superficies: 0 acero, 1 hamon, 2 hierro, 3 oro, 4 tela de la tsuka, 5 rombos.

| Parte | Medida | Diseño |
|---|---|---|
| Kashira (remate) | z de +0.111 a +0.133 | Oro, 8 lados, algo abovedado; **es lo más trasero del arma** (pomo a 8 cm detrás del puño, como hoy) |
| Tsuka | z de −0.152 a +0.111 (26 cm), 4.8 × 4.0 cm de sección | Octogonal con un leve abultado en el medio, **tela negra**; 6 rombos en relieve (2 mm) en carbón sobre las dos caras anchas; 2 menuki de oro en el medio |
| Fuchi (collar) | z de −0.170 a −0.152 | Oro, sección apenas mayor que la tsuka |
| Tsuba | **12 cm** de diámetro máx., 8 mm de grosor, z de −0.181 a −0.173 | Hierro oscuro, contorno mokkō de 4 lóbulos en los ejes; **4 calados en rombo** en las diagonales; canto de oro |
| Seppa | 5.2 cm de diámetro, 3 mm | Dos arandelas de oro, una a cada cara de la tsuba (frente hasta z = −0.184) |
| Habaki | 5.6 × 1.6 cm, z de −0.184 a −0.214 | Oro |
| Hoja | de z = −0.190 a −1.267 | Shinogi-zukuri: sección de 7 puntos (filo, línea del hamon, shinogi, dos vértices del lomo). Ancho 5.0 cm en la base → 4.0 cm en el yokote; espesor 9 mm → 6 mm. **Hamon ondulado** (superficie 1) en la franja del filo. **Kissaki:** los últimos 5 cm cierran a una punta |
| Curvatura (sori) | punta en x = +0.096 (igual que hoy) | El eje va de x = 0 en la base a +0.096 en la punta con una panza de 2 cm hacia el filo (el filo es la cara convexa) |

- `TrailBase`, `TrailTip` y `Hilt` **no cambian**: las poses, el alcance (AC211) y el `grip_position` siguen valiendo.
- El brillo de Hosho (`material_overlay`) cubre las seis superficies.

### 2.3 La funda (espacio del arma, `Model` en identidad)

Superficies: 0 laca negra, 1 laca roja, 2 oro, 3 sageo gris.

| Parte | Medida | Diseño |
|---|---|---|
| Koiguchi (boca) | z de −0.184 a −0.206 | Oro |
| Cuerpo | z de −0.206 a −1.222 | Sigue la curva de la hoja. Sección de 8 lados de **2.5 cm de espesor** y ancho de la hoja + 2.2 cm. Caras anchas en laca negra; **las dos caras angostas (filo y lomo) en laca roja** |
| Kojiri (punta) | z de −1.222 a −1.282 | Oro, se cierra en chaflanes |
| Kurigata | 3 cm, sobresale 1.2 cm del lomo, en z = −0.45 | Oro |
| **Sageo** | cordón de 7 mm de grueso | **Gris.** Sale de la kurigata, hace un lazo en el plano de la funda, se anuda y deja dos puntas cortas, juntas; ~8 cm en total |

- El `Grip` (−0.3032) queda sobre el cuerpo de la funda, donde la toma la mano izquierda.
- La hoja envainada queda a ≥ 1.5 mm del contorno de la funda (AC696 se conserva).

## 3. Resources y datos

- Las medidas son constantes del generador. Sin Resources nuevos: `katana.tres`, `katana_swing_config.tres` y `samurai_stats.tres` no cambian.
- `WeaponData` no cambia.

## 4. Interfaz pública

Sin cambios. El generador expone `build_blade() -> ArrayMesh` y `build_sheath() -> ArrayMesh` (reemplazan a `build(bone)`), y las constantes de las partes que usan los tests (`test/helpers/katana_parts.gd`).

## 5. Criterios de aceptación (AC1231–AC1240)

- **AC1231** Escenas: `katana.tscn` y `katana_sheath.tscn` tienen un solo `MeshInstance3D` (`Model`, transform identidad) con `katana_blade.res` (6 superficies) y `katana_sheath.res` (4), cada una con su material de §2.1 y ninguno con textura. Los marcadores no cambian: `TrailBase` (0, 0, −0.2), `TrailTip` z = −1.27 (±0.03), `Hilt` (0, 0, −0.0533), `Grip` (0, 0, −0.3032).
- **AC1232** Hoja:
  - punta en z = −1.267 (±0.01) y x = +0.096 (±0.01);
  - ancho de 4.8 a 5.2 cm en la base y de 3.8 a 4.2 cm en el yokote;
  - espesor de 8 a 10 mm en la base;
  - el eje se aparta de la cuerda base–punta entre 1.5 y 3 cm, hacia el filo (−X);
  - los últimos 5 cm se estrechan sin volver a ensancharse hasta la punta;
  - los vértices de la superficie hamon están en la mitad del filo (−X del eje);
  - el filo (borde −X) tiene un espesor ≤ 1 mm;
  - `attack_range` sigue en 2.3 y `hilt_offset` en 0.35 (AC686).
- **AC1233** Tsuba:
  - diámetro máximo de 0.115 a 0.125, en X y en Y;
  - grosor de 6 a 12 mm;
  - cara trasera entre z = −0.175 y −0.165;
  - 4 calados: un rayo en Z a 3.6 cm del centro no toca el hierro en los 4 ángulos diagonales y sí lo toca en los 4 ejes;
  - ninguno de sus vértices cae dentro de la mano derecha en reposo (AC684).
- **AC1234** Tsuka:
  - de la cara trasera de la tsuba al extremo trasero del arma hay entre 0.29 y 0.33 m;
  - el kashira es la parte más trasera y el puño derecho (z = −0.0533) queda dentro de la tsuka;
  - sección mínima ≥ 4.5 cm;
  - la tela es negra: `albedo_color` con valor (V) ≤ 0.12; los rombos, con V ≤ 0.25 y más claros que la tela;
  - hay 6 o más rombos en relieve y 2 menuki de oro;
  - el pomo sobresale ≥ 5 cm detrás de la mano (AC684).
- **AC1235** Funda:
  - espesor de 2.2 a 2.8 cm en el cuerpo;
  - el final en z = −1.282 (±0.003), cerrado en chaflanes;
  - la boca en la cara delantera de la tsuba (≤ 1 cm, AC685);
  - las dos caras angostas del cuerpo son la superficie roja;
  - oro en la boca, en la punta y en la kurigata;
  - **la hoja envainada queda dentro del contorno de la funda con ≥ 1.5 mm de margen** (AC696 adaptado: los vértices de las superficies de hoja).
- **AC1236** Sageo:
  - superficie propia con material gris (canales dentro de ±0.05 entre sí y valor de 0.5 a 0.7);
  - su primer punto está a ≤ 1 cm de la kurigata;
  - el cordón mide de 0.05 a 0.12 m a lo largo de la funda (Z) y se aparta como máximo 0.09 m de su lomo (X).
- **AC1237** Los nueve materiales son `StandardMaterial3D` de color plano, sin textura, con los colores de §2.1 (±0.03). Hosho: con el brillo puesto, las seis superficies de la katana lo muestran (`material_overlay` de `Model`).
- **AC1238** El generador reproduce `katana_blade.res` y `katana_sheath.res` (vértices y normales ±0.1 mm, mismas superficies), junto con el resto del set. `SOURCE.md` nombra el generador y no menciona el glb como fuente.
- **AC1239** Limpieza y regresión:
  - no existen `katana.glb`, `katana_palette.png`, `katana_material.tres` ni sus `.import`, y nada fuera de `docs/` los referencia;
  - la tabla de colores de la constitución y `color-registry.md` nombran la katana generada;
  - pasan `weapon_model_test` (AC237, AC683, AC686, AC688 y AC694–AC695 reescritos), `sheath_grip_test` (AC684, AC685, AC696), `sheathe_test`, `sheathe_release_test`, `class_combat_identity_test` y `samurai_rest_guard_test`, salvo los fallos previos registrados (AC211 del Samurái, AC212 y AC221);
  - import y smoke test del arena con el Samurái, sin errores ni warnings.
- **AC1240** Sin cuerpo atravesado: en cada clip del Samurái, muestreado cada 1/30 s, ningún vértice de la tsuba ni de las seppa cae dentro del torso ni de la cabeza (mismo volumen que AC653, con 2 cm de tolerancia en la esfera de la cabeza, que es aproximada), salvo en los cuadros donde la hoja ya lo atraviesa (el fallo previo de AC653 en `attack_5`, ver §10). La tsuka no se mide: su remate trasero ya invadía el volumen del torso con el pomo viejo (la mano cuelga junto a la cadera), y ese volumen es una elipse aproximada.

**Próximo libre después de esta spec: AC1241.**

## 6. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC1231–AC1240 en `CLAUDE.md` y `ac-registry.md`; enmienda 6.0.1.
2. **Malla:** nuevo `build_katana_meshes.gd` y las dos `.res`; los nueve materiales. **Hoja de capturas** (frente, canto, detalle de tsuba, hamon y kissaki, funda con sageo, y junto a la espada del Guerrero). **Te la muestro antes de seguir.**
3. **Escenas:** `katana.tscn` y `katana_sheath.tscn` pasan a la malla y a los materiales nuevos (identidad, mismos marcadores).
4. **Tests:** AC1231–AC1238 en `weapon_model_test` (y `KatanaParts` reescrito); AC684, AC685 y AC696 de `sheath_grip_test` adaptados; AC1240 en un test nuevo del Samurái.
5. **Poses:** hoja de capturas del reposo, la carrera, Envainar (carga y tajo) y un golpe; video antes/después del combo con `godot-capture`. Se retocan solo las muñecas que fallen.
6. **Limpieza y cierre:** borrar el glb, la paleta y el material viejo; `SOURCE.md`, `where-to-tune.md`, `CLAUDE.md`, `README` de specs, constitución y checklist.

## 7. Riesgos

- **La tsuka negra sobre el traje del Samurái:** si el humanoide lleva ropa oscura, se pierde. Se revisa en las capturas; los rombos en carbón y el oro de kashira, fuchi y menuki están para separarla.
- **Hoja y funda encajan:** se generan a la vez desde la misma curva, y AC1235 lo mide.
- **El sageo estático** cuelga siempre igual: puede atravesar el cuerpo en alguna pose. Es corto (~8 cm) y sale por el lomo, y AC1240 y las capturas lo revisan.
- **Más superficies** (6 y 4 en vez de 1): son mallas estáticas de unos cientos de vértices; el costo de dibujo es despreciable.

## 8. Constitución: enmienda PATCH 6.0.1

Principio II:
- la fila "Arma del jugador (katana del Samurái, con funda) | Modelo `katana.glb` (mallas derivadas)" pasa a "Mallas generadas `katana_blade.res` y `katana_sheath.res` | Colores de sus materiales en `materials/weapons/` (no reservados)";
- el ejemplo de "Scaffolding" (`assets/models/weapons/katana/katana.glb`) pasa a `assets/models/weapons/spartan_sword/spartan_sword.obj`, el único asset importado de armas que queda.

Es PATCH porque la regla de modelos generados (4.13.0) ya lo permite: solo cambia el registro. `color-registry.md`: el tono de oro viejo del arma no se confunde con el dorado de las cartas ni con la miel de la Colmena (es un arma opaca en la mano del jugador), como el latón del Guerrero; el gris del sageo no es el gris reservado de los enemigos porque es un objeto pequeño del arma del jugador.

## 9. Checklist de review de la constitución (se completa al cerrar)

- [x] I. Pilar declarado (combate).
- [x] II. Malla generada con su generador, escena adaptadora, materiales `.tres` compartidos, sin shaders; tabla de colores actualizada (6.0.1).
- [x] III. Sin valores de gameplay nuevos; `attack_range` en su `.tres`.
- [x] IV. Tipado estático, identificadores en inglés.
- [x] V. Las mallas se cargan una vez con la escena.
- [x] VI. Sin input nuevo.
- [x] VII. Sin cambios de combate.
- [x] VIII. Poses verificadas con hojas de capturas (reposo, carga de Envainar, `attack_1`, `attack_3`, `run`, `sheathe_release`): la katana, la funda y el sageo se leen y no atraviesan el cuerpo (AC1240). No hay video antes/después porque las poses no cambiaron.

## 10. Notas de la implementación (2026-09-29)

- Ancho de la hoja: la primera versión (4.2 → 3.2 cm) se veía delgada junto a la espada del Guerrero en las capturas; se subió a 5.0 → 4.0 cm (la de terceros medía 5.5) y con ella el habaki (5.6 cm) y las seppa (5.2 cm).
- Sageo: el primer cordón (12 cm, puntas abiertas) se veía como una horquilla; quedó más corto (~8 cm), con las dos puntas juntas y un grosor de 7 mm. Gris (0.61, 0.62, 0.65) para que los tres canales queden a ≤ 0.05.
- **Fallos previos de las suites vecinas** (verificados con `git archive HEAD` limpio, sin cambios de esta spec): AC641, AC650, AC652, AC653 (`attack_5` a 0.07 s, hoja en la cabeza), AC670, AC674 y AC724 de `class_combat_identity_test`, `sheath_grip_test` y `sheathe_release_test`, y AC241 de `sheathe_test`. Esta spec no los toca ni los empeora. AC1240 salta los cuadros donde AC653 ya falla.
- El generador es un `extends SceneTree` que reutiliza los helpers privados (`_loft`, `_quad`, `_tri`, `_box`, `_cap`) del generador del set del caballero.
