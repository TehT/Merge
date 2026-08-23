class_name GeoData
extends Node

## Provides geographic lookups: country at a point, nearest city, distance calculations.
## Requires country_index_map.png (RGB, ID encoded in R<<8|G) and
## countries.json + cities.json in res://data/. Referenced elsewhere via
## Game.geo_data (registers itself in _ready() — see game.gd).

var _country_image: Image
var _countries: Dictionary  # id string -> { name, iso_a3, sovereign }
var _cities: Array  # [{ name, country, region, lat, lon, pop, capital, class }]

func _ready() -> void:
	Game.geo_data = self

	# Load country index map for pixel lookups
	var country_tex := load("res://textures/country_index_map.png") as Texture2D
	if country_tex:
		_country_image = country_tex.get_image()
		_country_image.convert(Image.FORMAT_RGB8)
	else:
		push_warning("GeoData: country_index_map.png not found")

	# Load country names
	var countries_file := FileAccess.open("res://data/countries.json", FileAccess.READ)
	if countries_file:
		_countries = JSON.parse_string(countries_file.get_as_text())
		countries_file.close()
	else:
		push_warning("GeoData: countries.json not found")

	# Load cities
	var cities_file := FileAccess.open("res://data/cities.json", FileAccess.READ)
	if cities_file:
		_cities = JSON.parse_string(cities_file.get_as_text())
		cities_file.close()
	else:
		push_warning("GeoData: cities.json not found")

	print("GeoData loaded: %d countries, %d cities" % [_countries.size(), _cities.size()])


## Get the country at a given lon/lat. Returns a Dictionary or null if ocean.
func get_country_at(lon_deg: float, lat_deg: float) -> Variant:
	if _country_image == null:
		return null

	var u := (lon_deg / 360.0) + 0.5
	var v := 0.5 - (lat_deg / 180.0)

	var px := clampi(int(u * _country_image.get_width()), 0, _country_image.get_width() - 1)
	var py := clampi(int(v * _country_image.get_height()), 0, _country_image.get_height() - 1)

	var pixel := _country_image.get_pixel(px, py)
	var r := int(pixel.r8)
	var g := int(pixel.g8)
	var country_id := (r << 8) | g

	if country_id == 0:
		return null  # Ocean

	var id_str := str(country_id)
	if id_str in _countries:
		return _countries[id_str]
	return null


## Get the country at a grid cell center.
func get_country_at_cell(cell: Vector2i, grid_step_deg: float) -> Variant:
	var lon := (cell.x + 0.5) * grid_step_deg
	var lat := (cell.y + 0.5) * grid_step_deg
	return get_country_at(lon, lat)


## Find the nearest city to a given lon/lat.
## Returns a Dictionary with city info + "distance_km" field, or null.
## min_pop filters to cities above a population threshold (0 = all).
func get_nearest_city(lon_deg: float, lat_deg: float, min_pop: int = 0) -> Variant:
	if _cities.is_empty():
		return null

	var best: Dictionary = {}
	var best_dist := INF

	for city in _cities:
		if city.pop < min_pop:
			continue

		var dist := haversine_km(lat_deg, lon_deg, city.lat, city.lon)
		if dist < best_dist:
			best_dist = dist
			best = city.duplicate()
		var score: float = dist
		if city.capital:
			score *= 0.5
		# Big cities have a larger "pull radius"
		score *= 1.0 / (1.0 + log(float(city.pop)) * 0.05)

	if best.is_empty():
		return null

	best["distance_km"] = int(best_dist)
	return best


## Find the N nearest cities to a given lon/lat.
func get_nearby_cities(lon_deg: float, lat_deg: float, count: int = 5, min_pop: int = 0) -> Array:
	if _cities.is_empty():
		return []

	var results: Array = []

	for city in _cities:
		if city.pop < min_pop:
			continue

		var dist : float = haversine_km(lat_deg, lon_deg, city.lat, city.lon)
		var entry : Dictionary= city.duplicate()
		entry["distance_km"] = int(dist)

		if results.size() < count:
			results.append(entry)
			results.sort_custom(func(a, b): return a.distance_km < b.distance_km)
		elif dist < results[-1].distance_km:
			results[-1] = entry
			results.sort_custom(func(a, b): return a.distance_km < b.distance_km)

	return results


## Returns a random city Dictionary (same shape as get_nearest_city()), or
## null if no cities are loaded. min_pop filters to cities above a
## population threshold (0 = all).
func get_random_city(min_pop: int = 0) -> Variant:
	if _cities.is_empty():
		return null

	var pool: Array = _cities.filter(func(city): return city.pop >= min_pop)
	if pool.is_empty():
		return null

	return pool[randi() % pool.size()]


## Get a location description string for a lon/lat point.
## e.g. "France - 23 km from Toulouse"
func describe_location(lon_deg: float, lat_deg: float, min_pop: int = 50000) -> String:
	var country : Variant = get_country_at(lon_deg, lat_deg)
	var city : Variant = get_nearest_city(lon_deg, lat_deg, min_pop)

	var parts: PackedStringArray = []

	if country:
		parts.append(country.name)
	else:
		parts.append("International Waters")

	if city:
		if city.distance_km < 5:
			parts.append(city.name)
		else:
			parts.append("%d km from %s" % [city.distance_km, city.name])

	return " - ".join(parts)


## Get a location description for a grid cell.
func describe_cell(cell: Vector2i, grid_step_deg: float, min_pop: int = 50000) -> String:
	var lon := (cell.x + 0.5) * grid_step_deg
	var lat := (cell.y + 0.5) * grid_step_deg
	return describe_location(lon, lat, min_pop)


## Haversine distance in km between two lat/lon points. Static (pure math,
## no city data needed) so callers like TeamManager can use it without a
## GeoData instance.
static func haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var r := 6371.0  # Earth radius in km
	var dlat := deg_to_rad(lat2 - lat1)
	var dlon := deg_to_rad(lon2 - lon1)
	var a := sin(dlat / 2.0) * sin(dlat / 2.0) + \
			 cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * \
			 sin(dlon / 2.0) * sin(dlon / 2.0)
	var c := 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	return r * c
