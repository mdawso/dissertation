extends Node2D

@onready var layer_0: TileMapLayer = %Layer0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Globals.Map = layer_0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
