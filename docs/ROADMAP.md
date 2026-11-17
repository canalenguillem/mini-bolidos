# Roadmap — Mini Bólidos

Hito actual: **M7** (parcial: arte, audio y Android pendientes; M5 y M6 pendientes de validar jugando)

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
- [ ] Arte final (pack CC0) — pendiente: el humano descarga el pack a `assets/`
- [x] Animación de ruedas (placeholder)
- [x] Partículas: polvo, barro, salpicaduras, nitro y marcas de derrape (placeholder de color por superficie)
- [ ] Audio: motor con pitch, derrape, choques y música por tema
- [x] Sacudida de cámara en choques y zoom con la velocidad
- [ ] Controles táctiles y exportación a Android

## Opcionales
- [ ] Pista "Mesa de billar" como homenaje a Micro Machines V3
- [ ] Contrarreloj con fantasma
- [ ] Multijugador local a 2
- [ ] Tema Ártico
