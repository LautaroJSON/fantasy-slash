# Feature: Modelos 3D de las armas (Spartan sword y Falchion)

- **Estado:** Implementada (2026-09-25, 285 tests GdUnit4 en verde; import y smoke test headless sin errores ni warnings; render de control de ambas armas)
- **Constitución:** `docs/constitution.md` v3.0.0 (enmienda MAJOR aprobada con esta spec: assets importados permitidos con reglas)
- **Pilares (Principio I):**
  - **Combate:** cada clase se reconoce de un vistazo por la silueta de su arma. El hitbox sigue siendo lógico (`SwordSwingConfig` / `HitboxMath`), así que el gameplay no cambia.
- **Dependencias:** `berserker.md` (Implementada). Reemplaza la parte de "malla del arma" de `berserker.md` (AC185) y de `combat-mvp.md`.

## 1. Objetivo

- El Guerrero usa el modelo **Spartan sword** y el Berserker, el **Falchion**. Ambos son `.obj` y reemplazan a los `BoxMesh` de `sword.tscn` y `greatsword.tscn`.
- Los modelos se ordenan con el scaffolding de assets de la constitución v3.0.0 y se usan a través de una escena adaptadora.

## 2. Scaffolding

```
assets/models/weapons/
├── falchion/        falchion.obj · falchion.mtl · SOURCE.md
└── spartan_sword/   spartan_sword.obj · spartan_sword.mtl · SOURCE.md
materials/weapons/
├── falchion_iron_material.tres     Color(0.578, 0.567, 0.590)
├── falchion_handle_material.tres   Color(0.026, 0.016, 0.026)
├── falchion_trim_material.tres     Color(0.233, 0.109, 0.447)
├── spartan_iron_material.tres      Color(0.467, 0.427, 0.393)
├── spartan_handle_material.tres    Color(0.026, 0.025, 0.024)
└── spartan_trim_material.tres      Color(0.596, 0.538, 0.483)
```

- Los colores son el `Kd` de cada `.mtl`. El orden de las superficies del `.obj` es: 0 hierro, 1 mango, 2 detalle.
- Se borran los `.obj`/`.mtl` sueltos de `assets/` y los duplicados de `combat/`, además de `materials/sword_material.tres` y `materials/greatsword_material.tres`, que quedan sin uso.

## 3. Escenas (adaptadoras)

El importador `wavefront_obj` produce un recurso `Mesh`. Cada escena del arma tiene un único `MeshInstance3D` `Model`. Su `transform` lleva el modelo a la convención del juego: origen en la mano, punta hacia −Z y hoja plana en XZ. Eso se logra con rotación de +90° en X y escala uniforme. Los materiales se asignan con `surface_material_override/0..2`.

| Escena | Raíz | Modelo | Escala | Guarda → z | Punta → z |
|---|---|---|---|---|---|
| `entities/player/weapons/sword.tscn` | `Sword` | `spartan_sword.obj` | 0.1156 | 0 | −1.2 |
| `entities/player/weapons/greatsword.tscn` | `Greatsword` | `falchion.obj` | 0.1584 | −0.15 | −1.9 |

Las puntas coinciden con las de los `BoxMesh` anteriores, así que el alcance visual no cambia. `WeaponData`, las poses de reposo, `SwordSwing` y `Player` no cambian. No hay GDScript de gameplay nuevo.

## 4. Criterios de aceptación

- **AC185 (reescrito)** Cada clase instancia una sola arma bajo `SwordPivot`: `Sword` para el Guerrero y `Greatsword` para el Berserker.
- **AC203** `Sword` tiene un único `MeshInstance3D` `Model`. Su `mesh` es `spartan_sword.obj` con 3 superficies, y cada `surface_override_material` es el `.tres` de spartan correspondiente (mismo objeto).
- **AC204** Lo mismo para `Greatsword` con `falchion.obj` y los `.tres` de falchion.
- **AC205** El AABB del modelo, en el espacio de la escena del arma, tiene su punta en z ≈ −1.2 (espada) y ≈ −1.9 (mandoble), ±0.05. La hoja es más ancha en X que gruesa en Y.
- **AC206** Todos los materiales del arma son `StandardMaterial3D` sin textura.
- **AC207** Regresión: AC186/AC187 (poses y barrido) y la suite completa en verde.

## 5. Notas

- El hierro del Falchion (≈0.58) se parece al gris de los enemigos (0.5). Se acepta porque la silueta de una hoja no se confunde con una cápsula.
- La licencia del pack de origen (`Swords_pack_01`) queda **a confirmar** en cada `SOURCE.md`.

- **Durante la implementación:**
  - La base de `Transform3D` en `.tscn` va en el orden inverso al que se supuso: la rotación correcta es `Transform3D(s,0,0, 0,0,-s, 0,s,0, …)`. AC205 lo detectó.
  - Se eliminaron las líneas `Ka` de los `.mtl`, porque el importador PBR emitía un warning por cada material. Queda registrado en `SOURCE.md`.

### Review de la constitución (cierre)
- **I:** Combate. La silueta del arma identifica la clase y el gameplay no cambia.
- **II (v3.0.0):** los assets viven en `assets/models/weapons/<arma>/` con `SOURCE.md`, se usan vía escena adaptadora y con 6 `StandardMaterial3D` `.tres` compartidos de color plano. Sin shaders ni texturas.
- **III:** sin valores nuevos en scripts. La transformación del modelo es parte de la escena adaptadora; alcance y hitbox siguen en `SwordSwingConfig`.
- **IV:** el test nuevo está tipado y los nombres de archivo en `snake_case`.
- **V:** una sola malla por arma, instanciada una vez al equipar. Materiales compartidos.
- **VI:** sin cambios de input.

## 6. Plan de implementación

1. Enmienda 3.0.0 y esta spec.
2. Scaffolding de `assets/models/weapons/` y borrado de los originales.
3. Materiales `materials/weapons/*.tres`.
4. `sword.tscn` y `greatsword.tscn` con `Model`.
5. Tests AC185 y AC203–AC206.
6. Borrado de los materiales viejos, suite completa, smoke test, checklist y estado **Implementada**.
