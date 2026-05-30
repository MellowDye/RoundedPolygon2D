@tool
## A 2D polygon with rounded corners.
extends Polygon2D
class_name RoundedPolygon2D

## Sets the corner radius of all vertices of the polygon.
@export_range(0, 1, 1, "or_greater", "suffix:px") var corner_radius: int = 0:
	set(v):
		corner_radius = v
		_check_drawing_mode()
		queue_redraw()

## Sets the number of divisions each corner has.
@export_range(0, 20, 1) var corner_detail: int = 8:
	set(v):
		corner_detail = v
		_check_drawing_mode()
		queue_redraw()

## If [code]true[/code], makes both sides of the rounded corners the same width if one of the sides
## is capped when the corner radius is bigger than the space available, making it more
## circular at high radius values.
@export var uniform_corners: bool = true:
	set(v):
		uniform_corners = v
		_check_drawing_mode()
		queue_redraw()


## The computed polygon with rounded corners.
var rounded_polygon: PackedVector2Array
## The computed vertex colors from the rounded corners.
var rounded_vertex_colors: PackedColorArray
## The computed uv with rounded corners.
var rounded_uv: PackedVector2Array

const Utils = preload("res://addons/RoundedPolygon2D/Utils.gd")

func _check_drawing_mode() -> void:
	# Toggles the default Polygon2D if rounding is not necessary
	if corner_radius == 0 or corner_detail == 0:
		polygons.clear()
	else:
		polygons = [null]

func _draw() -> void:
	if polygon.size() < 3:
		return

	if not corner_radius or not corner_detail:
		return

	polygons = [null]

	rounded_polygon = _build_rounded_polygon()
	rounded_vertex_colors = _build_vertex_colors()
	rounded_uv = _build_rounded_uv()

	draw_polygon(rounded_polygon, rounded_vertex_colors, rounded_uv, texture)

	# Debug
	#draw_polyline(rounded_polygon, Color.RED, 2)
	#for point in rounded_polygon:
		#draw_circle(point, 2, Color("white", 0.5))

func _build_rounded_polygon() -> PackedVector2Array:
	var points: PackedVector2Array

	for i in polygon.size():
		var point: Vector2 = polygon[i]
		var point_before: Vector2 = polygon[i - 1]
		var point_after: Vector2 = polygon[(i + 1) % polygon.size()]
		var direction_b: Vector2 = point.direction_to(point_before)
		var direction_a: Vector2 = point.direction_to(point_after)
		var distance_a: float = corner_radius
		var distance_b: float = corner_radius

		# Locks the anchors in case the middle point between the points is smaller
		# than the corner radius
		# NOTE: mid point is moved backwards to avoid overlapping
		if uniform_corners:
			var mid_point = min(point.distance_to(point_before), point.distance_to(point_after)) / 2.0
			mid_point -= 0.1
			if corner_radius > mid_point:
				distance_a = mid_point
				distance_b = mid_point
		else:
			var mid_point_b = point.distance_to(point_before) / 2.0 - 0.1
			if corner_radius > mid_point_b:
				distance_b = mid_point_b

			var mid_point_a = point.distance_to(point_after) / 2.0 - 0.1
			if corner_radius > mid_point_a:
				distance_a = mid_point_a

		var anchor_before: Vector2 = point + direction_b * distance_b
		var anchor_after: Vector2 = point + direction_a * distance_a

		# Build arc
		var arc_points: PackedVector2Array
		for j in range(1, corner_detail):
			var arc_point: Vector2 = anchor_before.bezier_interpolate(
				point.lerp(anchor_before, 0.5),
				point.lerp(anchor_after, 0.5),
				anchor_after,
				float(j) / corner_detail
			)
			arc_points.append(arc_point)

		points.append(anchor_before)
		points.append_array(arc_points)
		points.append(anchor_after)
	return points

func _build_rounded_uv() -> PackedVector2Array:
	if not texture:
		return []

	var points: PackedVector2Array

	for i in range(polygon.size()):
		var polygon_triangle: PackedVector2Array
		var uv_triangle: PackedVector2Array

		if polygon.size() != uv.size():
			return []

		# Get triangles
		for j in range(-1, 2):
			var polygon_index = posmod(i + j, polygon.size())
			polygon_triangle.append(polygon[polygon_index])
			uv_triangle.append(uv[polygon_index])

		for j in range(corner_detail + 1):
			var corner_point = rounded_polygon[(i * (corner_detail + 1) + j) % rounded_polygon.size()]
			var polygon_bary = Utils.get_2d_triangle_barycentric_coords(
				corner_point,
				polygon_triangle[0],
				polygon_triangle[1],
				polygon_triangle[2],
				)
			var uv_point = Utils.barycentric_coords_to_cartesian(uv_triangle, polygon_bary)
			uv_point /= texture.get_size()
			points.append(uv_point)

	return points

func _build_vertex_colors() -> PackedColorArray:
	if not vertex_colors:
		return [color]

	var colors: PackedColorArray
	for i in range(polygon.size()):
		var polygon_triangle: PackedVector2Array
		var mix_colors: PackedColorArray

		for j in range(-1, 2):
			var polygon_index = posmod(i + j, polygon.size())
			polygon_triangle.append(polygon[polygon_index])

			# In case that there aren't enough vertex colors for each vertex of the polygon
			# it will use the polygon's color, funny that Polygon2D says that it does
			# has the same functionality but as for godot 4.4 it isn't working
			if polygon_index >= vertex_colors.size():
				mix_colors.append(color)
			else:
				mix_colors.append(vertex_colors[polygon_index])

		# Color each vertex using the barycentric coordenates
		for j in range(corner_detail + 1):
			var corner_point = rounded_polygon[(i * (corner_detail + 1) + j) % rounded_polygon.size()]
			var bary = Utils.get_2d_triangle_barycentric_coords(
				corner_point,
				polygon_triangle[0],
				polygon_triangle[1],
				polygon_triangle[2],
				)
			var mix_weights: PackedFloat32Array = [bary[0], bary[1], bary[2]]
			colors.append(Utils.mix_colors(mix_colors, mix_weights))
	return colors
