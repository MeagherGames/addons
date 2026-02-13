extends Node

const EVENT_TYPE_MESSAGE: Dictionary = {
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

var my_peer: ENetMultiplayerPeer = null
var mesh_nodes: Dictionary[int, MeshNode] = {}
var port_offset: int = 0

var discovery_socket: PacketPeerUDP = null
var discovery_timer: Timer = null


static func get_peer_id(address: String, port: int) -> int:
	if address == "":
		return -1
	var hash_input: String = "%s:%d" % [address, port]
	return hash_input.hash() & 0x7FFFFFFF # Ensure positive integer

func get_next_port() -> int:
	port_offset = (port_offset + 1) % MAX_PORTS
	while true:
		var potential_port = MESH_PORT + port_offset
		var port_in_use: bool = false
		for node in mesh_nodes.values():
			if node.shared_port == potential_port:
				port_in_use = true
				break
		if not port_in_use:
			return potential_port
		port_offset = (port_offset + 1) % MAX_PORTS
	return -1 # Should not reach here


func is_peer_connected(peer_id: int) -> bool:
	return mesh_nodes.has(peer_id) and mesh_nodes[peer_id].is_connected_to_mesh


func has_peer(peer_id: int) -> bool:
	return mesh_nodes.has(peer_id)

func remove_peer(peer_id: int) -> void:
	mesh_nodes.erase(peer_id)


func get_mesh_addresses(peer_id: int) -> PackedStringArray:
	var addresses: PackedStringArray = []
	for node in mesh_nodes.values():
		if not node or node.id == peer_id:
			continue
		addresses.append("%d:%s:%d" % [node.id, node.address, node.port])
	return addresses


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	stop_mesh_discovery()


func _process(_delta: float) -> void:
	# Mesh creation/connection handling
	_discovery_loop()

	if not mesh_nodes.is_empty():
		for peer_id in mesh_nodes.keys():
			var node = mesh_nodes.get(peer_id)
			if not node or not node.peer:
				remove_peer(peer_id)
				continue
			
			if node.is_connected_to_mesh or node.shared_port == -1:
				continue # Already connected or invalid

			var service_data = node.peer.service()
			if service_data[0] == ENetConnection.EventType.EVENT_CONNECT:
				if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer != my_peer:
					# First connection, create mesh
					my_peer.create_mesh(node.my_id)
					multiplayer.multiplayer_peer = my_peer
					get_tree().root.set_multiplayer_authority(node.my_id, true)
					push_warning("Created mesh %d" % node.my_id)
					
				
				if my_peer.add_mesh_peer(peer_id, node.peer) != OK:
					push_error("[%d] Failed to add mesh peer %d at %s:%d at port %d" % [node.my_id, peer_id, node.address, node.port, node.shared_port])
					remove_peer(peer_id)
					continue
				node.is_connected_to_mesh = true
				push_warning("[%d] Connected to mesh node %d at %s:%d at port %d" % [node.my_id, peer_id, node.address, node.port, node.shared_port])
			elif service_data[0] != ENetConnection.EventType.EVENT_NONE:
				push_error("[%d] %s from mesh node %d at %s:%d at port %d" % [node.my_id, EVENT_TYPE_MESSAGE[service_data[0]], peer_id, node.address, node.port, node.shared_port])
				push_error(service_data)
				remove_peer(peer_id)


func start_mesh_discovery() -> Error:
	if discovery_socket != null:
		return OK # Already started

	discovery_socket = PacketPeerUDP.new()
	discovery_socket.set_broadcast_enabled(true)

	var result: Error = discovery_socket.bind(DISCOVERY_PORT)
	if result != OK:
		discovery_socket.close()
		result = discovery_socket.bind(0) # Try any available port
	
	if result != OK:
		push_error("Failed to bind discovery socket on port %d" % DISCOVERY_PORT)
		discovery_socket = null
		return result

	# Setup multiplayer peer
	my_peer = ENetMultiplayerPeer.new()
	my_peer.peer_disconnected.connect(_on_peer_disconnected)

	# Enable processing
	set_process(true)

	# Setup periodic discovery broadcast timer
	discovery_timer = Timer.new()
	discovery_timer.wait_time = DISCOVERY_BROADCAST_INTERVAL
	discovery_timer.autostart = true
	discovery_timer.timeout.connect(_discovery_broadcast)
	add_child(discovery_timer)
	# Initial broadcast
	_discovery_broadcast.call_deferred()
	return OK


func stop_mesh_discovery() -> void:
	# Stop discovery processing
	if my_peer == null:
		return # Not running

	# Disable processing
	set_process(false)
	
	# Stop and free discovery resources
	discovery_timer.queue_free()
	discovery_socket.close()
	discovery_socket = null

	# Disconnect multiplayer peer signals
	my_peer.close()
	my_peer.peer_disconnected.disconnect(_on_peer_disconnected)
	my_peer = null

	# Reset id and peers
	for peer_id in mesh_nodes.keys():
		remove_peer(peer_id)
	mesh_nodes.clear()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().root.set_multiplayer_authority(1, true)


func _discovery_broadcast() -> void:
	var message = JSON.stringify({
		type = "discovery",
	}).to_utf8_buffer()
	discovery_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	discovery_socket.put_packet(message)


func _discovery_loop() -> void:
	while discovery_socket.is_bound() and discovery_socket.get_available_packet_count() > 0:
		# Packet must be grabbed first before other info is available
		var packet: PackedByteArray = discovery_socket.get_packet()
		var peer_address = discovery_socket.get_packet_ip()
		var peer_port = discovery_socket.get_packet_port()

		# filter out invalid packets
		if packet.size() == 0 or peer_address == "" or peer_port == 0:
			continue

		if IP.get_local_addresses().has(peer_address) and peer_port == discovery_socket.get_local_port():
			continue # Ignore our own packets

		# Our packet data is JSON encoded
		var packet_data = packet.get_string_from_utf8()

		var json = JSON.new()
		if json.parse(packet_data) != OK:
			# push_warning("Received invalid JSON packet from %s:%d" % [peer_address, peer_port])
			# push_error(json.get_error_message())
			continue # Invalid JSON
		var peer_data = json.data

		# push_warning("Received packet from %s:%d (%s, %d)" % [peer_address, peer_port])
		# push_warning(peer_data)
		
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


func _on_peer_discovered(address: String, port: int) -> void:
	var peer_id: int = get_peer_id(address, port)

	if discovery_socket.get_local_port() == DISCOVERY_PORT:
		# Notify other local peers about the new node
		# This is a relay for nodes that are not listening to broadcasts
		for node in mesh_nodes.values():
			if node.peer_id == peer_id:
				continue
			var is_local: bool = IP.get_local_addresses().has(node.address)
			if not is_local or node.port == DISCOVERY_PORT:
				continue
			discovery_socket.set_dest_address(node.address, node.port)
			discovery_socket.put_packet(JSON.stringify({
				type = "discovery",
				address = address,
				port = port,
			}).to_utf8_buffer())

	if has_peer(peer_id):
		return
	
	# push_warning("Discovered peer %d at %s:%d" % [peer_id, address, port])
	discovery_socket.set_dest_address(address, port)
	discovery_socket.put_packet(JSON.stringify({
		type = "join_mesh",
		peer_id = peer_id,
	}).to_utf8_buffer())


func _on_mesh_joined(address: String, port: int, my_id: int) -> void:
	var peer_id: int = get_peer_id(address, port)

	if not is_peer_connected(peer_id):
		_setup_mesh_handshake(my_id, peer_id, address, port)

		# Acknowledge by sending back our join mesh request
		discovery_socket.set_dest_address(address, port)
		discovery_socket.put_packet(JSON.stringify({
			type = "join_mesh",
			peer_id = peer_id,
		}).to_utf8_buffer())


func _setup_mesh_handshake(my_id: int, peer_id: int, peer_address: String, peer_port: int) -> void:
	var node: MeshNode = mesh_nodes.get(peer_id, null)
	if not node:
		node = MeshNode.new()
		node.my_id = my_id
		node.peer_id = peer_id
		node.address = peer_address
		node.port = peer_port
		node.peer = ENetConnection.new()
		mesh_nodes[peer_id] = node

	var should_host: bool = my_id < peer_id
	if should_host:
		if node.shared_port == -1:
			node.shared_port = get_next_port()
			# push_warning("[%d] Attempting to connect to mesh node %d at %s:%d via port %d" % [node.my_id, peer_id, peer_address, peer_port, node.shared_port])
			if node.peer.create_host_bound("*", node.shared_port, 1) != OK:
				# we'll try again later
				node.shared_port = -1
		
		if node.shared_port != -1:
			discovery_socket.set_dest_address(peer_address, peer_port)
			discovery_socket.put_packet(JSON.stringify({
				type = "connect_to_mesh",
				shared_port = node.shared_port,
			}).to_utf8_buffer())
		

func _on_mesh_connect(address: String, port: int, shared_port: int) -> void:
	var peer_id: int = get_peer_id(address, port)
	var node: MeshNode = mesh_nodes.get(peer_id, null)
	if not node or node.shared_port != -1:
		return # Already connecting or invalid
	# push_warning("[%d] Connecting to mesh node %d at %s:%d via port %d" % [node.my_id, peer_id, address, port, shared_port])
	node.shared_port = shared_port
	node.peer.create_host(1)
	node.peer.connect_to_host(address, shared_port)

func _on_peer_disconnected(peer_id: int) -> void:
	var node: MeshNode = mesh_nodes.get(peer_id, null)
	if node:
		push_warning("[%d] Peer %d disconnected" % [node.my_id, peer_id])
		return
	remove_peer(peer_id)
