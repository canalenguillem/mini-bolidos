# Roadmap — Mini Bólidos

Hito actual: **M10** (online; M8 y M9 validados). M7 queda con solo Android pendiente: se hará después del online

Regla: no empezar un hito hasta que el anterior pase `./tools/check.sh` y el humano haya validado lo que hay que probar jugando.

## M0 — Esqueleto
- [x] `project.godot` (Godot 4.7, 1280×720, canvas_items/expand, acciones del InputMap de GDD → Controles)
- [x] Estructura de carpetas de CLAUDE.md
- [x] Copiar `tools/check.sh` y `tools/load_all.gd` (desde la skill `godot-verificar`)
- [x] Instalar GUT en `addons/gut` y crear un test trivial que pase
- [x] Autoloads vacíos: `Events`, `GameState`, `SaveSystem`
- [x] `./tools/check.sh` en verde

## M1 — Un coche que se conduce bien
- [x] `DriveInput`, `CarController`, `PlayerController`
- [x] `CarData`, `CarStats` (+ tests), `SurfaceData`
- [x] `car.tscn` con la física de la skill `fisica-coche-arcade` (placeholder con `Polygon2D`)
- [x] `test_track.tscn`: un óvalo con paredes y zonas de asfalto, tierra y barro
- [x] Camera2D con suavizado y adelanto
- [x] Nitro funcionando
- [x] **Humano:** probar la sensación de conducción y ajustar `@export`

## M2 — Reglas de carrera
- [x] `track.gd` común: checkpoints generados desde `RacingLine`, `StartGrid`, `get_surface_at`
- [x] `LapTracker` (+ tests) y cálculo de posiciones (+ tests)
- [x] `RaceManager`: cuenta atrás → carrera → fin
- [x] HUD: vuelta X/3, posición, tiempo, barra de nitro
- [x] Reaparición (atasco, fuera del mapa, tecla R)
- [x] Pantalla de resultados

## M3 — Rivales IA
- [x] `AIController` según la skill `ia-rival`
- [x] 3 rivales con personalidades distintas
- [x] Detección de atasco y reaparición
- [x] Rubber banding suave
- [x] Modo carrera rápida jugable de principio a fin
- [x] **Humano:** ¿la IA es divertida? ¿demasiado fácil o difícil?

## M4 — Temas: Oeste y Jungla
- [x] TileSets con custom data `surface`
- [x] `west_01`, `west_02`, `jungle_01`, `jungle_02` (skill `crear-pista`)
- [x] Obstáculos: barriles (RigidBody2D), tren que cruza, troncos, vados
- [x] `TrackData` para cada pista

## M5 — Garaje y progresión
- [x] `UpgradeDef` × 4, `CarData` × 3
- [x] `GameState` + `SaveSystem` (+ tests)
- [x] Escena de garaje: elegir coche, comprar coche, comprar mejoras y ver stats con barras
- [x] Premios de carrera → dinero
- [x] Desbloqueo de pistas

## M6 — Menús y campeonato
- [x] Menú principal, selección de pista, pausa, opciones (volumen)
- [x] Modo campeonato (4 pistas, puntos y premio final)
- [x] Mejores tiempos por pista

## M7 — Pulido y Android
- [x] Arte final (pack CC0 Kenney Racing): coches, barriles y textura de los tiles. Cactus, troncos y tren siguen como polígonos (el pack no los trae)
- [x] Animación de ruedas (placeholder)
- [x] Partículas: polvo, barro, salpicaduras, nitro y marcas de derrape (placeholder de color por superficie)
- [x] Audio: motor con pitch, derrape, choques y música por tema (generado con lamb)
- [x] Sacudida de cámara en choques y zoom con la velocidad
- [ ] Controles táctiles y exportación a Android

## M8 — Servidor base y cuentas (repo aparte: `mini-bolidos-server`, ver `docs/ONLINE.md`)
- [x] Docker Compose: FastAPI, MariaDB, MongoDB, Redis y frontend (nginx) en una red privada; solo el frontend publica puerto
- [x] Registro con usuario y contraseña, correo de activación (Gmail SMTP por `.env`), login y recuperación de contraseña
- [x] Multiusuario con sesiones revocables; admin (`enguillem@gmail.com`) con listado de usuarios, bloqueo y expulsión
- [x] Presencia: ver quién está conectado ahora mismo
- [x] Frontend React + TypeScript: registro, activación, login, panel admin y usuarios conectados
- [x] Tests del backend y despliegue en `75enguiem`
- [x] **Humano:** registrarse con un correo real, activar la cuenta, entrar como admin y ver usuarios conectados

## M9 — Salas y carreras online (servidor)
- [x] WebSocket único por usuario: salas en espera, cola, la carrera arranca al llegar a 5 jugadores
- [x] Relevo de estados de los coches (cada cliente simula el suyo) y validación de checkpoints y tiempos de meta
- [x] Resultados y estadísticas en MariaDB; telemetría y auditoría en MongoDB
- [x] Tests con 5 clientes simulados

## M10 — Cliente online en Godot
- [ ] Menú: "Jugar solo" (como ahora) u "Online" (login/registro contra el servidor)
- [ ] Lista de salas, entrar en cola, cuenta atrás sincronizada
- [ ] Coches remotos con interpolación, posiciones y resultados compartidos
- [ ] **Humano:** carrera real con 5 jugadores

## M11 — Operación
- [ ] Dominio `bolidos.enguillem.es`, copias de seguridad, límites de uso y revisión de privacidad (alumnado)
- [ ] Descarga del cliente desde la web

## Opcionales
- [ ] Pista "Mesa de billar" como homenaje a Micro Machines V3
- [ ] Contrarreloj con fantasma
- [ ] Multijugador local a 2
- [ ] Tema Ártico
