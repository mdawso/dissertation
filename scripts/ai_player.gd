extends CharacterBody2D

var peer : StreamPeerTCP
const TCP_IP : String = "127.0.0.1"
const TCP_PORT : int = 9876

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var state_label: Label = %StateLabel

func _ready() -> void:
	Globals.AIPlayer = self
	peer = StreamPeerTCP.new()
	peer.connect_to_host(TCP_IP,TCP_PORT)
	peer.poll()
	if peer.get_status() == 2: # 2 is status connected
		print("%s Connected" % [self])
		peer.put_data(("Hello from %s" % [self]).to_ascii_buffer())

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	peer.poll()
	
	if peer.get_status() == 2:
		
		# recieve data from python and process it
		var available_bytes = peer.get_available_bytes()
		if available_bytes > 0:
			var packetString = peer.get_string(available_bytes)
			var data = JSON.parse_string(packetString)
			print(data)
			
			state_label.text = data.move
			
			if data.move == "left":
				velocity.x = -SPEED
			elif data.move == "right":
				velocity.x = SPEED
			elif data.move == "jump" and is_on_floor():
				velocity.y = JUMP_VELOCITY
			
			peer.put_data("godot processed data".to_ascii_buffer())
			
		# send back response
		# TODO send data
		# tiles around player
		# distance to goal

	move_and_slide()
