# fantasy-slash

Juego de tipo hack and slash roguelike en tercera persona desarrollado con Godot 4.7 y GDScript.

## Descripción

Este proyecto combina:

- combate cuerpo a cuerpo en tercera persona
- oleadas de enemigos
- mejoras y progresión por run
- mecánicas de dash, habilidades y control de cámara
- enfoque en diseño de balance y datos en Resources

## Requisitos

- Godot 4.7.x
- Windows / PC para desarrollo principal
- Git para control de versiones

## Cómo abrir el proyecto

1. Clonar el repositorio.
2. Abrir la carpeta con Godot.
3. Importar el proyecto desde `project.godot`.
4. Ejecutar la escena principal o la escena de arena según corresponda.

## Estructura principal

- `data/`: stats, upgrades, configuración y balance
- `components/`: lógica reutilizable del juego
- `entities/`: entidades y escenas del jugador/enemigos
- `systems/`: sistemas globales y flujo de juego
- `ui/`: interfaz
- `test/`: pruebas con GdUnit4

## Buenas prácticas

- No commitear archivos generados por Godot (`.godot`, `.import`, caches, builds).
- Mantener el contenido balanceable en Resources `.tres`.
- Usar `git lfs` para activos pesados si el proyecto crece.
- Revisar la constitución de diseño antes de tocar lógica o balance.

## Licencia

A definir según la política del proyecto.
