extends Node
# this script is from a test - do not reenable
#
#var server : UDPServer
#var peer : PacketPeerUDP
#
#const UDP_IP : String = "127.0.0.1"
#const UDP_PORT : int = 9876
#
#func _ready() -> void:
	#server = UDPServer.new()
	#server.listen(UDP_PORT, UDP_IP)
#
#func _physics_process(_delta : float) -> void:
	#server.poll()
	#
	## handle incoming connection
	#if server.is_connection_available():
		#peer = server.take_connection()
		#
		## Receive data
		#var packet = peer.get_packet()
		#print("Accepted peer: %s:%s" % [peer.get_packet_ip(), peer.get_packet_port()])
		#print("Received data: %s" % [packet.get_string_from_utf8()])
		#
		## Send data
		#peer.put_packet("Godot Handshake".to_ascii_buffer())
	#
	#if peer:
		#var packet = peer.get_packet()
		#if packet:
			#print("Recieved data: %s" % [packet.get_string_from_utf8()])
