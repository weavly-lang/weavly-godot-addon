class_name WeavlySpeaker
extends Node

const GROUP: StringName = &"weavly_speakers"

## The id of the character whose lines show in a bubble above this node's parent.
@export var character: String = ""
## Where the bubble points, from a Node2D parent's position, unaffected by its rotation and scale.
@export var offset_2d: Vector2 = Vector2(0, -64)
## Where the bubble points, from a Node3D parent's position, unaffected by its rotation and scale.
@export var offset_3d: Vector3 = Vector3(0, 2, 0)


func _init() -> void:
	add_to_group(GROUP)


## False when the parent is hidden, isn't a Node2D or Node3D, or is behind the 3D camera.
func is_on_screen() -> bool:
	var parent: Node = get_parent()
	if parent is Node2D:
		return parent.is_visible_in_tree()
	if parent is Node3D:
		var camera: Camera3D = get_viewport().get_camera_3d()
		return (
			parent.is_visible_in_tree()
			and camera != null
			and not camera.is_position_behind(parent.global_position + offset_3d)
		)
	return false


## Where the bubble points, in the viewport's coordinates.
func get_screen_position() -> Vector2:
	var parent: Node = get_parent()
	if parent is Node2D:
		return parent.get_canvas_transform() * (parent.global_position + offset_2d)
	if parent is Node3D:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			return camera.unproject_position(parent.global_position + offset_3d)
	return Vector2.ZERO
