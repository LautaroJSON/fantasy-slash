# enemies (modelos de enemigos)

- **Origen:** originales del proyecto, generados por código (`docs/specs/enemy-models.md`, constitución 6.0.0). No hay `.glb`, `.obj` ni esqueleto: cada tipo es un script `<Tipo>Model` que extiende `EnemyModel` y construye sus mallas (`ArrayMesh` de normales planas, con `MeshKit`) y sus clips (`EnemyClipKit`) **una vez por tipo**, compartidos por todas las instancias del pool.
- **Licencia:** propia del proyecto.
- **Concepto:** "La Plaga", soldados y bestias fusionados con quitina, resina y armadura oxidada. Cada tipo tiene un tono dominante propio (paletas en `docs/color-registry.md`).
- **Uso:** solo desde la escena adaptadora de cada tipo, `entities/enemy/models/<id>_model.tscn`, asignada en `EnemyStats.model`. Materiales `.tres` compartidos en `materials/enemies/`.

## Contenido

- `mesh_kit.gd` (`MeshKit`): utilidades de mallas de caras planas: caja, cuña, cono, prisma y loft. Une en una sola malla las partes que comparten articulación y material.
- `enemy_clip_kit.gd` (`EnemyClipKit`): hornea los clips (cúbica monótona a 60 cuadros por segundo, superposición por articulación, emisores de partículas).
- `enemy_model.gd` (`EnemyModel`): base. Árbol `Flinch → Hips → …`, `Motion` (clips del cuerpo), `Overlay` (reacción al golpe, solo toca `Flinch`) y `Fx` (partículas). Escucha las señales de `EnemyHands`.
- `bruto/bruto_model.gd`: el Bruto.
- `king/king_model.gd`: The King (`docs/specs/boss-king.md`, `boss-king-rework.md`), un caballero noble de acero pulido y oro, con capa vino, faldón marfil y un mandoble a dos manos. La armadura y la hoja usan el shader `shaders/enemies/king_metal.gdshader` (`ShaderMaterial` compartido, color plano y reflejo procedural, sin texturas); lo que no es armadura es mate. Sus mallas tienen una superficie por material. No es de La Plaga: su paleta tiene una excepción nominal registrada en `docs/color-registry.md`.

## Convenciones de los clips

- Nombres fijos: `idle` y `walk` (loop), `windup`, `strike` y `recover` (sin loop, sostienen su última pose). Los de estado (`stunned`, `airborne`, `guard_down`, `transition`, `exposed`) y los propios de un tipo salen de la spec.
- Duración nominal 1.0 s, estirada al tiempo real (`speed = largo / segundos`). El clip `hit` de `Overlay` dura 0.3 s y no se estira.
- Un clip lista solo lo que se aparta del reposo: `"torso": Vector3` (rotación en grados), `"hips:p"` (posición), `"hips:s"` (escala) y `"emit:<emisor>"` (bool). Rotación X > 0 inclina la parte de arriba hacia atrás (+Z); el frente es −Z.

## Presupuestos (Principio V)

Enemigo común: ≤ 800 triángulos, ≤ 8 `MeshInstance3D` (sin las manos), ≤ 3 materiales, ≤ 1 emisor de ≤ 8 partículas, sin sombras. Boss: ≤ 6.000, ≤ 16, ≤ 4, ≤ 2 emisores de ≤ 16. Los verifica `test/assets/enemy_models_test.gd`.
