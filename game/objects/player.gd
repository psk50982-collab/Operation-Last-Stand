extends CharacterBody3D

@export_subgroup("Properties")
@export var movement_speed = 5
@export_range(0, 100) var number_of_jumps: int = 2
@export var jump_strength = 8

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []

var weapon: Weapon
var weapon_index := 0

var mouse_sensitivity = 700
var gamepad_sensitivity := 0.075

var mouse_captured := true

var movement_velocity: Vector3
var rotation_target: Vector3

var input_mouse: Vector2

var health: float = 100.0
var gravity := 0.0

var previously_floored := false

var jumps_remaining: int

var container_offset = Vector3(1.2, -1.1, -2.75)

var tween: Tween

signal health_updated(health: float)
signal ammo_updated(current: int, reserve: int, capacity: int)
signal reload_state_updated(is_reloading: bool)
signal died

@onready var camera = $Head/Camera
@onready var raycast = $Head/Camera/RayCast
@onready var muzzle = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
@onready var container = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var sound_footsteps = $SoundFootsteps
@onready var blaster_cooldown = $Cooldown
@onready var reload_timer: Timer = $ReloadTimer

@export var crosshair: TextureRect

var magazine_ammo: Array[int] = []
var reserve_ammo: Array[int] = []
var is_reloading := false
var is_dead := false

# Functions

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if weapons.is_empty():
		push_error("Player requires at least one weapon resource.")
		set_physics_process(false)
		return

	for weapon_resource in weapons:
		if weapon_resource == null:
			push_error("Player weapon list contains an empty resource.")
			set_physics_process(false)
			return
		magazine_ammo.append(weapon_resource.magazine_size)
		reserve_ammo.append(weapon_resource.reserve_ammo)

	reload_timer.timeout.connect(_finish_reload)
	weapon = weapons[weapon_index]
	jumps_remaining = number_of_jumps
	initiate_change_weapon(weapon_index)
	health_updated.emit(health)
	_emit_ammo_updated()

func _physics_process(delta):
	if is_dead:
		velocity = Vector3.ZERO
		return

	handle_controls(delta)
	handle_gravity(delta)

	var world_movement := global_transform.basis * movement_velocity
	var blend_weight := clampf(delta * 10.0, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, world_movement.x, blend_weight)
	velocity.z = lerpf(velocity.z, world_movement.z, blend_weight)
	velocity.y = -gravity
	move_and_slide()

	container.position = container.position.lerp(
		container_offset - (basis.inverse() * Vector3(velocity.x, 0.0, velocity.z) / 30.0),
		blend_weight
	)

	sound_footsteps.stream_paused = true
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 1.0:
		sound_footsteps.stream_paused = false

	camera.position.y = lerpf(camera.position.y, 0.0, clampf(delta * 5.0, 0.0, 1.0))

	if is_on_floor() and gravity > 1.0 and !previously_floored:
		Audio.play("sounds/land.ogg")
		camera.position.y = -0.1

	previously_floored = is_on_floor()

	if position.y < -10:
		get_tree().reload_current_scene()

# Mouse movement

func _input(event):
	if event is InputEventMouseMotion and mouse_captured:
		input_mouse = event.relative / mouse_sensitivity
		handle_rotation(event.relative.x, event.relative.y, false)

func handle_controls(delta):
	if is_dead:
		return

	# Mouse capture
	if Input.is_action_just_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	
	if Input.is_action_just_pressed("mouse_capture_exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
		
		input_mouse = Vector2.ZERO
	
	# Movement
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	movement_velocity = Vector3(input.x, 0, input.y).normalized() * movement_speed
	
	# Handle Controller Rotation
	var rotation_input := Input.get_vector("camera_left", "camera_right", "camera_down", "camera_up")
	if rotation_input:
		handle_rotation(rotation_input.x, rotation_input.y, true, delta)
	
	# Shooting
	action_shoot()

	if Input.is_action_just_pressed("reload"):
		action_reload()

	# Jumping
	if Input.is_action_just_pressed("jump"):
		if jumps_remaining:
			action_jump()

	# Weapon switching
	action_weapon_toggle()

# Camera rotation

func handle_rotation(xRot: float, yRot: float, isController: bool, delta: float = 0.0):
	if isController:
		rotation_target -= Vector3(-yRot, -xRot, 0).limit_length(1.0) * gamepad_sensitivity
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		camera.rotation.x = lerp_angle(camera.rotation.x, rotation_target.x, delta * 25)
		rotation.y = lerp_angle(rotation.y, rotation_target.y, delta * 25)
	else:
		rotation_target += (Vector3(-yRot, -xRot, 0) / mouse_sensitivity)
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		camera.rotation.x = rotation_target.x;
		rotation.y = rotation_target.y;
	
# Handle gravity

func handle_gravity(delta):
	gravity += 20 * delta

	if gravity < 0 and is_on_ceiling():
		gravity = 0
	
	if gravity > 0 and is_on_floor():
		jumps_remaining = number_of_jumps
		gravity = 0

# Jumping

func action_jump():
	Audio.play("sounds/jump_a.ogg, sounds/jump_b.ogg, sounds/jump_c.ogg")
	gravity = - jump_strength
	jumps_remaining -= 1

# Shooting

func action_shoot():
	if is_dead or is_reloading or !Input.is_action_pressed("shoot"):
		return
	if !blaster_cooldown.is_stopped():
		return

	if magazine_ammo[weapon_index] <= 0:
		action_reload()
		return

	magazine_ammo[weapon_index] -= 1
	_emit_ammo_updated()
	Audio.play(weapon.sound_shoot)

	muzzle.play("default")
	muzzle.rotation_degrees.z = randf_range(-45, 45)
	muzzle.scale = Vector3.ONE * randf_range(0.40, 0.75)
	muzzle.position = container.position - weapon.muzzle_position
	blaster_cooldown.start(weapon.cooldown)

	for _shot_index in range(weapon.shot_count):
		raycast.target_position.x = randf_range(-weapon.spread, weapon.spread)
		raycast.target_position.y = randf_range(-weapon.spread, weapon.spread)
		raycast.force_raycast_update()

		if !raycast.is_colliding():
			continue

		var collider = raycast.get_collider()
		if collider is Node and collider.is_in_group("enemies") and collider.has_method("damage"):
			collider.damage(weapon.damage)

		var impact = preload("res://objects/impact.tscn")
		var impact_instance = impact.instantiate()
		impact_instance.play("shot")
		get_tree().root.add_child(impact_instance)
		impact_instance.global_position = raycast.get_collision_point() + (raycast.get_collision_normal() / 10.0)
		impact_instance.look_at(camera.global_transform.origin, Vector3.UP, true)

	var knockback = random_vec2(weapon.min_knockback, weapon.max_knockback)
	container.position.z += 0.25
	rotation_target.x = clampf(rotation_target.x + knockback.x, deg_to_rad(-90.0), deg_to_rad(90.0))
	rotation_target.y += knockback.y
	camera.rotation.x = rotation_target.x
	rotation.y = rotation_target.y

func action_reload():
	if is_dead or is_reloading or weapon == null:
		return
	if magazine_ammo[weapon_index] >= weapon.magazine_size or reserve_ammo[weapon_index] <= 0:
		return

	is_reloading = true
	blaster_cooldown.stop()
	reload_state_updated.emit(true)
	reload_timer.start(weapon.reload_time)

func _finish_reload():
	if !is_reloading or is_dead:
		return

	var ammo_needed := weapon.magazine_size - magazine_ammo[weapon_index]
	var ammo_to_load: int = mini(ammo_needed, reserve_ammo[weapon_index])
	magazine_ammo[weapon_index] += ammo_to_load
	reserve_ammo[weapon_index] -= ammo_to_load
	is_reloading = false
	reload_state_updated.emit(false)
	_emit_ammo_updated()

func _emit_ammo_updated():
	if weapon == null or magazine_ammo.is_empty():
		return
	ammo_updated.emit(
		magazine_ammo[weapon_index],
		reserve_ammo[weapon_index],
		weapon.magazine_size
	)

# Toggle between available weapons (listed in 'weapons')

func action_weapon_toggle():
	if !is_reloading and weapons.size() > 1 and Input.is_action_just_pressed("weapon_toggle"):
		weapon_index = wrapi(weapon_index + 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)
		
		Audio.play("sounds/weapon_change.ogg")

# Initiates the weapon changing animation (tween)

func initiate_change_weapon(index):
	weapon_index = index
	
	tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT_IN)
	tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), 0.1)
	tween.tween_callback(change_weapon) # Changes the model

# Switches the weapon model (off-screen)

func change_weapon():
	weapon = weapons[weapon_index]

	# Step 1. Remove previous weapon model(s) from container
	
	for n in container.get_children():
		container.remove_child(n)
	
	# Step 2. Place new weapon model in container
	
	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)
	
	weapon_model.position = weapon.position
	weapon_model.rotation_degrees = weapon.rotation
	
	# Step 3. Set model to only render on layer 2 (the weapon camera)
	
	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2
		
	# Set weapon data
	
	raycast.target_position = Vector3(0, 0, -1) * weapon.max_distance
	if is_instance_valid(crosshair):
		crosshair.texture = weapon.crosshair
	_emit_ammo_updated()

func damage(amount: float):
	if is_dead or amount <= 0.0:
		return

	health = maxf(0.0, health - amount)
	health_updated.emit(health)

	if health <= 0.0:
		is_dead = true
		blaster_cooldown.stop()
		reload_timer.stop()
		is_reloading = false
		reload_state_updated.emit(false)
		died.emit()

# Create a random knockback vector
static func random_vec2(_min: Vector2, _max: Vector2) -> Vector2:
	var _sign = -1 if randi() % 2 == 0 else 1
	return Vector2(randf_range(_min.x, _max.x), randf_range(_min.y, _max.y) * _sign)
