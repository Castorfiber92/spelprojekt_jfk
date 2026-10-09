extends PanelContainer
class_name BuffSlot
@export var icon : TextureRect
@export var stacks_label : Label

func setup(behavior : Behavior):
	if behavior.current_stacks > 0:
		stacks_label.text = str(behavior.current_stacks)
	else: stacks_label.text = ""
	var enum_string = behavior.data.name
	var texture_tag = enum_string.to_lower()
	var sliced_texture = Ui.get_buff_texture(texture_tag)
	
	if sliced_texture != null:
		icon.texture = sliced_texture
	
