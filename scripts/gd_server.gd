extends Node

var server : UDPServer
var peers : Array = []

const UDP_IP : String = "127.0.0.1"
const UDP_PORT : int = 9876

func _ready() -> void:
	server = UDPServer.new()
	server.listen(UDP_PORT, UDP_IP)

func _process(_delta : float) -> void:
	server.poll()
	
	# handle incoming connections
	if server.is_connection_available():
		var peer: PacketPeerUDP = server.take_connection()
		peers.append(peer)
		
		# Recieve data
		var packet = peer.get_packet()
		print("Accepted peer: %s:%s" % [peer.get_packet_ip(), peer.get_packet_port()])
		print("Received data: %s" % [packet.get_string_from_utf8()])
		
		# Send data
		peer.put_packet("Godot Handshake".to_ascii_buffer())

	
