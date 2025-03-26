extends CharacterBody2D

var peer : StreamPeerTCP
const TCP_IP : String = "127.0.0.1"
const TCP_PORT : int = 9876

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

const SIGHT_RANGE : int = 3
var numOfObservations : int = (2*SIGHT_RANGE+1)**2

var deathPenalty = false
var winReward = false

const observing : bool = true # bool to toggle all data gathering for model, debug

@onready var finish_line_raycast: RayCast2D = %FinishLineRaycast

@onready var debug_finish_line_vector: Line2D = %DEBUG_FinishLineVector
@onready var debug_finish_line_vector_length_label: Label = %DEBUG_FinishLineVectorLengthLabel
@onready var debug_state_label: Label = %DEBUG_StateLabel
@onready var debug_visible_tile_labels: Node2D = %DEBUG_VisibleTileLabels

var spawnPosition : Vector2

var previousDistToFinishLine : float = 1000

func apply_death_penalty():
	deathPenalty = true
	
func apply_win_reward():
	winReward = true

# observe to return dictionary of all the tiles the player can see
func observe() -> Dictionary:
	
	# gather data
	
	#print("observe start")
	
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
						#var lenOfVecToTile : float = (Globals.Map.map_to_local(coordinates) - self.position).length()
						#visibleTiles[coordinates] = lenOfVecToTile
						visibleTiles[coordinates] = 1
				else: 
					var point = Globals.Map.map_to_local(coordinates)
					if Globals.isWithinFinishLineBounds(point): visibleTiles[coordinates] = 2
					else: visibleTiles[coordinates] = 0
					
				if debug_visible_tile_labels.visible:
					var newLabel : Label = Label.new()
					newLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					newLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					newLabel.position = Globals.Map.map_to_local(coordinates) + Vector2(-5,-12.5) # this is added to line the numbers up to the centres of the tiles
					newLabel.text = str(visibleTiles[coordinates])
					debug_visible_tile_labels.add_child(newLabel)
					
	#print("observe end")
	
	return visibleTiles

# action to act on data send back by model
func action(delta : float, data : int) -> void:
	
	# apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	if debug_state_label.visible:
		debug_state_label.text = "action: "+ str(data)

	if data == 0:
		velocity.x = -SPEED
	elif data == 1:
		velocity.x = SPEED
	elif data == 2 and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	move_and_slide()
	
# reward to reward the model
func reward() -> float:
	
	var hasGotCloser : bool = false
	var distToFinishLine : float = 1000
	var finishLineVisible : bool = false
	var r : float = 0
	
	if Globals.FinishLine:
			
			var vecToFinishLine : Vector2 = Globals.FinishLine.global_position - self.global_position
			finish_line_raycast.set_target_position(vecToFinishLine)
			distToFinishLine = vecToFinishLine.length()
			finishLineVisible = not finish_line_raycast.is_colliding()
			
			hasGotCloser = true if distToFinishLine < previousDistToFinishLine else false
			previousDistToFinishLine = distToFinishLine
			
			if debug_finish_line_vector.visible:
				debug_finish_line_vector.points[1] = vecToFinishLine
				debug_finish_line_vector.default_color = Color.GREEN if finishLineVisible else Color.RED
			
			if debug_finish_line_vector_length_label.visible:
				debug_finish_line_vector_length_label.position = vecToFinishLine/2 + Vector2(0,-30)
				debug_finish_line_vector_length_label.text = str(vecToFinishLine.length())
		
	if deathPenalty == true: return -10
	elif winReward == true: return 30
	elif hasGotCloser: return 1
	else: return -1

func reset() -> void:
	self.global_position = spawnPosition

func _ready() -> void:
	Globals.AIPlayer = self
	spawnPosition = self.global_position
	print("%s observations" % [numOfObservations])
	peer = StreamPeerTCP.new()
	peer.connect_to_host(TCP_IP,TCP_PORT)
	peer.poll()
	if peer.get_status() == peer.STATUS_CONNECTED:
		print("%s Connected" % [self])

func _physics_process(delta: float) -> void:
	
	if peer.get_status() == peer.STATUS_CONNECTED:
		
		# first we send the reward and from the previous frame and the current state
		var model_reward : float = reward()
		peer.put_float(model_reward)
		peer.poll()
		var next_state : Dictionary = observe()
		var next_state_encoded : PackedByteArray = JSON.stringify(next_state).to_utf8_buffer()
		peer.put_data(next_state_encoded)
		peer.poll()
		
		# wait for a message saying the python script is ready to start a new loop
		peer.poll()
		var _isready : String = peer.get_string(5)
		#print(ready)
		
		deathPenalty = false
		winReward = false
		
		# we make an observation and send to python
		var visibleTiles : Dictionary = observe()
		var visibleTilesEncoded : PackedByteArray = JSON.stringify(visibleTiles).to_utf8_buffer()
		peer.put_data(visibleTilesEncoded)
		peer.poll()
		
		# next we wait for python to respond then act based on the model's output
		# 0 = move left
		# 1 = move right
		# 2 = jump
		
		peer.poll()
		var model_action : int = peer.get_u8()
		action(delta, model_action)
		
