extends Polygon2D # Works similarly for CollisionPolygon2D

func _ready() -> void:
	# 1. Define four Vector2 points in local coordinates
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0),       # Top-Left
		Vector2(200, 0),     # Top-Right
		Vector2(200, 200),   # Bottom-Right
		Vector2(0, 200)      # Bottom-Left
	])
	
	# 2. Assign the points array to the polygon property
	self.polygon = points
