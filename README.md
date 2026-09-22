<div align="center">

# 🏔️ Mountain of Echoes

**Asciende. Observa. Aprende a escuchar la montaña.**

Un plataformas 2D ambientado en una montaña nevada, con guardianes que exploran y persiguen al jugador.

![Godot](https://img.shields.io/badge/Godot-4.x-478CBF?logo=godotengine&logoColor=white)
![Lenguaje](https://img.shields.io/badge/Lenguaje-GDScript-74c7ec)
![Estado](https://img.shields.io/badge/Estado-Prototipo_jugable-f9c74f)
![Metodología](https://img.shields.io/badge/Metodolog%C3%ADa-SUM-94e2d5)

[El juego](#-el-juego) · [Ejecutar](#-ejecutar-el-proyecto) · [Controles](#-controles) · [Desarrollo](#-desarrollo-y-organización) · [Roadmap](#-roadmap)

</div>

---

## 🌨️ El juego

La idea de **Mountain of Echoes** parte de un viaje hacia la cima para devolver la lluvia a unas tierras que la han perdido. En el camino, el jugador atraviesa escenarios nevados y se enfrenta a los espíritus que custodian la montaña.

La visión del proyecto es que la montaña responda a la forma de jugar: reconocer patrones de movimiento y convertirlos en cambios controlados del entorno.

**El prototipo actual se centra en la base jugable:** recorrer un nivel, esquivar guardianes, recuperar runas y alcanzar el santuario. La clasificación con KNN y la gravedad adaptativa forman parte del trabajo pendiente.

## 🎮 Qué puedes jugar ahora

- **Movimiento del personaje:** desplazamiento lateral, salto de altura variable y dash con recarga.
- **Salto más tolerante:** un pequeño margen para saltar al abandonar una plataforma y un buffer para registrar la pulsación antes de aterrizar.
- **Un nivel nevado:** plataformas, huecos, decoración y fondo con movimiento de paralaje.
- **Guardianes flotantes:** combinan wandering y seeking con estados de regreso y aturdimiento.
- **Refugios:** funcionan como checkpoints para retomar el recorrido después de caer o recibir daño.
- **Runas y ecos:** las runas son obligatorias para activar la meta; los ecos son coleccionables opcionales.
- **Santuario final:** completa el nivel al llegar con todas las runas.
- **Interfaz y audio:** indicadores de progreso, tiempo, mensajes, música y efectos.
- **Nivel editable:** terreno pintable y escenas reutilizables para personajes, enemigos y objetos.

> Los coleccionables se conservan al reaparecer durante la partida. Todavía no hay guardado persistente al cerrar el juego.

## 🧠 Comportamiento de los guardianes

Los enemigos utilizan **steering y una máquina de estados**. Su comportamiento actual no depende de un modelo entrenado.

| Estado | Comportamiento |
|---|---|
| **WANDER** | Explora su zona mediante un objetivo que cambia suavemente sobre un círculo proyectado delante de su movimiento. |
| **SEEK** | Acelera hacia el jugador cuando lo detecta y tiene línea de visión. |
| **RETURN** | Regresa a su origen al perder al jugador o alejarse demasiado de su zona. |
| **STUNNED** | Permanece aturdido temporalmente cuando el jugador cae sobre él. |

Seeking calcula una velocidad deseada hacia el objetivo y ajusta la velocidad actual mediante una aceleración limitada. Wandering cambia el objetivo para producir exploración sin una ruta fija.

Pulsa **F3** durante la partida para visualizar estados, radios de detección y vectores de velocidad.

Los guardianes colisionan con el terreno, pero **no implementan búsqueda de caminos**. Al diseñar nuevas zonas, necesitan espacio para patrullar y regresar.

## 🚀 Ejecutar el proyecto

### Desde Godot

El entorno utilizado por el equipo en este prototipo es **Godot 4.7.2**, edición estándar con GDScript y renderer **Compatibility**. Usa la misma versión que el equipo y el workflow de CI para evitar diferencias de importación.

1. Clona el repositorio con una cuenta que tenga acceso:

   ```bash
   git clone https://github.com/jperezh04/mountain-of-echoes.git
   cd mountain-of-echoes
   ```

2. En el gestor de proyectos de Godot, pulsa **Importar** y selecciona `project.godot`.
3. Espera a que termine la importación de los recursos.
4. Abre `moe_editable/snow_level.tscn`.
5. Pulsa **F6** para ejecutar esa escena.

**F5** ejecuta la escena principal del proyecto. Para que abra este nivel, establece `moe_editable/snow_level.tscn` como escena principal desde el panel de archivos.

> Si no aparece `moe_editable`, comprueba que estás en la rama que contiene el nivel editable. Durante el desarrollo, algunas funcionalidades pueden estar todavía en una rama de trabajo y no en `main`.

### Desde una compilación para Windows

Cuando haya una compilación publicada, estará disponible en [Releases](https://github.com/jperezh04/mountain-of-echoes/releases).

Descarga la versión para Windows, descomprime el paquete si corresponde y ejecuta `MountainOfEchoes.exe`. Si la distribución incluye un archivo `.pck` o bibliotecas adicionales, conserva los archivos juntos.

## ⌨️ Controles

| Acción | Tecla |
|---|---|
| Moverse | **A / D** o **← / →** |
| Saltar | **Espacio**, **W** o **↑** |
| Realizar un salto corto | Soltar antes la tecla de salto |
| Dash | **Shift** |
| Volver al último refugio | **R** |
| Mostrar u ocultar la depuración de IA | **F3** |
| Silenciar o restaurar la música | **M** |
| Pausar o continuar | **Esc** |
| Reiniciar después de completar el nivel | **R** |

## 🛠️ Modificar el nivel

Abre `moe_editable/snow_level.tscn` en la vista **2D**. Realiza los cambios con el juego detenido, desde el árbol **Local**.

| Nodo | Edición |
|---|---|
| `Ground` | Pintar y borrar tiles. Los tiles configurados incluyen colisión. |
| `Player` | Cambiar el punto inicial y ajustar parámetros de movimiento. |
| `Guardians` | Mover, duplicar o eliminar guardianes y ajustar su comportamiento. |
| `Objects` | Distribuir runas, ecos, refugios y el santuario. |
| `Decoration` | Mover, escalar y duplicar árboles. |
| `HUD` | Modificar los elementos de la interfaz. |

**Ctrl+D** duplica el objeto seleccionado y **Ctrl+S** guarda la escena. Las escenas de `moe_editable/prefabs/` también se pueden arrastrar al nivel para crear instancias.

El objetivo cuenta las runas presentes en la escena al iniciar: si añades una runa, también será necesaria para completar el nivel. La posición de cada guardián define su origen de patrulla.

Para ampliar el mapa, revisa también los límites de `Player/Camera2D` y el límite de caída del nivel. Conserva un solo nodo `Player` en la raíz.

La guía detallada del paquete está en `moe_editable/EMPIEZA_AQUI.md`.

## 📁 Archivos principales

| Ruta | Propósito |
|---|---|
| `project.godot` | Configuración del proyecto. |
| `moe_editable/snow_level.tscn` | Distribución del nivel editable. |
| `moe_editable/prefabs/` | Escenas reutilizables de jugador, guardián, objetos y árboles. |
| `moe_editable/scripts/` | Movimiento, IA, interacciones, controlador del nivel y fondo. |
| `moe_editable/art/` | Texturas, TileSet y créditos de los packs. |
| `moe_editable/audio/` | Música y efectos de sonido. |
| `.github/workflows/` | Automatizaciones de integración continua. |
| `export_presets.cfg` | Ajustes de exportación compartidos. |

Las carpetas de prototipos anteriores pueden coexistir durante la transición al nivel editable.

## 🤝 Desarrollo y organización

El proyecto utiliza **SUM** como metodología de trabajo y **GitHub Projects** para organizar actividades, responsables e iteraciones.

El tablero separa el avance de cada tarea mediante los estados **Product Backlog**, **Por hacer**, **En progreso**, **En Prueba** y **Hecho**. Los campos de prioridad, estimación, iteración, disciplina, fase SUM y requisito permiten relacionar el trabajo con la planificación.

El tablero apoya la metodología; su aplicación también requiere acordar objetivos, revisar resultados, registrar riesgos y ajustar el trabajo con base en las pruebas.

### Flujo de contribución

1. Seleccionar una issue y revisar su alcance y criterios de aceptación.
2. Trabajar en una rama relacionada con la tarea, por ejemplo `feature/guardian-behavior`.
3. Implementar y probar el cambio en Godot.
4. Abrir un pull request hacia `main`, enlazando la issue correspondiente.
5. Revisar el resultado y los checks de GitHub Actions antes de integrar.
6. Actualizar la tarea en el tablero con la evidencia de lo realizado.

Las comprobaciones automáticas de CI complementan las pruebas manuales. Un check correcto no garantiza por sí solo que el nivel sea divertido, que un salto sea cómodo o que la dificultad esté equilibrada.

### Criterios para dar una tarea por terminada

- Cumple los criterios de aceptación de la issue.
- Se probó el comportamiento afectado y se registró el resultado.
- No introduce errores de scripts ni referencias a recursos inexistentes.
- Los checks requeridos del pull request están correctos.
- La documentación y los créditos se actualizan cuando corresponde.

## 📦 Builds y archivos del repositorio

El código, las escenas, los assets necesarios y la configuración de exportación forman parte del proyecto versionado.

Las nuevas compilaciones para jugar se distribuirán mediante **Releases**. Exporta fuera de la carpeta del proyecto o en una carpeta ignorada, y evita añadir los `.exe` y `.pck` generados en nuevos commits.

La carpeta `.godot/` contiene cachés y datos locales que el editor regenera; debe permanecer ignorada.

## 🧭 Roadmap

| Etapa | Alcance | Estado |
|---|---|---|
| Base de movimiento | Desplazamiento, salto y dash | Disponible en el prototipo |
| Guardianes | Wandering, seeking, regreso y aturdimiento | Disponible en el prototipo |
| Recorrido inicial | Plataformas, refugios, runas y santuario | Disponible en el prototipo |
| Edición visual | TileMapLayer y escenas reutilizables | Disponible en el paquete editable |
| Pulido del nivel | Balance, feedback visual, audio y coherencia artística | Por iterar |
| Sombra | Comportamiento vinculado al recorrido del jugador | Planificado |
| Telemetría | Registrar acciones y resumirlas en ventanas de observación | Planificado |
| Clasificación KNN | Reconocer patrones de comportamiento con datos etiquetados | Planificado |
| Gravedad adaptativa | Aplicar cambios graduales según el comportamiento detectado | Planificado |
| Nuevos niveles | Ampliar la progresión y la variedad de desafíos | Planificado |

Antes de integrar KNN en la partida, se definirán las variables observadas, las clases de comportamiento, el conjunto de datos y los criterios de evaluación. Los cambios de gravedad deberán tener límites y señales claras para el jugador.

## 🎨 Créditos y licencias

| Recurso | Procedencia |
|---|---|
| Terreno Four Seasons | RottingPixels |
| Pack de recursos y efectos | Brackeys; sonidos de Asbjørn Thirslund |
| Música | Sofia Thirslund / Brackeys |
| Sprite del panda rojo | Recurso aportado al proyecto; autoría y licencia pendientes de confirmar |
| Guardianes, pinos e interfaz del prototipo | Geometría y elementos construidos para esta implementación |

Los créditos y condiciones suministrados con los packs se conservan en `moe_editable/art/BRACKEYS_LICENSE.txt` y `moe_editable/art/ROTTING_PIXELS.txt`. El pack de Brackeys declara sus assets bajo **CC0**; esa declaración no debe extenderse automáticamente a otros recursos.

No se declara una licencia general para el código en este README. La licencia de cada recurso externo debe respetarse de forma independiente.

---

<div align="center">

**Mountain of Echoes** · Un ascenso que estamos construyendo, probando y mejorando por iteraciones.

</div>
