extends Node3D

@export var player: Node3D
@export_range(1.0, 1000.0) var max_health := 100.0

@onready var raycast = $RayCast
@onready var muzzle_a = $MuzzleA
@onready var muzzle_b = $MuzzleB

signal health_updated(current: float, maximum: float)
signal died(enemy: Node3D)

var health := 100.0
var time := 0.0
var target_position: Vector3
var destroyed := false

# When ready, save the initial position

func _ready():
	health = max_health
	add_to_group("enemies")
	target_position = position


func _process(delta):
	if !is_instance_valid(player) or destroyed:
		return

	look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP, true)
	target_position.y += (cos(time * 5) * 1) * delta  # Sine movement (up and down)

	time += delta

	position = target_position

# Take damage from player

func damage(amount: float):
	if destroyed or amount <= 0.0:
		return

	Audio.play("sounds/enemy_hurt.ogg")

	health = maxf(0.0, health - amount)
	health_updated.emit(health, max_health)

	if health <= 0.0:
		destroy()

# Destroy the enemy when out of health

func destroy():
	if destroyed:
		return

	Audio.play("sounds/enemy_destroy.ogg")
	destroyed = true
	died.emit(self)
	queue_free()

# Shoot when timer hits 0

func _on_timer_timeout():
	if destroyed or !is_instance_valid(player):
		return

	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()

		if collider.has_method("damage"):  # Raycast collides with player
			
			# Play muzzle flash animation(s)

			muzzle_a.frame = 0
			muzzle_a.play("default")
			muzzle_a.rotation_degrees.z = randf_range(-45, 45)

			muzzle_b.frame = 0
			muzzle_b.play("default")
			muzzle_b.rotation_degrees.z = randf_range(-45, 45)

			Audio.play("sounds/enemy_attack.ogg")

			collider.damage(5)  # Apply damage to player
