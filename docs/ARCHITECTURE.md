# Arquitectura — Mini Bólidos

## Autoloads

| Nombre | Archivo | Responsabilidad |
|---|---|---|
| `Events` | `autoload/events.gd` | Bus de señales globales: `race_started`, `lap_completed(car, lap)`, `race_finished(results)`, `money_changed(amount)` |
| `GameState` | `autoload/game_state.gd` | Dinero, coches comprados, niveles de mejora por coche, pistas desbloqueadas y coche seleccionado. Sin lógica de UI |
| `SaveSystem` | `autoload/save_system.gd` | Serializa `GameState` a `user://save.json` con un campo `version` para poder migrar |

Nada más va en autoload. `RaceManager` es un nodo de la escena de carrera, no un singleton.

## Recursos de datos (`class_name … extends Resource`)

```
CarData        id, display_name, price, sprite: Texture2D,
               base_max_speed, base_acceleration, base_grip, base_steering,
               braking, drag, max_reverse, nitro_boost, nitro_duration
UpgradeDef     id ("engine" | "turbo" | "tires" | "nitro"), display_name,
               base_cost, cost_growth (1.6), per_level (0.06…), max_level (5)
TrackData      id, display_name, theme, scene: PackedScene, laps, reward_mult,
               unlock_cost, thumbnail
SurfaceData    id, grip_mult, speed_mult, drag_mult, particles_color, sound
```

`CarStats` (en `scripts/car_stats.gd`, extiende `RefCounted`) es el **resultado calculado** de combinar `CarData` con los niveles de mejora: `CarStats.build(car_data, levels: Dictionary) -> CarStats`. Es función pura y está cubierta por tests.

## El coche

```
Car (CharacterBody2D)            scenes/car/car.gd
├── Sprite2D
├── CollisionShape2D (Rectangle)
├── Controller (Node)            PlayerController | AIController (extienden CarController)
├── SkidMarks / GPUParticles2D
└── EngineAudio (AudioStreamPlayer2D)
```

- El coche mira hacia **+X** en coordenadas locales (`transform.x` es "adelante").
- Cada frame de física: `var input: DriveInput = $Controller.get_input(delta)`.
- `DriveInput` (`RefCounted`) tiene `throttle: float` (0..1), `brake: float` (0..1), `steer: float` (-1..1), `nitro: bool` y `reset: bool`.
- El coche no sabe si lo conduce una persona o la IA. Para cambiar de piloto basta con cambiar el nodo `Controller`.
- La superficie bajo el coche la consulta `Car` a la pista (`Track.get_surface_at(global_position) -> SurfaceData`).
- Física detallada: skill `fisica-coche-arcade`.

## La pista

```
Track (Node2D)                   scenes/tracks/track.gd (script común a todas)
├── Ground (TileMapLayer)        TileSet con custom data "surface": String
├── Walls (TileMapLayer)         con física (capa walls) — o StaticBody2D + CollisionPolygon2D
├── Decor (TileMapLayer / Node2D)
├── Obstacles (Node2D)           barriles, tren, troncos… (escenas propias)
├── SurfaceZones (Node2D)        Area2D opcionales con meta "surface" (charcos, manchas)
├── RacingLine (Path2D)          bucle cerrado en el sentido de la carrera; empieza en la línea de meta
├── Checkpoints (Node2D)         GENERADO por script a partir de RacingLine
└── StartGrid (Node2D)           Marker2D × 4 detrás de la línea de meta
```

`track.gd` expone:

- `get_surface_at(global_pos: Vector2) -> SurfaceData`: primero mira las `SurfaceZones` y si no, el tile de `Ground`.
- `get_progress(global_pos: Vector2) -> float`: offset sobre `RacingLine` en 0..1.
- `get_respawn_transform(checkpoint_index: int) -> Transform2D`
- `start_transforms() -> Array[Transform2D]`

## La carrera

```
Race (Node)                      scenes/race/race.gd = RaceManager
├── Track (instancia de TrackData.scene)
├── Cars (Node2D)                coches instanciados en StartGrid
├── Camera2D                     sigue al jugador
└── HUD (CanvasLayer)            posición, vuelta, tiempo, nitro, cuenta atrás
```

- `LapTracker` (`scripts/lap_tracker.gd`, `RefCounted`, uno por coche) recibe `checkpoint_passed(index)`. Valida el orden y cuenta las vueltas. **Lógica pura con tests.**
- La posición en carrera se ordena por `vueltas × N_checkpoints + último_checkpoint + progreso_hasta_el_siguiente`.
- Estados de `RaceManager`: `COUNTDOWN → RACING → FINISHED`. Al terminar emite `Events.race_finished(results)` y `GameState` aplica el premio.

## Capas de física

| Capa | Nombre | Quién está | Colisiona con (mask) |
|---|---|---|---|
| 1 | walls | paredes y obstáculos estáticos | — |
| 2 | cars | coches | walls, cars, obstacles |
| 3 | checkpoints | Area2D de checkpoints | (monitoriza cars) |
| 4 | obstacles | obstáculos dinámicos (RigidBody2D) | walls, cars, obstacles |
| 5 | surfaces | SurfaceZones (Area2D) | (monitoriza cars) |

## Flujo de escenas

`main_menu → track_select | garage → race → results → (garage | track_select)`

Para cambiar de escena se usa `get_tree().change_scene_to_packed()`. La pista elegida se pasa por `GameState.current_track: TrackData`.

## Guardado (`user://save.json`)

```json
{
  "version": 1,
  "money": 1200,
  "owned_cars": ["beetle", "buggy"],
  "selected_car": "buggy",
  "upgrades": { "beetle": { "engine": 2, "turbo": 1, "tires": 0, "nitro": 0 } },
  "unlocked_tracks": ["west_01", "west_02", "jungle_01"],
  "best_times": { "west_01": 83.42 }
}
```

## Tests mínimos obligatorios

- `test_car_stats.gd`: las mejoras aplican bien los porcentajes y respetan el nivel máximo.
- `test_economy.gd`: coste de mejora por nivel; no se puede comprar sin dinero.
- `test_lap_tracker.gd`: vueltas en orden, checkpoints saltados no cuentan, marcha atrás no suma.
- `test_race_positions.gd`: la ordenación por progreso es correcta.
- `test_save_system.gd`: ida y vuelta de guardado; un archivo corrupto no rompe el juego.
