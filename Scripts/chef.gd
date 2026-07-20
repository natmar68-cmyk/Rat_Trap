extends CharacterBody3D

signal player_hit

# ─────────────────────────────────────────────
# Settings
# ─────────────────────────────────────────────
@export var move_speed: float = 10.0
@export var chase_speed: float = 1000.0
@export var sight_range: float = 14.0
@export var sight_fov_deg: float = 90.0
@export var attack_range: float = 2.8
@export var attack_cooldown: float = 1.2
@export var alert_linger: float = 3.0
@export var roam_radius: float = 10.0

# ─────────────────────────────────────────────
# Nodes
# ─────────────────────────────────────────────
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var area: Area3D = $Area3D

# Correct path from your screenshots
@onready var anim_player: AnimationPlayer = $Chef/Chef/AnimationPlayer

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────
enum State {
	ROAM,
	ALERT,
	CHASE,
	ATTACK,
	DEAD
}

var state: State = State.ROAM

var player: Node3D
var spawn_position: Vector3
var roam_target: Vector3

var alert_timer := 0.0
var attack_timer := 0.0
var last_known_pos := Vector3.ZERO
var is_attacking := false

const GRAVITY := -9.8

# ─────────────────────────────────────────────

func _ready():

	spawn_position = global_position
	roam_target = _random_roam_point()

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	_set_loop("Walking (1)", true)
	_set_loop("Running (1)", true)

	_play_anim("Walking (1)")

func _physics_process(delta):

	if state == State.DEAD:
		return

	_apply_gravity(delta)

	match state:
		State.ROAM:
			_state_roam()

		State.ALERT:
			_state_alert(delta)

		State.CHASE:
			_state_chase(delta)

		State.ATTACK:
			_state_attack(delta)

	move_and_slide()

# --------------------------------------------------
# ROAM
# --------------------------------------------------

func _state_roam():

	_move_toward(roam_target, move_speed)

	if nav_agent.is_navigation_finished():
		roam_target = _random_roam_point()

	if _can_see_player():
		_enter_state(State.ALERT)

# --------------------------------------------------
# ALERT
# --------------------------------------------------

func _state_alert(delta):

	velocity.x = 0
	velocity.z = 0

	alert_timer -= delta

	if player:
		last_known_pos = player.global_position
		_face_target(last_known_pos)

	if _can_see_player():
		_enter_state(State.CHASE)
	elif alert_timer <= 0:
		_enter_state(State.ROAM)

# --------------------------------------------------
# CHASE
# --------------------------------------------------

func _state_chase(delta):

	if player == null:
		_enter_state(State.ROAM)
		return

	if _can_see_player():
		last_known_pos = player.global_position
		alert_timer = alert_linger

	nav_agent.target_position = last_known_pos

	_move_toward_nav(chase_speed)

	var dist = global_position.distance_to(player.global_position)

	if dist <= attack_range:
		_enter_state(State.ATTACK)
	elif !_can_see_player():
		alert_timer -= delta
		if alert_timer <= 0:
			_enter_state(State.ROAM)

# --------------------------------------------------
# ATTACK
# --------------------------------------------------

func _state_attack(delta):

	velocity.x = 0
	velocity.z = 0

	attack_timer -= delta

	if player == null:
		_enter_state(State.ROAM)
		return

	_face_target(player.global_position)

	if attack_timer <= 0 and !is_attacking:

		is_attacking = true

		_play_anim("Picking Up")

		await anim_player.animation_finished

		_do_attack()

		attack_timer = attack_cooldown
		is_attacking = false

		if global_position.distance_to(player.global_position) <= attack_range:
			_play_anim("Picking Up")
		else:
			_enter_state(State.CHASE)

# --------------------------------------------------
# Attack
# --------------------------------------------------

func _do_attack():
	emit_signal("player_hit")

# --------------------------------------------------
# State Changes
# --------------------------------------------------

func _enter_state(new_state):

	if state == new_state:
		return

	state = new_state

	match state:

		State.ROAM:
			alert_timer = 0
			_play_anim("Walking (1)")

		State.ALERT:
			alert_timer = alert_linger
			_play_anim("Picking Up")

		State.CHASE:
			_play_anim("Running (1)")

		State.ATTACK:
			attack_timer = 0

		State.DEAD:
			_die()

# --------------------------------------------------
# Death
# --------------------------------------------------

func _die():

	set_physics_process(false)

	$CollisionShape3D.disabled = true

	queue_free()

# --------------------------------------------------
# Vision
# --------------------------------------------------

func _can_see_player():

	if player == null:
		return false

	var to_player = player.global_position - global_position

	if to_player.length() > sight_range:
		return false

	var forward = -global_transform.basis.z

	var angle = rad_to_deg(forward.angle_to(to_player.normalized()))

	if angle > sight_fov_deg * 0.5:
		return false

	return true

# --------------------------------------------------
# Gravity
# --------------------------------------------------

func _apply_gravity(delta):

	if !is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

# --------------------------------------------------
# Movement
# --------------------------------------------------

func _move_toward(target, speed):

	nav_agent.target_position = target
	_move_toward_nav(speed)

func _move_toward_nav(speed):

	if nav_agent.is_navigation_finished():

		velocity.x = 0
		velocity.z = 0
		return

	var next = nav_agent.get_next_path_position()

	var dir = (next - global_position).normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	_face_direction(Vector3(dir.x,0,dir.z))

func _face_target(target):

	var dir = target - global_position
	dir.y = 0

	if dir.length_squared() > 0.001:
		_face_direction(dir.normalized())

func _face_direction(dir):

	if dir.length_squared() < 0.001:
		return

	var basis = Basis.looking_at(dir, Vector3.UP)

	global_transform.basis = global_transform.basis.slerp(basis,0.15)

# --------------------------------------------------
# Roaming
# --------------------------------------------------

func _random_roam_point():

	var angle = randf() * TAU
	var radius = randf_range(2,roam_radius)

	var point = spawn_position + Vector3(
		cos(angle) * radius,
		0,
		sin(angle) * radius
	)

	return NavigationServer3D.map_get_closest_point(
		nav_agent.get_navigation_map(),
		point
	)

# --------------------------------------------------
# Animation
# --------------------------------------------------

func _play_anim(name:String):

	if anim_player == null:
		return

	if !anim_player.has_animation(name):
		push_warning("Animation '%s' doesn't exist." % name)
		return

	if anim_player.current_animation == name:
		return

	anim_player.play(name)

func _set_loop(name:String, loop:bool):

	if !anim_player.has_animation(name):
		return

	var anim = anim_player.get_animation(name)

	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	else:
		anim.loop_mode = Animation.LOOP_NONE
