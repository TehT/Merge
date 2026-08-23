class_name WeatherController
extends Node

## Manages weather state and provides per-cell weather queries.
## Attach to your scene and call update_materials() with your globe/detail materials.

# --- Exported tunables ---
@export var wind_speed: float = 0.3          ## 0.0 = calm, 1.0 = gale
@export var wind_angle_degrees: float = 75.0 ## Prevailing wind direction (75° ≈ westerlies)
@export var cloud_coverage: float = 0.5      ## Global cloud amount 0.0 - 1.0
@export var cloud_opacity: float = 0.55      ## Max cloud visual opacity

# --- Runtime state ---
var weather_time: float = 0.0
var game_day: float = 0.0
var season: float = 0.0  ## 0.0 = Jan, 0.5 = Jul, 1.0 = Dec

var _materials: Array[ShaderMaterial] = []
var _moisture_texture: Texture2D
var _moisture_image: Image  # CPU-side copy for gameplay queries
var _wind_direction: Vector2

func _ready() -> void:
	_wind_direction = Vector2(
		cos(deg_to_rad(wind_angle_degrees)),
		sin(deg_to_rad(wind_angle_degrees))
	).normalized()

	# Load moisture data for CPU-side queries
	_moisture_texture = preload("res://textures/moisture_map_2048.png")
	_moisture_image = _moisture_texture.get_image()

func _process(delta: float) -> void:
	weather_time += delta
	
	# Sync season from GeoscapeController's day_of_year
	var geoscape := get_node_or_null("../GeoscapeController")
	if geoscape:
		season = geoscape.day_of_year / 365.25
	
	_wind_direction = Vector2(
		cos(deg_to_rad(wind_angle_degrees + sin(weather_time * 0.01) * 15.0)),
		sin(deg_to_rad(wind_angle_degrees + sin(weather_time * 0.01) * 15.0))
	).normalized()

	for mat in _materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("weather_time", weather_time)
			mat.set_shader_parameter("wind_direction", _wind_direction)
			mat.set_shader_parameter("wind_speed", wind_speed)
			mat.set_shader_parameter("cloud_coverage", cloud_coverage)
			mat.set_shader_parameter("cloud_opacity", cloud_opacity)
			mat.set_shader_parameter("season", season)

## Register a ShaderMaterial that uses the weather include.
## Call this for both your globe material and detail material.
func register_material(mat: ShaderMaterial) -> void:
	if mat not in _materials:
		_materials.append(mat)
		mat.set_shader_parameter("moisture_map", _moisture_texture)

# --- Gameplay queries ---

## Get weather conditions for a grid cell.
## Returns a Dictionary with climate info for gameplay use.
func get_cell_weather(cell: Vector2i, grid_cols: int, grid_rows: int) -> Dictionary:
	# Convert cell to equirectangular UV
	var uv := Vector2(
		(float(cell.x) + 0.5) / float(grid_cols),
		(float(cell.y) + 0.5) / float(grid_rows)
	)

	# Sample moisture from CPU-side image
	var px := clampi(int(uv.x * _moisture_image.get_width()), 0, _moisture_image.get_width() - 1)
	var py := clampi(int(uv.y * _moisture_image.get_height()), 0, _moisture_image.get_height() - 1)
	var moisture := _moisture_image.get_pixel(px, py).r

	# Latitude for seasonal effects
	var lat := (0.5 - uv.y) * 180.0
	var itcz_shift := sin(season * TAU) * 8.0
	var itcz_boost := exp(-0.5 * pow((lat - itcz_shift) / 10.0, 2.0)) * 0.15
	moisture = clampf(moisture + itcz_boost, 0.0, 1.0)

	# Determine conditions from moisture + season
	var cloud_chance := moisture * cloud_coverage
	var precip_chance := cloud_chance * moisture  # squared moisture = precip is rarer than clouds

	# Temperature modifier from latitude + season
	var base_temp :float = 1.0 - abs(lat) / 90.0  # 1.0 at equator, 0.0 at poles
	var season_mod :float = cos((season - 0.5) * TAU) * 0.15 * sign(lat)  # warmer in local summer
	var temperature :float = clampf(base_temp + season_mod, 0.0, 1.0)

	# Determine precipitation type
	var precip_type := "none"
	if precip_chance > 0.3:
		if temperature < 0.25:
			precip_type = "snow"
		elif temperature < 0.35:
			precip_type = "sleet"
		else:
			precip_type = "rain"
		# Heavy variants
		if precip_chance > 0.6:
			if precip_type == "rain":
				precip_type = "heavy_rain"
			elif precip_type == "snow":
				precip_type = "blizzard"

	# Visibility modifier (for gameplay: affects detection, movement)
	var visibility := 1.0
	if cloud_chance > 0.4:
		visibility -= (cloud_chance - 0.4) * 0.5
	if precip_chance > 0.3:
		visibility -= (precip_chance - 0.3) * 0.8
	visibility = clampf(visibility, 0.1, 1.0)

	# Movement modifier
	var movement_mod := 1.0
	match precip_type:
		"rain": movement_mod = 0.9
		"heavy_rain": movement_mod = 0.7
		"snow": movement_mod = 0.8
		"sleet": movement_mod = 0.75
		"blizzard": movement_mod = 0.5

	return {
		"moisture": moisture,
		"cloud_chance": cloud_chance,
		"precip_chance": precip_chance,
		"precip_type": precip_type,
		"temperature": temperature,      # 0.0 = freezing, 1.0 = tropical
		"visibility": visibility,         # 1.0 = clear, 0.1 = near-zero
		"movement_modifier": movement_mod, # multiplier on movement speed/range
		"season": season,
	}

## Convenience: is it currently "bad weather" in this cell?
func is_bad_weather(cell: Vector2i, grid_cols: int, grid_rows: int) -> bool:
	var w := get_cell_weather(cell, grid_cols, grid_rows)
	return w.precip_type in ["heavy_rain", "blizzard", "sleet"]
