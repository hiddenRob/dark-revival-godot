extends Node
## WorldManager - Manages the game world, districts, and map progression
## Handles district unlocking, block states, and world persistence

signal district_loaded(district_id: String)
signal block_cleared(block_id: String)
signal world_changed

# District definitions
var districts: Dictionary = {}
var current_district_id: String = "hub"

# Block states within districts
# Structure: {district_id: {block_id: {cleared: bool, enemies_defeated: int, loot_collected: Array}}}
var block_states: Dictionary = {}

# World progression
var total_districts: int = 0
var cleared_districts: int = 0


func _ready() -> void:
	initialize_world()
	print("[WorldManager] World initialized - %d districts" % total_districts)


## Initialize the world with district structure
func initialize_world() -> void:
	# Define district structure based on design doc
	districts = {
		"hub": {
			"name": "Safe Haven",
			"type": "hub",
			"difficulty": 0,
			"blocks": [],
			"unlocked": true,
			"secured": true
		},
		"district_1": {
			"name": "Old Quarter",
			"type": "residential",
			"difficulty": 1,
			"blocks": ["block_1a", "block_1b", "block_1c", "block_1d"],
			"unlocked": true,
			"secured": false,
			"main_building": "school"
		},
		"district_2": {
			"name": "Industrial Zone",
			"type": "industrial",
			"difficulty": 2,
			"blocks": ["block_2a", "block_2b", "block_2c", "block_2d", "block_2e"],
			"unlocked": false,
			"secured": false,
			"main_building": "factory"
		},
		"district_3": {
			"name": "Downtown",
			"type": "commercial",
			"difficulty": 3,
			"blocks": ["block_3a", "block_3b", "block_3c", "block_3d"],
			"unlocked": false,
			"secured": false,
			"main_building": "city_hall"
		},
		"district_4": {
			"name": "Suburbs",
			"type": "residential",
			"difficulty": 2,
			"blocks": ["block_4a", "block_4b", "block_4c", "block_4d"],
			"unlocked": false,
			"secured": false,
			"main_building": "mall"
		}
	}
	
	total_districts = districts.size()
	
	# Initialize block states
	for district_id in districts:
		block_states[district_id] = {}
		var district = districts[district_id]
		if district.has("blocks"):
			for block_id in district["blocks"]:
				block_states[district_id][block_id] = {
					"cleared": false,
					"enemies_defeated": 0,
					"loot_collected": [],
					"last_cleared": 0
				}


## Load a district scene
func load_district(district_id: String) -> bool:
	if district_id not in districts:
		print("[WorldManager] District not found: %s" % district_id)
		return false
	
	var district = districts[district_id]
	if not district["unlocked"]:
		print("[WorldManager] District not unlocked: %s" % district_id)
		return false
	
	current_district_id = district_id
	print("[WorldManager] Loading district: %s (%s)" % [district_id, district["name"]])
	
	# Signal for scene transition
	district_loaded.emit(district_id)
	return true


## Check if a block is cleared
func is_block_cleared(block_id: String) -> bool:
	if current_district_id not in block_states:
		return false
	return block_states[current_district_id].get(block_id, {}).get("cleared", false)


## Mark a block as cleared
func clear_block(block_id: String) -> void:
	if current_district_id not in block_states:
		return
	
	if block_id in block_states[current_district_id]:
		block_states[current_district_id][block_id]["cleared"] = true
		block_states[current_district_id][block_id]["last_cleared"] = Time.get_unix_time_from_system()
		print("[WorldManager] Block cleared: %s in %s" % [block_id, current_district_id])
		block_cleared.emit(block_id)
		
		# Check if district is now secured
		check_district_secured()


## Add enemies defeated count to a block
func add_enemies_defeated(block_id: String, count: int) -> void:
	if current_district_id in block_states and block_id in block_states[current_district_id]:
		block_states[current_district_id][block_id]["enemies_defeated"] += count


## Add loot collected from a block
func add_loot_collected(block_id: String, loot_id: String) -> void:
	if current_district_id in block_states and block_id in block_states[current_district_id]:
		if loot_id not in block_states[current_district_id][block_id]["loot_collected"]:
			block_states[current_district_id][block_id]["loot_collected"].append(loot_id)


## Check if all blocks in current district are cleared
func check_district_secured() -> void:
	if current_district_id == "hub":
		return
	
	var district = districts[current_district_id]
	var all_cleared = true
	
	for block_id in district["blocks"]:
		if not is_block_cleared(block_id):
			all_cleared = false
			break
	
	if all_cleared and not district["secured"]:
		district["secured"] = true
		print("[WorldManager] District secured: %s!" % district["name"])
		
		# Update GameManager
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			game_manager.secure_district(current_district_id)
		
		# Unlock next district
		unlock_next_district()
		world_changed.emit()


## Unlock the next district in sequence
func unlock_next_district() -> void:
	var district_order = ["hub", "district_1", "district_2", "district_3", "district_4"]
	var current_index = district_order.find(current_district_id)
	
	if current_index >= 0 and current_index < district_order.size() - 1:
		var next_district_id = district_order[current_index + 1]
		if next_district_id in districts:
			districts[next_district_id]["unlocked"] = true
			print("[WorldManager] Unlocked next district: %s" % districts[next_district_id]["name"])


## Get district data
func get_district(district_id: String) -> Dictionary:
	return districts.get(district_id, {})


## Get block state
func get_block_state(block_id: String) -> Dictionary:
	return block_states.get(current_district_id, {}).get(block_id, {})


## Get all blocks in current district
func get_current_district_blocks() -> Array:
	var district = districts.get(current_district_id, {})
	return district.get("blocks", [])


## Get cleared blocks count in current district
func get_cleared_blocks_count() -> int:
	var count = 0
	var blocks = get_current_district_blocks()
	for block_id in blocks:
		if is_block_cleared(block_id):
			count += 1
	return count


## Get total blocks in current district
func get_total_blocks_count() -> int:
	return get_current_district_blocks().size()


## Get district completion percentage
func get_district_completion() -> float:
	var total = get_total_blocks_count()
	if total == 0:
		return 0.0
	return float(get_cleared_blocks_count()) / float(total) * 100.0


## Reset district (for testing/debugging)
func reset_district(district_id: String) -> void:
	if district_id in block_states:
		for block_id in block_states[district_id]:
			block_states[district_id][block_id]["cleared"] = false
			block_states[district_id][block_id]["enemies_defeated"] = 0
			block_states[district_id][block_id]["loot_collected"] = []
		
		if district_id in districts:
			districts[district_id]["secured"] = false
		
		print("[WorldManager] District reset: %s" % district_id)
		world_changed.emit()


## Save world state
func save_world() -> Dictionary:
	return {
		"districts": districts,
		"block_states": block_states,
		"current_district_id": current_district_id
	}


## Load world state
func load_world(data: Dictionary) -> void:
	if data.has("districts"):
		districts = data["districts"]
	if data.has("block_states"):
		block_states = data["block_states"]
	if data.has("current_district_id"):
		current_district_id = data["current_district_id"]
	
	print("[WorldManager] World state loaded")
	world_changed.emit()
