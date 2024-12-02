extends CharacterBody2D

var peer : StreamPeerTCP
const TCP_IP : String = "127.0.0.1"
const TCP_PORT : int = 9876

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

const SIGHT_RANGE : int = 2
var numOfObservations : int = (2*SIGHT_RANGE+1)**2

const observing : bool = true # bool to toggle all data gathering for model, debug

@onready var finish_line_raycast: RayCast2D = %FinishLineRaycast

@onready var debug_finish_line_vector: Line2D = %DEBUG_FinishLineVector
@onready var debug_finish_line_vector_length_label: Label = %DEBUG_FinishLineVectorLengthLabel
@onready var debug_state_label: Label = %DEBUG_StateLabel
@onready var debug_visible_tile_labels: Node2D = %DEBUG_VisibleTileLabels

var spawnPosition : Vector2

func reset():
	self.global_position = spawnPosition

func _ready() -> void:
	Globals.AIPlayer = self
	spawnPosition = self.global_position
	peer = StreamPeerTCP.new()
	peer.connect_to_host(TCP_IP,TCP_PORT)
	peer.poll()
	if peer.get_status() == 2: # 2 is status connected
		print("%s Connected" % [self])
		var setupData : Dictionary = {"numOfObservations":numOfObservations, "numOfActions": 5}
		peer.put_data(JSON.stringify(setupData).to_ascii_buffer())

func _physics_process(delta: float) -> void:
	
	move_and_slide()
	
	# apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# gather data
	
	var dataToSend : String = "No Data!"
	
	if observing:
	
		var visibleTiles : Dictionary = {}
		var distToFinishLine : float = 0
		var reward : float = 0
		var finishLineVisible : bool = false
		
		if debug_visible_tile_labels.visible:
			for n in debug_visible_tile_labels.get_children():
				debug_visible_tile_labels.remove_child(n)
				n.queue_free() 
		
		if Globals.Map:
			
			var playerPosOnMap : Vector2 = Globals.Map.local_to_map(position)
			
			for x in range(playerPosOnMap.x - SIGHT_RANGE, playerPosOnMap.x + SIGHT_RANGE + 1): # +1 because the max is exclusive
				for y in range(playerPosOnMap.y - SIGHT_RANGE, playerPosOnMap.y + SIGHT_RANGE + 1):
					
					var coordinates : Vector2 = Vector2i(x,y)
					var cellTileData : TileData = Globals.Map.get_cell_tile_data(coordinates)
					
					if cellTileData:
						if cellTileData.get_collision_polygons_count(0) > 0:
							var lenOfVecToTile : float = (Globals.Map.map_to_local(coordinates) - self.position).length()
							visibleTiles[coordinates] = lenOfVecToTile
					else:
						visibleTiles[coordinates] = false
						
					if debug_visible_tile_labels.visible:
						var newLabel : Label = Label.new()
						newLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						newLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
						newLabel.position = Globals.Map.map_to_local(coordinates) + Vector2(-5,-12.5) # this is added to line the numbers up to the centres of the tiles
						newLabel.text = str(1 if visibleTiles[coordinates] else 0)
						debug_visible_tile_labels.add_child(newLabel)
		
		if Globals.FinishLine:
			var vecToFinishLine : Vector2 = Globals.FinishLine.global_position - self.global_position
			finish_line_raycast.set_target_position(vecToFinishLine)
			distToFinishLine = vecToFinishLine.length()
			finishLineVisible = not finish_line_raycast.is_colliding()
			if debug_finish_line_vector.visible:
				debug_finish_line_vector.points[1] = vecToFinishLine
				debug_finish_line_vector.default_color = Color.GREEN if finishLineVisible else Color.RED
			if debug_finish_line_vector_length_label.visible:
				debug_finish_line_vector_length_label.position = vecToFinishLine/2 + Vector2(0,-30)
				debug_finish_line_vector_length_label.text = str(vecToFinishLine.length())
		
		var gatheredDataDict : Dictionary = {"visibleTiles": visibleTiles, "distToFinishLine": distToFinishLine, "finishLineVisible": finishLineVisible}
		dataToSend = JSON.stringify(gatheredDataDict)
	
	peer.poll()
	
	if peer.get_status() == 2:
		
		peer.put_data(dataToSend.to_ascii_buffer())
		
		# recieve data from python and process it
		
		var available_bytes : int = peer.get_available_bytes()
		if available_bytes > 0:
			
			var packetString : String = peer.get_string(available_bytes)
			print("Recieved data: " + packetString)
			
			# FIXME this is a horrible way of doing this make a proper buffer you poof
			var splitStrings : Array = packetString.split("|",false) # this handles a case where multiple json strings are sent in one packet
			
			if splitStrings.size() > 1:
				print("Multiple json strngs detected!")
			
			for s : String in splitStrings:
				
				var data : Dictionary = JSON.parse_string(s)
				
				if debug_state_label.visible:
					debug_state_label.text = "direction : " + data.direction + "\n" + "jump : " + str(data.jump)
				
				if data.direction == "left":
					velocity.x = -SPEED
				elif data.direction == "right":
					velocity.x = SPEED
				elif data.jump == true and is_on_floor():
					velocity.y = JUMP_VELOCITY
