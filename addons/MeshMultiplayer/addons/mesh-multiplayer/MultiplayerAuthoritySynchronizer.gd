class_name MultiplayerAuthoritySynchronizer extends Node

## This node allows a custom authority strategy to be setup for a tree.
## During authorization which is the only step before scene synchronization we 
## define the authority by passing initial data, this enables proper first connection sync.

## Emitted when the peer is ready to sync, this is when node spawning should be done
## Only the new peer and authority handle this
## the authority should sync the new peer across other peers using other Godot nodes
signal peer_ready(peer_id:int)
## Emitted when a peer no longer has the same authority as you
signal peer_exit(peer_id:int)
## Emitted when the authority has changed
signal authority_changed(peer_id:int)

var strategy: MultiplayerAuthorityStrategy = BasicMultiplayerAuthorityStrategy.new() :
	set(value):
		if strategy == value:
			return
		notify_exit()
		if strategy:
			strategy.exit_requested.disconnect(notify_exit)
			strategy.join_requested.disconnect(notify_joined)
		strategy = value
		if strategy:
			strategy.exit_requested.connect(notify_exit)
			strategy.join_requested.connect(notify_joined)
		notify_joined()
		
var visibility_multiplayer: VisibilityMultiplayer = VisibilityMultiplayer.new()

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		get_tree().set_multiplayer(visibility_multiplayer)
	if what == NOTIFICATION_READY:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.peer_authenticating.connect(_on_peer_authenticating)
		# If other nodes override this, it will break authority syncing
		multiplayer.auth_callback = _on_auth

func _on_peer_connected(peer_id: int) -> void:
	# Tell the peer about ourselves
	_notify_joined.rpc_id(peer_id, strategy.get_authority_data(), get_multiplayer_authority()) 

func _on_peer_disconnected(peer_id: int) -> void:
	# This check handles a case where you have a custom MultiplayerAPI 
	# that changes the peer list you recieve
	if visibility_multiplayer.is_peer_visible(peer_id):
		visibility_multiplayer.set_peer_visible(peer_id, false)
		peer_exit.emit(peer_id)
		if get_multiplayer_authority() == peer_id:
			# This is a simple deterministic approach to getting a new authority right away.
			# These peers should have the same state as you, otherwise some weirdness happened
			# and it doesn't make much of a differnce in that case because the same authority will
			# be selected for everyone ideally.
			var new_authority: int = multiplayer.get_unique_id()
			for other_peer_id in visibility_multiplayer.get_visible_peers():
				if other_peer_id >= new_authority:
					new_authority = other_peer_id
			set_multiplayer_authority(new_authority, true)
			authority_changed.emit(new_authority)

func _on_auth(peer_id: int, data: PackedByteArray) -> void:
	var data_str: String = data.get_string_from_utf8()
	var json = JSON.new()
	var err = json.parse(data_str)
	if err != OK:
		push_warning("Failed to parse auth data from peer %d" % peer_id)
		return
	push_warning("[%s] Authenticating peer %d with data %s" % [Time.get_time_string_from_system(), peer_id, json.data])
	var peer_data:Array = json.data[0]
	var authority_id: int = json.data[1]
	if strategy.is_peer_authority(multiplayer.get_unique_id(), peer_id, peer_data):
		set_multiplayer_authority(authority_id, true)
		authority_changed.emit(authority_id)
	multiplayer.complete_auth(peer_id)

func _on_peer_authenticating(peer_id: int) -> void:
	var data: PackedByteArray = PackedByteArray(JSON.stringify([
		strategy.get_authority_data(),
		get_multiplayer_authority()
	]).to_utf8_buffer())
	multiplayer.send_auth(peer_id, data)
	push_warning("[%s] Peer %d is authenticating" % [Time.get_time_string_from_system(), peer_id])

## Start the join handshake, this does nothing if you're not the authority.
func notify_joined() -> void:
	if not is_inside_tree() or not multiplayer:
		return
	push_warning("Telling others that we have joined")
	_notify_joined.rpc(strategy.get_authority_data(), get_multiplayer_authority())

## Start the exit handshake from your authority.
## This only needs to be done if you are looking to either
## go offline, switch to a new authoirty, or become one for others.
## Disconnecting is already handled
func notify_exit() -> void:
	if not is_inside_tree() or not multiplayer:
		return
	var id: int = multiplayer.get_unique_id()
	peer_exit.emit(id)
	set_multiplayer_authority(id, true)
	authority_changed.emit(id)
	_notify_exit.rpc()
	visibility_multiplayer.clear_visible_peers()


#region RPC handshake functions

@rpc("any_peer", "call_remote", "reliable", 1)
func _notify_joined(peer_data:Array, authority_id:int) -> void:
	# We only start the authority sync handshake if we're the authority
	# peers that are not an authority will wait for their authority to notify them of a peer
	if not is_multiplayer_authority():
		return
	
	var my_authority_id: int = get_multiplayer_authority()
	if not strategy.is_valid_peer(my_authority_id, authority_id, peer_data):
		return
		
	var peer_id: int = multiplayer.get_remote_sender_id()
	
	if authority_id == my_authority_id:
		push_warning("Joinning peer %d already recognizes us as authority" % peer_id)
		_notify_authority.rpc_id(peer_id, strategy.get_authority_data(), my_authority_id)
		return
	
	if strategy.is_peer_authority(my_authority_id, authority_id, peer_data):
		set_multiplayer_authority(authority_id, true)
		authority_changed.emit(authority_id)
		push_warning("Confirming the authority of peer %d" % authority_id)
		_confirm_authority.rpc_id(authority_id)
	else:
		push_warning("Notifying %d of our authority" % peer_id)
		_notify_authority.rpc_id(peer_id, strategy.get_authority_data(), my_authority_id)

@rpc("any_peer", "call_remote", "reliable", 1)
func _notify_authority(peer_data:Array, authority_id: int) -> void:
	# A peer is attempting to gain authority over us
	var peer_id: int = multiplayer.get_remote_sender_id()
	var my_authority_id:int = get_multiplayer_authority()
	if strategy.is_peer_authority(my_authority_id, authority_id, peer_data):
		set_multiplayer_authority(authority_id, true)
		authority_changed.emit(authority_id)
		push_warning("Confirming the authority of peer %d" % authority_id)
		_confirm_authority.rpc_id(authority_id)

@rpc("any_peer", "call_remote", "reliable", 1)
func _notify_exit() -> void:
	# A peer has told us they're no longer under our authority
	var peer_id: int = multiplayer.get_remote_sender_id()
	_on_peer_disconnected(peer_id)
		
@rpc("any_peer", "call_remote", "reliable", 1)
func _confirm_authority() -> void:
	if not is_multiplayer_authority():
		return
	# A peer for which we requested authority over, has confirmed they accepted our authority
	var peer_id: int = multiplayer.get_remote_sender_id()
	push_warning("Peer %d has accepted my authority" % peer_id)
	visibility_multiplayer.set_peer_visible(peer_id, true)
	
	# Now we're getting into peer "visibility" this is basically final synchronization step
	# Confirming to all peers that the new peer is a sibling under the authority of their authority
	
	# As the authority, tell our peer about others under our authority
	push_warning("Telling %d about other peers" % peer_id)
	for other_peer_id in visibility_multiplayer.get_visible_peers():
		if other_peer_id == peer_id:
			continue
		_notify_peer_visible.rpc_id(peer_id, other_peer_id)
		_notify_peer_visible.rpc_id(other_peer_id, peer_id)
	
	# Notify that we ready now that we have at least 1 peer
	_notify_peer_visible.rpc_id(peer_id, peer_id)
	#_notify_peer_visible.rpc(peer_id)
	# This will happen for every new peer also
	# Might be something stateful we could track to only do this once, but for now this is fine
	peer_ready.emit(multiplayer.get_unique_id())

@rpc("authority", "call_remote", "reliable", 1)
func _notify_peer_visible(peer_id: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not sender_id == get_multiplayer_authority():
		return
	
	if peer_id == multiplayer.get_unique_id():
		# This is the authority asking us to confirm our own visibility
		visibility_multiplayer.set_peer_visible(sender_id, true)
		_confirm_visible.rpc_id(sender_id)
		push_warning("Confirming to %d I am ready" % sender_id)
	elif not visibility_multiplayer.is_peer_visible(peer_id):
		# THis is the authority telling us about a new peer
		visibility_multiplayer.set_peer_visible(peer_id, true)
		push_warning("Peer %d has joined the authority of %d" % [peer_id, get_multiplayer_authority()])

@rpc("any_peer", "call_remote", "reliable", 1)
func _confirm_visible() -> void:
	if not is_multiplayer_authority():
		return
	# The new peer has fully confirmed they are visible and ready to finish syncing
	var peer_id: int = multiplayer.get_remote_sender_id()
	peer_ready.emit(peer_id)
	push_warning("Peer %d has confirmed they are ready" % peer_id)

#endregion
