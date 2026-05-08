extends Node
## LightManager - Manages light sources, darkness, and visibility
## Core mechanic: Light = safety, resources, and progression

signal light_level_changed(new_level: float)
signal light_source_added(source_id: String)
signal light_source_removed(source_id: String)
signal darkness_zone_entered(zone_id: String)
signal darkness_zone_exited(zone_id: String)

# Light sources in the world
# Structure: {source_id: {position: Vector2, radius: float, intensity: float, active: bool, type: String}}
var light_sources: Dictionary = {}

# Player light (personal light source)
var player_light_radius: float = 150.0
var player_light_intensity: float = 1.0

# Ambient light level (0.0 = pitch black, 1.0 = full daylight)
var ambient_light: float = 0.1

# Darkness zones
var darkness_zones: Dictionary = {}

# Light consumption rate
var base_light_consumption: float = 2.0  # Light per second
var current_light_consumption: float = 2.0


func _ready() -> void:
	print("[LightManager] Initialized - Base consumption: %.1f/s" % base_light_consumption)
	_start_light_consumption_timer()


## Add a light source to the world
func add_light_source(source_id: String, position: Vector2, radius: float = 100.0, intensity: float = 1.0, type: String = "static") -> void:
	light_sources[source_id] = {
		"position": position,
		"radius": radius,
		"intensity": intensity,
		"active": true,
		"type": type,
		"flicker": type == "torch",
		"flicker_speed": randf_range(0.5, 2.0) if type == "torch" else 0.0
	}
	print("[LightManager] Light source added: %s (%s, radius: %.0f)" % [source_id, type, radius])
	light_source_added.emit(source_id)


## Remove a light source
func remove_light_source(source_id: String) -> void:
	if source_id in light_sources:
		light_sources.erase(source_id)
		print("[LightManager] Light source removed: %s" % source_id)
		light_source_removed.emit(source_id)


## Toggle a light source on/off
func toggle_light_source(source_id: String, active: bool) -> void:
	if source_id in light_sources:
		light_sources[source_id]["active"] = active
		var state = "ON" if active else "OFF"
		print("[LightManager] Light source %s: %s" % [source_id, state])


## Set player light radius (upgrades/equipment)
func set_player_light_radius(radius: float) -> void:
	player_light_radius = clamp(radius, 50.0, 500.0)
	print("[LightManager] Player light radius: %.0f" % player_light_radius)


## Set player light intensity
func set_player_light_intensity(intensity: float) -> void:
	player_light_intensity = clamp(intensity, 0.1, 3.0)
	print("[LightManager] Player light intensity: %.2f" % player_light_intensity)


## Calculate light level at a position
func get_light_at_position(position: Vector2) -> float:
	var total_light = ambient_light
	
	for source_id in light_sources:
		var source = light_sources[source_id]
		if not source["active"]:
			continue
		
		var distance = position.distance_to(source["position"])
		if distance < source["radius"]:
			var falloff = 1.0 - (distance / source["radius"])
			var intensity = source["intensity"]
			
			# Add flicker for torches
			if source.get("flicker", false):
				var flicker_value = sin(Time.get_ticks_msec() * 0.01 * source.get("flicker_speed", 1.0))
				intensity *= 0.8 + (flicker_value * 0.2)
			
			total_light += intensity * falloff
	
	return minf(1.0, total_light)


## Check if a position is in darkness
func is_in_darkness(position: Vector2, threshold: float = 0.3) -> bool:
	return get_light_at_position(position) < threshold


## Add a darkness zone (area with enhanced darkness)
func add_darkness_zone(zone_id: String, polygon: PackedVector2Array, darkness_level: float = 0.8) -> void:
	darkness_zones[zone_id] = {
		"polygon": polygon,
		"darkness_level": darkness_level,
		"active": true
	}
	print("[LightManager] Darkness zone added: %s" % zone_id)


## Check if position is in a darkness zone
func is_in_darkness_zone(position: Vector2) -> String:
	for zone_id in darkness_zones:
		var zone = darkness_zones[zone_id]
		if not zone["active"]:
			continue
		
		if _point_in_polygon(position, zone["polygon"]):
			return zone_id
	
	return ""


## Start light consumption timer (call from GameManager)
func _start_light_consumption_timer() -> void:
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_light_consumption_tick)
	add_child(timer)
	timer.start()


func _on_light_consumption_tick() -> void:
	# Calculate current consumption based on active light sources
	var consumption = base_light_consumption
	
	# Add consumption from player light
	consumption += player_light_intensity * 0.5
	
	# Signal GameManager to consume light
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and consumption > 0:
		# TODO: Implement light resource consumption
		# game_manager.consume_light(int(consumption))
		pass
	
	current_light_consumption = consumption


## Get light at player position
func get_player_light() -> float:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("get_player_position"):
		var player_pos = game_manager.get_player_position()
		return get_light_at_position(player_pos)
	return ambient_light


## Calculate light multiplier for combat/survival
func get_light_multiplier(position: Vector2) -> float:
	var light = get_light_at_position(position)
	# More light = better visibility, easier combat
	# Less light = harder to see, enemies stronger
	return 0.5 + (light * 0.5)  # Range: 0.5 (dark) to 1.0 (bright)


## Visual overlay helper - get darkness intensity for shader
func get_darkness_intensity(position: Vector2) -> float:
	var zone_id = is_in_darkness_zone(position)
	if zone_id != "":
		return darkness_zones[zone_id]["darkness_level"]
	
	var light = get_light_at_position(position)
	return 1.0 - light  # Invert: low light = high darkness


## Create a temporary light source (grenade, spell, etc.)
func create_temporary_light(position: Vector2, radius: float = 200.0, duration: float = 5.0, intensity: float = 2.0) -> String:
	var source_id = "temp_light_%d" % Time.get_ticks_msec()
	add_light_source(source_id, position, radius, intensity, "temporary")
	
	# Auto-remove after duration
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): remove_light_source(source_id))
	add_child(timer)
	timer.start()
	
	print("[LightManager] Temporary light created: %s (%.1fs)" % [source_id, duration])
	return source_id


## Helper: Check if point is in polygon
func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside = false
	var j = polygon.size() - 1
	
	for i in polygon.size():
		var vi = polygon[i]
		var vj = polygon[j]
		
		if ((vi.y > point.y) != (vj.y > point.y)) and \
		   (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x):
			inside = !inside
		
		j = i
	
	return inside


## Get all active light sources
func get_active_light_sources() -> Array:
	var active = []
	for source_id in light_sources:
		if light_sources[source_id]["active"]:
			active.append(source_id)
	return active


## Get total light coverage (for stats/UI)
func get_total_light_coverage() -> float:
	var total_radius = 0.0
	for source_id in light_sources:
		if light_sources[source_id]["active"]:
			total_radius += light_sources[source_id]["radius"]
	
	# Add player light
	total_radius += player_light_radius
	
	return total_radius
