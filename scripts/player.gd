extends CharacterBody2D

@onready var sprite_2d: Sprite2D = %Sprite2D
@onready var timer_label: Label = %TimerLabel
@onready var time_to_beat_label: Label = %TimeToBeatLabel

const SPEED = 300.0
const JUMP_VELOCITY = -400

var timer : float
var timerRunning : bool
var finished : bool = true

var spawnPoint : Vector2

func reset() -> void:
	pass
	#self.global_position = spawnPoint

func start_timer() -> void:
	finished = false
	timerRunning = true

func _ready() -> void:
	timer = 0
	Globals.Player = self
	spawnPoint = self.global_position

func _physics_process(delta: float) -> void:
	
	time_to_beat_label.text = "Time to beat: " + str(snapped(Globals.timeToBeat, 0.01))
	timer_label.text = "Your time: " + str(snapped(timer, 0.01))
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if not finished:
		# Handle jump.
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# Get the input direction and handle the movement/deceleration.
		var direction := Input.get_axis("left", "right")
		
		if direction:
			velocity.x = direction * SPEED
			sprite_2d.flip_h = true if direction < 0 else false # Flip the sprite based on direction
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	
	if timerRunning:
		increment_timer(delta)
	
func increment_timer(delta : float) -> void:
	timer += delta
	
func stop_timer() -> void:
	timerRunning = false
	finished = true
