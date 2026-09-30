# Sistema de oro

- **Estado:** Implementada (2026-09-29; gold_system_test y gold_arena_test en verde, smoke test de la arena sin errores; enmienda 6.5.0 aplicada)
- **Constitución:** `docs/constitution.md`. **Enmienda MINOR propuesta** (Principio III): las cartas de stats pueden tener "niveles ascendidos" después de `max_stacks` (ver *Cartas sin techo*).
- **Pilar (Principio I):** Progresión (las mejoras pasan a ser una decisión de recursos dentro de la run) y Supervivencia (curación y reroll compiten por el mismo oro; el oro sobrante ya no rompe la run infinita).
- **Dependencias:** `combat-mvp.md`, `upgrade-caps.md`, `upgrade-ban.md`, `early-power-curve.md`, `endless-without-upgrades.md`, `enemy-rage.md`.
- **ACs reservados:** AC1396 a AC1425 (los tests cubren AC1396-AC1417; AC1414-AC1415, AC1418-AC1420 se verificaron por diseño: oferta vacía sin cambios, HUD, sandbox sin cobro, datos en `.tres`).

## Objetivo

1. Los enemigos sueltan **monedas** al morir. La moneda queda en el suelo hasta que el jugador la recoge.
2. El jugador tiene un stat **Radio de recogida** (`pickup_radius`). Su valor inicial es el mismo en todas las clases y sube con una carta. Dentro del radio, la moneda vuela hacia el jugador.
3. Las mejoras **ya no son gratis**. Al terminar una oleada se abre la **tienda**: el picker actual, con precio en cada carta. Se compra lo que se pueda pagar, o nada, y se sigue.
4. Sumideros de oro que hacen que nunca sobre: **reroll** con precio creciente, **curación** con precio creciente y **cartas sin techo** con rendimiento decreciente.
5. El oro se pierde al terminar la run.

## Estructura de nodos

- `entities/pickups/coin.tscn` (`Coin`, `Area3D`): malla primitiva (`CylinderMesh` plano dorado), `CollisionShape3D`. Va en un pool (`CoinPool`, como `EnemyPool`).
- `systems/gold_wallet.gd` (`GoldWallet`, `Node`): en el nivel, junto a `RunState`. Guarda el oro actual y emite `changed`.
- `systems/coin_spawner.gd` (`CoinSpawner`, `Node`): escucha `Enemy.killed` y suelta monedas.
- `ui/shop/` : el `UpgradePicker` gana precios. Se agregan botones de reroll y curación.
- HUD: contador de oro.

## Resources y datos

- `resources/gold_config.gd` (`GoldConfig`) → `data/economy/gold_config.tres`:
  - `coin_value_base`, `coin_value_per_wave` (valor de una moneda según la oleada).
  - `drops_per_enemy_kind` (por tipo: fodder, normal, élite, boss).
  - `max_coins_on_floor` (tope; al superarlo se fusiona la moneda más vieja con la más cercana, sumando valor).
  - `magnet_speed`, `magnet_acceleration`, `collect_distance`.
  - `stage_change_auto_collect: bool` (al cambiar de stage, las monedas restantes se recogen solas).
- `resources/shop_config.gd` (`ShopConfig`) → `data/economy/shop_config.tres`:
  - Precio de una carta: `base_price × price_growth_per_wave^(wave) × price_growth_per_purchase^(compras de esa carta)`.
  - `reroll_base_price`, `reroll_growth` (crece con cada reroll de la oleada y se reinicia en la siguiente).
  - `heal_base_price`, `heal_growth`, `heal_fraction` (fracción de vida máxima).
  - `free_picks_until_wave`: las primeras oleadas mantienen picks gratis (`early-power-curve.md`), para que el arranque no dependa del oro.
- `PlayerStats`: nuevo stat `PICKUP_RADIUS`. Valor igual en todos los `<clase>_stats.tres`.
- `data/upgrades/pickup_radius.tres`: carta "Imán", con `max_stacks`.
- `UpgradeData`: `ascension_levels` (cuántos niveles extra tras `max_stacks`), `ascension_amount_factor` (fracción del bono, decreciente por nivel), `ascension_price_growth`.
- `CombatRules`: no cambia.

## Interfaz pública

- `GoldWallet`: `add(amount: int)`, `try_spend(amount: int) -> bool`, `get_gold() -> int`, señal `changed`.
- `ShopPricing` (`RefCounted`, funciones puras estáticas): `card_price(card, wave, times_bought, config) -> int`, `reroll_price(rerolls_done, config) -> int`, `heal_price(heals_done, config) -> int`.
- `UpgradePicker.show_offer(offer, prices, gold, can_reroll, heal_price)`; señales `upgrade_bought(card)`, `reroll_requested`, `heal_requested`, `closed`.
- `Coin`: `activate(value: int, position: Vector3)`; emite `collected(value)`.

## Lógica interna

1. **Drop.** `CoinSpawner` recibe `Enemy.killed`. Toma un `Coin` del pool y lo pone en la posición del enemigo con un pequeño impulso. El valor sale de `GoldConfig` según tipo y oleada.
2. **Recogida.** Cada `Coin` compara su distancia al jugador con `pickup_radius`. Dentro del radio, acelera hacia él. Al llegar a `collect_distance`, suma al `GoldWallet` y vuelve al pool. Fuera del radio se queda quieta y **no vence por tiempo**.
3. **Tope de monedas.** Sobre `max_coins_on_floor` se fusiona la más vieja con la vecina (suma valores). Así no se pierde oro ni crece el costo de físicas.
4. **Tienda.** `WaveManager._on_all_dead` calcula la oferta como hoy. La abre con precios. Comprar = `try_spend` + `player.apply_upgrade`; la carta comprada se reemplaza o se quita, y la tienda sigue abierta hasta "Continuar".
5. **Reroll.** Cobra `reroll_price`, arma una oferta nueva con `UpgradeOffer.pick` y sube el contador de rerolls de la oleada.
6. **Curación.** Cobra `heal_price`, cura `heal_fraction` de la vida máxima y sube el contador.
7. **Cartas sin techo.** Al llegar a `max_stacks`, una carta con `ascension_levels > 0` sigue en el pool como "Ascendida": su bono es `amount × ascension_amount_factor^nivel` y su precio usa `ascension_price_growth`. Al agotar los niveles ascendidos, sale del pool como hoy. `endless-without-upgrades.md` sigue valiendo: oferta vacía → sin tienda y arranca Rage.
8. **Oleada sin nada comprable.** Si el jugador no puede pagar nada, la tienda igual se abre (puede pasar a la siguiente oleada con "Continuar"), salvo que la oferta esté vacía.
9. **Fin de run.** `GoldWallet` vive en el nivel: recargar la escena lo reinicia.
10. **Sandbox.** Las mejoras del panel del sandbox siguen gratis.

## Criterios de aceptación

- **AC1396** Un enemigo muerto suelta monedas con el valor de `GoldConfig` para su tipo y oleada.
- **AC1397** Una moneda no vence: sigue en el suelo mientras el jugador no la recoja.
- **AC1398** Una moneda dentro de `pickup_radius` vuela hacia el jugador y, al llegar, suma su valor al oro.
- **AC1399** Una moneda fuera de `pickup_radius` no se mueve.
- **AC1400** `pickup_radius` tiene el mismo valor inicial en todas las clases.
- **AC1401** La carta "Imán" sube `pickup_radius` y sale del pool en su `max_stacks`.
- **AC1402** Al pasar `max_coins_on_floor`, la moneda más vieja se fusiona con la vecina y el oro total no cambia.
- **AC1403** `GoldWallet.try_spend` devuelve `false` y no cambia el oro si no alcanza.
- **AC1404** `ShopPricing.card_price` crece con la oleada y con las compras de esa carta.
- **AC1405** En la tienda, una carta se compra solo si el oro alcanza; al comprarla se aplica y se descuenta el precio.
- **AC1406** Una carta que no se puede pagar se ve deshabilitada, con su precio.
- **AC1407** La tienda se puede cerrar sin comprar nada y la oleada avanza.
- **AC1408** Reroll: cobra `reroll_price`, cambia la oferta y el siguiente reroll de la oleada cuesta más.
- **AC1409** El contador de rerolls se reinicia en cada oleada.
- **AC1410** Curación: cobra `heal_price`, cura `heal_fraction` de la vida máxima y el siguiente cuesta más. No cura por encima del máximo.
- **AC1411** En las oleadas `<= free_picks_until_wave`, los picks son gratis como hoy.
- **AC1412** Una carta en `max_stacks` con `ascension_levels > 0` sigue en el pool como ascendida, con bono decreciente.
- **AC1413** Una carta ascendida en su último nivel sale del pool.
- **AC1414** Con la oferta vacía no se abre la tienda y arranca Rage (sin cambios).
- **AC1415** El HUD muestra el oro y se actualiza al recoger o gastar.
- **AC1416** Con `stage_change_auto_collect` activo, las monedas restantes se suman al oro al cambiar de stage.
- **AC1417** El oro se reinicia al reiniciar la run.
- **AC1418** El sandbox no cobra las mejoras.
- **AC1419** Ningún valor de oro, precio ni radio está hardcodeado; todo viene de `.tres`.
- **AC1420** Funciona con teclado y mouse, mando y táctil (botones de la tienda accesibles).

## Plan

1. `PlayerStats.PICKUP_RADIUS`, `pickup_radius.tres`, valor en las 4 clases y sus tests.
2. `GoldWallet` + `GoldConfig` + tests puros.
3. `ShopPricing` (funciones puras) + `ShopConfig` + tests.
4. `Coin`, `CoinPool`, `CoinSpawner` y drop desde `Enemy.killed`; fusión por tope.
5. HUD del oro.
6. `UpgradePicker` con precios, comprar y "Continuar"; `WaveManager` abre la tienda.
7. Reroll y curación.
8. Ascensión de cartas (`UpgradeData` + `UpgradeOffer`) y enmienda de la constitución.
9. Documentar en `where-to-tune.md`, actualizar `ac-registry.md` y el contador de CLAUDE.md.
10. Tests dirigidos, smoke test de la arena (con `godot-tester`) y checklist de la constitución.

## Supuestos a confirmar

- "Stat de absorción" = **radio de recogida**, con carta de mejora ("Imán").
- Las monedas restantes al cambiar de stage se recogen solas.
- Los picks gratis del arranque se mantienen, según `early-power-curve.md`.

## Notas de implementación

- `Coin` es un `Node3D` sin colisión (no `Area3D`): la distancia al jugador se revisa en `CoinSpawner._physics_process`.
- Tope de monedas: un drop sin moneda libre suma su valor a la más cercana (en vez de "la más vieja").
- Tipo de enemigo para el valor de la moneda: se deriva de `EnemyStats` (`hud_health_bar` = boss, grupo de tokens FODDER = fodder); no hay un campo nuevo en cada enemigo. Se dropea una moneda por muerte; ninguna en el sandbox.
- El bloqueo de cartas también se compra en la tienda (`ban_base_price`), con la regla de `CardBanRules` para cuándo se ofrece.
- La carta "Imán" está en el grupo Defensa de la pausa; `pickup_radius` tiene fila en `stat_display_table.tres`. Daño, Defensa, Vida, Bono de daño y Robo de vida tienen 5 niveles ascendidos (factor 0.7).
- El conteo de la pausa y el tooltip muestran el máximo con ascensión (`total_copies()`); `pause_menu_tabs_test` y `sandbox_run_test` se adaptaron sin cambiar lo que verifican. `upgrade_caps_test` AC120 usa la carta de Rango (sin ascensión) porque Daño ya no sale del pool en su tope.
- Fallas previas de HEAD, no relacionadas: `stats_rework_test` (AC229 y otras), `upgrade_caps_test` AC119 (Parry), `arena_waves_test` AC22/AC23 y `boss_challenge_run_test` AC155.
