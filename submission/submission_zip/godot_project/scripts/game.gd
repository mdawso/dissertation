extends Node2D

@onready var world: Node2D = %World
@onready var spawns: Node2D = %Spawns

const PLAYER_SPAWN = preload("res://scenes/player_spawn.tscn")
const AI_SPAWN = preload("res://scenes/ai_spawn.tscn")
const PILLAR_MAP_BASE = preload("res://scenes/pillar_map_base.tscn")
const SNAKE_MAP_BASE = preload("res://scenes/snake_map_base.tscn")
const PLATFORM_MAP_BASE = preload("res://scenes/platform_map_base.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	world.remove_child(world.get_child(0)) # get rid of the existing child, we have this cuz it makes using the editor a bit easier
	var newMap : TileMapLayer
	match MapSettings.MapType:
		0:
			newMap = PILLAR_MAP_BASE.instantiate()
		1:
			newMap = SNAKE_MAP_BASE.instantiate()
		2:
			newMap = PLATFORM_MAP_BASE.instantiate()
	world.add_child(newMap)
	Globals.Map = newMap
	
	spawns.add_child(AI_SPAWN.instantiate())
	if MapSettings.PlayerEnabled: spawns.add_child(PLAYER_SPAWN.instantiate())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
