extends Node
## ResourceState — a persistent node in Main.tscn, referenced elsewhere via
## its scene-unique name (%ResourceState). Tracks the player's Funding and
## Intel economy. Kept separate from ConcealmentState: this is a simple
## ledger, while concealment is a threshold-driven meter with its own
## growing set of concerns.

signal funding_changed(new_value: int, delta: int)
signal intel_changed(new_value: int, delta: int)

@export var starting_funding: int = 500
@export var starting_intel: int = 20

var funding: int = 0
var intel: int = 0

func _ready() -> void:
	funding = starting_funding
	intel = starting_intel

func earn_funding(amount: int) -> void:
	if amount == 0:
		return
	funding += amount
	funding_changed.emit(funding, amount)

func spend_funding(amount: int) -> bool:
	if funding < amount:
		return false
	funding -= amount
	funding_changed.emit(funding, -amount)
	return true

func earn_intel(amount: int) -> void:
	if amount == 0:
		return
	intel += amount
	intel_changed.emit(intel, amount)

func spend_intel(amount: int) -> bool:
	if intel < amount:
		return false
	intel -= amount
	intel_changed.emit(intel, -amount)
	return true
