@tool
extends RefCounted

const SyncingAnimationPlayer = preload("../Tools/SyncingAnimationPlayer.gd")

func _run() -> void:
    EditorInterface.popup_node_selector(_on_animation_player_selected, ["AnimationPlayer"])

func _on_animation_player_selected(node_path):
    var root = EditorInterface.get_edited_scene_root()
    var animation_player = root.get_node(node_path)

    # Create AnimationTree, new AnimationPlayer, and connect them
    # Then in the new AnimationPlayer, create animations that copy the names and lengths of the animations in selected AnimationPlayer
    # Create new tracks that are animation player tracks that put the animation from the selected AnimationPlayer into the new AnimationPlayer

    # Create AnimationTree
    var animation_tree := AnimationTree.new()
    animation_tree.name = "AnimationTree"
    root.add_child(animation_tree, true)
    animation_tree.owner = root

    # Create new AnimationPlayer
    var new_animation_player := AnimationPlayer.new()
    new_animation_player.name = "AnimationPlayerNew"
    new_animation_player.set_script(SyncingAnimationPlayer)
    root.add_child(new_animation_player, true)
    new_animation_player.owner = root

    # Connect AnimationTree to new AnimationPlayer
    animation_tree.anim_player = new_animation_player.get_path()

    pass