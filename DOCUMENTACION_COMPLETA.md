# Documentación Completa — Mountain of Echoes & The Catcade Easter Egg

Este documento reúne tanto la **arquitectura y funcionamiento completo de la aplicación** (*Mountain of Echoes*) como la **bitácora detallada de todos los cambios, sistemas e interfaces implementados hoy**.

---

## 1. Visión General de la Aplicación

**Mountain of Echoes** es un videojuego de plataformas 2D de precisión y exploración ambientado en una cordillera nevada mística, desarrollado en **Godot Engine 4.7.2** con **GDScript 2.0**.

El jugador controla al **Guardián de la Cordillera** (*Panda del Eco*, o su variante desbloqueable *Red Nyanko Ranger*) en su ascenso a través de ruinas heladas para recolectar **Runas** y **Ecos**, superar a los **Guardianes corruptos** y escapar de la **Sombra del Eco**, mientras la montaña adapta dinámicamente su física según el estilo de juego detectado por telemetría. Además, esconde una máquina recreativa secreta que permite jugar **THE BATTLE CAT-A-PULT**, un minijuego balístico completo de 3 niveles.

### Especificaciones Técnicas
| Parámetro | Configuración |
| :--- | :--- |
| **Motor** | Godot Engine 4.7.2 (`GL Compatibility`) |
| **Lenguaje** | GDScript 2.0 con tipado estático |
| **Escena Principal de Entrada** | `res://moe_editable/ui/main_menu.tscn` |
| **Escena del Juego Principal** | `res://moe_editable/snow_level.tscn` |
| **Escena del Minijuego Arcade** | `res://moe_editable/minigames/catcade/catcade.tscn` |
| **Resolución Dinámica** | `1280×720` (Menú Principal / Selección de Niveles), `800×450` (Nivel Principal), `640×360` (Minijuego Cat-A-Pult) |
| **Ejecutable Exportado** | `MountainOfEchoes.exe` |

---

## 2. Arquitectura General del Sistema

### Estructura de Directorios Relevante
```text
mountain-of-echoes/
├── project.godot                     # Configuración general y escena inicial (main_menu.tscn)
├── export_presets.cfg                # Configuración de exportación Windows (MountainOfEchoes.exe)
├── Arpa de Abel.mp3                  # Tema musical principal del menú (en bucle)
└── moe_editable/
    ├── snow_level.tscn               # Escena del nivel principal (3 zonas, refugios, arcade)
    ├── art/                          # Sprites del jugador, tileset nevado y skin Nyanko Ranger
    ├── audio/                        # Efectos de sonido y música ambiental del nivel
    ├── prefabs/                      # Prefabs: player, guardian, shadow, rune, echo, checkpoint, exit, arcade_machine
    ├── scripts/
    │   ├── level.gd                  # Orquestador del nivel principal, HUD compacto y flujo de zonas
    │   ├── player.gd                 # Controlador de movimiento, físicas, dash, stomp y skins
    │   ├── guardian.gd               # IA de enemigos patrulleros (WANDER, SEEK, STUNNED)
    │   ├── echo_shadow.gd            # IA del perseguidor temporal (Sombra del Eco)
    │   ├── telemetry.gd              # Sistema de telemetría y adaptación climática/gravitatoria
    │   ├── item.gd                   # Lógica de activación de runas, ecos, refugios y santuario
    │   ├── backdrop.gd               # Fondo parallax procedural con partículas de nieve
    │   └── arcade_machine.gd         # Máquina recreativa interactiva que lanza Cat-A-Pult
    ├── ui/
    │   ├── main_menu.tscn            # Escena de Pantalla Principal y Selección de Niveles
    │   ├── main_menu.gd              # Construcción e interacción completa de la UI principal
    │   ├── art/                      # Fondos y miniaturas extraídas de Stitch
    │   └── fonts/                    # Fuentes Cinzel Decorative, Cinzel y Space Grotesk
    └── minigames/
        └── catcade/
            ├── catcade.tscn          # Escena principal del minijuego Cat-A-Pult
            ├── assets/               # Sprites de gatos, enemigos BCU, bloques y efectos
            ├── prefabs/              # Slingshot, CatProjectile, DestructibleBlock, AnimalEnemy
            ├── scenes/levels/        # Los 3 niveles jugables (level_01, level_02, level_03)
            └── scripts/              # Lógica del tirachinas, trayectoria, proyectiles y niveles
```

---

## 3. Sistemas del Juego Principal (*Mountain of Echoes*)

### 3.1. Controlador del Jugador (`moe_editable/scripts/player.gd`)
- **Movimiento y Salto de Precisión**:
  - Velocidad base de `260 px/s`, gravedad de `1200 px/s²` y salto variable (cortar el salto al soltar `ESPACIO` multiplica la velocidad vertical por `0.52`).
  - **Coyote Time** (`0.11 s`): Permite saltar brevemente tras abandonar una cornisa.
  - **Jump Buffering** (`0.12 s`): Ejecuta el salto automáticamente si se presiona justo antes de tocar el suelo.
- **Dash con Estela Fantasma (*Ghost Trail*)**:
  - Impulso horizontal a `620 px/s` durante `0.15 s` con recarga de `0.8 s`, generando siluetas translúcidas (`_spawn_ghost()`).
- **Combate por Pisotón (*Stomp*)**:
  - Caer sobre un Guardián lo aturde y propulsa al jugador hacia arriba (`jump_speed * 0.82`).
- **Sistema de Skins Persistente**:
  - Permite alternar entre el **Panda del Eco** (`apply_panda_skin()`) y el **Red Nyanko Ranger** (`apply_cat_skin()`), conservando la elección entre escenas mediante variables estáticas (`cat_skin_unlocked`, `start_checkpoint_index`, `saved_runes`, `saved_echoes`).

### 3.2. IA de los Guardianes (`moe_editable/scripts/guardian.gd`)
Cada guardián opera bajo una máquina de estados finitos:
1. **`WANDER`**: Patrulla horizontalmente dentro de su radio asignado.
2. **`SEEK`**: Si el jugador entra en el rango de detección, persigue su posición con aceleración incrementada.
3. **`STUNNED`**: Permanece inmovilizado temporalmente tras recibir un pisotón del jugador.
- Con la tecla `F3` se activa la visualización de depuración (vectores de velocidad, radio de visión y estado actual).

### 3.3. La Sombra del Eco (`moe_editable/scripts/echo_shadow.gd`)
- Se activa al cruzar el segundo tramo de la montaña (`x > 1750`) y se retira al llegar al santuario (`x > 3850`).
- Registra en una cola circular la posición del jugador en cada fotograma físico y la reproduce con un retraso de **`2.2 segundos`**, obligando al jugador a mantenerse en movimiento sin volver sobre sus propios pasos.

### 3.4. Telemetría y Adaptación Dinámica (`moe_editable/scripts/telemetry.gd`)
- Analiza en tiempo real las acciones del jugador (frecuencia de saltos, uso de dash, muertes y tiempo de ascenso) y clasifica su perfil en:
  - **VELOZ / AGRESIVO** -> Activa *Viento Gélido* (mayor intensidad visual de viento y gravedad ligeramente más pesada `1.08x`).
  - **CAUTELOSO / PERSISTENTE** -> Activa *Aliento Sereno* (gravedad más ligera `0.92x` para facilitar saltos largos).
  - **EQUILIBRADO** -> Mantiene gravedad estándar (`1.0x`).

### 3.5. Etapas del Nivel Principal (`moe_editable/scripts/level.gd`)
El mapa continuo de la cordillera se divide en 3 etapas seleccionables desde el menú:
1. **Etapa 01 • El Paso de los Guardianes** (`Spawn: Vector2(100, 384)`): Tramo inicial con plataformas escalonadas, primeros guardianes y la máquina arcade secreta.
2. **Etapa 02 • Valle de la Sombra del Eco** (`Spawn: Vector2(1410, 320)`): Tramo intermedio de alta precisión donde despierta la Sombra del Eco.
3. **Etapa 03 • El Santuario de la Cumbre** (`Spawn: Vector2(2620, 304)`): Ascenso vertical final hacia el monolito del Santuario (`x = 4150`).

---

## 4. Subsistema Arcade: *THE BATTLE CAT-A-PULT* (`Catcade`)

Ubicado en `moe_editable/minigames/catcade/`, combina la física balística de *Angry Birds* con la estética absurda de *The Battle Cats*.

### Componentes del Minijuego
- **Gestor Principal (`catcade_manager.gd`)**:
  - Controla la cola de gatos, el puntaje, la transición entre los **3 niveles** (`level_01.tscn`, `level_02.tscn`, `level_03.tscn`), el temblor de cámara (*screen shake*) y la pantalla de victoria/derrota.
- **Tirachinas y Predictor de Trayectoria (`slingshot.gd` y `trajectory_predictor.gd`)**:
  - Permite estirar al gato con el ratón, dibuja las bandas elásticas en tiempo real y proyecta la parábola balística exacta considerando la gravedad del motor.
- **Proyectiles Felinos (`cat_projectile.gd`)**:
  - **Gato Normal**: Equilibrado, expresiones dinámicas (reposo, estiramiento, vuelo, impacto y victoria).
  - **Gato Tanque (*Heavy Cat*)**: Mayor masa e inercia para demoler estructuras de piedra.
  - **Gato Cohete (*Rocket Cat*)**: Al hacer clic o presionar `ESPACIO` en pleno vuelo, multiplica su velocidad hacia el objetivo con partículas de propulsión.
- **Estructuras y Enemigos (`destructible.gd` y `animal_enemy.gd`)**:
  - Bloques de **Hielo**, **Madera** y **Piedra** con daño progresivo basado en el impulso de impacto.
  - Enemigos animales (Perros, Serpientes, Patos y Jefes Jabalí) que son derrotados por impacto directo, caída de escombros o fuera de límites.

---

## 5. Bitácora de Todos los Cambios Realizados Hoy

### 5.1. Pantalla de Título y Selección de Niveles (Stitch UI + *Arpa de Abel*)
- **Creación de `moe_editable/ui/main_menu.tscn` y `moe_editable/ui/main_menu.gd`**:
  - Se recrearon fielmente las dos pantallas diseñadas en Stitch (`stitch_mountain_of_echoes_hud (1)` para el menú principal y `stitch_mountain_of_echoes_hud` para la selección de niveles).
  - Se extrajeron e importaron las 5 ilustraciones de Stitch en `moe_editable/ui/art/` (`bg_title.png`, `bg_level_select.png`, `thumb_level01.png`, `thumb_level02.png`, `thumb_catapult.png`) y las fuentes tipográficas en `moe_editable/ui/fonts/` (`CinzelDecorative-Bold.ttf`, `Cinzel.ttf`, `SpaceGrotesk.ttf`).
  - **Música Principal**: Se integró `Arpa de Abel.mp3` con reproducción en bucle (`loop=true`) y píldora superior interactiva para silenciar o reactivar la música.
  - **Botones 100% Funcionales**:
    - `NUEVO JUEGO`: Inicia la partida en la Zona 01.
    - `SELECCIÓN DE NIVELES`: Abre el mapa de constelación **El Sendero de la Montaña** con tarjetas para iniciar directamente en cualquiera de las 3 etapas o en el minijuego *The Battle Cat-A-Pult*.
    - `CAT-A-PULT ARCADE`: Lanza el minijuego directamente desde el menú principal.
    - `AJUSTES & SONIDO`: Abre el modal de configuración (control deslizable de volumen maestro, música, cambio de skin, pantalla completa y guía de controles).
    - `SALIR AL ESCRITORIO [ESC]`: Cierra la aplicación limpiamente.
    - `Tarjeta de Perfil y Skin`: Permite cambiar con un clic entre *Panda del Eco* y *Red Nyanko Ranger*.

### 5.2. Mejoras en el HUD dentro del Juego y Eliminación de Textos Invasivos
- **Botón `← MENÚ` en Partida (`snow_level.tscn` y `level.gd`)**:
  - Se agregó un botón interactivo en la esquina superior derecha del HUD durante la partida para regresar al menú principal en cualquier momento con un clic, sin bloquear el salto (`focus_mode = FOCUS_NONE`) y sin generar dependencias cíclicas.
- **Eliminación de la Guía de Botones en Partida**:
  - Se ocultaron `HUD/BottomPanel` y `HUD/Controls` al iniciar el juego para dejar limpia la parte inferior de la pantalla.
- **Contador Superior Compacto (`x1`, `x3`) sin Revelar Totales**:
  - Se redujo el panel superior a una píldora discreta en la esquina superior izquierda (`190×30 px`) que muestra **`◆ Runas x0   ✦ Ecos x0`** (`x1`, `x3`, etc.) sin revelar cuántas runas o ecos existen en total en el mapa.
- **Eliminación de Mensajes de Ventisca / Clima**:
  - Se eliminaron los avisos flotantes automáticos de clima/ventisca en `telemetry.gd` y `level.gd` para que no interrumpan la partida.

### 5.3. Corrección y Pulido Completo del Minijuego *Cat-A-Pult*
- **Input del Tirachinas Independiente de Hardware (`slingshot.gd`)**:
  - Se reemplazó `get_global_mouse_position()` por `to_global(make_input_local(event).position)` y se eliminó la cancelación por `Input.is_mouse_button_pressed()` en `_process`, garantizando que el arrastre y lanzamiento funcionen tanto con ratón real como en pruebas automatizadas (`--headless`).
- **Aislamiento de Colisiones (`cat_projectile.gd`)**:
  - Los proyectiles felinos usan la capa/máscara de colisión `16` (bit 5) para no chocar con el suelo invisible del nivel de nieve cuando el minijuego se abre desde la máquina arcade.
- **Integración de Assets BCU, 3 Niveles y Skin de Recompensa**:
  - Se integraron los sprites de `bcu-assets`, los 3 niveles basados en las capturas de referencia, la salida rápida con `Q` y el desbloqueo automático de la skin **Red Nyanko Ranger** al superar los 3 niveles.

---

## 6. Controles Rápidos de Referencia

| Contexto | Acción | Tecla / Control |
| :--- | :--- | :--- |
| **Nivel Principal** | Moverse | `A` / `D` o `←` / `→` |
| **Nivel Principal** | Saltar (altura variable) | `ESPACIO` / `W` / `↑` |
| **Nivel Principal** | Dash aéreo o terrestre | `SHIFT` |
| **Nivel Principal** | Entrar a la máquina arcade | `E` / `W` / `↑` (frente al gabinete) |
| **Nivel Principal** | Volver al Menú Principal | Clic en botón **`← MENÚ`** (arriba a la derecha) o `ESC` + `Q` |
| **Nivel Principal** | Reiniciar en último refugio | `R` |
| **Nivel Principal** | Silenciar música / Ver IA Debug | `M` / `F3` |
| **Cat-A-Pult Arcade** | Apuntar y lanzar gato | Arrastrar y soltar con clic izquierdo |
| **Cat-A-Pult Arcade** | Habilidad en vuelo (Gato Cohete) | Clic izquierdo o `ESPACIO` en el aire |
| **Cat-A-Pult Arcade** | Reiniciar nivel arcade / Salir | `R` / `Q` (o `ESC`) |
