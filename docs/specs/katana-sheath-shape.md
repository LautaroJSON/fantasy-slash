# Feature: funda de la katana más gruesa y con el final redondeado

- **Estado:** Implementada (2026-09-27). **La forma de la funda la reemplaza `katana-visual-rework.md`** (AC694, AC695: reescritos; AC696 se conserva, medido con la malla nueva).
- **Constitución:** `docs/constitution.md` v4.12.0 → **enmienda PATCH 4.12.1** (ver §8).
- **Pilar (Principio I):** **combate.** La funda tiene casi el mismo ancho que la hoja y es una tira de 1.1 cm, así que en la mano izquierda y en la carga de Envainar se confunde con una segunda espada. Más gruesa y con el final (*kojiri*) redondeado, se lee como vaina, y la katana del Samurái se distingue de su funda.
- **Dependencias:** `katana-hand-proportions.md` (generador `build_katana_meshes.gd`, AC683–AC688), `sheath-in-left-hand.md` (AC671–AC677), `sheath-socket-hand-grip.md` (AC670).
- **Decisiones del responsable (2026-09-27):**
  - **Espesor ×2** (1.1 → 2.2 cm), **mismo ancho** (5.9 cm);
  - **esquinas suavizadas** en el final: se mantiene el corte casi recto y se redondean las dos esquinas (no un semicírculo completo).

## 1. Estado actual (medido, espacio de `katana_sheath.tscn`, −Z = hacia la punta)

| Parte | Medida hoy |
|---|---|
| Cuerpo | Tira curva de **5.9 cm** de ancho y **1.1 cm** de espesor (±0.55 cm). Su sección es el contorno 2D de la funda extruido en el espesor: cada "anillo" del glb son 6 vértices sobre una misma línea de espesor. |
| Anillos del cuello | Dos, en z ≈ −0.31 (el *koiguchi*, donde está el `Grip`) y z ≈ −0.51. Tienen ±1.36 cm de espesor: sobresalen 0.81 cm del cuerpo de cada lado. |
| Final | De z = −1.248 a −1.270. Ocho puntos de contorno: 4 en la esquina exterior (radio ~1.5 cm, pero incompleta), 2 en el borde del final y 2 en la esquina interior, casi viva. |
| Punta de la hoja envainada | Contorno a **1–3 mm** del final de la funda: (0.096, −1.2675), (0.126, −1.2623), (0.081, −1.2593) y (0.135, −1.2472). |

## 2. Diseño

### 2.1 Espesor

Se aplica solo a los vértices de la funda (`SHEATH_BONE`), sobre el eje de espesor de la malla (Z de la malla, Y del arma):

- **Cuerpo** (|z| ≤ medio espesor del cuerpo): z × 2. Pasa de 1.1 a 2.2 cm.
- **Anillos del cuello** (|z| mayor): z ± medio espesor del cuerpo, con el signo de z. Así siguen sobresaliendo 0.81 cm del cuerpo nuevo (±1.91 cm, 3.8 cm en total) y no se inflan ×2 hasta tapar el mango.

El ancho (X) y la curva no cambian. Las normales del cuerpo se transforman con la inversa de la escala. En los anillos, que solo se trasladan, no cambian.

### 2.2 Final con esquinas suavizadas

- **La funda se estira 1.2 cm a lo largo.** La boca sigue en la cara delantera de la tsuba (AC685) y el final pasa de z = −1.270 a **z = −1.282**. Hace falta porque la punta de la hoja está a 1–3 mm del final y, al redondear las esquinas, la esquina exterior de la hoja quedaría afuera. El mapeo en Y que ya hace el generador (boca → final) toma el nuevo final.
- **Esquinas de radio 1.5 cm.** El contorno del final pasa a ser: borde exterior, arco de 1.5 cm, borde del final recto, arco de 1.5 cm, borde interior. Los ocho puntos de contorno existentes se reparten sobre ese perfil en el mismo orden y en la misma fracción de largo que tenían sobre el contorno original. No se agregan ni quitan vértices; los arcos son facetados, como el resto del modelo low poly.
- **Normales del final:** se recalculan en el plano del contorno (perpendiculares al perfil nuevo en cada punto). Las de las caras de arriba y abajo no cambian.

### 2.3 Generador y datos (Principios II y III)

| Archivo | Cambio |
|---|---|
| `assets/models/weapons/katana/tools/build_katana_meshes.gd` | Constantes nuevas: `SHEATH_THICKNESS_SCALE` (2.0), `SHEATH_BODY_HALF_THICKNESS`, `NEW_SHEATH_END_Y` (final en z = −1.282), `SHEATH_CORNER_RADIUS` (1.5 cm) y el inicio de la región del final. Pasos nuevos para la funda: espesor (§2.1) y final (§2.2). La hoja no cambia. |
| `assets/models/weapons/katana/katana_sheath.res` | Regenerada. |
| `assets/models/weapons/katana/SOURCE.md` | Documenta los pasos nuevos. |

Sin cambios: `katana_blade.res`, `katana_sheath.tscn` (`Grip` y `Model`), `katana.tres` (`sheath_position`, `sheath_rotation`), el primer cuadro de `sheathe_slash` y todo el código de comportamiento.

## 3. Interfaz pública

Sin cambios. El generador suma constantes; sus funciones estáticas (`build`, `source_arrays`, `new_guard_front_y`, `main_bone`) no cambian de firma.

## 4. Criterios de aceptación (AC694–AC697)

- **AC694** Espesor. En el espacio de `katana_sheath.tscn`, lejos de los anillos y del final (z entre −0.60 y −1.15):
  - la funda mide entre 2.1 y 2.3 cm de espesor;
  - su ancho en cada línea de contorno es el mismo que en el glb (±1 mm);
  - los anillos del cuello sobresalen del cuerpo lo mismo que antes, 0.81 cm (±1 mm).
- **AC695** Final suavizado:
  - el final de la funda está en z = −1.282 (±2 mm);
  - los puntos de cada esquina están a 1.5 cm (±3 mm) del centro de su arco;
  - entre dos segmentos consecutivos del contorno del final no hay giros de más de 45°;
  - el ancho del final, medido donde terminan los arcos, es el de la funda (±2 mm).
- **AC696** La hoja sigue adentro: con la katana envainada (`sheathe_charge`, t = 0), todos los vértices de la hoja de `katana_blade.res` caen dentro del contorno de la funda (con ≥ 1.5 mm de margen) y dentro de su espesor. La boca sigue en la cara delantera de la tsuba (AC685).
- **AC697** Asset y regresión:
  - la funda conserva la cantidad de vértices, los índices y las UV del glb, y la hoja no cambia (AC688, con el generador reproduciendo las dos mallas);
  - `SOURCE.md` documenta el espesor y el final;
  - pasan `weapon_model_test`, `sheath_grip_test` (AC671–AC677, AC684–AC685), `sheathe_test` y `class_combat_identity_test`, salvo los fallos previos registrados en `katana-hand-proportions.md` §9;
  - el import y el smoke test del arena con el Samurái corren sin errores ni warnings.

**Próximo libre después de esta spec: AC698.**

## 5. Plan

Cada paso deja el proyecto andando.

1. **Base:** traer `main` a la rama (tiene `jump-cancels-strike`, AC689–AC693, y ahí el próximo libre es AC694). Reservar AC694–AC697 en `CLAUDE.md` (próximo libre → AC698) y aplicar la enmienda 4.12.1 (§8).
2. **Generador:** paso de espesor (§2.1), estiramiento y esquinas del final (§2.2). Regenerar `katana_sheath.res` sobre la copia del scratchpad y copiarla al proyecto.
3. **Capturas:** funda suelta (arriba y de costado), en la mano izquierda en la guardia, en la carga de Envainar y en la vista del juego, antes y después. Te las muestro, y si el radio o el espesor no convencen se ajustan dentro de los rangos de los ACs.
4. **Tests:** AC694–AC696 en `weapon_model_test.gd` y `sheath_grip_test.gd`; AC697 extiende AC688. Suite completa comparada con `main` y smoke tests.
5. **Cierre:** notas y checklist en esta spec, `SOURCE.md` y `CLAUDE.md` (entrada "Largo visual del arma": la funda también sale del generador).

## 6. Tests adaptados (se anotan al cerrar)

- Ninguno: AC688 ya compara la malla guardada con la que genera el script, así que cubre la funda nueva sin cambiar lo que verifica.

## 7. Riesgos

- **Funda más gruesa contra el cuerpo:** en la carga de Envainar la funda cruza la cadera. Con 1.1 cm más de espesor puede atravesar el torso en algún cuadro. Se revisa en las capturas; si pasa, se ajusta el `wrist_l` de `LEFT_SHEATH_ARM` (como en `sheath-in-left-hand.md`).
- **Ocho puntos para dos arcos:** cada esquina queda con 3–4 segmentos. Si se ve dentada, se puede bajar el radio dentro de AC695 o repartir los puntos distinto. No se agregan vértices.
- **Margen de la hoja en el borde interior:** el vértice (0.081, −1.2593) queda a ~2 mm del borde interior. AC696 exige ≥ 1.5 mm; si no alcanza, se estira el final unos milímetros más.

## 8. Enmienda: 4.12.1 (PATCH)

La regla de **mallas derivadas** (Principio II, desde 4.11.0) habla de reproporcionar regiones "estirando o escalando". Se aclara que también cubre reubicar los vértices de un extremo sobre un perfil más suave, siempre sin agregar ni quitar vértices ni cambiar UV o materiales:

> … Una malla derivada también puede reproporcionar regiones del modelo (estirar o escalar un mango, una guarda, **o redondear un extremo reubicando sus vértices**) para que encaje con el cuerpo del jugador **o se distinga de otra parte**, sin agregar ni quitar vértices ni cambiar UV o materiales (desde 4.11.0). …

Historial: *4.12.1 (2026-09-27): Principio II: la reproporción de una malla derivada incluye redondear un extremo reubicando sus vértices, y puede servir para distinguir una parte de otra (ver `katana-sheath-shape.md`).*

Es PATCH porque no agrega un permiso nuevo: mantiene los mismos límites (ni vértices, ni UV, ni materiales nuevos) y precisa qué entra en "reproporcionar".

## 9. Notas de implementación

- **Medidas finales** (espacio de `katana_sheath.tscn`):
  - cuerpo de **2.2 cm** de espesor (antes 1.1) y el mismo ancho, 5.9 cm;
  - anillos del cuello de **3.8 cm** (±1.91 cm), que siguen sobresaliendo 0.81 cm;
  - final en **z = −1.282**;
  - esquina exterior con 4 puntos y esquina interior con 4 puntos, sobre arcos de 1.5 cm;
  - ancho donde terminan los arcos de 5.93 cm, contra 5.87 cm en la última estación.
- **Cambio respecto de §2.2: no se estira toda la funda, solo el final.**
  - Al estirar la funda entera 1.2 cm, el ensanche de la punta se corría con ella y la esquina de la hoja (0.135, −1.247) quedaba a 0.6 mm del borde exterior.
  - Ahora el cuerpo conserva su largo (mapeo boca → final original) y el perfil redondeado lleva el final a −1.282. El largo total crece lo mismo, 1.2 cm.
  - Cada borde sigue la dirección que va de la última estación antes del final al primer punto del final de su lado. Así se conserva el ensanche que ya tenía la punta del glb, y la hoja queda a ≥ 1.5 mm del contorno en todo su largo.
  - Con 2.5 mm, AC696 falla a lo largo de toda la hoja: el margen real es de 1.5–2.5 mm porque hoja y funda corren paralelas en el glb.
- **Normales:**
  - cuerpo: se dividen por la escala (1, 1, 2);
  - anillos: sin cambio (solo se trasladan);
  - lados del final: se recalculan sumando las normales de sus caras nuevas, con el sentido de la normal original.
- **Capturas** (Xvfb + OpenGL, antes y después): funda desde arriba, de costado, primer plano del final, guardia, carga de Envainar y vista alta.
  - De costado, la funda se ve claramente más gruesa que la hoja, y el final tiene las dos esquinas redondeadas (antes solo la exterior).
  - Desde la cámara del juego el cambio es sutil, porque desde arriba se ve sobre todo el ancho, que no cambió (decisión del responsable).
  - En la carga, la funda más gruesa no atraviesa el torso en los cuadros revisados (riesgo de §7).
- **Tests nuevos:**
  - `weapon_model_test`: AC694 y AC695;
  - `sheath_grip_test`: AC696;
  - AC697 lo cubre AC688, que compara las dos mallas con las que genera el script. Ningún test adaptado.
- **Suites:** `weapon_model_test` (14/14) y `sheath_grip_test` (15/15, corrida sin AC670, que es previo y corta la suite) en verde.
  - Suite completa (712 casos) comparada con la rama antes de este cambio, en las mismas condiciones: fallan los mismos tests previos (AC188, AC211, AC221, AC236, AC285/AC298, AC288, AC298, AC363, AC578, AC653 y AC670, registrados en `katana-hand-proportions.md` §9).
  - `hitstop_test` (AC619–AC621) y `attack_component_test` AC9 alternan entre corridas en las dos versiones. Es el mismo error intermitente, un enemigo liberado durante la estocada (`attack_component.gd:359`), y es ajeno a la funda. Esta spec no agrega ningún fallo.
- **Smoke test:** escena principal, arena y arena con el Samurái (`--quit-after 300`), e import, sin errores ni warnings (salvo los de UID inválido de cualquier copia limpia, porque los `.uid` están en el `.gitignore`).

### Checklist de la constitución

- [x] Principio I: pilar de combate (la silueta del Samurái: katana y funda distinguibles).
- [x] Principio II: la malla derivada sigue en la carpeta del asset, con `SOURCE.md` y su generador (4.12.1); mismo material de paleta; sin colores nuevos.
- [x] Principio III: sin valores de gameplay nuevos; las medidas son constantes del generador (preparación del asset).
- [x] Principio IV: el generador con tipado estricto, en inglés.
- [x] Principio V: sin cambios en runtime (solo una malla precalculada).
- [x] Principios VI y VII: sin cambios.
