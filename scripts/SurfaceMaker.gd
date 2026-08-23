@tool
class_name SurfaceMarker
extends Node3D
## A selectable site pinned to a lat/lon on the globe. Lives as a child of the
## Globe node so it inherits the planet's rotation automatically.

## Sit fractionally proud of the surface so the billboard doesn't z-fight the sphere.
const SURFACE_OFFSET := 1.004

@export var site_name: String = "Site":
	set(value):
		site_name = value
		name = "Marker_" + value.replace(" ", "_")
@export_range(-90.0, 90.0) var latitude: float = 0.0:
	set(value):
		latitude = value
		_reposition()
@export_range(-180.0, 180.0) var longitude: float = 0.0:
	set(value):
		longitude = value
		_reposition()
@export var marker_size: float = 0.07:
	set(value):
		marker_size = value
		if _mesh and _mesh.mesh is QuadMesh:
			(_mesh.mesh as QuadMesh).size = Vector2(value, value)

## false = sitting on the sphere, true = sitting on the flat unfolded map.
## Set by MarkerLayer, which mirrors the globe shader's own flatten toggle,
## so markers and coastlines jump together with no in-between animation.
var flatten: float = 0:
	set(value):
		flatten = value
		_reposition()

## Arbitrary payload so game code can hang mission data off a marker.
var data: Dictionary = {}

var selected: bool = false:
	set(value):
		selected = value
		if _material:
			_material.set_shader_parameter("selected", 1.0 if value else 0.0)

var hovered: bool = false:
	set(value):
		hovered = value
		if _material:
			_material.set_shader_parameter("hovered", 1.0 if value else 0.0)

## Renders as a diamond HQ icon instead of a dot, and skips the one-shot
## spawn glow (a static base appearing isn't "a new event").
var is_base: bool = false:
	set(value):
		is_base = value
		_spawn_active = false
		if _material:
			_material.set_shader_parameter("is_base", 1.0 if value else 0.0)
			_material.set_shader_parameter("spawn_glow", 0.0)

## Sets the marker's idle/base color, e.g. for urgency-based coloring of
## event markers. Safe to call any time after _build() has run (i.e. once
## this marker has entered the tree).
func set_color(color: Color) -> void:
	if _material:
		_material.set_shader_parameter("base_color", Vector3(color.r, color.g, color.b))

## Duration of the one-shot "just spawned" ring, in seconds.
@export var spawn_highlight_duration: float = 2.5

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _pulse_t: float = 0.0
var _hover_scale: float = 1.0 ## eased toward target each frame, not snapped
var _spawn_elapsed: float = 0.0
var _spawn_active: bool = true


## Converts lat/lon (degrees) to a position on a sphere of the given radius.
##
## This must agree with two things or markers land on the wrong geography:
##   1. Godot's SphereMesh vertex layout, which is
##        y = cos(PI * v),  w = sin(PI * v),  x = sin(u * TAU) * w,  z = cos(u * TAU) * w
##   2. The equirectangular convention land_mask.png was rasterized with:
##        u = lon / 360 + 0.5      (lon -180..180 maps left..right)
##        v = 0.5 - lat / 180      (lat +90..-90 maps top..bottom)
static func latlon_to_position(lat_deg: float, lon_deg: float, radius: float = 1.0) -> Vector3:
	var u := lon_deg / 360.0 + 0.5
	var v := 0.5 - lat_deg / 180.0
	var phi := PI * v
	var w := sin(phi)
	return Vector3(sin(u * TAU) * w, cos(phi), cos(u * TAU) * w) * radius


## Flat-plane counterpart to latlon_to_position(), using the exact same u/v
## formula and the exact same PLANE_HALF_WIDTH/HEIGHT constants as the
## flatten unfold in geoscape.gdshader's vertex(). Must be kept in sync
## with that shader or markers will land off the coastlines.
const PLANE_HALF_WIDTH := PI
const PLANE_HALF_HEIGHT := PI / 2.0

static func latlon_to_flat_position(lat_deg: float, lon_deg: float) -> Vector3:
	var u := lon_deg / 360.0 + 0.5
	var v := 0.5 - lat_deg / 180.0
	return Vector3(
		(u - 0.5) * 2.0 * PLANE_HALF_WIDTH,
		(0.5 - v) * 2.0 * PLANE_HALF_HEIGHT,
		0.0
	)


func _ready() -> void:
	_build()
	_reposition()


func _build() -> void:
	if _mesh:
		return
	_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(marker_size, marker_size)
	_mesh.mesh = quad

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/marker.gdshader")
	_material.set_shader_parameter("selected", 1.0 if selected else 0.0)
	_mesh.material_override = _material

	# Markers are small and always face the camera; skip shadow/AABB culling fuss.
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _reposition() -> void:
	# Replicate the shader's two-stage interpolation
	var stage1 := clampf(flatten * 2.0, 0.0, 1.0)
	var stage2 := clampf(flatten * 2.0 - 1.0, 0.0, 1.0)

	var u := longitude / 360.0 + 0.5
	var v := 0.5 - latitude / 180.0
	var phi := PI * v
	var theta := u * TAU

	# STAGE 1: Sphere to Cylinder
	var sphere_r := sin(phi)
	var sphere_y := cos(phi)
	var cyl_r := 1.0
	var cyl_y := (0.5 - v) * 2.0 * PLANE_HALF_HEIGHT

	# Multiply radius by SURFACE_OFFSET to prevent Z-fighting in all states
	var r := lerpf(sphere_r, cyl_r, stage1) * SURFACE_OFFSET
	var y := lerpf(sphere_y, cyl_y, stage1)

	var x_pos := sin(theta) * r
	var z_pos := cos(theta) * r

	# STAGE 2: Unroll Math
	if stage2 > 0.0:
		var unroll := maxf(1.0 - stage2, 0.0001)
		var R := (1.0 / unroll) * SURFACE_OFFSET
		var s := (u - 0.5) * TAU
		var theta_roll := s * unroll

		x_pos = -R * sin(theta_roll)
		z_pos = -(SURFACE_OFFSET - R + R * cos(theta_roll))

	position = Vector3(x_pos, y, z_pos)


func _process(delta: float) -> void:
	if selected and _material:
		_pulse_t = fmod(_pulse_t + delta * 1.4, 1.0)
		_material.set_shader_parameter("pulse", _pulse_t)

	if _spawn_active:
		_spawn_elapsed += delta
		var t := clampf(_spawn_elapsed / spawn_highlight_duration, 0.0, 1.0)
		if _material:
			_material.set_shader_parameter("spawn_glow", 1.0 - t)
		if t >= 1.0:
			_spawn_active = false

	var target_scale: float = 1.25 if hovered else 1.0
	_hover_scale = lerp(_hover_scale, target_scale, clamp(delta * 12.0, 0.0, 1.0))
	if _mesh:
		_mesh.scale = Vector3.ONE * _hover_scale


## True when this marker should be visible/pickable from the camera's side.
## On the sphere this means "on the near hemisphere". On the flattened map
## there's no far side to hide, so every marker counts as facing.
func is_facing_camera(camera: Camera3D) -> bool:
	# During unroll (stage 2), everything faces the camera
	if flatten > 0.5:
		return true
	# Globe is centred on the origin, so the marker's own world position doubles
	# as its outward surface normal.
	var surface_normal := global_position.normalized()
	var to_camera := (camera.global_position - Vector3.ZERO).normalized()
	return surface_normal.dot(to_camera) > 0.0
