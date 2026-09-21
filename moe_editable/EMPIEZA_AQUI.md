# Mountain of Echoes — nivel editable

## Instalar y abrir

1. Descomprime el ZIP y copia **moe_editable** junto a **project.godot**.
2. Abre Godot y espera la importación de recursos.
3. Abre **moe_editable/snow_level.tscn** y selecciona la pestaña **2D**.
4. Pulsa **F6** para jugar esta escena.

Es una versión independiente y completa: incluye assets y sonidos normalizados.
No requiere instalar primero la demo ni los parches anteriores. No reemplaza
`project.godot` ni los archivos de `moe_snow_demo`.
Para que F5 abra esta versión, clic derecho en `snow_level.tscn` → establecer
como escena principal. Usa exactamente `res://moe_editable/snow_level.tscn`.

El nivel está guardado en la escena. No debes ejecutar ningún generador.
Tienes nodos reales visibles antes de pulsar Play, no solamente una previsualización.

## Tu primera edición

1. Despliega **Guardians** en el árbol de la izquierda.
2. Selecciona **Guardian01**, pulsa **F** para centrar la vista y arrástralo
   a otra posición con la herramienta de mover.
3. En el Inspector cambia **Max Speed** (por ejemplo, de 165 a 120).
4. **Ctrl+D** duplica el guardián seleccionado; mueve la copia a otro lugar.
5. Guarda con **Ctrl+S** y prueba con **F6**.

Haz los cambios con el juego detenido y en el árbol **Local**. Los cambios del
árbol Remoto corresponden a la partida que se está ejecutando.

## Qué editar

| Nodo | Qué puedes hacer |
|---|---|
| Ground | Pintar y borrar suelo mediante TileMapLayer |
| Player | Mover el punto inicial; ajustar velocidad, salto, gravedad y dash |
| Player/Camera2D | Ajustar límites de cámara; habilita Hijos editables en la instancia si es necesario |
| Guardians | Mover, duplicar o borrar cada guardián |
| Objects/Rune… | Mover, duplicar o borrar runas |
| Objects/Echo… | Mover, duplicar o borrar ecos opcionales |
| Objects/Refuge… | Mover o duplicar los checkpoints |
| Objects/Sanctuary | Mover la meta |
| Decoration/Pine… | Mover, escalar, duplicar y borrar pinos |
| HUD | Modificar los nodos Label y Panel de la interfaz |
| SnowLevel | Cambiar el título del nivel y el límite inferior de caída |

### Pintar y borrar terreno

Selecciona **Ground**. En el panel inferior **TileMap**, selecciona el atlas y
un tile de nieve (fila superior) o roca (fila inferior). Pinta con el botón
izquierdo; usa el borrador o el botón derecho para borrar.

La cuadrícula es de **16 × 16 unidades**. Los cuatro tiles habilitados tienen
colisión sólida incluida: la colisión aparece y desaparece con cada celda.
No necesitas colocar un StaticBody2D por bloque. Para crear un hueco profundo,
borra también las celdas de roca que quedan debajo de la superficie.

Los cuatro tiles están en las columnas 7 y 8, filas 0 y 1 del atlas (índices
desde cero). El atlas no habilita todos los dibujos del PNG para pintarlos.
Puedes añadir otros tiles y definir sus colisiones desde el editor TileSet.
El pintado es manual; esta versión no incluye autotiling de terrenos.

### Mover y añadir objetos

Los archivos de **moe_editable/prefabs/** son escenas reutilizables:

- `player.tscn`: panda, animaciones, colisión y cámara.
- `guardian.tscn`: enemigo con wandering, seeking, regreso y aturdimiento.
- `rune.tscn`: coleccionable obligatorio.
- `echo.tscn`: coleccionable opcional.
- `checkpoint.tscn`: refugio.
- `exit.tscn`: santuario final.
- `pine.tscn`: árbol decorativo sin colisión.

Arrastra un prefab desde Sistema de archivos a la vista 2D, o duplica una
instancia existente con Ctrl+D. Mantén **un solo Player** y conserva ese nombre
en la raíz. Coloca la base del jugador y de los checkpoints sobre el suelo.
El origen del santuario también representa su base.

El controlador descubre todos los guardianes y objetos de la escena al iniciar,
aunque estén dentro de carpetas Node2D. Cuenta automáticamente las runas: si
añades una cuarta, tendrás que recoger cuatro para ganar. Los ecos son opcionales.
El jugador reaparece en el último refugio activado, conservando coleccionables
durante la partida. No existe guardado persistente al cerrar el juego.

### Configurar guardianes

Selecciona la raíz de una instancia del guardián. Propiedades del Inspector:

| Campo | Función |
|---|---|
| Detect Radius | Distancia para empezar a perseguir; predeterminado 210 |
| Lose Radius | Radio de pérdida del objetivo; predeterminado 310 |
| Max Speed | Rapidez máxima de persecución; predeterminado 165 |
| Max Acceleration | Límite de la aceleración de steering; predeterminado 360 |
| Home Leash | Distancia máxima desde su origen antes de regresar; 370 |
| Patrol Half Size | Semiancho y semialto del área de wandering |
| Show Detection In Editor | Muestra el círculo de detección en la vista 2D |

Deja Lose Radius mayor que Detect Radius para evitar cambios constantes de estado.
La posición que asignes al guardián será su origen de patrulla. Son guardianes
flotantes: usa zonas abiertas, sin encerrarlos dentro de bloques. Seeking no es
búsqueda de caminos; una pared compleja puede impedir que alcancen su objetivo.
En juego, F3 muestra estados y vectores. Caer sobre ellos los aturde.

### Cámara, fondo e interfaz

Si amplías el mapa más allá de x=4320, aumenta el límite derecho de
**Player/Camera2D**. Para modificar nodos internos de una instancia, clic derecho
sobre Player → **Hijos editables**. Cambiar un prefab abierto por separado afecta
a todas sus instancias que no tengan esa propiedad sobrescrita.

HUD y Backdrop se guardan ocultos para que no tapen el mapa durante la edición.
Puedes activar su visibilidad desde el árbol. El controlador los muestra al jugar.
Los textos de estadísticas, objetivo, mensajes y victoria se actualizan al jugar;
para cambiar el nombre de la zona, usa **Level Title** en SnowLevel.
El fondo de montañas, paralaje y nieve sigue dibujándose mediante `backdrop.gd`;
no es terreno ni un conjunto de montañas editables por separado. Los pinos sí son
instancias editables. El layout utiliza una resolución lógica de 800 × 450.

## Controles

A/D o flechas: mover · Espacio/W/↑: saltar · Shift: dash · R: volver al refugio
F3: depuración de IA · M: música · Esc: pausa · R al ganar: reiniciar

## Estructura y alcance

La distribución está en `snow_level.tscn`; ya no depende de listas de coordenadas
en el controlador. El controlador conecta los nodos guardados y gestiona objetivos,
reaparición, interfaz e input. No reconstruye ni sobrescribe tus tiles al jugar.
El TileSet compartido se guarda en `art/snow_tileset.tres`.

Esta entrega conserva la lógica del prototipo, no añade todavía KNN, telemetría,
gravedad adaptativa, navegación A* ni guardado de partidas.

## Créditos

Terreno: RottingPixels. Sonidos y música: Brackeys / Asbjørn y Sofia Thirslund.
Las licencias y atribuciones suministradas con los packs están en `art/`.
La música se convirtió a OGG y los sonidos se normalizaron a PCM de 16 bits.
Panda: sprite sheet suministrado por el usuario; pendiente confirmar autoría
y licencia antes de distribuir públicamente. Guardianes, pinos y santuario
están construidos con geometría 2D.

## Validación

24 comprobaciones automáticas en Godot 4.5.1 / Linux: nodos serializados, tiles
con colisión, animaciones, wandering, seeking, pérdida del objetivo, aturdimiento,
recorrido principal con triggers, checkpoints, reaparición, inmunidad y dash.
Se modificó, guardó y volvió a cargar una escena de prueba para comprobar posición
del jugador y guardián, velocidad del enemigo, posición del checkpoint, nueva runa,
borrado de tiles y colisión de una celda pintada. Todas pasaron.
La prueba de recorrido suspende a los enemigos para aislar geometría y triggers;
no equivale a una evaluación humana de toda la dificultad del combate.
No ejecutado en Windows ni en Godot 4.7.2: prueba allí con F6 antes del commit.

Referencias de las APIs utilizadas:
https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
https://docs.godotengine.org/en/stable/classes/class_packedscene.html
