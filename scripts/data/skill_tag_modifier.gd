## SkillTagModifier — a single tag-interaction rule between a mission/
## encounter context and a skill: when the active context carries
## trigger_tag, every skill carrying affects_tag has its effective rank
## shifted by rank_delta for that computation.
##
## Purely data — SkillHandler evaluates these generically against whatever
## tags are active at the time (an event's tags today, an encounter phase's
## tags later). No skill interaction is ever hardcoded in code; add a new
## .tres under res://data/tag_modifiers/ to add a new interaction.
class_name SkillTagModifier
extends Resource

## The context tag that must be present for this rule to apply — e.g. an
## event/encounter tagged "fragile".
@export var trigger_tag: String = ""

## The skill tag this rule reacts to — e.g. a skill tagged "Explosive".
@export var affects_tag: String = ""

## How much to shift the affected skill's effective rank when both tags
## are present. Negative to penalize, positive to boost.
@export var rank_delta: int = 0
