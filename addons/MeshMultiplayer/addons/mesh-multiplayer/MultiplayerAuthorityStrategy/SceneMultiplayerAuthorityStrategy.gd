class_name SceneMultiplayerAuthorityStrategy extends MultiplayerAuthorityStrategy

var _current_scene:WeakRef = null:
	set(value):
		if _current_scene != value:
			_current_scene = value
			_timestamp = Time.get_unix_time_from_system()
			if _current_scene:
				join_requested.emit()
				#push_warning("Changed scene to %s at %d" % [_get_scene_path(), _timestamp])
			else:
				exit_requested.emit()

var _timestamp: float = INF

func _init() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree.current_scene:
		# First node added should be the root
		tree.node_added.connect(func(_node: Node): _current_scene = weakref(tree.current_scene), CONNECT_ONE_SHOT)
	else:
		_current_scene = weakref(tree.current_scene)
	tree.node_removed.connect(func(node: Node): if _current_scene and node == _current_scene.get_ref(): _current_scene = null)
	tree.scene_changed.connect(func(): _current_scene = weakref(tree.current_scene))

func _get_scene_path() -> String:
	if not (_current_scene and _current_scene.get_ref()):
		return ""
	var node: Node = _current_scene.get_ref() as Node
	if not node.scene_file_path:
		return node.get_path()
	return node.scene_file_path

func get_authority_data() -> Array:
	return [_get_scene_path(), _timestamp]

func is_peer_authority(authority_id:int, peer_authority_id:int, peer_data: Array) -> bool:
	var peer_scene_path: String = peer_data[0]
	var scene_path: String = _get_scene_path()
	#push_warning("is_peer_authority [%d %s %d] [%d %s %d]" % ([authority_id, scene_path, _timestamp, peer_authority_id] + peer_data))
	if not peer_scene_path or not scene_path or not peer_scene_path == scene_path:
		return false
	var peer_timestamp: float = peer_data[1]
	if _timestamp < peer_timestamp:
		return false
	return true

func is_valid_peer(_authority_id:int, _peer_authority_id:int, peer_data: Array) -> bool:
	var peer_scene_path: String = peer_data[0]
	var scene_path: String = _get_scene_path()
	return peer_scene_path == scene_path
