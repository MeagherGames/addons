extends Node

var scene_spawner:MultiplayerSpawner = MultiplayerSpawner.new()
var spawn_node:Node = Node.new()
var clients:Dictionary = {}
var loaded_scenes:Dictionary = {}

func _get_instanced_node_path(node_path:NodePath, peer_id:int, instanced:bool) -> NodePath:
	# Helper function to get the correct scene path for instanced scenes.
	if instanced:
		return NodePath(String(node_path) + "_" + str(peer_id))
	else:
		return node_path

func get_node_path(peer_id:int, path:String, parent:Node,instanced: bool) -> NodePath:
	var scene_path:String = path
	if path.begins_with("uid://"):
		# If the scene path is a UID, convert it to a scene path.
		var uid = ResourceUID.text_to_id(path)
		scene_path = ResourceUID.get_id_path(uid)
	elif not ResourceLoader.exists(scene_path):
		push_error("Scene path '%s' does not exist." % scene_path)
		return NodePath()
	ResourceUID.text_to_id(scene_path)
	# Helper function to get the node path from a scene path.
	if parent:
		# get the name of the node from the scene path
		if scene_path.ends_with(".tscn") or scene_path.ends_with(".scn"):
			var packed_scene:PackedScene = load(scene_path)
			var node = packed_scene.instantiate()
			var tmp_node:Node = Node.new()
			tmp_node.name = node.name
			node.queue_free()
			parent.add_child(tmp_node,true, Node.INTERNAL_MODE_FRONT)
			var node_path = _get_instanced_node_path(tmp_node.get_path(), peer_id, instanced)
			parent.remove_child(tmp_node)
			tmp_node.queue_free()
			return node_path
		return NodePath()
	else:
		push_error("Node '%s' not found in parent '%s'." % [scene_path, parent.name])
		return NodePath()

func _ready() -> void:
	add_child(spawn_node,true)
	scene_spawner.spawn_function = spawn_scene
	scene_spawner.spawn_path = NodePath("..")
	spawn_node.add_child(scene_spawner)

func add_client(peer_id:int) -> void:
	if not multiplayer.is_server():
		push_error("Only the server can add clients.")
		return
	# This function is called by the server to add a new client.
	clients[peer_id] = {
		"active_scene": NodePath(),
	}

func remove_client(peer_id:int) -> void:
	if not multiplayer.is_server():
		push_error("Only the server can remove clients.")
		return
	# This function is called by the server to remove a client.
	if clients.has(peer_id):
		unload_scene(peer_id, clients[peer_id]["active_scene"])
		clients.erase(peer_id)



func load_scene(peer_id:int, path:String, instanced:bool) -> void:
	if not multiplayer.is_server():
		push_error("Only the server can load scenes.")
		return
	# This function is called by the client to request loading a scene.
	if not clients.has(peer_id):
		push_error("Client with peer_id %d does not exist." % peer_id)
		return
	if not ResourceLoader.exists(path):
		push_error("Scene path '%s' does not exist." % path)
		return
	var scene_path = path
	if path.begins_with("uid://"):
		# If the scene path is a UID, convert it to a scene path.
		var uid = ResourceUID.text_to_id(path)
		scene_path = ResourceUID.get_id_path(uid)

	var node_path = get_node_path(peer_id, scene_path, spawn_node,instanced)
	if get_tree().root.get_node_or_null(node_path) != null:
		clients[peer_id]["active_scene"] = node_path
		loaded_scenes[String(node_path)] += 1
	else:
		var scene = scene_spawner.spawn({
			"peer_id": peer_id,
			"scene_path": scene_path,
			"instanced": instanced,
			"node_path": node_path
		})
		clients[peer_id]["active_scene"] = node_path
		loaded_scenes[String(node_path)] = 1


func unload_scene(peer_id:int, node_path:NodePath) -> void:
	if not multiplayer.is_server():
		push_error("Only the server can unload scenes.")
		return
	# This function is called by the client to unload a scene.
	var node = get_node_or_null(node_path)
	if node:
		if clients.has(peer_id) and clients[peer_id]["active_scene"] == node_path:
			clients[peer_id]["active_scene"] = NodePath()
		if loaded_scenes.has(node_path):
			loaded_scenes[node_path] -= 1
			if loaded_scenes[node_path] <= 0:
				loaded_scenes.erase(node_path)
				node.queue_free()

func spawn_scene(data:Dictionary) -> Node:
	var packed_scene = load(data.scene_path)
	var scene:Node = packed_scene.instantiate()
	if data.instanced:
		scene.name = scene.name + "_" + str(data.peer_id)
	if (scene.has_node("MultiplayerSynchronizer")):
		var synchronizer = scene.get_node("MultiplayerSynchronizer")
		synchronizer.set_multiplayer_authority(1)  # Server has authority
		synchronizer.add_visibility_filter(client_scene_visibility_filter.bind(data.node_path))
		synchronizer.update_visibility()
		return scene
	var synchronizer = MultiplayerSynchronizer.new()
	scene.add_child(synchronizer)
	synchronizer.set_multiplayer_authority(1)  # Server has authority
	var config = SceneReplicationConfig.new()
	synchronizer.replication_config = config
	synchronizer.add_visibility_filter(client_scene_visibility_filter.bind(data.node_path))
	synchronizer.update_visibility()

	return scene

func client_scene_visibility_filter(peer_id:int, node_path:NodePath) -> bool:
	return clients.has(peer_id) and clients[peer_id]["active_scene"] == node_path
