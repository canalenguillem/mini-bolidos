extends Node
## Bus de señales globales.

signal race_started
signal lap_completed(car: Car, lap: int)
signal race_finished(results: Array)
signal money_changed(amount: int)
