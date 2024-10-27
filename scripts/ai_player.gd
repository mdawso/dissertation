extends CharacterBody2D

var peer : StreamPeerTCP
const TCP_IP : String = "127.0.0.1"
const TCP_PORT : int = 9876

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

func _ready() -> void:
	Globals.AIPlayer = self
	peer = StreamPeerTCP.new()
	peer.connect_to_host(TCP_IP,TCP_PORT)
	peer.poll()
	if peer.get_status() == StreamPeerTCP.Status.STATUS_CONNECTED:
		print("%s Connected" % [self])
		peer.put_data(("Hello from %s" % [self]).to_ascii_buffer())

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if peer:
		peer.poll()
		var data = peer.get_data(8)
		if data:
			print(data)

	move_and_slide()
