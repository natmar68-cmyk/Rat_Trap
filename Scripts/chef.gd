extends CharacterBody3D

const PATROL_SPEED = 3.0
const CHASE_SPEED = 7.0
const GRAVITY = 20.0

var player: Node3D = null
var chasing: bool = false
var patrol_targets: Array[Node3D] = []
var current_patrol_index: int = 0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detection_zone: Area3D = $DetectionZone
@onready var kill_zone: Area3D = $KillZone

@export var patrol_points: Array[NodePath] = []

func _ready():
	detection_zone.body_entered.connect(_on_detection_zone_entered)
	detection_zone.body_exited.connect(_on_detection_zone_exited)
	kill_zone.body_entered.connect(_on_kill_zone_entered)

	for path in patrol_points:
		patrol_targets.append(get_node(path))

	if patrol_targets.size() == 0:
		print("Chef: No patrol points assigned in Inspector")
	else:
		print("Chef: Found ", patrol_targets.size(), " patrol points")
		await get_tree().physics_frame
		nav_agent.target_position = patrol_targets[0].global_position

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if chasing and player:
		_chase(delta)
	elif patrol_targets.size() > 0:
		_patrol(delta)

	move_and_slide()

func _chase(delta):
	nav_agent.target_position = player.global_position
	_move_toward_target(CHASE_SPEED)

func _patrol(delta):
	if nav_agent.is_navigation_finished():
		current_patrol_index = (current_patrol_index + 1) % patrol_targets.size()
		nav_agent.target_position = patrol_targets[current_patrol_index].global_position
		return
	_move_toward_target(PATROL_SPEED)

func _move_toward_target(speed: float):
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position)
	direction.y = 0
	direction = direction.normalized()

	if direction.length() > 0.1:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		look_at(global_position + Vector3(direction.x, 0, direction.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func _on_detection_zone_entered(body):
	if body.is_in_group("Player"):
		print("Chef: Player spotted!")
		chasing = true
		player = body

func _on_detection_zone_exited(body):
	if body.is_in_group("Player"):
		print("Chef: Lost player, resuming patrol")
		chasing = false
		player = null
		if patrol_targets.size() > 0:
			nav_agent.target_position = patrol_targets[current_patrol_index].global_position

func _on_kill_zone_entered(body):
	if body.is_in_group("Player"):
		print("Chef: Player caught!")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file.call_deferred("res://Scenes/death_screen.tscn")
