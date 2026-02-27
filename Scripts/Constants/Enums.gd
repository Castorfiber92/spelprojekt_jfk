extends Node
enum Team {FRIEND, ENEMY, SELF}
enum Target {SINGLE, MULTI}
enum Tribe {CRITTER, ORC, UNDEAD, GNOME}
const Tribe_MAP = {
	"critter": Enums.Tribe.CRITTER,
	"orc": Enums.Tribe.ORC,
	"undead": Enums.Tribe.UNDEAD,
	"gnome": Enums.Tribe.GNOME
}
enum CombatPhase {IDLE, 
	PRE_TURN,      # Buffs ticking down, "Start of turn" abilities
	SELECT_ACTION, # AI choosing or Player clicking
	FIND_TARGETS,  # Validation
	BEFORE_ACT,    # Last chance to interrupt/stun
	EXECUTE,       # The actual animation/damage
	AFTER_ACT,     # "On kill" effects, follow-up attacks
	POST_TURN      # Cleanup
	}
