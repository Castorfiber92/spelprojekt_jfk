extends PanelContainer
class_name BuffSlot
@export var icon : TextureRect
@export var stacks_label : Label

func setup(behavior : Behavior):
	stacks_label.text = str(behavior.stacks)
	var enum_int = behavior.tag
	var texture_tag = BehaviorBase.BehaviorTag.keys()[enum_int].to_lower()
	var sliced_texture = Ui.get_buff_texture(texture_tag)
	
	if sliced_texture != null:
		icon.texture = sliced_texture
