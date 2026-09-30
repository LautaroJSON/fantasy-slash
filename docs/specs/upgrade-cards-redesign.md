# Rediseño de cartas de mejora, categorías y rolls

- **Estado:** Implementada (2026-09-30)
- **Constitución:** `docs/constitution.md`. Sin enmienda: los rolls son datos en `.tres` (Principio III) y la UI reusa `UpgradePickerConfig`.
- **Pilar (Principio I):** Progresión (cada oferta es una decisión con más matices: qué stat y qué tan buen roll) y legibilidad de la UI.
- **Dependencias:** `gold-system.md` (precios, ascensión), `upgrade-ban.md`, `upgrade-caps.md`, `affliction.md`, `sandbox-arena-control.md`.
- **ACs:** AC1426 a AC1443 (los 13 criterios de abajo, en orden, AC1439 de la revisión visual y AC1440 del bloqueo de clics y AC1441 a AC1443 del marco de foco); AC1444 a AC1470 quedan reservados para la spec hermana que lleva los rolls al sandbox.

## Objetivo

1. Las cartas se ven con jerarquía: ícono, título, nivel/rareza, descripción alineada a la izquierda con el valor resaltado, y precio al pie.
2. Las cartas blancas (stats del jugador) se agrupan en **Daño**, **Defensivo** y **Mejora**, con su ícono.
3. Cada carta blanca sortea un **roll** (mínimo, medio, alto, máximo) al armarse la oferta. El color del número muestra el roll y el **precio** en la tienda lo acompaña.
4. Las cartas azules (habilidad), doradas (únicas) y violetas (aflicción) mantienen su color, con los cambios de texto de abajo.

## Tipos de carta

| Carta | Color | Título | Ícono |
| --- | --- | --- | --- |
| Stat del jugador | Blanca | Nombre del stat | Según categoría |
| Mejora de habilidad | Azul | Nombre de la habilidad | Ícono de la habilidad si existe; si no, uno genérico |
| Única de habilidad | Dorada | Como hoy, con "Nv N" | Sin cambios de comportamiento |
| Aflicción | Violeta | "Aflicción: Veneno" (con el nombre de la aflicción) | El de `assets/icons/status/` |
| Bloquear mejora | Roja | Como hoy | Prohibido |

### Categorías de las blancas

`UpgradeCard.Group` ya tiene `OFFENSE`, `DEFENSE`, `ABILITY`, `AFFLICTION` (usado por el menú de pausa). Se agrega **`UTILITY`** ("Mejora") y las blancas se asignan así:

| Categoría | Ícono | Stats |
| --- | --- | --- |
| Daño (`OFFENSE`) | Espada | Daño, Crítico, Daño crítico, Bono de daño, Velocidad de ataque, Rango |
| Defensivo (`DEFENSE`) | Escudo | Defensa, Vida |
| Mejora (`UTILITY`) | Flechas hacia arriba | Robo de vida, Velocidad, Imán, Acumulación de Aflicción |

El menú de pausa muestra el grupo nuevo en su tabla (`stat_display_table.tres` no cambia: agrupa por stat, no por `Group`); solo hay que revisar que `sandbox` y pausa toleren el valor nuevo.

Stats que faltan y **no** entran en este cambio: regeneración de vida, reducción de daño en %, daño contra jefes.

## Rolls

### Datos

- `UpgradeData` gana `roll_amounts: Array[float]` con **4 valores** (mínimo, medio, alto, máximo). Si está vacío, la carta no sortea (usa `amount`, como las cartas de aflicción o de habilidad).
- `amount` pasa a ser el valor del **roll medio** (compatibilidad con tests viejos y el sandbox).
- `resources/roll_config.gd` (`RollConfig`) → `data/upgrades/roll_config.tres`:
  - `weights: Array[float]` = `[50, 30, 15, 5]`.
  - `price_factors: Array[float]` = `[0.6, 1.0, 1.5, 2.5]`.
  - `colors: Array[Color]` = blanco, azul, violeta, dorado (color del número).
  - `names: Array[String]` = "Mínimo", "Medio", "Alto", "Máximo" (para la etiqueta que acompaña al color).

### Valores por stat

Bajados los tres stats que pediste: Daño, Crítico y Acumulación de Aflicción. La columna "Hoy" es el valor fijo actual.

| Stat | Hoy | Mín | Medio | Alto | Máx |
| --- | --- | --- | --- | --- | --- |
| Daño | +4 | +1 | +3 | +6 | +9 |
| Crítico | +5 % | +1 % | +3 % | +6 % | +10 % |
| Daño crítico | +15 % | +8 % | +15 % | +25 % | +40 % |
| Bono de daño | +10 % | +5 % | +10 % | +18 % | +30 % |
| Velocidad de ataque | +0.15 | +0.05 | +0.15 | +0.28 | +0.45 |
| Rango | +0.3 m | +0.1 | +0.3 | +0.5 | +0.9 |
| Defensa | +2 | +1 | +2 | +4 | +7 |
| Vida | +20 | +10 | +20 | +35 | +60 |
| Robo de vida | +3 % | +1 % | +3 % | +5 % | +9 % |
| Velocidad | +0.5 | +0.2 | +0.5 | +0.9 | +1.5 |
| Imán | +1.5 m | +0.5 | +1.5 | +2.7 | +4.5 |
| Acumulación de Aflicción | +10 % | +3 % | +7 % | +12 % | +20 % |

Con los pesos 50/30/15/5 el valor esperado por copia queda: Daño ≈ 2.7 (hoy 4), Crítico ≈ 2.9 % (hoy 5 %), Acumulación ≈ 6.6 % (hoy 10 %), y los demás ≈ el valor de hoy. Es decir, esos tres stats bajan a propósito.

### Sorteo

- `systems/upgrade_roll.gd` (`UpgradeRoll`, `RefCounted`, funciones estáticas): `roll(card, config, rng) -> int` devuelve el tier según los pesos con el RNG inyectado (reproducible por seed).
- `UpgradeOffer.pick()` sigue eligiendo cartas; después cada carta con `roll_amounts` se **instancia con su roll**: `UpgradeData.rolled(tier) -> UpgradeData` devuelve un duplicado (`resource_local_to_scene`, sin escribir a disco) con `amount = roll_amounts[tier]` y `roll_tier = tier`.
- El duplicado mantiene `is_same_kind` (por stat), así que la oferta no repite el mismo stat, el reroll y el ban siguen igual, y `player.count_upgrade` cuenta por stat, no por identidad.
- El ban bloquea el **stat** (la carta base del catálogo), no el roll.
- **Ascensión:** el factor decreciente se aplica al valor sorteado (`amount_for_copy` ya usa `amount` de la instancia).
- El sandbox (`sandbox-arena-control.md`) sigue dando el roll medio.

### Precio

`ShopPricing.card_price()` multiplica por `price_factors[roll_tier]` además de lo que ya hace (oleada, copias, ascensión). Con precio base 60 en la oleada 1: mínimo 36, medio 60, alto 90, máximo 150. Promedio con los pesos ≈ 0.95 del precio de hoy, así que la economía no se mueve. Las primeras oleadas gratis (`free_picks_until_wave`) siguen sin precio.

## UI

- `ui/upgrade_card/upgrade_card_view.tscn` (`UpgradeCardView`): raíz **`Button`** (los tests usan `get_card_buttons()` y `pressed`/`disabled`). Contenido:
  - `PanelContainer` con `StyleBoxFlat` (marco de 5 px del color del tipo, panel interior oscuro, borde y esquinas redondeadas).
  - Píldora de nivel/rareza arriba a la derecha.
  - Círculo con ícono.
  - `Label` de título (Cinzel).
  - Línea divisoria del color del tipo.
  - `RichTextLabel` (BBCode) con la descripción, alineada a la izquierda; el valor clave va en negrita y con el color del tipo o del roll.
  - Franja de precio al pie (ícono de moneda; gris si no alcanza el oro).
- `Button.text` sigue existiendo (con el texto plano de la carta) para lectores de pantalla y para los tests que lo leen.
- Colores por tipo: los de `UpgradePickerConfig`; se agregan `card_panel_color` y el color de la línea/ícono por tipo.
- Descripción de violetas: se resalta si aplica a **"golpes"** o a **"tus habilidades"** (dato nuevo `applies_to` en `AfflictionUpgradeData`, con el texto resaltado en la descripción).
- La barra de tienda (oro, cambiar oferta, curar, continuar) se mantiene; solo cambia el estilo si queda desentonando.

### Animación (D)

Entrada en abanico, una carta tras otra (`Tween`, 0.35 s con 0.06 s de retardo entre cartas); al enfocar o pasar el mouse, la carta sube 6 px y crece 4 %; las demás se apagan al 70 %; un brillo recorre las cartas doradas cada 3 s. Todo con `process_mode = ALWAYS` (el juego está pausado) y respetando el foco de mando y táctil.

### Assets

- **Fuentes:** Cinzel (títulos) y Alegreya Sans (descripciones), licencia OFL, en `assets/fonts/` con `SOURCE.md`.
- **Íconos:** de game-icons.net (CC BY 3.0, créditos en `assets/icons/cards/SOURCE.md`): espada, escudo, flechas hacia arriba, prohibir y moneda; para violetas se reusan los de `assets/icons/status/`.
- **Marco:** el marco plano descrito arriba (sin descargas). Un pack ornamental queda como paso opcional posterior.

## Plan

1. `UpgradeCard.Group.UTILITY` y asignar `group` a las 12 cartas blancas. Revisar pausa y sandbox.
2. `RollConfig`, `roll_amounts` en `UpgradeData` y `UpgradeRoll` con sus tests (pesos, seed, ascensión).
3. Aplicar el sorteo a la oferta (`UpgradeOffer`/`wave_manager`) y el factor de precio en `ShopPricing`. Tests de oferta, precio y ban.
4. Descargar fuentes e íconos y anotar `SOURCE.md`.
5. `UpgradeCardView` con la estructura nueva, estilos por tipo y textos (título de aflicción, resaltado de golpes y habilidades). Adaptar `upgrade_picker.gd` y `upgrade_ban_picker.gd`.
6. Animación (D).
7. Captura visual con `godot-capture`, tests dirigidos y smoke test con `godot-tester`, checklist de la constitución y estado **Implementada**.

## Criterios de aceptación (borrador; se numeran al reservar)

1. Las 12 cartas blancas tienen una categoría entre Daño, Defensivo y Mejora, con su ícono.
2. Cada carta blanca ofrece un roll con la distribución de `RollConfig`; con la misma seed la oferta es idéntica.
3. El número de la carta usa el color del roll (blanco, azul, violeta, dorado) y muestra su nombre.
4. Aplicar una carta suma el valor sorteado, no el medio.
5. El precio en la tienda es `precio actual × factor del roll`; en las oleadas gratis no cuesta nada.
6. Una oferta no repite el mismo stat aunque los rolls difieran; bloquear una carta bloquea el stat.
7. Las copias de ascensión reducen el valor sorteado con el factor de siempre.
8. Las cartas violetas titulan "Aflicción: <nombre>" y resaltan si aplican a golpes o a habilidades.
9. Las cartas azules titulan con el nombre de la habilidad.
10. La descripción está alineada a la izquierda y el valor clave resaltado.
11. Los botones de carta siguen siendo `Button` y se navegan con teclado, mando y táctil.
12. Las cartas entran con animación y el foco las destaca.
13. Los valores de la tabla de rolls están en `.tres`, no en código.

## Notas de implementación (desvíos de la propuesta)

- **Categoría:** no se agregó `UpgradeCard.Group.UTILITY`. El grupo del menú de pausa (`Ofensivo/Defensivo/Habilidad/Aflicción`) se dejó como estaba; la categoría de la carta es un enum propio, `UpgradeData.Category` (`DAMAGE`, `DEFENSE`, `UTILITY`), que solo elige el ícono. Así la pausa, el sandbox y sus tests no cambian.
- **Texto de la carta:** cada `UpgradeData` gana `value_format` (`ValueFormat`, ya existente) y `value_label` ("de daño"); `description` sigue guardando el texto del roll medio, que usan la pausa y el sandbox.
- **Violetas:** el "golpes / tus habilidades" sale del enum `AfflictionUpgradeData.source` ya existente; no hizo falta el dato `applies_to`. Se resalta en la línea "Se acumula con tus golpes / tus habilidades".
- **Azules:** el título es el nombre de la habilidad (`AbilityData.title`); el stat que mejora ("Enfriamiento") va resaltado como primera línea del texto, sacado del título de la mejora ("Parry: enfriamiento").
- **Conteo por stat:** `StatsComponent` pasó de contar y ascender por identidad del recurso a hacerlo por stat, porque cada carta ofrecida es una copia con su roll. `remove_upgrade` quita la carta exacta o, si no está, la última copia del mismo stat.
- **Crítico:** con el medio en 3 %, `max_stacks` pasó de 19 a 32 (base 5 % + 32 × 3 % = 101 %, la primera copia que llega al tope de `combat_rules`). `test_ac230` de `upgrade_caps_test.gd` pasó de "aterriza exacto en 100 %" a "la última copia es la primera que llega al 100 %", que es lo que ya hacía `test_ac231` con el daño crítico.
- **Tests adaptados sin cambiar lo que verifican:** `sandbox_run_test` (fila del crítico: 5 % → 20 %), `affliction_run_test` (acumulación: +14 %), `ability_run_test` (el estilo de la carta blanca ya no es el del botón por defecto, sino el marco blanco de `common_card_color`); `upgrade_offer_test` y `stats_rework_test` (12 cartas) los cambió la spec de oro. El texto plano de los botones (`Button.text`) sigue siendo "Título (nivel)\nDescripción", así que los tests que lo leen no cambiaron.
- **Animación:** la carta enfocada no cambia de tamaño (escalar un `Control` vuelve borroso el texto): las demás bajan al 75 % de brillo y la enfocada muestra su marco más claro y el borde de foco. Las doradas alternan el brillo de su marco cada 1.4 s.
- **Tamaño:** cartas de 208 × 340 px, para que entren cinco (con la de bloqueo) en 1152 px. El texto vive en un `Control` de alto mínimo fijo, así una descripción larga (las únicas) se parte en líneas en vez de ensanchar la carta.
- **Fuera de esta spec:** el submenú de bloqueo (`UpgradeBanPicker`) conserva sus botones de texto; la barra de la tienda (oro, cambiar oferta, curar, continuar) solo suma la fuente del título. El marco ornamental (9-slice) y el sandbox con rolls son las dos specs siguientes.
- **Fallos que ya estaban en el árbol de trabajo y no son de esta spec** (confirmados en `HEAD`): `test_ac119` de `upgrade_caps_test`, `test_ac229` de `stats_rework_test`, y los valores viejos de `test_ac22`/`test_ac23` de `arena_waves_test` (la base del Guerrero es 20 de daño y 200 de vida), y `test_ac155` de `boss_challenge_run_test`.

## Revisión visual (2026-09-30, AC1439)

- El valor de la carta blanca tiene el mismo tamaño que el texto (solo en negrita y con el color del roll), en una sola línea: "+3 de daño".
- Cartas de 208 × 340 px (más anchas y menos altas; cinco caben en 1152 px). El texto de la descripción es un `RichTextLabel` con desplazamiento: si no entra, aparece la barra y la rueda del mouse lo mueve (`mouse_filter` PASS, así el clic sigue llegando a la carta). Con mando o táctil no hay desplazamiento propio todavía.
- Violetas: el texto empieza con "Tus <golpes|habilidades> acumulan <Aflicción>.", con la fuente en el color de la carta y la Aflicción en el color de su barra (`AfflictionData.bar_material`). Sigue la descripción del nivel sin su primera línea (que decía lo mismo) y se quitó la línea final "Se acumula con…".

## Bloqueo de clics al abrir la oferta (AC1440)

- Problema: el jugador termina la oleada haciendo clic sin parar y el clic elige una carta sin querer.
- Al abrirse una oferta (o la tienda) las cartas ignoran los clics durante `card_lock_duration` (1 s, `upgrade_picker_config.tres`) y se ven atenuadas (`card_locked_brightness`, 0.6); al pasar el tiempo se iluminan. El tiempo corre aunque el juego esté en cámara lenta.
- Un clic que empezó durante el bloqueo no cuenta aunque se suelte después (`UpgradeCardView.accepts_press`). Vale igual para teclado y mando (el botón de aceptar).
- Las cartas siguen enfocables, así que el mando ya tiene el foco puesto. No bloquea los botones de la tienda (cambiar oferta, curar, continuar) ni el reroll: un clic ahí no compra nada.
- El bloqueo se aplica a cada oferta nueva y a la apertura de la tienda; no al refrescarla tras comprar, ni al volver del submenú de bloqueo.
- Revisión visual: el espacio entre cartas es de 18 px (cartas de 208 px). La carta enfocada ya no se escala: escalar un `Control` volvía borroso el texto.

## Marco de foco solo al navegar (AC1441–AC1443)

- Problema: la primera carta (y la del menú de clases y de habilidades) salía con un marco blanco, el foco que se le da de entrada para el mando, aunque el jugador use el mouse.
- Nuevo autoload `UiNav` (`systems/ui_nav_mode.gd`, `UiNavMode`): sabe si el jugador navega con teclado o mando (acciones `ui_up/down/left/right`, `ui_focus_next/prev`, `ui_accept`) o con el mouse/táctil (cualquier movimiento o clic lo apaga). Las teclas de juego como WASD no cuentan.
- `UiNav.bind_focus_frame(button)`: el botón dibuja su marco de foco (el suyo, o el del tema) solo mientras se navega; si no, un `StyleBoxEmpty`. Lo usan las cartas de mejora (`UpgradeCardView`), las cartas de habilidad, las de clase y los botones del menú principal. La carta sigue teniendo el foco: solo cambia que no se dibuja.

## Ajuste de categoría (2026-09-30)

- **Robo de vida** pasa de Defensivo a **Mejora** (ícono de flechas). Solo cambia la carta: en la pausa sigue en la sección Defensivo (`UpgradeData.group`).
- **Azules:** el título pasa a ser "Habilidad: <nombre de la habilidad>" (antes solo el nombre), igual que las violetas ("Aflicción: Veneno").

## Entrada limpia, cartas sin stock y tienda (AC1444–AC1446)

- **Sin bloqueo visible:** se quitó el atenuado al abrir y el destello al desbloquear. La entrada es la animación: las cartas suben desde abajo (`card_enter_rise`, 160 px), inclinadas en abanico (`card_enter_tilt`, ±10°, más las de los bordes), chicas (70 %) y transparentes, y aterrizan una tras otra (`card_enter_stagger`, 0.12 s) con un pequeño rebote (`TRANS_BACK`). Todo dura `card_enter_total` (1 s) sin importar cuántas cartas haya, y no le afecta la cámara lenta.
- **Durante la entrada** no se puede seleccionar ni hacer hover (la carta dibuja su estilo normal, no el de hover); en cuanto aterriza la última, todas responden. Un clic que empezó antes de eso nunca cuenta. Los botones de la tienda que gastan oro (cambiar oferta, curar) y "Continuar" esperan igual.
- Cada carta vive en un `Control` "casillero" del tamaño de la carta, así se puede animar su posición mientras el contenedor las ordena. La entrada no se repite cuando la tienda se refresca tras una compra o un reroll.
- **Carta que no se puede comprar** (falta oro): sin hover, sin foco de teclado ni mando y sin efecto de resalte sobre las demás; se ve apagada.
- **Tienda:** el oro es un panel destacado con la moneda, "Oro" y la cantidad grande en el color de los precios. "Cambiar oferta" y "Curar" son botones con marco, ícono (dados, corazón con cruz), nombre y, cuando cuestan, moneda y precio; "Continuar" con el mismo marco. Sin oro suficiente se ven a media opacidad. Íconos nuevos en `assets/icons/cards/` (`reroll.svg`, `heal.svg`). Los botones usan `UiNav`, así que solo dibujan el marco de foco al navegar con teclado o mando.

## Retoque de la tienda (AC1447)

- **Oro:** una píldora redonda y sin borde, en dorado suave, con la moneda y la cantidad grande; sin la palabra "Oro" (la moneda alcanza) y de forma distinta a los botones, que son rectángulos con marco.
- **Botones:** más espacio interno (22 px a cada lado) y más grandes (310, 280 y 200 × 62 px).
- **Curar:** marco verde (`heal_color` en `upgrade_picker_config.tres`, más claro al pasar el mouse), y muestra la vida que da en verde ("+60") antes de la moneda y el precio. La cantidad es `min(vida máxima × heal_fraction, vida que falta)`, la calcula `WaveManager` y llega por el parámetro nuevo `heal_amount` de `show_shop` (por defecto 0: sin cantidad).
