# Feature: espada y escudo del Guerrero, reposo y marcha de caballero

- **Estado:** Implementada (2026-09-27). ACs: AC743–AC756. Alcance: opción A (2.0).
- **Constitución:** `docs/constitution.md` v4.12.1 → **enmienda MINOR a 4.13.0** (aplicada, ver §8).
- **Pilar (Principio I):** **combate.** El Guerrero es la clase que el jugador ve primero y hoy se lee como "un tipo con una espada": su guardia de hoplita simula un escudo que no existe. Espada y escudo a juego le dan una silueta propia de un vistazo (se distingue del Samurái y del Berserker entre enemigos), y el reposo y la marcha de caballero, con el combo arrancando desde ese reposo, hacen que cada golpe se lea como un movimiento que sale de la calma.
- **Referencias del responsable (2026-09-27):**
  1. un caballero templario caminando de frente: espada colgando baja en la derecha, escudo al costado izquierdo;
  2. un caballero de espaldas caminando: espada baja junto a la pierna derecha, escudo colgando al costado izquierdo;
  3. un escudo de acero oscuro, curvado, con la cruz de Santiago en latón y remaches de latón en el borde.
- **Decisiones del responsable (2026-09-27):**
  - el escudo sigue la **referencia 3** (acero + cruz dorada), y la espada hace juego con él;
  - la espada es **realista y proporcional al escudo**, y el alcance baja (ver §2.4: hay una decisión pendiente sobre cuánto);
  - el reposo nuevo reemplaza **toda la guardia** (`_stance()`): `idle` y todos los clips que arrancan o terminan en ella, incluidos los 4 golpes del combo;
  - el escudo es **solo visual**: no bloquea ni reduce daño (una mecánica de bloqueo sería otra spec);
  - se descarta la espada hoplita.
- **Dependencias:**
  - `class-combat-identity.md` (perfil del Guerrero; AC639, AC645, AC652, AC653);
  - `sheath-in-left-hand.md` (el mismo mecanismo de socket en `wrist_l`, que acá lleva el escudo);
  - `weapon-reach.md` (AC211, AC212);
  - `hoplite-sword.md` y `weapon-models.md` (AC203, AC209: se reescriben);
  - `sprint-stamina.md` (Propuesta, otra sesión): su `sprint` del Guerrero, "con escudo y espada al frente", tendrá que usar el escudo de esta spec.

## 1. Estado actual

- **Arma:** `data/classes/warrior/sword.tres` → `entities/player/weapons/sword.tscn` → `hoplite_sword.obj` (pack de terceros) con tres materiales `hoplite_*`. Punta en z = −1.47 del pivot; `attack_range` 2.2 por AC211 (`0.35 + 1.47 × cos 0.15 + 0.4`).
- **Mano izquierda:** vacía. La guardia de hoplita (`warrior_profile.gd`, `_stance()`) adelanta el brazo izquierdo "como si llevara escudo", y en los golpes ese brazo hace de contrapeso libre (se tira atrás hasta `shoulder_l` −78°).
- **Guardia:** pierna izquierda adelante, torso girado −12°, espada a la altura de la cadera con la punta adelante (`GUARD_ARM`). `idle` respira en 2.0 s y `run` tiene un período de 0.6 s (AC645).
- **Socket en la mano izquierda:** existe para la funda del Samurái (`WeaponData.sheath*`, `Player._equip_sheath()`), atado a `WeaponMount` y a Envainar.

## 2. Diseño

### 2.1 El juego de caballero: un asset generado

No hay archivo fuente de terceros: la espada y el escudo son **mallas originales, low poly y de normales planas** (como el humanoide), generadas **offline** por un script de la carpeta del asset y guardadas como `.res`. En runtime solo se cargan, igual que las mallas derivadas de la katana.

```
assets/models/weapons/knight_set/
  SOURCE.md                    origen (original, desde las referencias), medidas y cómo regenerar
  knight_sword.res             ArrayMesh, 3 superficies: acero claro, latón, cuero
  knight_shield.res            ArrayMesh, 4 superficies: acero oscuro, latón, cuero, acero claro (canto)
  tools/build_knight_meshes.gd extends SceneTree, headless; todas las medidas son constantes del script
entities/player/weapons/
  knight_sword.tscn            Model + TrailBase + TrailTip
  knight_shield.tscn           Model + Grip + Center + Top + Bottom + Left + Right
materials/weapons/
  knight_steel_material.tres       acero claro de la hoja y el canto del escudo
  knight_dark_steel_material.tres  acero oscuro de la cara del escudo
  knight_brass_material.tres       latón: cruz, remaches, guarda y pomo
  knight_leather_material.tres     cuero: empuñadura y correas
```

Colores (no reservados, `StandardMaterial3D` de color plano, sin texturas):

| Material | `albedo_color` | Metálico / rugosidad |
|---|---|---|
| Acero claro | ≈ (0.62, 0.64, 0.67) | 0.85 / 0.35 |
| Acero oscuro | ≈ (0.30, 0.31, 0.33) | 0.8 / 0.4 |
| Latón | ≈ (0.76, 0.58, 0.24) | 0.9 / 0.4 |
| Cuero | ≈ (0.30, 0.18, 0.10) | 0 / 0.85 |

### 2.2 El escudo (referencia 3)

Ejes del escudo en su escena: +Y arriba, +X a la derecha mirando la cara, **−Z es la cara exterior** (la convexa).

- **Silueta (heater con copete):** 0.80 m de alto × 0.58 m de ancho.
  - arriba: los dos hombros en (±0.29, 0.30) suben en un arco suave hasta un pico central en (0, 0.40), como la referencia;
  - costados rectos hasta y = 0;
  - abajo: dos curvas que se cierran en la punta, en (0, −0.40).
- **Curvatura:** la sección horizontal es un arco de radio 0.75 m (flecha ≈ 6 cm entre el centro y los costados), convexo hacia afuera. Recto en vertical. La cara se divide en 8 franjas verticales para que el arco se lea en low poly.
- **Espesor:** 1.2 cm, con un canto de acero claro de 1.5 cm alrededor del contorno.
- **Cruz de Santiago en latón**, en relieve de 5 mm sobre la cara, siguiendo la curvatura:
  - brazo vertical de y = +0.30 a y = −0.30; el brazo de abajo se afina como una hoja de espada y termina en punta;
  - brazo horizontal en y = +0.12, de x = −0.20 a x = +0.20;
  - las puntas de arriba y de los costados terminan en flor de lis simplificada: una punta de lanza y dos volutas cortas hacia atrás.
- **Remaches:** 16 cúpulas de latón (6 lados, 2.2 cm de diámetro) a 4 cm del borde, repartidas por el contorno, y una en el centro de la cruz.
- **Dorso:** una empuñadura de cuero horizontal en el centro y dos correas (enarmas) más arriba. El marcador `Grip` está en el centro de la empuñadura, donde se toma con la mano.
- **Marcadores** (para los tests y para posar): `Grip`, `Center` (centro de la cara), `Top` (pico), `Bottom` (punta), `Left`, `Right` (costados a y = 0).

### 2.3 La espada (a juego)

Espada de armas de una mano, con la guarda y el pomo de latón que repiten las flores de la cruz del escudo.

| Parte | Medida | Diseño |
|---|---|---|
| Pomo | 6 cm de diámetro | Disco de latón (8 lados), biselado |
| Empuñadura | 17 cm | Cuero, sección octogonal de 3.2 cm, con dos anillos de latón en los extremos |
| Guarda | 26 cm de ancho, 2.5 cm de alto | Latón recto que se ensancha en los extremos, cada uno con la flor de lis de la cruz |
| Hoja | ver §2.4 | Acero claro, sección de rombo (arista central que hace de vaceo), 5 cm de ancho en la guarda y 3 cm antes de la punta, que se cierra en los últimos 12 cm |

- La proporción con el escudo es la de la referencia 1: la hoja es ≈ 1.15–1.2 veces el alto del escudo.
- En `knight_sword.tscn`, la hoja apunta a −Z (como toda arma del juego), `TrailBase` en la cara delantera de la guarda y `TrailTip` en la punta.
- `sword.tres` (el `WeaponData` del Guerrero) apunta a `knight_sword.tscn`. El `grip_position` se recalcula para que el puño derecho quede en el medio de la empuñadura.

### 2.4 Alcance: **decisión pendiente**

La regla de AC211 ata el largo visual al alcance: `attack_range = 0.35 + |punta z| × cos 0.15 + 0.4`.

| Opción | Hoja | Del pivot a la punta | Largo total | `attack_range` |
|---|---|---|---|---|
| A. **Recomendada** | 0.93 m | 1.26 m | ≈ 1.20 m | **2.0** |
| B. Realista estricta | 0.78 m | 1.00 m | ≈ 1.00 m | **1.74** |

- **El problema de B:** el Bruto y el Escudero se frenan a 2.0 m para atacar (`attack_range` 2.0 en sus stats), y la hitbox del jugador mide del centro del enemigo. Con 1.74, `attack_2` y `attack_3` (×1.0) y `attack_1` (×1.1 = 1.91) no les llegan: solo el remate (×1.2 = 2.09) pega. El Guerrero perdería contra el enemigo más común, y AC212 ("el Guerrero golpea a un Bruto quieto en su alcance") dejaría de cumplirse.
- **A** es el alcance más corto que conserva AC212: la espada sigue siendo una espada de una mano realista (≈ 1.2 m, como una espada de armas larga), el escudo queda en la proporción de la referencia, y el Guerrero pasa de 2.2 a 2.0 (−9 %: pega más corto que el Samurái, 2.3, y que el Berserker, 3.0).
- Con B habría que reescribir AC212 y probablemente compensar al Guerrero (daño o velocidad), que es balance fuera de esta spec.

El resto de la spec asume **A**. Si elegís B, cambian solo los números de esta tabla, AC746 y AC747.

### 2.5 El escudo en la mano izquierda

Mismo mecanismo que la funda del Samurái, pero separado de ella (la funda tiene semántica propia: Envainar guarda la katana en su socket).

- `WeaponData` suma cuatro campos, con la misma forma que los de la funda:
  - `shield: PackedScene` (null si la clase no lleva escudo);
  - `shield_joint: StringName` (`&"wrist_l"`);
  - `shield_position: Vector3`, `shield_rotation: Vector3`: el agarre, relativo a la articulación.
- `Player._equip_shield(weapon)` crea `ShieldSocket` en `shield_joint` con `LowPolyHumanoid.attach_to_joint()` (escala compensada, como `SheathSocket`) y cuelga ahí la escena del escudo. `get_shield()` lo devuelve.
- La mano izquierda **sostiene el escudo sin objetivo de mano**: el `Grip` queda sobre la mano por construcción (`left_grip` vale 0 en todos los clips del Guerrero).
- El ángulo del escudo lo da la muñeca izquierda de cada pose.
- El escudo no tiene colisión ni hitbox.

### 2.6 El reposo nuevo (referencias 1 y 2)

Reemplaza a `_stance()` del perfil del Guerrero. Se mide en el espacio del `Visual` (−Z hacia el enemigo, +X a la derecha del personaje).

| Parte | Hoy (guardia de hoplita) | Nuevo (reposo de caballero) |
|---|---|---|
| Cadera y torso | Girados −8° y −12°, torso volcado | Casi de frente (≤ 15°) y erguido (≤ 8°), el pecho abierto |
| Cabeza | Compensa el giro | Al frente, apenas baja |
| Piernas | Izquierda bien adelante, rodillas flexionadas | Separadas al ancho de los hombros, la izquierda apenas adelante (≤ 15 cm), rodillas casi rectas, el peso en la derecha |
| Brazo derecho y espada | `GUARD_ARM`: espada a la cadera, punta adelante | **`REST_BLADE`**: el brazo cuelga junto al muslo; la espada baja en diagonal hacia adelante y afuera, la punta cerca del piso |
| Brazo izquierdo y escudo | Adelantado, mano vacía | **`SHIELD_ARM`**: el codo flexionado a la altura de la cintura; el escudo al costado izquierdo, casi vertical, la cara mirando adelante y afuera, el pico a la altura del hombro |

- **Respiración:** se conserva el período de 2.0 s (AC645). El pecho sube, y el escudo y la punta de la espada acompañan apenas.
- **AC645** sigue valiendo: la amplitud de la cadera en `idle` queda entre la del Berserker y la del Samurái.
- Los ángulos se calculan con el script de brazos (mano, dirección de la hoja y del escudo como objetivos) y se ajustan con hojas de capturas al lado de las referencias.

### 2.7 La marcha (`run`, referencia 2)

`run` sigue siendo caminar (como lo define `sprint-stamina.md`). Mismo ciclo (0.6 s, contacto y paso de cada pierna, loop, cúbico), con la silueta de la referencia 2:

- torso erguido (≤ 10° de vuelco), con un contragiro leve con cada paso; la cabeza arriba;
- pasos firmes, poco rebote, los pies en dos líneas cercanas;
- **brazo derecho:** la espada cuelga baja junto a la pierna derecha y se balancea poco con el paso; la punta nunca toca el piso;
- **brazo izquierdo:** el escudo colgando al costado izquierdo, firme, con un vaivén leve.

`run_stop` frena y vuelve al reposo nuevo. El salto (`jump_*`) y `hit` usan `REST_BLADE` y `SHIELD_ARM` donde hoy usan `GUARD_ARM` y el brazo izquierdo libre, y terminan en el reposo.

### 2.8 El combo parte del reposo

- `attack_1` arranca en el reposo nuevo (su primer cuadro es la pose de `idle` en t = 0) y los 4 golpes terminan en él. `attack_2`, `attack_3` y `attack_4` conservan su primer cuadro de encadenado (el final del golpe anterior), como hoy.
- **Tiempos intactos:** los eventos (`hit_on`, `hit_off`, `combo`, `end`) y `warrior_combo.tres` no cambian, así que AC652 (compromiso de 0.22 s) y el DPS se mantienen.
- **La anticipación de la estocada** (`attack_1`, t = 0.06) ahora sube la espada desde abajo: el recorrido es más largo, en el mismo tiempo. Si se lee mal, se retoca esa pose.
- **El brazo izquierdo deja de ser contrapeso libre:** con un escudo de 80 cm, tirarlo atrás a −78° lo haría atravesar el cuerpo o volar. En los golpes:
  - en la anticipación el escudo sube al frente izquierdo y cubre el torso;
  - en el impacto se recoge contra el costado izquierdo, girando con el torso;
  - nunca pasa por detrás de la espalda ni atraviesa el cuerpo o la hoja.
- Las poses intermedias del brazo derecho, la cadera y el torso no cambian salvo que se rompan (la hoja atraviesa el cuerpo o el escudo, o el golpe se lee mal). Cada corrección se anota.

### 2.9 Se descarta la espada hoplita

Se borran `entities/player/weapons/sword.tscn`, `assets/models/weapons/hoplite_sword/` y `materials/weapons/hoplite_*_material.tres`. La Spartan sword (`spartan_sword.tscn`) sigue en reserva, como hoy.

## 3. Resources y datos

| Archivo | Cambio |
|---|---|
| `resources/weapon_data.gd` | + `shield`, `shield_joint`, `shield_position`, `shield_rotation` |
| `data/classes/warrior/sword.tres` | `model` → `knight_sword.tscn`, `grip_position`/`grip_rotation` recalculados, campos del escudo |
| `data/classes/warrior/warrior_stats.tres` | `attack_range` 2.2 → **2.0** (opción A) |
| `data/classes/warrior/sword_swing_config.tres` | Sin cambios (`hilt_offset` 0.35, `blade_tilt` −0.15) |
| `data/classes/warrior/warrior_combo.tres` | Sin cambios |

- Las medidas de las mallas son datos del asset: constantes del generador, como las de `build_katana_meshes.gd`.
- Las poses son datos del asset, en el perfil (Principio II).

## 4. Interfaz pública

```gdscript
# WeaponData
@export var shield: PackedScene
@export var shield_joint: StringName
@export var shield_position: Vector3
@export var shield_rotation: Vector3

# Player
func get_shield() -> Node3D          # null si la clase no lleva escudo
func get_shield_socket() -> Node3D   # null si la clase no lleva escudo
```

No cambia la interfaz de `WeaponMount`, `PlayerAnimator` ni `AttackComponent`.

## 5. Criterios de aceptación (AC743–AC756)

**El escudo**

- **AC743** `knight_shield.tscn` tiene un solo `MeshInstance3D` (`Model`, con `knight_shield.res`) cuyas superficies usan los materiales compartidos de `materials/weapons/knight_*` (acero oscuro, latón, cuero y acero claro), y los marcadores `Grip`, `Center`, `Top`, `Bottom`, `Left` y `Right`. Los materiales son de color plano, sin texturas.
- **AC744** Forma del escudo, en su escena:
  - alto (`Top`–`Bottom`) entre 0.78 y 0.82 m, y ancho (`Left`–`Right`) entre 0.56 y 0.60 m;
  - el pico (`Top`) está ≥ 8 cm más alto que los extremos del borde superior;
  - curvado: la cara exterior en el centro sobresale entre 5 y 7 cm hacia −Z respecto de los costados;
  - espesor de la placa ≤ 2 cm;
  - la superficie de latón (cruz y remaches) está del lado exterior (−Z) y ocupa ≥ 70 % del alto y ≥ 65 % del ancho del escudo.
- **AC745** El generador reproduce las mallas: `build_knight_meshes.gd` genera `knight_sword.res` y `knight_shield.res` con los mismos vértices, normales e índices que los del repo (±0.1 mm). *(Como AC688 de la katana.)*

**La espada**

- **AC746** `knight_sword.tscn` tiene un solo `MeshInstance3D` (`Model`, con `knight_sword.res`) con los materiales compartidos de acero claro, latón y cuero, y:
  - `TrailTip` en z = −1.26 (±0.03);
  - `TrailBase` a ≤ 3 cm de la cara delantera de la guarda;
  - largo total (pomo a punta) entre 1.15 y 1.25 m, guarda de 0.29 a 0.33 m de ancho *(era 0.24–0.28; ver §11)* y empuñadura de 0.15 a 0.19 m.
- **AC747** Alcance: `warrior_stats.tres` tiene `attack_range` 2.0, y AC211 (`0.35 + |punta z| × cos 0.15 + 0.4`, ±0.05) y AC212 (el Guerrero golpea a un Bruto quieto a 2.0 m) siguen pasando con la espada nueva.
- **AC748** La mano derecha toma la empuñadura: en `idle` y en el impacto de cada golpe, el centro de la malla de la mano derecha está sobre el eje de la espada (≤ 1.5 cm) y entre los dos extremos de la empuñadura.

**El escudo en la mano**

- **AC749** Con el Guerrero, `ShieldSocket` es hijo de la articulación `shield_joint` (`wrist_l`) con el `shield_position`/`shield_rotation` de `sword.tres` y la escala compensada, y el escudo es hijo del socket. El Samurái y el Berserker no tienen `ShieldSocket` (`get_shield()` es null), y el Guerrero no tiene funda.
- **AC750** La mano sostiene el escudo sin objetivo de mano: en todos los clips del Guerrero, muestreados cada 1/30 s, `left_hand_grip_weight` vale 0 y el centro de la malla de la mano izquierda está sobre el `Grip` del escudo (≤ 1 mm).
- **AC751** El escudo no atraviesa el cuerpo ni el piso: en todos los clips del Guerrero, muestreados cada 1/30 s, en el espacio del `Visual`:
  - `Center`, `Top`, `Bottom`, `Left` y `Right` quedan fuera de una cápsula de radio 0.16 m que va de la articulación `hips` a `neck`;
  - los cinco quedan a ≥ 3 cm sobre el piso;
  - `Center` nunca pasa detrás de la espalda (z ≤ 0.15 m).

**El reposo y la marcha**

Se miden en el espacio del `Visual`.

- **AC752** El reposo de la referencia 1 (`idle`, t = 0):
  - el frente del torso a ≤ 15° de −Z, inclinado ≤ 8° de la vertical, y la cabeza al frente (±12°);
  - los tobillos separados 20 a 35 cm de lado, y el izquierdo ≤ 15 cm más adelante que el derecho;
  - la mano derecha junto al muslo derecho (x ≥ 0.15 m, y entre 0.7 y 1.0 m), la hoja entre 35° y 50° bajo la horizontal *(ajustado al implementar, §11)*, la punta adelante (z < 0) y a la derecha (x > 0.2 m), a ≥ 5 cm del piso;
  - el escudo a la izquierda (`Center` con x ≤ −0.25 m), casi vertical (el eje `Bottom`→`Top` a ≤ 20° de la vertical), el pico entre 1.2 y 1.5 m de alto, y la cara exterior mirando adelante y afuera (su normal con componentes −Z y −X, a ≤ 60° de −Z).
- **AC753** La marcha de la referencia 2 (`run`, cada 1/30 s del ciclo):
  - el torso inclinado ≤ 10°;
  - la hoja siempre ≥ 35° bajo la horizontal y la punta a ≥ 5 cm del piso;
  - el escudo a la izquierda (`Center` con x ≤ −0.2 m) y casi vertical (≤ 25°);
  - el período sigue siendo 0.6 s (AC645).
- **AC754** El combo parte del reposo: el primer cuadro de `attack_1` y el último de los 4 golpes, `run_stop`, `hit` y `jump_land` coinciden con `idle` en t = 0 (cada articulación a ≤ 0.5°, `hips_pos` a ≤ 1 mm). Los eventos de los golpes siguen en los tiempos de `warrior_combo.tres` (AC652 sin cambios).

**Limpieza y regresión**

- **AC755** La hoplita se fue: no existen `entities/player/weapons/sword.tscn`, `assets/models/weapons/hoplite_sword/` ni `materials/weapons/hoplite_*`, y ningún archivo del proyecto (fuera de `docs/`) los referencia. La tabla de colores de la constitución nombra la espada y el escudo del Guerrero.
- **AC756** Regresión:
  - pasan `weapon_model_test` (AC203 y AC209 reescritos, §6), `weapon_reach_test`, `class_combat_identity_test` (AC639, AC645, AC652, y AC653: la hoja no atraviesa el cuerpo en ningún clip), `attack_component_test`, `combat_feel_test`, `player_animator_test`, `humanoid_model_test`, `sheath_grip_test` y `berserker_run_test` (adaptado, §6);
  - quedan exceptuados los fallos previos registrados;
  - import y smoke test del arena con el Guerrero sin errores ni warnings.

**Próximo libre después de esta spec: AC757.**

## 6. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC743–AC756 en `CLAUDE.md` (próximo libre → AC757), y la enmienda 4.13.0 en la constitución.
2. **Escudo:**
   - `build_knight_meshes.gd` con el escudo, los 4 materiales y `knight_shield.tscn`;
   - hoja de capturas del escudo solo (frente, dorso, perfil y tres cuartos) al lado de la referencia 3. **Te la muestro antes de seguir.**
3. **Espada:**
   - la espada en el mismo generador y `knight_sword.tscn`;
   - hoja de capturas de espada y escudo juntos, a escala con el humanoide. **Te la muestro.**
4. **Montaje:**
   - `WeaponData` con los campos del escudo, `Player._equip_shield()`, `sword.tres` con la espada nueva, el agarre y el escudo, `attack_range` 2.0;
   - el Guerrero anda con la guardia vieja y el escudo en la mano (el perfil todavía no cambia).
5. **Reposo y marcha:**
   - `REST_BLADE`, `SHIELD_ARM` y `_stance()` nuevos, calculados con el script de brazos para los objetivos de §2.6; la marcha, el salto, `run_stop` y `hit`;
   - hoja de capturas de `idle` y `run` (frente, espaldas, perfil y cámara del juego) al lado de las referencias 1 y 2. **Te la muestro.**
6. **Golpes:**
   - el brazo izquierdo con escudo en los 4 golpes; se retocan las poses que se rompan;
   - hoja de capturas de los 4 golpes (arranque, anticipación, impacto y final). **Te la muestro.**
7. **Limpieza:** se borran la hoplita, su escena y sus materiales; AC203 y AC209 reescritos, `berserker_run_test` adaptado.
8. **Tests:**
   - AC743–AC746 en `test/entities/player/weapon_model_test.gd`;
   - AC747–AC755 en `test/entities/player/warrior_sword_and_shield_test.gd`;
   - corro solo esas suites y las de AC756.
9. **Cierre:** notas en esta spec, `SOURCE.md` del asset y del humanoide, mapa de `CLAUDE.md` ("Largo visual del arma", "Funda del arma" → también el escudo) y specs recientes.

## 7. Tests adaptados (se anotan al cerrar)

- **AC203** (`weapon_model_test`): "la espada es el modelo hoplita con materiales compartidos" pasa a "la espada es `knight_sword.res` con los materiales `knight_*`".
- **AC209** (`weapon_model_test`): "los materiales hoplitas son de color plano" pasa a los materiales `knight_*`.
- **`SWORD_TIP_Z`** (`weapon_model_test`): −1.47 → −1.26.
- **`berserker_run_test`**: compara contra `HOPLITE_SWORD_MODEL`; pasa a `knight_sword.res`.
- Cualquier test con valores fijos de la guardia de hoplita que aparezca en las suites de AC756.

## 8. Constitución: enmienda MINOR 4.13.0

Principio II:

1. **Nuevo tipo de asset: modelos generados por script.** Texto propuesto, después de "Mallas derivadas":
   > **Modelos generados** (desde 4.13.0): un arma o accesorio del jugador sin archivo fuente puede ser una malla estática original, low poly y de normales planas, generada **offline** por un script que vive en `tools/` de la carpeta del asset y guardada como `.res` en esa carpeta. Sus medidas son constantes del script, su `SOURCE.md` registra el origen (original, con las referencias usadas) y cómo regenerarla, y un test verifica que el script reproduzca las mallas del repo. Se usa como cualquier asset: vía escena adaptadora y con materiales `.tres` compartidos. Nunca se genera en runtime.
2. **Tabla de colores:** la fila "Arma del jugador (espada del Guerrero) | Modelo `hoplite_sword.obj`" pasa a "Arma del jugador (espada y escudo del Guerrero) | Mallas generadas `knight_sword.res` y `knight_shield.res` | Colores de sus materiales en `materials/weapons/` (no reservados)".
3. **Registro de colores no reservados:** acero, latón y cuero del juego de caballero. El latón es parecido al dorado de las cartas de mejora única; no se confunden porque uno es un arma opaca en la mano del jugador y el otro, cartas de UI y el brillo de la katana.

Es MINOR porque agrega una forma nueva de meter assets sin cambiar las reglas existentes. `sprint-stamina.md` propone 4.12.2 (PATCH): la que se implemente primero toma su número y la otra se renumera.

## 9. Riesgos

- **El escudo es grande (80 cm) y va en la muñeca:** un giro chico de muñeca lo mueve mucho y puede atravesar las piernas en poses bajas (la estocada profunda de `attack_4` baja la cadera 22 cm). AC751 lo acota muestreando cada 1/30 s; se corrige pose por pose.
- **La espada sube desde abajo en `attack_1`** con el mismo tiempo de anticipación (0.06 s): puede verse como un salto. Si pasa, se ajusta la pose de anticipación (no los tiempos, que son de gameplay).
- **Alcance:** 2.0 deja al Guerrero justo en el alcance del Bruto y del Escudero (sin margen). Si en juego se siente corto, la carta de alcance lo sube; ajustar el balance sería otra spec.
- **Un asset de cero** es más arte que reproporcionar la katana. Mitigación: las capturas del escudo solo (paso 2) validan el estilo antes de hacer la espada y las poses.
- **`sprint-stamina.md`** (otra sesión) define un `sprint` del Guerrero: si se implementa antes, sus poses no tendrán escudo y habrá que revisarlas; si se implementa después, tiene que usar `SHIELD_ARM`.

## 10. Checklist de review de la constitución (se completa al cerrar)

- [x] I. Pilar declarado (combate).
- [x] II. Asset en `assets/models/weapons/knight_set/` con `SOURCE.md`, escenas adaptadoras, materiales `.tres` compartidos de color plano, sin shaders; enmienda 4.13.0 aplicada.
- [x] III. `attack_range` y los datos del escudo en `.tres`; las medidas de las mallas son datos del asset.
- [x] IV. Tipado estático, identificadores en inglés.
- [x] V. Sin allocations por frame: el escudo se instancia una vez al equipar la clase.
- [x] VI. Sin input nuevo.
- [x] VII. Tiempos del combo sin cambios (AC652).

## 11. Notas de implementación (2026-09-27)

- **Mallas** (`assets/models/weapons/knight_set/`, detalle en su `SOURCE.md`):
  - generadas por `tools/build_knight_meshes.gd`, sin índices, UV ni texturas;
  - la espada: 1.20 m, punta en z = −1.26, guarda de 26 cm, empuñadura de 17 cm;
  - la hoja quedó en 8 cm → 5.8 cm, con la arista central de 2.4 cm de espesor y los filos en espesor cero (no 5 → 3 cm como en §2.3). Primero se probó 6.5 → 4.5 cm; después el responsable la pidió más ancha y gruesa, sin perder el filo;
  - la guarda pasó a 31 cm de ancho, 3.2 cm de alto y 3.6 cm de espesor, con la lengüeta y los extremos más grandes (pedido del responsable). AC746 acepta ahora 0.29 a 0.33 m, y `TrailBase` sigue a la cara delantera (z = −0.322);
  - la flor de lis de la cruz tiene dos pétalos que se curvan atrás y una punta central (la primera versión eran flechas);
  - el copete del escudo usa un borde levemente cóncavo (exponente 0.7), más parecido a la referencia 3;
  - los remaches miden 2.8 cm.
- **Montaje:**
  - el pivot de la espada quedó 20 cm detrás del puño (`grip_position` = (0, −0.04, 0.1538)), así la punta en −1.26 cumple AC211 con `attack_range` 2.0;
  - de la mano a la punta hay 1.05 m, así que el daño llega ≈ 0.5 m más allá de lo que se ve de la hoja (con la hoplita la diferencia era menor). Es consecuencia directa de la espada realista;
  - el escudo cuelga de `wrist_l` con `shield_position` = (−0.0437, −0.0033, 0) y `shield_rotation` = (0, π/2, 0): el `Grip` (en y = −0.05 del escudo) cae en el centro de la mano.
- **Poses** (calculadas con un script de brazos y revisadas con hojas de capturas):
  - `REST_BLADE`: `shoulder_r` (−22, −22, −12), `elbow_r` 86, `wrist_r` (−110, −4, −5). La hoja queda 42° bajo la horizontal y la punta a 12 cm del piso;
  - `SHIELD_ARM` (reposo): `shoulder_l` (−47, −35, −10), `elbow_l` 94, `wrist_l` (−47, −1, 9). El escudo queda vertical, con la cara 37° hacia afuera y el pico a 1.27 m;
  - `SHIELD_COVER` (anticipación y `hit`), `SHIELD_TUCK` (revés, frenada y salto) y **`SHIELD_FORE`** (nuevo): el escudo frente a la cintura. Recogido al costado, el escudo pasaba detrás de la espalda en los impactos que giran el torso 46° a 90° a la izquierda (AC751), así que esos golpes usan `SHIELD_FORE`. En la carga de `attack_3` (torso girado 90°) el hombro cruza más: `shoulder_l` (10, −95, −51);
  - marcha: `WALK_WRIST` (−101, −4, −5) y un balanceo del hombro de −25°/−20°, así la hoja se mantiene entre 39° y 44° y la punta no toca el piso;
  - `LIFTED_WRIST` (−70, −4, −5), en el salto y en un cuadro nuevo de `attack_2` (t = 0.32): al agacharse o al volver del tajo bajo a la izquierda hacia el reposo bajo a la derecha, la punta se clavaba en el piso (hasta −30 cm). El cuadro nuevo no cambia los eventos del golpe.
- **AC752 ajustado:** la hoja en reposo va entre **35° y 50°** bajo la horizontal (no 45° a 80°). Con 1.05 m de la mano a la punta y la mano a 0.85 m, más de ≈ 49° clava la punta en el piso.
- **AC751 ampliado:** además del escudo, verifica que la punta de la espada quede a ≥ 5 cm del piso en todos los clips.
- **Tests:**
  - `warrior_sword_and_shield_test` (9 casos, AC747–AC755). AC747 también da un golpe real a un Bruto a 2.0 m, porque AC212 (`weapon_reach_test`) no corre (ver abajo);
  - `weapon_model_test` (18 casos, con AC743–AC746);
  - regresión de AC756: `class_combat_identity_test` (25), `attack_component_test` (21), `combat_feel_test` (30), `player_animator_test` (13), `humanoid_model_test` (5), `sheath_grip_test` (16), en verde;
  - import y smoke test del arena (Guerrero por defecto) sin errores ni warnings.
- **Tests adaptados:**
  - AC203 → `test_ac203_the_sword_is_the_knight_model_with_shared_materials`;
  - AC209 → `test_ac209_knight_materials_are_flat_colors`;
  - `SWORD_TIP_Z` −1.47 → −1.26 (la Spartan sword conserva −1.47 en `SPARTAN_TIP_Z`);
  - `berserker_run_test` AC185: la espada del Guerrero es `knight_sword.res` (nodo `KnightSword`);
  - `humanoid_model_test` AC591: las mallas del cuerpo ya no incluyen lo que cuelga del `ShieldSocket`.
- **Fallos previos y ajenos** (ya registrados en `katana-hand-proportions.md` y `dash-iframes.md`):
  - AC211 con el Samurái (`attack_range` 2.3 contra ≈ 2.0 por la regla); con el Guerrero pasa;
  - AC212 llama a `AttackComponent.advance_cooldown()`, que ya no existe desde el combo;
  - AC221 (stats del barrido del Berserker).
- **GdUnit:** cuando un test acumula muchas fallas en un bucle, la suite deja de correr los tests siguientes. Por eso, mientras AC751 fallaba, aparecían solo 5 casos.
