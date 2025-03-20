extends Node

var Player : CharacterBody2D
var AIPlayer : CharacterBody2D

var FinishLine : Area2D

func isWithinFinishLineGlobalBounds(point : Vector2):
	var bl = FinishLine.global_position
	var tr = Vector2(FinishLine.global_position.x + FinishLine.collision_shape_2d.shape.size.x, FinishLine.global_position.y + FinishLine.collision_shape_2d.shape.size.y)
	if point.x > bl.x and point.x < tr.x and point.y > bl.y and point.y < bl.y: return true 
	else: return false

var Map : TileMapLayer
