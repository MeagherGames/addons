@tool
extends "res://addons/aseprite-importer/Tools/AsepriteImporterTool.gd"

const SyncingAnimationPlayer = preload("../Tools/SyncingAnimationPlayer.gd")
const ANIMATION_TREE_META = "__ASEPRITE_IMPORTER_ANIMATION_TREE"
const ANIMATION_PLAYER_META = "__ASEPRITE_IMPORTER_ANIMATION_PLAYER"

func get_name() -> StringName:
    return "AsepriteImporter: Animation Tree from Animation Player"

func run() -> void:
    var selection = EditorInterface.get_selection()
    for node in selection.get_selected_nodes():
        if node is AnimationPlayer:
            _on_animation_player_selected(node.get_path())
            return

    # No AnimationPlayer selected, so prompt the user to select one
    EditorInterface.popup_node_selector(_on_animation_player_selected, ["AnimationPlayer"])

func _on_animation_player_selected(node_path):
    var root = EditorInterface.get_edited_scene_root()
    var selected_node = root.get_node(node_path)
    var animation_tree:AnimationTree
    var animation_player:AnimationPlayer

    # Check meta data to see if AnimationTree and AnimationPlayer already exist
    if selected_node.has_meta(ANIMATION_TREE_META) and selected_node.has_meta(ANIMATION_PLAYER_META):
        var animation_tree_path = selected_node.get_meta(ANIMATION_TREE_META)
        var animation_player_path = selected_node.get_meta(ANIMATION_PLAYER_META)
        animation_tree = root.get_node_or_null(animation_tree_path) as AnimationTree
        animation_player = root.get_node_or_null(animation_player_path) as AnimationPlayer
        if animation_tree and animation_player:
            EditorInterface.edit_node(animation_tree)
            return
        else:
            selected_node.remove_meta(ANIMATION_TREE_META)
            selected_node.remove_meta(ANIMATION_PLAYER_META)

    var undo_redo = EditorInterface.get_editor_undo_redo()

    undo_redo.create_action("Create AnimationTree from AnimationPlayer", UndoRedo.MERGE_DISABLE, root)

    # Create AnimationTree
    if not animation_tree:
        animation_tree = AnimationTree.new()
        animation_tree.name = "AnimationTree"
        undo_redo.add_do_method(root, "add_child", animation_tree, true)
        undo_redo.add_undo_method(root, "remove_child", animation_tree)
        undo_redo.add_do_property(animation_tree, "owner", root)
    
    # Create new AnimationPlayer
    if not animation_player:
        animation_player = AnimationPlayer.new()
        animation_player.name = "AnimationPlayerNew"
        animation_player.set_script(SyncingAnimationPlayer)
        animation_player.set("source_animation_player", node_path)
        undo_redo.add_do_method(root, "add_child", animation_player, true)
        undo_redo.add_undo_method(root, "remove_child", animation_player)
        undo_redo.add_do_property(animation_player, "owner", root)

    undo_redo.add_do_method(self, "configure", root, node_path, animation_tree, animation_player)
    undo_redo.add_undo_method(self, "unconfigure", root, node_path)

    undo_redo.commit_action()

func configure(root, node_path, animation_tree, animation_player):
    animation_tree.anim_player = animation_player.get_path()
    var selected_node = root.get_node(node_path)
    selected_node.set_meta(ANIMATION_TREE_META, root.get_path_to(animation_tree))
    selected_node.set_meta(ANIMATION_PLAYER_META, root.get_path_to(animation_player))

func unconfigure(root, node_path) -> void:
    var selected_node = root.get_node(node_path)
    if selected_node:
        var animation_tree_path = selected_node.get_meta(ANIMATION_TREE_META)
        selected_node.remove_meta(ANIMATION_TREE_META)
        
        var animation_player_path = selected_node.get_meta(ANIMATION_PLAYER_META)
        selected_node.remove_meta(ANIMATION_PLAYER_META)
