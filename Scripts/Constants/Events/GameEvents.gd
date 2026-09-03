extends Node
signal map_event_triggered(event : MapEvent)

# Timeline Execution Channels
signal battle_started(manager: CombatManager)
signal round_ended(manager: CombatManager)
signal turn_started(slot: HeroSlot, manager: CombatManager)
signal action_execution_requested(slot: HeroSlot, manager: CombatManager)
signal turn_ended(slot: HeroSlot, manager: CombatManager)
# Action Delivery Pipeline
signal effect_created(effect: CombatEffect)

# State Mutation Shouts
signal hero_damaged(target_hero: Hero, attacker_slot: HeroSlot, amount: int)
signal hero_healed(target_hero: Hero, source_slot: HeroSlot, amount: int)
