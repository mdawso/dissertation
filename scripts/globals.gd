extends Node

var Player : CharacterBody2D
var AIPlayer : CharacterBody2D

var FinishLine : Area2D

func isWithinFinishLineBounds(point : Vector2) -> bool:
	var bottomleft : Vector2 = FinishLine.position
	var topright : Vector2 = Vector2(FinishLine.position.x + FinishLine.collision_shape_2d.shape.size.x, FinishLine.position.y + FinishLine.collision_shape_2d.shape.size.y)
	if point.x >= bottomleft.x and point.x <= topright.x and -point.y >= bottomleft.y and -point.y <= topright.y: return true
	else: return false

var Map : TileMapLayer
