# Feature: Golpe aéreo del Samurái

- **Estado:** Propuesta
- **Constitución:** `docs/constitution.md` v4.7.0 (sin enmienda).
- **Pilares (Principio I):**
  - **Combate:** el salto del samurái pasa a tener un golpe propio, rápido y de un solo uso, que se apunta con la orientación del personaje.
  - **Progresión:** usa el daño, el crítico y el robo de vida del ataque básico, y el arco y el alcance del jugador más un bonus, así que las cartas del personaje lo mejoran.
- **Dependencias:** `samurai.md` y `sword-sweep.md` (Implementadas). Convive con `berserker-air-slash.md` (en curso en otra sesión): son piezas separadas, y cada clase declara la suya.

## 1. Objetivo

- **Solo el Samurái:** su clase declara un `AirStrikeConfig`. El Guerrero y el Berserker no tienen uno. El Berserker tiene su propio tajo aéreo, de otra spec.
- **Golpe aéreo:** en el aire (sin tocar el piso), apretar `attack` hace un **barrido horizontal reforzado** hacia donde **mira** el personaje:
  - **Sin autoapuntado:** no gira hacia el enemigo más cercano. En el aire, el personaje ya mira hacia donde se mueve.
  - **Daño del ataque básico:** `outgoing(DAMAGE, DAMAGE_BONUS, crítico, CRIT_DAMAGE)`, un tiro de crítico, robo de vida sobre el total y el empuje normal del ataque.
  - **Área:** un sector de arco `ATTACK_ARC + arc_bonus_degrees` (100° + 80° = **180°**, con tope en 360°) y alcance `ATTACK_RANGE + range_bonus` (2.0 + 0.5 = **2.5 m**).
  - La espada hace el barrido horizontal con ese arco y la estela del arma.
  - Emite `attacked`, como cualquier barrido.
- **Pequeña pausa:** al golpear, el samurái queda **suspendido** `hang_duration` (**0.1 s**) sin gravedad, con movimiento horizontal normal. Después sigue cayendo normalmente.
- **Uno por salto:** después del golpe aéreo, `attack` no hace nada más hasta tocar el piso. Al aterrizar se habilita de nuevo.
- No se puede lanzar mientras se dashea, se castea o se carga una habilidad.
- En el piso, el ataque del samurái sigue igual que hoy.

## 2. Diseño

- **Datos (Principio III):**
  - `resources/air_strike_config.gd` (`AirStrikeConfig`): `arc_bonus_degrees`, `range_bonus`, `hang_duration` y `max_arc_degrees` (360).
  - `data/classes/samurai/air_strike_config.tres`: 80 · 0.5 · 0.1 · 360.
  - `CharacterClassData`: `+ @export var air_strike: AirStrikeConfig` (null = sin golpe aéreo). `samurai.tres` lo referencia.
  - Stats fijos por diseño: los bonus y la pausa no tienen carta. El daño, el arco y el alcance base sí suben con las cartas del personaje.
- **`AttackComponent.air_strike_with_roll(config, crit_roll)`:** hace el barrido sin autoapuntado, con el arco y el alcance ampliados, pone el enfriamiento del ataque (el mismo intervalo) y aplica el mismo golpe. `_strike` y `_collect_hits` pasan a recibir el arco y el alcance. `air_strike(config)` tira el crítico al azar.
- **`AirStrikeComponent`** (nodo nuevo `AirStrike` en `player.tscn`: `body`, `attack` y `movement`):
  - `setup(config)`: lo llama `Player` al aplicar la clase.
  - `is_enabled()`.
  - `handle(attack_pressed, blocked) -> bool`: en el aire, habilitado y no usado, si se aprieta ataque y no está bloqueado, golpea, marca "usado" y arranca la pausa. Devuelve verdadero si el ataque normal no debe correr (samurái en el aire).
  - `refresh_landing()`: en el piso limpia "usado".
  - `controls_motion()` (durante la pausa) y `move_body(delta, wish_direction)`, con `movement.hover_move(..., 1.0)`.
  - `is_used_this_jump()` y `get_hang_left()`.
- **`Player`:**
  - `_handle_attack()` primero consulta a `air_strike.handle(...)`, con `blocked = is_casting() or dash.is_dashing()`; si devuelve verdadero, no hace el barrido normal.
  - `_handle_movement()` le da el control del movimiento a `air_strike` durante la pausa, salvo que haya un dash.
  - `_apply_character_class()` llama `air_strike.setup(clase.air_strike)`.

## 3. Criterios de aceptación (se reservan al empezar la implementación)

- **AC590** `air_strike_config.tres` tiene los valores de §2 y `samurai.tres` lo referencia. `warrior.tres` y `berserker.tres` tienen `air_strike` null.
- **AC591** Samurái en el aire, al apretar `attack`:
  - se emite `attacked` una vez;
  - la espada barre con arco `ATTACK_ARC + 80` (180°);
  - un enemigo al costado (a 80° del frente) y a 2.3 m recibe el golpe, que un barrido normal (100°, 2.0 m) no alcanzaría.
- **AC592** Sin autoapuntado: con un enemigo detrás, el `Visual` no gira hacia él y el enemigo no recibe el golpe.
- **AC593** Daño: igual al del ataque básico. Con tiro de crítico favorable se multiplica por (1 + CRIT_DAMAGE). El robo de vida cura sobre el total aplicado.
- **AC594** Pausa: durante `hang_duration` la velocidad vertical es 0 y la altura no baja (±0.02 m). Después vuelve a caer con gravedad.
- **AC595** Uno por salto: mantener `attack` en el aire después del golpe no emite otro `attacked` hasta aterrizar. Al aterrizar, `attack` hace el barrido normal del piso. En un nuevo salto se puede volver a lanzar el golpe aéreo.
- **AC596** Guerrero en el aire: `attack` hace el barrido normal (con autoapuntado) varias veces por salto, como hoy. En el piso, el ataque del samurái no cambia.
- **AC597** Regresión:
  - pasan los tests de ataque, espada, samurái y dash;
  - si `berserker-air-slash.md` tiene un test que exige que el samurái barra normal en el aire, se adapta, porque su primer golpe en el aire ahora es este (sigue emitiendo `attacked`);
  - import y smoke test no dan errores ni warnings.

## 4. Plan

1. Reservar AC590–AC597 en `CLAUDE.md` (próximo libre → AC598).
2. Datos: `AirStrikeConfig`, su `.tres` y `CharacterClassData.air_strike`.
3. `AttackComponent`: `air_strike_with_roll` y el arco/alcance como parámetros.
4. `AirStrikeComponent` y su nodo en `player.tscn`; integración en `Player`.
5. Tests AC590–AC597, captura del golpe en el aire, smoke test y cierre (estado **Implementada**).
