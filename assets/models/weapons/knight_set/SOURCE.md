# knight_set

- **Origen:** modelo original del proyecto (constitución 4.13.0, "modelos generados"), hecho a partir de tres referencias del responsable: dos caballeros caminando con espada y escudo, y un escudo de acero con la cruz de Santiago en latón (ver `docs/specs/warrior-sword-and-shield.md`).
- **Licencia:** propia del proyecto.
- **Uso:**
  - `knight_sword.res` → `entities/player/weapons/knight_sword.tscn` (espada del Guerrero, `data/classes/warrior/sword.tres`);
  - `knight_shield.res` → `entities/player/weapons/knight_shield.tscn` (escudo del Guerrero, cuelga de `wrist_l`).
- **Generador:** `tools/build_knight_meshes.gd` (`extends SceneTree`, headless, desde la raíz del proyecto; el comando está en su encabezado). Todas las medidas son constantes del script. Mallas low poly de normales planas, sin índices, UV ni texturas. `weapon_model_test` (AC745) verifica que el script reproduzca las mallas del repo: si cambiás una constante, regenerá y copiá los `.res`.
- **Superficies y materiales** (`materials/weapons/`, color plano):
  - espada: 0 acero (`knight_steel_material`), 1 latón (`knight_brass_material`), 2 cuero (`knight_leather_material`);
  - escudo: 0 acero oscuro (`knight_dark_steel_material`), 1 latón, 2 cuero, 3 acero (canto y borde).

## Espada

Espacio del arma (el `Model` en identidad): la hoja apunta a −Z, la guarda cruza X y el plano de la hoja es XZ.

| Parte | Medida |
|---|---|
| Punta (`TrailTip`) | z = −1.26 |
| Hoja | sección de rombo (arista central de 2.4 cm, filos en espesor cero), 8 cm de ancho en la guarda y 5.8 cm a 13 cm de la punta, donde se cierra |
| Guarda (`TrailBase` en su cara delantera, z = −0.322) | latón, 31 cm de ancho, 3.2 cm de alto y 3.6 cm de espesor, con una lengüeta sobre la hoja y extremos ensanchados que terminan en punta de lanza |
| Empuñadura | cuero octogonal, 17 cm, centrada en el puño (z = −0.205), con dos anillos de latón |
| Pomo | disco de latón biselado, 6 cm |
| Largo total | 1.20 m |

El puño derecho cae en z = −0.205 porque `grip_position` = (0, −0.04, 0.1538) en `sword.tres` (la mano mide ×1.333). Si cambia la mano del humanoide, se recalculan `FIST_Z` y `grip_position`.

## Escudo

Espacio del escudo: +Y arriba, la cara exterior (convexa) mira a −Z y el dorso a +Z.

- **Silueta heater con copete:** 0.80 × 0.58 m. Los hombros en y = 0.30 suben hasta el pico en y = 0.40 (exponente 0.7, borde levemente cóncavo); costados rectos hasta y = 0; abajo cierra en punta en y = −0.40 (exponente 0.6).
- **Curvatura:** arco horizontal de radio 0.75 m en 12 franjas (5.8 cm de flecha). Placa de 1.2 cm, con un canto de acero de 1.5 cm levantado 3 mm.
- **Cruz de Santiago:** relieve de latón de 5 mm; brazo superior y laterales con flor de lis (pétalos que se curvan atrás y punta central), brazo inferior en forma de hoja de espada. La tapa se subdivide (lados ≤ 3 cm) para seguir la curva.
- **Remaches:** 16 cúpulas hexagonales de 2.8 cm a 4 cm del borde, y una en el centro de la cruz.
- **Dorso:** empuñadura de cuero horizontal a 9 cm de la placa (lugar para el puño), sobre dos postes, y una correa más arriba.
- **Marcadores de la escena:** `Grip` (centro de la empuñadura, y = −0.05), `Center`, `Top`, `Bottom`, `Left` (−X) y `Right` (+X).

El escudo cuelga de `wrist_l` con `shield_position` = (−0.0437, −0.0033, 0) y `shield_rotation` = (0, π/2, 0): así el `Grip` queda en el centro de la mano izquierda, la empuñadura atraviesa el puño y la cara mira hacia afuera con el brazo colgando. Si se mueve el `Grip`, se recalcula `shield_position`.

## Mandoble

Mandoble del Berserker (`entities/player/weapons/greatsword.tscn`, `docs/specs/berserker-greatsword.md`), de la misma familia: se hizo a partir de una referencia del responsable (un mandoble tipo "Matadragones"). Mismo espacio que la espada. Superficies: 0 acero oscuro (las caras de la hoja), 1 acero (los biseles), 2 latón (guarda, marca, anillos y pomo), 3 cuero (mango).

| Parte | Medida |
|---|---|
| Punta (`TrailTip`) | z = −2.21, corrida 12 cm hacia −X: el filo +X corta en diagonal durante los últimos 36 cm |
| Hoja | 30 cm de ancho y filos paralelos. Sección hexagonal: una losa de 3 cm de espesor y 22 cm de ancho (acero oscuro) y un bisel de 4 cm por filo, que cierra a espesor cero (acero) |
| Marca de forja | la cruz de Santiago del escudo a 0.3×, 18 cm de alto, 8 cm delante de la guarda, con relieve de 3 mm en las dos caras |
| Guarda | bloque de latón de 36 cm × 7 cm × 6 cm, sección de ocho lados; los extremos se ensanchan y cierran en punta de lanza |
| Mango | cuero octogonal de 42 cm (z de −0.19 a +0.23), con anillos de latón en los extremos y entre las manos (z = +0.02) |
| Pomo | disco de latón de 8 cm |
| Largo total | ≈ 2.5 m |

El puño derecho cae en z = +0.133 (`grip_position` (0, −0.04, −0.1) de `greatsword.tres`) y la mano izquierda en `OffHand` (z = −0.1). La estela va de `TrailBase` (−0.77) a la punta.
