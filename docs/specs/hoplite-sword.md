# Feature: Espada hoplita para el Guerrero

> **Reemplazada** por `warrior-sword-and-shield.md` (2026-09-27): el Guerrero usa la espada y el escudo de caballero; la hoplita se borró.

- **Estado:** Implementada (2026-09-25, 287 tests GdUnit4 en verde; import y smoke test headless sin errores ni warnings; render de control de las tres armas)
- **Constitución:** `docs/constitution.md` v3.0.1 (PATCH aprobada con esta spec: fila de la espada del Guerrero en la tabla de colores)
- **Pilares (Principio I):**
  - **Combate:** el arma del Guerrero cambia de silueta; hitbox, poses y barrido no cambian.
- **Dependencias:** `weapon-models.md` (Implementada).

## 1. Objetivo

- El Guerrero pasa a usar el modelo **Classic hoplite sword** (`Swords_pack_01` / `Lowpoly_swords`).
- La **Spartan sword** queda en el juego: se conservan su asset y sus materiales, y su escena adaptadora pasa a ser propia (`spartan_sword.tscn`). Hoy no la usa ninguna clase, pero se puede asignar a cualquier `WeaponData`.

## 2. Modelo (medido del `.obj`, 65 vértices)

| Parte | y | Superficie |
|---|---|---|
| Punta | −8.99 | 0 `Iron_hoplite` (hoja + guarda, guarda en y ≈ 1.0–1.33) |
| Mango | 1.33 → 3.25 | 1 `Black_handle_hoplite` |
| Pomo | 3.25 → 4.11 | 2 `Gray_hoplite` |

## 3. Scaffolding

```
assets/models/weapons/hoplite_sword/   hoplite_sword.obj · hoplite_sword.mtl · SOURCE.md
materials/weapons/
├── hoplite_iron_material.tres    Color(0.765, 0.786, 0.8)
├── hoplite_handle_material.tres  Color(0.035, 0.035, 0.035)
└── hoplite_trim_material.tres    Color(0.21, 0.227, 0.22)
```

## 4. Escenas

| Escena | Raíz | Modelo | `Model.transform` | Guarda → z | Punta → z |
|---|---|---|---|---|---|
| `entities/player/weapons/sword.tscn` (Guerrero, vía `sword.tres`) | `Sword` | `hoplite_sword.obj` | `Transform3D(0.1201,0,0, 0,0,-0.1201, 0,0.1201,0, 0,0,-0.12)` | 0 | −1.2 |
| `entities/player/weapons/spartan_sword.tscn` (sin uso) | `SpartanSword` | `spartan_sword.obj` | igual que antes | 0 | −1.2 |

Sin cambios en `WeaponData`, `sword.tres`, poses ni GDScript de gameplay.

## 5. Criterios de aceptación

- **AC203 (actualizado)** `Sword` usa `hoplite_sword.obj` con sus 3 `.tres` hoplite.
- **AC205 (actualizado)** La punta de `Sword` sigue en z ≈ −1.2 ±0.05 y la hoja es plana en XZ.
- **AC208** `spartan_sword.tscn` usa `spartan_sword.obj` con sus 3 `.tres` y tiene la punta en z ≈ −1.2.
- **AC209** Los materiales hoplite son `StandardMaterial3D` sin textura.
- **AC210** Regresión: suite completa en verde (AC185: el Guerrero sigue teniendo una sola arma `Sword`).

### Review de la constitución (cierre)
- **I:** Combate, como declara la spec.
- **II (v3.0.1):** el asset está en `assets/models/weapons/hoplite_sword/` con `SOURCE.md`, se usa vía escena adaptadora y con 3 `.tres` compartidos de color plano. La Spartan conserva su escena adaptadora.
- **III / IV / V / VI:** sin GDScript de gameplay nuevo; el test nuevo está tipado; una malla por arma instanciada una vez; sin cambios de input.

## 6. Plan de implementación

1. Enmienda 3.0.1 y esta spec.
2. Asset, `SOURCE.md` y materiales hoplite.
3. `spartan_sword.tscn` + `sword.tscn` con la hoplite.
4. Tests.
5. Import, suite, smoke test, render de control, estado **Implementada**.
