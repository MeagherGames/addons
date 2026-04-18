class_name LanMeshNetwork extends RefCounted

const _EVENT_TYPE_MESSAGE: Dictionary = {
	ENetConnection.EventType.EVENT_NONE: "EVENT_NONE",
	ENetConnection.EventType.EVENT_CONNECT: "EVENT_CONNECT",
	ENetConnection.EventType.EVENT_DISCONNECT: "EVENT_DISCONNECT",
	ENetConnection.EventType.EVENT_ERROR: "EVENT_ERROR",
	ENetConnection.EventType.EVENT_RECEIVE: "EVENT_RECEIVE"
}

class MeshNode extends RefCounted:
	var my_id: int
	var peer_id: int
	var address: String
	var port: int
	var shared_port: int = -1
	var peer: ENetConnection
	var is_connected_to_mesh: bool = false

const DISCOVERY_PORT: int = 4343
const DISCOVERY_BROADCAST_INTERVAL: float = 5.0
const MESH_PORT: int = 5454
const MAX_PORTS: int = 1000

static var _my_peer: ENetMultiplayerPeer = null
static var _mesh_nodes: Dictionary[int, MeshNode] = {}
static var _port_offset: int = 0

static var _discovery_socket: PacketPeerUDP = null
static var _timer = 0.0
static var debug:bool = false


static func _get_peer_id(address: String, port: int) -> int:
	if address == "":
		return -1
	var hash_input: String = "%s:%d" % [address, port]
	return hash_input.hash() & 0x7FFFFFFF # Ensure positive integer


static func _get_next_port() -> int:
	_port_offset = (_port_offset + 1) % MAX_PORTS
	var attempts = 0
	while attempts < MAX_PORTS:
		var potential_port = MESH_PORT + _port_offset
		var port_in_use: bool = false
		for node in _mesh_nodes.values():
			if node.shared_port == potential_port:
				port_in_use = true
				break
		if not port_in_use:
			return potential_port
		_port_offset = (_port_offset + 1) % MAX_PORTS
		attempts += 1
	return -1

static func _is_peer_connected(peer_id: int) -> bool:
	return _mesh_nodes.has(peer_id) and _mesh_nodes[peer_id].is_connected_to_mesh

static func _has_peer(peer_id: int) -> bool:
	return _mesh_nodes.has(peer_id)

static func _remove_peer(peer_id: int) -> void:
	_mesh_nodes.erase(peer_id)


static func _process() -> void:
	var tree:SceneTree = Engine.get_main_loop() as SceneTree
	
	var delta = tree.root.get_process_delta_time()
	_timer += delta
	if _timer >= DISCOVERY_BROADCAST_INTERVAL:
		_discovery_broadcast()
		_timer = 0.0
	
	# Mesh creation/connection handling
	_discovery_loop()

	if not _mesh_nodes.is_empty():
		for peer_id in _mesh_nodes.keys():
			var node = _mesh_nodes.get(peer_id)
			if not node or not node.peer:
				_remove_peer(peer_id)
				continue
			
			if node.is_connected_to_mesh or node.shared_port == -1:
				continue # Already connected or invalid

			var service_data = node.peer.service()
			if service_data[0] == ENetConnection.EventType.EVENT_CONNECT:
				if not tree.root.multiplayer.has_multiplayer_peer() or tree.root.multiplayer.multiplayer_peer != _my_peer:
					# First connection, create mesh
					_my_peer.create_mesh(node.my_id)
					tree.root.multiplayer.multiplayer_peer = _my_peer
					tree.root.set_multiplayer_authority(node.my_id, true)
					if debug: push_warning("Created mesh %d" % node.my_id)
					
				
				if _my_peer.add_mesh_peer(peer_id, node.peer) != OK:
					if debug: push_error("[%d] Failed to add mesh peer %d at %s:%d at port %d" % [node.my_id, peer_id, node.address, node.port, node.shared_port])
					_remove_peer(peer_id)
					continue
				node.is_connected_to_mesh = true
				if debug: push_warning("[%d] Connected to mesh node %d at %s:%d at port %d" % [node.my_id, peer_id, node.address, node.port, node.shared_port])
			elif service_data[0] != ENetConnection.EventType.EVENT_NONE:
				push_error("[%d] %s from mesh node %d at %s:%d at port %d" % [node.my_id, _EVENT_TYPE_MESSAGE[service_data[0]], peer_id, node.address, node.port, node.shared_port])
				push_error(service_data)
				_remove_peer(peer_id)

## Begin broadcasting over LAN and connecting to the mesh network
static func start_mesh_discovery() -> Error:
	if is_mesh_discovery_active():
		return OK # Already started

	_discovery_socket = PacketPeerUDP.new()
	_discovery_socket.set_broadcast_enabled(true)

	var result: Error = _discovery_socket.bind(DISCOVERY_PORT)
	if result != OK:
		_discovery_socket.close()
		result = _discovery_socket.bind(0) # Try any available port
	
	if result != OK:
		push_error("Failed to bind discovery socket on port %d" % DISCOVERY_PORT)
		_discovery_socket = null
		return result

	# Setup multiplayer peer
	_my_peer = ENetMultiplayerPeer.new()
	_my_peer.peer_disconnected.connect(_on_peer_disconnected)

	# Enable processing
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.process_frame.connect(_process)
	
	# Initial broadcast
	_discovery_broadcast.call_deferred()
	return OK
	
static func is_mesh_discovery_active() -> bool:
	return _discovery_socket != null

## Stop broadcasting on the LAN network and go offline
static func stop_mesh_discovery() -> void:
	# Stop discovery processing
	if _my_peer == null:
		return # Not running

	# Disable processing
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.process_frame.disconnect(_process)
	
	# Stop and free discovery resources
	_discovery_socket.close()
	_discovery_socket = null

	# Disconnect multiplayer peer signals
	_my_peer.close()
	_my_peer.peer_disconnected.disconnect(_on_peer_disconnected)
	_my_peer = null

	# Reset id and peers
	for peer_id in _mesh_nodes.keys():
		_remove_peer(peer_id)
	_mesh_nodes.clear()
	
	tree.root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	tree.root.set_multiplayer_authority(1, true)


static func _discovery_broadcast() -> void:
	var message = JSON.stringify({
		type = "discovery",
	}).to_utf8_buffer()
	_discovery_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_discovery_socket.put_packet(message)


static func _discovery_loop() -> void:
	while _discovery_socket.is_bound() and _discovery_socket.get_available_packet_count() > 0:
		# Packet must be grabbed first before other info is available
		var packet: PackedByteArray = _discovery_socket.get_packet()
		var peer_address = _discovery_socket.get_packet_ip()
		var peer_port = _discovery_socket.get_packet_port()

		# filter out invalid packets
		if packet.size() == 0 or peer_address == "" or peer_port == 0:
			continue

		if IP.get_local_addresses().has(peer_address) and peer_port == _discovery_socket.get_local_port():
			continue # Ignore our own packets

		# Our packet data is JSON encoded
		var packet_data = packet.get_string_from_utf8()

		var json = JSON.new()
		if json.parse(packet_data) != OK:
			if debug: push_warning("Received invalid JSON packet from %s:%d" % [peer_address, peer_port])
			if debug: push_error(json.get_error_message())
			continue # Invalid JSON
		var peer_data = json.data

		if debug: push_warning("Received packet from %s:%d (%s, %d)" % [peer_address, peer_port])
		if debug: push_warning(peer_data)
		
		match peer_data.get("type", ""):
			"discovery":
				_on_peer_discovered(peer_data.get("address", peer_address), peer_data.get("port", peer_port))
			"join_mesh":
				var my_id = peer_data.get("peer_id", 0)
				_on_mesh_joined(peer_address, peer_port, my_id)
			"connect_to_mesh":
				var shared_port = peer_data.get("shared_port", 0)
				_on_mesh_connect(peer_address, peer_port, shared_port)
				pass


static func _on_peer_discovered(address: String, port: int) -> void:
	var peer_id: int = _get_peer_id(address, port)

	if _discovery_socket.get_local_port() == DISCOVERY_PORT:
		# Notify other local peers about the new node
		# This is a relay for nodes that are not listening to broadcasts
		for node in _mesh_nodes.values():
			if node.peer_id == peer_id:
				continue
			var is_local: bool = IP.get_local_addresses().has(node.address)
			if not is_local or node.port == DISCOVERY_PORT:
				continue
			_discovery_socket.set_dest_address(node.address, node.port)
			_discovery_socket.put_packet(JSON.stringify({
				type = "discovery",
				address = address,
				port = port,
			}).to_utf8_buffer())

	if _has_peer(peer_id):
		return
	
	if debug: push_warning("Discovered peer %d at %s:%d" % [peer_id, address, port])
	_discovery_socket.set_dest_address(address, port)
	_discovery_socket.put_packet(JSON.stringify({
		type = "join_mesh",
		peer_id = peer_id,
	}).to_utf8_buffer())


static func _on_mesh_joined(address: String, port: int, my_id: int) -> void:
	var peer_id: int = _get_peer_id(address, port)

	if not _is_peer_connected(peer_id):
		_setup_mesh_handshake(my_id, peer_id, address, port)

		# Acknowledge by sending back our join mesh request
		_discovery_socket.set_dest_address(address, port)
		_discovery_socket.put_packet(JSON.stringify({
			type = "join_mesh",
			peer_id = peer_id,
		}).to_utf8_buffer())


static func _setup_mesh_handshake(my_id: int, peer_id: int, peer_address: String, peer_port: int) -> void:
	var node: MeshNode = _mesh_nodes.get(peer_id, null)
	if not node:
		node = MeshNode.new()
		node.my_id = my_id
		node.peer_id = peer_id
		node.address = peer_address
		node.port = peer_port
		node.peer = ENetConnection.new()
		_mesh_nodes[peer_id] = node

	var should_host: bool = my_id < peer_id
	if should_host:
		if node.shared_port == -1:
			node.shared_port = _get_next_port()
			if debug: push_warning("[%d] Attempting to connect to mesh node %d at %s:%d via port %d" % [node.my_id, peer_id, peer_address, peer_port, node.shared_port])
			if node.peer.create_host_bound("*", node.shared_port, 1) != OK:
				# we'll try again later
				node.shared_port = -1
		
		if node.shared_port != -1:
			_discovery_socket.set_dest_address(peer_address, peer_port)
			_discovery_socket.put_packet(JSON.stringify({
				type = "connect_to_mesh",
				shared_port = node.shared_port,
			}).to_utf8_buffer())
		

static func _on_mesh_connect(address: String, port: int, shared_port: int) -> void:
	var peer_id: int = _get_peer_id(address, port)
	var node: MeshNode = _mesh_nodes.get(peer_id, null)
	if not node or node.shared_port != -1:
		return # Already connecting or invalid
	if debug: push_warning("[%d] Connecting to mesh node %d at %s:%d via port %d" % [node.my_id, peer_id, address, port, shared_port])
	node.shared_port = shared_port
	node.peer.create_host(1)
	node.peer.connect_to_host(address, shared_port)

static func _on_peer_disconnected(peer_id: int) -> void:
	var node: MeshNode = _mesh_nodes.get(peer_id, null)
	if node:
		if debug: push_warning("[%d] Peer %d disconnected" % [node.my_id, peer_id])
		return
	_remove_peer(peer_id)
