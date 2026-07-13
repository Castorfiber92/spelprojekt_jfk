extends Node
# FIX 1: Add a default frame or box for neutral/unspecified icons 
# (Change the Rect2 coordinates to whatever generic frame icon you want to use)
const BUFF_REGIONS = {
	"neutral_icon": Rect2(166, 55, 236, 252), # Fallback frame
	"burn_icon": Rect2(166, 55, 236, 252), 
	"freeze_icon": Rect2(447, 57, 251, 249),
	"mark_icon": Rect2(758, 81, 231, 213),
	"stun_icon": Rect2(1036, 83, 262, 211),
	"curse_icon": Rect2(752,659,269,238),
	"armor_icon": Rect2(183,661,261,241),
	"power_icon": Rect2(730,374,276,234)
}

const EVENT_ICON_REGIONS = {
	"combat_icon": Rect2(126, 335, 195, 173),
	"tavern_icon": Rect2(342, 331, 235, 177),
	"shop_icon": Rect2(826, 329, 199, 186),
	"encounter_icon": Rect2(1053, 335, 202, 173),
	"boss_icon": Rect2(1023, 546, 241, 178)
}

@onready var sheet_texture_buffs = preload("res://Graphics/buff icons.png")
@onready var sheet_texture_owicons = preload("res://Graphics/Overworld sprites/Overworld icons.png")

# OPTIMIZATION: Keep a dictionary cache of created textures so we don't 
# constantly instantiate new objects in memory every single redraw frame!
var _buff_texture_cache: Dictionary = {}

func get_buff_texture(buff_id: String) -> AtlasTexture:
	var full_key = (buff_id.to_lower() + "_icon")
	
	# If we already built this texture previously, hand back the cached version instantly!
	if _buff_texture_cache.has(full_key):
		return _buff_texture_cache[full_key]
	
	# Fallback if an unrecognized ID slips through the pipeline
	if not BUFF_REGIONS.has(full_key):
		push_warning("Buff ID not found: " + full_key + ". Using neutral fallback.")
		full_key = "neutral_icon"
	
	# Instantiate and store it in our dictionary cache
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = sheet_texture_buffs
	atlas_tex.region = BUFF_REGIONS[full_key]
	_buff_texture_cache[full_key] = atlas_tex
	
	return atlas_tex

func get_overworld_event_texture(event_id: String) -> AtlasTexture:
	var full_key = (event_id.to_lower() + "_icon")
	
	if not EVENT_ICON_REGIONS.has(full_key):
		push_error("Ow icon ID not found!")
		return null
	
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = sheet_texture_owicons
	atlas_tex.region = EVENT_ICON_REGIONS[full_key]
	return atlas_tex
