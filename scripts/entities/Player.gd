extends CharacterBody2D
## Player controller for Dark Revival
## Handles movement, interaction, and basic combat

signal health_changed(new_health: int, max_health: int)
signal light_changed(new_light: int)
signal item_collected(item_id: String)
signal enemy_defeated(enemy_id: String)

@export var speed: float = 200.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

@export var max_health: int = 100
var current_health: int = 100

@export var attack_damage: int = 10
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 0.5

var is_attacking: bool = false
var attack_timer: float = 0.0
var is_interacting: bool = false
var facing_direction: Vector2 = Vector2.DOWN

# References
var current_interactable: Node2D = null
var light_radius: float = 150.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_hitbox: Area2D = $AttackHitbox if has_node("AttackHitbox") else null


func _ready() -> void:
	current_health = max_health
	print("[Player] Ready - Health: %d/%d, Speed: %.0f" % [current_health, max_health, speed])


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_actions(delta)
	_update_facing()
	
	# Apply velocity
	move_and_slide()


func _handle_movement(delta: float) -> void:
	var input_direction = Vector2.ZERO
	
	# Keyboard input
	input_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	# Normalize to prevent faster diagonal movement
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()
	
	# Apply movement
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		facing_direction = input_direction.normalized()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _handle_actions(delta: float) -> void:
	# Attack
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_perform_attack()
	
	# Interaction
	if Input.is_action_just_pressed("interact") and current_interactable:
		_perform_interaction()
	
	# Update attack timer
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			if attack_hitbox:
				attack_hitbox.monitoring = false


func _perform_attack() -> void:
	is_attacking = true
	attack_timer = attack_cooldown
	
	print("[Player] Attacking! Damage: %d, Range: %.0f" % [attack_damage, attack_range])
	
	# Enable attack hitbox
	if attack_hitbox:
		attack_hitbox.monitoring = true
		# TODO: Play attack animation
		if animation_player and animation_player.has_animation("attack"):
			animation_player.play("attack")
	
	# Check for enemies in range
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 2  # Enemy layer
	query.transform = global_transform
	
	# Circle shape for attack range
	var circle = CircleShape2D.new()
	circle.radius = attack_range
	query.shape = circle
	
	var hits = space_state.intersect_shape(query, 10)
	for hit in hits:
		var collider = hit.collider
		if collider.is_in_group("enemies"):
			collider.take_damage(attack_damage)
			print("[Player] Hit enemy: %s" % collider.name)


func _perform_interaction() -> void:
	if current_interactable and current_interactable.is_in_group("interactables"):
		print("[Player] Interacting with: %s" % current_interactable.name)
		current_interactable.interact(self)


func _update_facing() -> void:
	# Flip sprite based on facing direction
	if facing_direction.x != 0:
		# Scale X to flip sprite
		if has_node("Sprite2D"):
			var sprite = get_node("Sprite2D")
			sprite.scale.x = abs(sprite.scale.x) * sign(facing_direction.x)


func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and is_attacking:
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)
			print("[Player] Attack hitbox hit: %s" % body.name)


func take_damage(amount: float) -> void:
	var game_manager = get_node_or_null("/root/GameManager")
	var actual_damage = amount
	if game_manager:
		actual_damage = game_manager.take_damage(amount)
	
	current_health = maxi(0, current_health - int(actual_damage))
	health_changed.emit(current_health, max_health)
	
	print("[Player] Took damage: %.1f → Health: %d/%d" % [actual_damage, current_health, max_health])
	
	# TODO: Play hit animation/flash
	if animation_player and animation_player.has_animation("hit"):
		animation_player.play("hit")
	
	if current_health <= 0:
		on_death()


func on_death() -> void:
	print("[Player] Player died!")
	# TODO: Implement death logic
	# - Trigger game over
	# - Respawning
	# - Light loss?
	pass


func heal(amount: int) -> void:
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	print("[Player] Healed: +%d → Health: %d/%d" % [amount, current_health, max_health])


func collect_item(item_id: String, item_data: Dictionary) -> void:
	print("[Player] Collected item: %s" % item_id)
	item_collected.emit(item_id)
	# TODO: Add to inventory


func _on_interactable_zone_body_entered(body: Node2D) -> void:
	if body == self and body.has_method("get_interactable"):
		current_interactable = body
		print("[Player] In range of interactable: %s" % current_interactable.name)


func _on_interactable_zone_body_exited(body: Node2D) -> void:
	if body == self:
		current_interactable = null
		print("[Player] Left interactable range")


## Set player position (for spawning/loading)
func set_position(pos: Vector2) -> void:
	global_position = pos


## Get player position (for other systems)
func get_position() -> Vector2:
	return global_position


## Get player light radius (for LightManager)
func get_light_radius() -> float:
	return light_radius


## Upgrade player stats
func upgrade_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"speed":
			speed = value
		"max_health":
			max_health = int(value)
			current_health = max_health
		"attack_damage":
			attack_damage = int(value)
		"attack_range":
			attack_range = value
	print("[Player] Upgraded %s to %.1f" % [stat_name, value])
