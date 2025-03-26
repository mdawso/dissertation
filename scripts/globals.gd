extends Node

var Player : CharacterBody2D
var AIPlayer : CharacterBody2D

var FinishLine : Area2D

func isWithinFinishLineBounds(point : Vector2):
	var bl = FinishLine.position
	var tr = Vector2(FinishLine.position.x + FinishLine.collision_shape_2d.shape.size.x, FinishLine.position.y + FinishLine.collision_shape_2d.shape.size.y)
	if point >= bl and point <= tr: return true
	else: return false

var Map : TileMapLayer
