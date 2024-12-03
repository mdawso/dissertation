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

var packet : String

func dict_to_string(dict : Dictionary) -> String:
	return JSON.stringify(dict)
	
func string_to_dict(string : String) -> Dictionary:
	return JSON.parse_string(string)

# observe to return dictionary of all the tiles the player can see
func observe() -> Dictionary:
	
	# gather data
	
	var visibleTiles : Dictionary = {}
	
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

	var returnData : Dictionary = {"type" : "observation", "observation" : visibleTiles}
	return returnData

# action to act on data send back by model
func action(delta : float, data : Dictionary) -> void:
	
	# apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	if debug_state_label.visible:
		debug_state_label.text = "action: "+ data.action

	if data.action == "left":
		velocity.x = -SPEED
	elif data.action == "right":
		velocity.x = SPEED
	elif data.action == "jump" and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	move_and_slide()
	
# reward to reward the model
func reward() -> int:
	
	var distToFinishLine : float = INF
	var finishLineVisible : bool = false
	var r : int = 0
	
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
				
	return r

func reset() -> void:
	self.global_position = spawnPosition

func _ready() -> void:
	Globals.AIPlayer = self
	spawnPosition = self.global_position
	peer = StreamPeerTCP.new()
	peer.connect_to_host(TCP_IP,TCP_PORT)
	peer.set_no_delay(true)
	peer.poll()
	if peer.get_status() == 2: # 2 is status connected
		print("%s Connected" % [self])
		var setupData : Dictionary = {"type": "init", "numOfObservations":numOfObservations, "numOfActions": 5}
		peer.put_data(JSON.stringify(setupData).to_utf8_buffer())

func _process(delta : float) -> void:
	
	peer.poll()
	if peer.get_status() == peer.STATUS_CONNECTED:
		var a_bytes = peer.get_available_bytes()
		if a_bytes > 0:
			packet = peer.get_utf8_string(a_bytes)
			var packetJSON = JSON.parse_string(packet)
		
			
			
	

func _physics_process(delta : float) -> void:
	pass
	peer.poll()
	if peer.get_status() == peer.STATUS_CONNECTED:
		var a_bytes = peer.get_available_bytes()
		if a_bytes > 0:
			packet = peer.get_utf8_string(a_bytes)
			var packetJSON = JSON.parse_string(packet)
			
			if packetJSON:
		
				if packetJSON["type"] == "action":
					action(delta, packetJSON)
				
				if packetJSON["type"] == "observe_request":
					var visible_tiles = observe()
					visible_tiles = JSON.stringify(visible_tiles)
					peer.put_data(visible_tiles.to_utf8_buffer())
								
				if packetJSON["type"] == "reward_request":
					var r = reward()
					var rewardDict = {"type": "reward", "reward": r}
					rewardDict = JSON.stringify(rewardDict)
					peer.put_data(rewardDict.to_utf8_buffer())
					
				peer.put_data("ack".to_utf8_buffer())
