extends CharacterBody2D

var peer : StreamPeerTCP
const TCP_IP : String = "127.0.0.1"
const TCP_PORT : int = 9876

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

const SIGHT_RANGE = 2

@onready var finish_line_raycast: RayCast2D = %FinishLineRaycast

@onready var debug_state_label: Label = %DEBUG_StateLabel
@onready var debug_visible_tile_labels: Node2D = %DEBUG_VisibleTileLabels


func _ready() -> void:
	Globals.AIPlayer = self
	peer = StreamPeerTCP.new()
	peer.connect_to_host(TCP_IP,TCP_PORT)
	peer.poll()
	if peer.get_status() == 2: # 2 is status connected
		print("%s Connected" % [self])
		peer.put_data(("Hello from %s" % [self]).to_ascii_buffer())

func _physics_process(delta: float) -> void:
	
	# apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# gather data
	var visibleTiles : Dictionary = {}
	var distToFinishLine : float = 0
	var finishLineVisible : bool = false
	
	if debug_visible_tile_labels.visible:
		for n in debug_visible_tile_labels.get_children():
			debug_visible_tile_labels.remove_child(n)
			n.queue_free() 
	
	if Globals.Map:
		
		var playerPosOnMap : Vector2 = Globals.Map.local_to_map(position)
		
		for x in range(playerPosOnMap.x - SIGHT_RANGE, playerPosOnMap.x + SIGHT_RANGE + 1): # +1 because the max is exclusive
			for y in range(playerPosOnMap.y - SIGHT_RANGE, playerPosOnMap.y + SIGHT_RANGE + 1):
				
				var coordinates = Vector2i(x,y)
				var cellTileData = Globals.Map.get_cell_tile_data(coordinates)
				
				if cellTileData:
					if cellTileData.get_collision_polygons_count(0) > 0:
						var lenOfVecToTile = (Globals.Map.map_to_local(coordinates) - self.position).length()
						visibleTiles[coordinates] = lenOfVecToTile
				else:
					visibleTiles[coordinates] = false
					
				if debug_visible_tile_labels.visible:
					var newLabel = Label.new()
					newLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					newLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					newLabel.position = Globals.Map.map_to_local(coordinates) + Vector2(-5,-12.5) # this is added to line the numbers up to the centres of the tiles
					newLabel.text = str(1 if visibleTiles[coordinates] else 0)
					debug_visible_tile_labels.add_child(newLabel)
	
	if Globals.FinishLine:
		var vecToFinishLine = Globals.FinishLine.position - self.position
		finish_line_raycast.set_target_position(vecToFinishLine)
		distToFinishLine = vecToFinishLine.length()
		finishLineVisible = not finish_line_raycast.is_colliding()
		
		
	var gatheredDataDict = {"visibleTiles": visibleTiles, "distToFinishLine": distToFinishLine, "finishLineVisible": finishLineVisible}
	var dataToSend = JSON.stringify(gatheredDataDict)
	
	peer.poll()
	
	if peer.get_status() == 2:
		
		peer.put_data(dataToSend.to_ascii_buffer())
		
		# recieve data from python and process it
		
		var available_bytes = peer.get_available_bytes()
		if available_bytes > 0:
			var packetString = peer.get_string(available_bytes)
			var data = JSON.parse_string(packetString)
			print("Recieved data: " + packetString)
			
			if data:
				
				if debug_state_label.visible:
					debug_state_label.text = "direction : " + data.direction + "\n" + "jump : " + str(data.jump)
				
				if data.direction == "left":
					velocity.x = -SPEED
				elif data.direction == "right":
					velocity.x = SPEED
				elif data.jump == true and is_on_floor():
					velocity.y = JUMP_VELOCITY

	move_and_slide()
