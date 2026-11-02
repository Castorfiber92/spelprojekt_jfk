extends Node
signal map_event_triggered(event : MapEvent)

# Timeline Execution Channels
signal combat_event(event_type: Enums.TriggerEvent, context: Dictionary)
# Action Delivery Pipeline
signal effect_created(effect: CombatEffect)

# State Mutation Shouts
signal hero_damaged(target_hero: Hero, attacker_slot: HeroSlot, amount: int)
signal hero_healed(target_hero: Hero, source_slot: HeroSlot, amount: int)
