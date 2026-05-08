extends Node2D
## HubScene - The safe starting area for players
## This is where players begin each session, meet NPCs, and prepare for expeditions

@onready var player: CharacterBody2D = $Player
@onready var light_display: Label = $UI/LightDisplay
@onready var health_display: Label = $UI/HealthDisplay
@onready var survivors_display: Label = $UI/SurvivorsDisplay
@onready var district_info: Label = $UI/DistrictInfo

var game_manager: Node = null


func _ready() -> void:
	print("[HubScene] Loaded - Safe Haven")
	
	# Get GameManager reference
	game_manager = get_node_or_null("/root/GameManager")
	
	if game_manager:
		# Connect to game manager signals
		game_manager.light_changed.connect(_on_light_changed)
		game_manager.resource_changed.connect(_on_resource_changed)
		
		# Update UI with current state
		_update_ui()
	
	# Position player in center of hub
	if player:
		player.global_position = Vector2(540, 1100)
		print("[HubScene] Player positioned at hub center")
	
	# Setup light source for the hub (permanent safe light)
	var light_manager = get_node_or_null("/root/LightManager")
	if light_manager:
		light_manager.add_light_source("hub_central_light", Vector2(540, 800), 600.0, 2.0, "permanent")


func _process(_delta: float) -> void:
	_update_ui()


func _update_ui() -> void:
	if game_manager:
		light_display.text = "💡 Light: %d" % game_manager.light
		health_display.text = "❤️ HP: %d/%d" % [player.current_health if player else 100, player.max_health if player else 100]
		survivors_display.text = "👥 Survivors: %d" % game_manager.survivors
	
	district_info.text = "📍 Safe Haven (Hub) - SECURE"


func _on_light_changed(new_light: int) -> void:
	_update_ui()


func _on_resource_changed(resource_type: String, new_amount: int) -> void:
	_update_ui()


## Transition to a district
func travel_to_district(district_id: String) -> void:
	var world_manager = get_node_or_null("/root/WorldManager")
	if world_manager:
		if world_manager.load_district(district_id):
			print("[HubScene] Traveling to district: %s" % district_id)
			# TODO: Implement scene transition
			# get_tree().change_scene_to_file("res://scenes/world/DistrictScene.tscn")
		else:
			print("[HubScene] Cannot travel to %s - not unlocked or loading failed" % district_id)


## Called when player returns from expedition
func on_expedition_return() -> void:
	print("[HubScene] Player returned from expedition!")
	# TODO: 
	# - Heal player
	# - Deposit loot
	# - Update progression
	# - Show summary UI
	pass


## Save game when in hub (auto-save point)
func save_game() -> void:
	if game_manager:
		game_manager.save_game(0)
		print("[HubScene] Game saved at hub")
