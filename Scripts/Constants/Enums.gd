extends Node
enum Team {FRIEND, ENEMY, SELF}
enum Target {
	SINGLE,     # Picks exactly N random/specific targets from the pool
	MULTI,     # Picks a primary target, then another
	CLEAVE,
	ALL        # Hits every single valid hero in the pool unconditionally
	#RANDOM_BOUNCE # Hits a target, then jumps to N random targets successively
}
enum Tribe {CRITTER, ORC, UNDEAD, GNOME, NEUTRAL}
static var Tribe_MAP = {
	"critter": Enums.Tribe.CRITTER,
	"orc": Enums.Tribe.ORC,
	"undead": Enums.Tribe.UNDEAD,
	"gnome": Enums.Tribe.GNOME,
	"neutral": Enums.Tribe.NEUTRAL
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

enum TriggerEvent {
	ON_EXECUTE_ACTION,
	ON_START_OF_BATTLE,
	ON_TURN_START,
	ON_TURN_END,
	ON_ATTACK,
	ON_DAMAGE_DEALT,
	ON_DAMAGE_TAKEN,
	ON_DEATH
}

# Helper mapping function to convert Enums to strings for method calling
const TRIGGER_STRINGS = {
	TriggerEvent.ON_EXECUTE_ACTION: "on_execute_action",
	TriggerEvent.ON_START_OF_BATTLE: "on_start_of_battle",
	TriggerEvent.ON_TURN_START: "on_turn_start",
	TriggerEvent.ON_TURN_END: "on_turn_end",
	TriggerEvent.ON_ATTACK: "on_attack",
	TriggerEvent.ON_DAMAGE_DEALT: "on_damage_dealt",
	TriggerEvent.ON_DAMAGE_TAKEN: "on_damage_taken",
	TriggerEvent.ON_DEATH: "on_death"
}
