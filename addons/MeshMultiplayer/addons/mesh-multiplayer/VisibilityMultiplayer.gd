class_name VisibilityMultiplayer extends MultiplayerAPIExtension

signal peer_visibility_changed(peer_id: int, visible: bool)
signal peer_authenticating(peer_id: int)

# We want to extend the default SceneMultiplayer.
var _base_multiplayer = SceneMultiplayer.new()
var _visible_peers:PackedInt32Array = []
var auth_callback: Callable

func set_peer_visible(peer_id: int, visible: bool) -> void:
	var is_visible = _visible_peers.has(peer_id)
	if visible != is_visible:
		if visible:
			_visible_peers.append(peer_id)
		else:
			_visible_peers.erase(peer_id)
		peer_visibility_changed.emit(peer_id, visible)

func is_peer_visible(peer_id: int) -> bool:
	return _visible_peers.has(peer_id)

func clear_visible_peers() -> void:
	_visible_peers.clear()
	
func get_visible_peers() -> PackedInt32Array:
	return PackedInt32Array(Array(get_peers()).filter(_filter_peers))

func _filter_peers(peer_id: int) -> bool:
	return is_peer_visible(peer_id)

func _init():
	# Just passthrough base signals (copied to var to avoid cyclic reference)
	_base_multiplayer.connected_to_server.connect(connected_to_server.emit)
	_base_multiplayer.connection_failed.connect(connection_failed.emit)
	_base_multiplayer.server_disconnected.connect(server_disconnected.emit)
	_base_multiplayer.peer_connected.connect(peer_connected.emit)
	_base_multiplayer.peer_disconnected.connect(peer_disconnected.emit)
	_base_multiplayer.peer_authenticating.connect(peer_authenticating.emit)
	_base_multiplayer.auth_callback = func(peer_id: int, data: PackedByteArray) -> void:
		if auth_callback:
			auth_callback.call(peer_id, data)
		else:
			complete_auth(peer_id)

func _poll():
	return _base_multiplayer.poll()

func _rpc(peer: int, object: Object, method: StringName, args: Array) -> Error:
	return _base_multiplayer.rpc(peer, object, method, args)

func _object_configuration_add(object, config: Variant) -> Error:
	if config is MultiplayerSynchronizer:
		config.add_visibility_filter(_filter_peers)
	return _base_multiplayer.object_configuration_add(object, config)

func _object_configuration_remove(object, config: Variant) -> Error:
	if config is MultiplayerSynchronizer:
		config.remove_visibility_filter(_filter_peers)
	return _base_multiplayer.object_configuration_remove(object, config)

func _set_multiplayer_peer(p_peer: MultiplayerPeer):
	_base_multiplayer.multiplayer_peer = p_peer

func _get_multiplayer_peer() -> MultiplayerPeer:
	return _base_multiplayer.multiplayer_peer

func _get_unique_id() -> int:
	return _base_multiplayer.get_unique_id()

func _get_remote_sender_id() -> int:
	return _base_multiplayer.get_remote_sender_id()

func _get_peer_ids() -> PackedInt32Array:
	return _base_multiplayer.get_peers()

func send_auth(peer_id: int, data: PackedByteArray) -> Error:
	return _base_multiplayer.send_auth(peer_id, data)

func complete_auth(peer_id: int) -> void:
	_base_multiplayer.complete_auth(peer_id)
