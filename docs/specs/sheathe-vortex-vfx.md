# Vórtice de corte: el efecto de luz del Contragolpe nivel 3, en Envainar

**Estado:** Implementada en la rama `poc/samurai-motion` (sin tests, igual que la prueba de animación)
**Constitución:** 4.26.0 (se sigue su tabla de colores: blanco aditivo, alpha ≤ 0.5, piso ≤ 0.3)

## 1. Objetivo

El estallido de Envainar toma el lenguaje visual del vórtice del Contragolpe nivel 3 (`CircleSlashVfx`: banda en espiral, trazos de luz con estela, marca en el piso y destello), **adaptado a un corte recto**. El vórtice del Guerrero gira alrededor del cuerpo; el de Envainar es un **tirabuzón de luz que sale disparado del jugador hasta la punta del corte**.

**Pilar (Principio I): Combate.** El golpe más fuerte del Samurái se lee de un vistazo: se ve hasta dónde llega y qué tan cargado salió.

## 2. Qué se ve

Todo pasa en el espacio del corte: origen en los pies, adelante −Z, largo L (el de hoy), eje a la altura del pecho.

1. **Banda en espiral.** Una cinta ancha que se enrosca alrededor del eje del corte (1.5 vueltas de punta a punta). La cabeza viaja del jugador a la punta en `sweep_duration` (~0.22 s) y deja atrás una estela que se angosta y se apaga. El borde de afuera va un poco más alto, igual que el embudo del Contragolpe, para que la cámara baja lo vea.
2. **Trazos de luz.** Entre 4 y 10 cintas finas, según el nivel, que corren adelante enroscándose a distintas distancias del eje. Cada una tiene su fase, su velocidad (×1.0 a ×1.5) y su largo de estela. Se reparten con los mismos pasos de razón áurea del Contragolpe, sin azar. Son "los rayos".
3. **Marca en el piso.** Una franja plana bajo el corte que crece con la cabeza y se apaga (alpha ≤ 0.3).
4. **Estallido.** Se conservan las chispas, el polvo, la grieta y el destello de hoy. La cantidad de chispas y la energía de la luz crecen con el nivel (×1, ×1.6, ×2.4), y se suma una luz breve que recorre el corte con la cabeza de la banda.
5. **Se quitan de Envainar** las paredes en V y la media luna con su eco: el vórtice las reemplaza. La línea en el piso durante la carga no cambia.

El Tajo aéreo del Berserker, que reutiliza `WindCutVfx`, no cambia.

## 3. Nivel del vórtice

Igual que el Contragolpe, crece con el nivel:

| Nivel | Cuándo | Ancho de banda | Trazos |
|---|---|---|---|
| 1 | carga < 50 % | ×0.8 | 4 |
| 2 | carga ≥ 50 % | ×1.0 | 7 |
| 3 | carga al 100 %, o Envainar mejorado (Hosho) | ×1.2 | 10 |

## 4. Estructura

- **`SheatheVortexVfx`** (`components/abilities/sheathe_vortex_vfx.gd`, `extends MeshInstance3D`, `top_level`). Tiene un `ImmediateMesh` hecho una vez que se rearma cada cuadro mientras dura, y la tabla de trazos se calcula una vez para el nivel máximo (mismo patrón que `CircleSlashVfx`). También tiene su luz breve. Interfaz: `play(transform, length, level)`, `advance(delta)` e `is_playing()`.
- **`SheatheVortexConfig`** (`resources/sheathe_vortex_config.gd`) en `data/abilities/sheathe/sheathe_vortex_config.tres`, con arrays `*_by_level`: vueltas, altura del eje, radio, ancho y levante de la banda, trazos (cantidad, radios, anchos, estelas, velocidades y vueltas), piso, duraciones, luz y escala de chispas.
- **Material:** reutiliza `materials/vfx/circle_slash_material.tres` (blanco aditivo, color por vértice, se desvanece cerca de la cámara).
- **`WindCutVfx`:**
  - `@export var vortex: SheatheVortexVfx` (opcional);
  - `show_walls` y `show_crescent` en `WindCutConfig`, en `true` por defecto; Envainar los pone en `false`;
  - `set_level(level)`, que escala las chispas y la luz;
  - `burst()` lanza el vórtice si hay uno.
- **`SheatheAbility`:** calcula el nivel (carga o mejorado) y se lo pasa a `WindCutVfx` antes del estallido.
- **`sheathe_ability.tscn`:** nodo `Vortex` nuevo, enlazado desde `WindCut`.

## 5. Criterios de aceptación (visuales, sin tests)

- **V1:** al soltar Envainar, un tirabuzón de luz sale del jugador y llega a la punta del corte en ~0.22 s, con trazos finos alrededor, y se apaga en ~0.3 s.
- **V2:** con carga baja se ve más chico (4 trazos) y al 100 % o mejorado se ve lleno (10 trazos, banda más ancha, más chispas y más luz).
- **V3:** no quedan paredes en V ni media luna en Envainar. El Tajo aéreo se ve igual que antes.
- **V4:** en la arena no hay errores en el log, y cortar el casteo con un dash sigue mostrando el estallido solo visual.

## 6. Plan

1. Crear `SheatheVortexConfig` y su `.tres`, y `SheatheVortexVfx` con la banda, los trazos, el piso y la luz.
2. Enganchar el vórtice en `WindCutVfx` (flags, `set_level`, `burst`) y en `sheathe_ability.tscn` y `SheatheAbility` (nivel).
3. Captura: una escena de herramienta que dispara el estallido en los tres niveles, en video, desde la cámara del juego y en cámara lenta. Ajuste de valores a ojo.
4. Smoke test en la arena y commit en la rama.

## 7. Notas de implementación

- **Cintas con sección en cruz:** cada quad se dibuja dos veces, una a lo ancho del eje y otra alrededor de él. Si no, las cintas de una hélice se ven de canto desde muchos ángulos y parecen hilos.
- **Valores ajustados a ojo con capturas:**
  - banda: radio 0.75 m y ancho 0.3 / 0.4 / 0.5;
  - trazos: ancho de 0.05 a 0.12 m y radio de 0.2 a 0.95 m.
- **`show_walls` y `show_crescent`** tienen que ir después de `script` en el `.tres`: si van antes, Godot los ignora.
- **Enlace al vórtice:** `WindCut.vortex` es un export de tipo nodo, así que el nodo de la escena necesita `node_paths=PackedStringArray("vortex")`.
- **Verificación:**
  - captura en video de los tres niveles, a velocidad real y al 30 %;
  - arena con el Samurái y Envainar equipado: cargas de distinto largo y dashes, dos estallidos con vórtice y sin errores de script.
