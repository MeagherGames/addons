@tool
extends AnimationPlayer

## This tool will copy animation details from another AnimationPlayer to this AnimationPlayer.
## It creates tracks that reference the animations from the source AnimationPlayer.
## It always keeps the length and loop mode of the animations in sync.
## If animations are removed from the source AnimationPlayer, they will not be removed from this AnimationPlayer unless you force sync.
## Any changes you make to these animations will not be removed unless you force sync.

@export_tool_button("Sync Animations", "Reload") var sync_animations: Callable:
	get: return Callable(sync )
@export_node_path("AnimationPlayer") var source_animation_player: NodePath
@export_tool_button("Force Reset Animations", "NodeWarning") var force_reset: Callable:
	get: return Callable(_reset_button_pressed)

func _ready() -> void:
	if not Engine.is_editor_hint():
		return

	var animation_player = get_node_or_null(source_animation_player)
	if animation_player:
		animation_player.animation_list_changed.connect(_on_animation_list_changed)
		animation_list_changed.connect(_on_animation_list_changed)
		_on_animation_list_changed()

func _on_animation_list_changed() -> void:
	if not Engine.is_editor_hint():
		return
	sync ()

func _reset_button_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	var are_you_sure: AcceptDialog = AcceptDialog.new()
	are_you_sure.dialog_text = "Are you sure you want to force sync? This will delete all the animations currently in this AnimationPlayer."
	are_you_sure.title = "Force Animation Sync"
	are_you_sure.ok_button_text = "Force Sync"
	are_you_sure.dialog_autowrap = true
	are_you_sure.confirmed.connect(sync.bind(true))
	are_you_sure.canceled.connect(are_you_sure.queue_free)
	are_you_sure.close_requested.connect(are_you_sure.queue_free)
	EditorInterface.popup_dialog_centered(are_you_sure, Vector2(300, 100))

func sync(force: bool = false) -> void:
	if not Engine.is_editor_hint():
		return

	var animation_player = get_node(source_animation_player)
	var animation_list = animation_player.get_animation_list()
	
	var animation_library: AnimationLibrary
	if force:
		remove_animation_library("")

	if not has_animation_library(""):
		animation_library = AnimationLibrary.new()
		add_animation_library("", animation_library)
	else:
		animation_library = get_animation_library("")

	for animation_name in animation_list:
		var source_animation = animation_player.get_animation(animation_name)
		var animation: Animation
		if has_animation(animation_name):
			animation = get_animation(animation_name)
		
		if not animation or force:
			animation = Animation.new()
			animation_library.add_animation(animation_name, animation)
			var track = animation.add_track(Animation.TYPE_ANIMATION)
			animation.track_set_path(track, owner.get_path_to(animation_player))
			animation.animation_track_insert_key(track, 0, animation_name)

		animation.length = source_animation.length
		animation.loop_mode = source_animation.loop_mode
