class_name Economy
extends RefCounted
## Reglas económicas puras: coste de mejoras y premios de carrera.

const PRIZES: Array[int] = [500, 300, 150, 50]  ## por puesto 1º..4º, antes de reward_mult


## Coste de comprar el siguiente nivel, estando en `level`: base × crecimiento^nivel.
static func upgrade_cost(def: UpgradeDef, level: int) -> int:
	return roundi(def.base_cost * pow(def.cost_growth, level))


## Premio por puesto (1 = primero) multiplicado por la pista. Fuera de los 4 primeros: 0.
static func prize(position: int, reward_mult: float) -> int:
	if position < 1 or position > PRIZES.size():
		return 0
	return roundi(PRIZES[position - 1] * reward_mult)
