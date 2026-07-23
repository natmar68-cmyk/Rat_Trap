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

# Matches scene tree: cat_v2 > Cat > AnimationPlayer
@onready var anim_player: AnimationPlayer = $Cat/AnimationPlayer

# ─────────────────────────────────────────────
# Animation names (must match exactly, including the pipes)
# ─────────────────────────────────────────────
const ANIM_WALK_SLOW := "SKM_Cat|SKM_Cat|Cat_WalkSlow"
const ANIM_TROT := "SKM_Cat|SKM_Cat|Cat_Trot"
const ANIM_IDLE := "SKM_Cat|AA_SKM_Cat|Cat_Idle01"
const ANIM_ATTACK := "SKM_Cat|SKM_Cat|Cat_Dash"   # placeholder - swap for your real attack clip
const ANIM_DEATH := "SKM_Cat|SKM_Cat|Cat_Death"

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

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	_set_loop(ANIM_WALK_SLOW, true)
	_set_loop(ANIM_TROT, true)

	_play_anim(ANIM_WALK_SLOW)

	call_deferred("_init_nav")

func _init_nav():
	await get_tree().physics_frame
	await get_tree().physics_frame
	roam_target = _random_roam_point()

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

		_play_anim(ANIM_ATTACK)

		await anim_player.animation_finished

		_do_attack()

		attack_timer = attack_cooldown
		is_attacking = false

		if global_position.distance_to(player.global_position) <= attack_range:
			_play_anim(ANIM_ATTACK)
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
			_play_anim(ANIM_WALK_SLOW)

		State.ALERT:
			alert_timer = alert_linger
			_play_anim(ANIM_IDLE)

		State.CHASE:
			_play_anim(ANIM_TROT)

		State.ATTACK:
			attack_timer = 0

		State.DEAD:
			_die()

# --------------------------------------------------
# Death
# --------------------------------------------------

func _die():

	set_physics_process(false)

	_play_anim(ANIM_DEATH)

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

	var target_basis = Basis.looking_at(dir, Vector3.UP)

	var body_scale = global_transform.basis.get_scale()
	var current_rotation = global_transform.basis.orthonormalized()

	var blended = current_rotation.slerp(target_basis, 0.15)

	global_transform.basis = blended.scaled(body_scale)

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

func _play_anim(anim_name:String):

	if anim_player == null:
		return

	if !anim_player.has_animation(anim_name):
		push_warning("Animation '%s' doesn't exist." % anim_name)
		return

	if anim_player.current_animation == anim_name:
		return

	anim_player.play(anim_name)

func _set_loop(anim_name:String, loop:bool):

	if !anim_player.has_animation(anim_name):
		return

	var anim = anim_player.get_animation(anim_name)

	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	else:
		anim.loop_mode = Animation.LOOP_NONE
