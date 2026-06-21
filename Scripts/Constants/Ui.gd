extends Node
const BUFF_REGIONS = {
	"burn_icon": Rect2(166, 55, 236, 252),    # X, Y, Width, Height
	"frozen_icon": Rect2(447, 57, 251, 249),
	"mark_icon": Rect2(758,81,231,213),
	"stun_icon": Rect2(1036,83,262,211)
}

@onready var sheet_texture = preload("res://Graphics/buff icons.png")

func get_buff_texture(buff_id: String) -> AtlasTexture:
	buff_id = buff_id + "_icon"
	print("Trying to grab ", str(buff_id.to_lower()))
	if not BUFF_REGIONS.has(buff_id):
		push_error("Buff ID not found!")
		return null
	
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = sheet_texture
	atlas_tex.region = BUFF_REGIONS[buff_id] # Applies the exact unaligned frame
	return atlas_tex
