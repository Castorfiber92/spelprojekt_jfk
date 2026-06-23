extends Node
const BUFF_REGIONS = {
	"burn_icon": Rect2(166, 55, 236, 252), 
	"frozen_icon": Rect2(447, 57, 251, 249),
	"mark_icon": Rect2(758,81,231,213),
	"stun_icon": Rect2(1036,83,262,211)
}

const EVENT_ICON_REGIONS = {
	"combat_icon": Rect2(126,335,195,173),
	"tavern_icon": Rect2(342,331,235,177),
	"shop_icon": Rect2(826,329,199,186),
	"encounter_icon": Rect2(1053,335,202,173),
	"boss_icon": Rect2(1023,546,241,178)
}

@onready var sheet_texture_buffs = preload("res://Graphics/buff icons.png")
@onready var sheet_texture_owicons = preload("res://Graphics/Overworld sprites/Overworld icons.png")

func get_buff_texture(buff_id: String) -> AtlasTexture:
	var full_key = (buff_id.to_lower() + "_icon")
	print("Trying to grab ", str(full_key))
	if not BUFF_REGIONS.has(full_key):
		push_error("Buff ID not found!")
		return null
	
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = sheet_texture_buffs
	atlas_tex.region = BUFF_REGIONS[full_key] # Applies the exact unaligned frame
	return atlas_tex
	
func get_overworld_event_texture(event_id: String) -> AtlasTexture:
	var full_key = (event_id.to_lower() + "_icon")
	print("Trying to grab ", str(full_key))
	if not EVENT_ICON_REGIONS.has(full_key):
		push_error("Ow icon ID not found!")
		return null
	
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = sheet_texture_owicons
	atlas_tex.region = EVENT_ICON_REGIONS[full_key] # Applies the exact unaligned frame
	return atlas_tex
