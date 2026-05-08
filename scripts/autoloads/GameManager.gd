extends Node
## GameManager - Global state manager for Dark Revival
## Handles game state, player stats, resources, and progression

signal light_changed(new_amount: int)
signal district_secured(district_id: String)
signal resource_changed(resource_type: String, new_amount: int)
signal game_saved
signal game_loaded

# Player resources
var light: int = 100  # Primary resource - fuels everything
var survivors: int = 0  # Number of rescued people
var supplies: int = 50  # Basic supplies for crafting/building

# District progression
var secured_districts: Array[String] = []
var secured_blocks: Array[String] = []  # Individual cleared areas

# Player stats
var max_health: int = 100
var current_health: int = 100
var damage_multiplier: float = 1.0
var defense_multiplier: float = 1.0

# Meta-progression unlocks
var unlocked_recipes: Array[String] = []
var unlocked_buildings: Array[String] = []
var unlocked_upgrades: Array[String] = []

# Current session state
var current_district: String = "hub"
var is_in_combat: bool = false
var session_start_time: int = 0


func _ready() -> void:
	session_start_time = Time.get_unix_time_from_system()
	print("[GameManager] Initialized - Light: %d, Survivors: %d" % [light, survivors])


func add_light(amount: int) -> void:
	light = maxi(0, light + amount)
	print("[GameManager] Light changed: %+d → %d" % [amount, light])
	light_changed.emit(light)


func consume_light(amount: int) -> bool:
	if light >= amount:
		light -= amount
		print("[GameManager] Light consumed: -%d → %d" % [amount, light])
		light_changed.emit(light)
		return true
	print("[GameManager] Not enough light! Need: %d, Have: %d" % [amount, light])
	return false


func add_survivor() -> void:
	survivors += 1
	print("[GameManager] Survivor rescued! Total: %d" % survivors)


func secure_district(district_id: String) -> void:
	if district_id not in secured_districts:
		secured_districts.append(district_id)
		print("[GameManager] District secured: %s" % district_id)
		district_secured.emit(district_id)


func is_district_secured(district_id: String) -> bool:
	return district_id in secured_districts


func secure_block(block_id: String) -> void:
	if block_id not in secured_blocks:
		secured_blocks.append(block_id)
		print("[GameManager] Block secured: %s" % block_id)


func is_block_secured(block_id: String) -> bool:
	return block_id in secured_blocks


func take_damage(amount: float) -> float:
	var actual_damage = amount / defense_multiplier
	current_health = maxi(0, current_health - actual_damage)
	print("[GameManager] Took damage: %.1f (after defense: %.1f) → HP: %d/%d" % 
		[amount, actual_damage, current_health, max_health])
	if current_health <= 0:
		on_player_death()
	return actual_damage


func heal(amount: int) -> void:
	current_health = mini(max_health, current_health + amount)
	print("[GameManager] Healed: +%d → HP: %d/%d" % [amount, current_health, max_health])


func on_player_death() -> void:
	print("[GameManager] Player died! Implementing respawn logic...")
	# TODO: Implement death/respawn mechanics
	# - Lose some light?
	# - Return to hub?
	# - Respawn at last safe point?
	pass


func add_resource(resource_type: String, amount: int) -> void:
	match resource_type:
		"supplies":
			supplies += amount
			print("[GameManager] Supplies: +%d → %d" % [amount, supplies])
		_:
			print("[GameManager] Unknown resource type: %s" % resource_type)
			return
	resource_changed.emit(resource_type, get_resource(resource_type))


func get_resource(resource_type: String) -> int:
	match resource_type:
		"supplies": return supplies
		"light": return light
		"survivors": return survivors
		_: return 0


func consume_resource(resource_type: String, amount: int) -> bool:
	var current = get_resource(resource_type)
	if current >= amount:
		match resource_type:
			"supplies": supplies -= amount
			"light": light -= amount
		resource_changed.emit(resource_type, get_resource(resource_type))
		return true
	return false


func unlock_recipe(recipe_id: String) -> bool:
	if recipe_id not in unlocked_recipes:
		unlocked_recipes.append(recipe_id)
		print("[GameManager] Recipe unlocked: %s" % recipe_id)
		return true
	return false


func has_recipe(recipe_id: String) -> bool:
	return recipe_id in unlocked_recipes


func unlock_building(building_id: String) -> bool:
	if building_id not in unlocked_buildings:
		unlocked_buildings.append(building_id)
		print("[GameManager] Building unlocked: %s" % building_id)
		return true
	return false


func has_building(building_id: String) -> bool:
	return building_id in unlocked_buildings


## Save game to file
func save_game(slot: int = 0) -> bool:
	var save_data = to_dict()
	var save_path = "user://save_%d.json" % slot
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		print("[GameManager] Save failed! Cannot open file: %s" % save_path)
		return false
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("[GameManager] Game saved to: %s" % save_path)
	game_saved.emit()
	return true


## Load game from file
func load_game(slot: int = 0) -> bool:
	var save_path = "user://save_%d.json" % slot
	
	if not FileAccess.file_exists(save_path):
		print("[GameManager] No save file found: %s" % save_path)
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	from_dict(save_data)
	print("[GameManager] Game loaded from: %s" % save_path)
	game_loaded.emit()
	return true


## Convert state to dictionary for saving
func to_dict() -> Dictionary:
	return {
		"resources": {
			"light": light,
			"survivors": survivors,
			"supplies": supplies
		},
		"progression": {
			"secured_districts": secured_districts,
			"secured_blocks": secured_blocks,
			"unlocked_recipes": unlocked_recipes,
			"unlocked_buildings": unlocked_buildings,
			"unlocked_upgrades": unlocked_upgrades
		},
		"player": {
			"max_health": max_health,
			"current_health": current_health,
			"damage_multiplier": damage_multiplier,
			"defense_multiplier": defense_multiplier
		},
		"session": {
			"current_district": current_district,
			"is_in_combat": is_in_combat
		}
	}


## Restore state from dictionary
func from_dict(data: Dictionary) -> void:
	if data.has("resources"):
		light = data["resources"].get("light", 100)
		survivors = data["resources"].get("survivors", 0)
		supplies = data["resources"].get("supplies", 50)
	
	if data.has("progression"):
		secured_districts.assign(data["progression"].get("secured_districts", []))
		secured_blocks.assign(data["progression"].get("secured_blocks", []))
		unlocked_recipes.assign(data["progression"].get("unlocked_recipes", []))
		unlocked_buildings.assign(data["progression"].get("unlocked_buildings", []))
		unlocked_upgrades.assign(data["progression"].get("unlocked_upgrades", []))
	
	if data.has("player"):
		max_health = data["player"].get("max_health", 100)
		current_health = data["player"].get("current_health", 100)
		damage_multiplier = data["player"].get("damage_multiplier", 1.0)
		defense_multiplier = data["player"].get("defense_multiplier", 1.0)
	
	if data.has("session"):
		current_district = data["session"].get("current_district", "hub")
		is_in_combat = data["session"].get("is_in_combat", false)
	
	print("[GameManager] State restored from save data")


## Auto-save every 5 minutes
func _process(_delta: float) -> void:
	var elapsed = Time.get_unix_time_from_system() - session_start_time
	if elapsed > 300 and int(elapsed) % 300 < 1:  # Every 5 minutes
		save_game(0)  # Auto-save to slot 0
