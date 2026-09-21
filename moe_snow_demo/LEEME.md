# Mountain of Echoes · El paso de los guardianes

## Instalar en tu proyecto existente

1. Cierra el juego si se está ejecutando. Descomprime el ZIP.
2. Copia la carpeta **moe_snow_demo** junto a tu archivo **project.godot**.
   La ruta debe quedar: `mountain-of-echoes/moe_snow_demo/snow_demo.tscn`.
3. Espera a que Godot importe los archivos. Abre `moe_snow_demo/snow_demo.tscn`.
4. Pulsa **F6** (ejecutar escena actual).

No necesitas montar nodos, configurar entradas ni instalar complementos.
No copies esta carpeta dentro de otra carpeta llamada moe_snow_demo.
La escena construye el nivel al ejecutarse; el árbol de edición muestra un nodo
raíz. Para inspeccionar sus nodos durante la ejecución usa el árbol Remoto.

**Para usar F5:** en el panel Sistema de archivos de Godot, haz clic derecho
sobre `snow_demo.tscn` y selecciona la opción para establecerla como escena
principal. La ruta exacta es `res://moe_snow_demo/snow_demo.tscn`.
Esto sustituye la referencia antigua a `level_01.tscn` como escena principal.
Este paquete no modifica referencias que puedas tener en otros scripts antiguos.

## Controles

| Acción | Tecla |
|---|---|
| Caminar | A/D o flechas izquierda/derecha |
| Saltar | Espacio, W o flecha arriba |
| Salto corto | Soltar la tecla antes |
| Dash | Shift, recarga de 0,8 s |
| Volver al último refugio | R |
| Ver estados y vectores de IA | F3 |
| Silenciar/restaurar música | M |
| Pausa | Esc |
| Reiniciar tras ganar | R |

## Objetivo

Recoge **las tres runas turquesas** y llega al santuario del extremo derecho.
Los **ecos dorados** son opcionales y están principalmente en plataformas altas.
Las lámparas activan refugios. Caer o tocar un guardián te devuelve al último
refugio, conservando los coleccionables durante esta partida.
No hay guardado persistente al cerrar el juego.

Mantener el salto permite cruzar todos los huecos de la ruta principal sin dash.
El dash facilita esquivar guardianes y da inmunidad al contacto mientras dura.
Saltar sobre un guardián mientras caes lo aturde durante 3,5 segundos.
La primera zona es segura para practicar. Hay seis guardianes más adelante.

## Seeking + wandering

Implementación en `scripts/guardian.gd`, con cuatro estados:

- **WANDER:** proyecta un círculo delante de la dirección de movimiento y
  desplaza un objetivo sobre ese círculo mediante pequeñas variaciones aleatorias
  del ángulo. Acota el objetivo a la zona de patrulla y aplica steering.
- **SEEK:** detecta al jugador a 210 unidades con línea de visión libre.
  Calcula velocidad deseada hacia el jugador y una aceleración limitada basada
  en la diferencia respecto de su velocidad actual.
- **RETURN:** vuelve al origen tras perder de vista al jugador durante 0,8 s,
  superar el radio de pérdida de 310 o alejarse más de 370 del origen.
  Reduce la velocidad al aproximarse a casa y vuelve a WANDER.
- **STUNNED:** queda aturdido temporalmente al recibir un salto encima.

Fórmulas de referencia:

`velocidad_deseada = normalizar(objetivo - posición) * rapidez`

`aceleración = limitar((velocidad_deseada - velocidad) / 0,25, aceleración_máxima)`

`velocidad = limitar(velocidad + aceleración * delta, rapidez)`

Los guardianes flotan: ambos algoritmos operan en dos dimensiones, sin requerir
saltos ni navegación terrestre. Colisionan con el terreno y usan un rayo para la
visión. No implementan búsqueda de caminos A* ni evitación avanzada de obstáculos;
una geometría muy cerrada puede bloquear su regreso. El nivel usa espacios abiertos.
Este es un sistema de steering con estados, no un clasificador de aprendizaje
automático. KNN, telemetría y gravedad adaptativa quedan para otra iteración.

## Editar

- `scripts/level.gd`: rectángulos PLATFORMS, CHECKPOINTS, RUNES, posiciones de
  guardianes, interfaz, objetivo, reaparición y decoración.
- `scripts/player.gd`: velocidad, gravedad, salto, dash y animaciones del panda.
- `scripts/guardian.gd`: radios, rapidez, fuerza y transición de estados.
- `scripts/backdrop.gd`: montañas, paralaje y nieve.

Terreno: tiles de 16 × 16 renderizados a 32 × 32 unidades.
Resolución lógica: 800 × 450 con bandas para conservar proporciones.
El paquete configura sus acciones `moe_*` en ejecución y no reemplaza tu Input Map.
La geometría está definida en código para facilitar la instalación. No es todavía
un mapa pintable con TileMapLayer. Tus escenas y scripts existentes permanecen aparte.

## Créditos

- Terreno: RottingPixels, Four Seasons Platformer Tileset. Archivo original de
  atribución en `art/ROTTING_PIXELS.txt`. El pack Brackeys aportado por el usuario
  identifica el mismo tileset y declara sus assets CC0.
- Música: Sofia Thirslund / Brackeys. Sonidos: Asbjørn Thirslund / Brackeys.
  Licencia y créditos originales incluidos en `art/BRACKEYS_LICENSE.txt`.
- Panda: sprite sheet proporcionado por el usuario. No se proporcionó licencia
  ni autoría; completar la atribución y comprobar permiso antes de distribución pública.
- Guardianes, montañas, pinos, santuario e interfaz: geometría dibujada por código.

## Validación

Preparado para proyectos Godot 4.x con renderer Compatibility.
Probado con Godot 4.5.1 en Linux; no se ejecutó en Godot 4.7.2 ni en Windows.
Se revisaron capturas reales del inicio y de una zona con guardianes usando
Compatibility / OpenGL. Las capturas se generaron con un controlador de audio
Dummy: el cierre de esa ejecución mostró advertencias de recursos de audio.
La ejecución headless desactiva audio para las comprobaciones automáticas.
Las pruebas automatizadas verifican inicio en suelo, wandering, activación y
movimiento de seeking, regreso, aturdimiento, recorrido principal sin dash,
recolección de runas, ambos checkpoints, reaparición, conservación de runas,
inmunidad y dash. El recorrido de geometría suspende enemigos para aislar los saltos;
no constituye una evaluación de dificultad de los seis combates simultáneamente.

Este ZIP solo incluye la carpeta adicional. No contiene `.godot`, ejecutables,
ni una copia de `project.godot` que sobrescriba la configuración del proyecto.
