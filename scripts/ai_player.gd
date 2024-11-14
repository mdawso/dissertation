extends CharacterBody2D

var peer : StreamPeerTCP
const TCP_IP : String = "127.0.0.1"
const TCP_PORT : int = 9876

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

const SIGHT_RANGE = 2

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
		
		# send data to python
		var visibleTiles = {}
		var playerPos = Globals.Map.local_to_map(position)
		
		for x in range(playerPos.x - SIGHT_RANGE, playerPos.x + SIGHT_RANGE + 1): # godot is really annoying here, +1 because the max is exclusive
			for y in range(playerPos.y - SIGHT_RANGE, playerPos.y + SIGHT_RANGE + 1):
				var coordinates = Vector2i(x,y)
				var cellTileData = Globals.Map.get_cell_tile_data(coordinates)
				if cellTileData:
					if cellTileData.get_collision_polygons_count(0) > 0:
						visibleTiles[coordinates] = 1
				else:
					visibleTiles[coordinates] = 0
		
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
				
			peer.put_data("Got it!".to_ascii_buffer())

	move_and_slide()
