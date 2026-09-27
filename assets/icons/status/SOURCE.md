# status icons

- **Origen:** [game-icons.net](https://game-icons.net), bajados del repo [`game-icons/icons`](https://github.com/game-icons/icons) (rama `master`).
- **Licencia:** [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). Hay que dar crédito a cada autor (tabla de abajo).
- **Uso:** íconos de buffs y debuffs (incluidos los estados de las Aflicciones, `docs/specs/affliction.md`) en la UI 2D (`StatusIconView`), referenciados desde `DebuffData.icon` y `BuffData.icon` (ver `docs/specs/status-icons.md` y el Principio II, desde 4.16.0). Se tiñen con el `icon_color` del estado.
- **Modificaciones:**
  - renombrados a `snake_case`;
  - se borró el cuadrado negro de fondo de cada SVG (`<path d="M0 0h512v512H0z"/>`), así queda solo el glifo blanco sobre transparente;
  - se agregó `width="64" height="64"` al `<svg>`, para que el importador (con sus valores por defecto; los `.import` no se versionan) genere texturas de 64 px y no de 512 px.

| Archivo | Autor | Ícono original | Estado |
|---|---|---|---|
| `bleeding_wound.svg` | Lorc | https://game-icons.net/1x1/lorc/bleeding-wound.html | Sangrado (`bleed`) |
| `cracked_shield.svg` | Lorc | https://game-icons.net/1x1/lorc/cracked-shield.html | Debilitar (`weaken`) |
| `enrage.svg` | Delapouite | https://game-icons.net/1x1/delapouite/enrage.html | Rage (`rage`) |
| `checked_shield.svg` | Lorc | https://game-icons.net/1x1/lorc/checked-shield.html | Escudo de la Colmena (`shield`) |
| `whirlwind.svg` | Lorc | https://game-icons.net/1x1/lorc/whirlwind.html | Conmoción (`concussion`) |
| `poison_bottle.svg` | Lorc | https://game-icons.net/1x1/lorc/poison-bottle.html | Veneno (`poison`, Aflicción) |
| `snowflake.svg` | Lorc | https://game-icons.net/1x1/lorc/snowflake-1.html | Escarcha (`frost`, Aflicción) |
| `acid_blob.svg` | Lorc | https://game-icons.net/1x1/lorc/acid-blob.html | Corrosión (`corrosion`, Aflicción) |
| `knocked_out_stars.svg` | Delapouite | https://game-icons.net/1x1/delapouite/knocked-out-stars.html | Aturdido (`stun`) |
| `crossed_swords.svg` | Lorc | https://game-icons.net/1x1/lorc/crossed-swords.html | Retado (`challenged`, Duelo de la Parada) |
| `laurels.svg` | Lorc | https://game-icons.net/1x1/lorc/laurels.html | Triunfo (`triumph`, Duelo de la Parada) |

## Cómo agregar un ícono

```bash
N=<nombre_snake_case>; P=<autor>/<icono>
curl -sSf -o assets/icons/status/$N.svg https://raw.githubusercontent.com/game-icons/icons/master/$P.svg
sed -i 's|<path d="M0 0h512v512H0z"/>||' assets/icons/status/$N.svg
sed -i 's|viewBox="0 0 512 512">|width="64" height="64" viewBox="0 0 512 512">|' assets/icons/status/$N.svg
```

Después se suma una fila a esta tabla. El importador usa los valores por defecto (textura 2D de 64 px).
