extends CharacterBody3D

# ─────────────────────────────────────────────
#  Enemy.gd  –  Godot 4  |  self-contained AI
#  States: ROAM → ALERT → CHASE → ATTACK → DEAD
# ─────────────────────────────────────────────

# ── Signals ───────────────────────────────────
signal player_hit

# ── Tunable parameters ────────────────────────
@export var move_speed        : float = 10.0
@export var chase_speed       : float = 12.0
@export var sight_range       : float = 14.0
@export var sight_fov_deg     : float = 90.0
@export var attack_range      : float = 2.8
@export var attack_cooldown   : float = 1.2
@export var alert_linger      : float = 3.0
@export var roam_radius       : float = 10.0

# ── Node references ───────────────────────────
@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D

# ── Internal state ────────────────────────────
enum State { ROAM, ALERT, CHASE, ATTACK, DEAD }
var state          : State = State.ROAM
var player         : Node3D
var spawn_position : Vector3
var roam_target    : Vector3
var alert_timer    : float = 0.0
var attack_timer   : float = 0.0
var last_known_pos : Vector3

const GRAVITY : float = -9.8


func _ready() -> void:
	scale = Vector3(4, 4, 4)   # ← add this line
	spawn_position = global_position
	roam_target    = _random_roam_point()

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_apply_gravity(delta)

	match state:
		State.ROAM:   _state_roam(delta)
		State.ALERT:  _state_alert(delta)
		State.CHASE:  _state_chase(delta)
		State.ATTACK: _state_attack(delta)

	move_and_slide()


# ── State handlers ────────────────────────────

func _state_roam(_delta: float) -> void:
	_move_toward(roam_target, move_speed)

	if nav_agent.is_navigation_finished():
		roam_target = _random_roam_point()

	if _can_see_player():
		_enter_state(State.ALERT)


func _state_alert(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	alert_timer -= delta

	if player:
		last_known_pos = player.global_position
		_face_target(last_known_pos)

	if _can_see_player():
		_enter_state(State.CHASE)
	elif alert_timer <= 0.0:
		_enter_state(State.ROAM)


func _state_chase(delta: float) -> void:
	if not player:
		_enter_state(State.ROAM)
		return

	if _can_see_player():
		last_known_pos = player.global_position
		alert_timer    = alert_linger

	nav_agent.target_position = last_known_pos
	_move_toward_nav(chase_speed)

	var dist := global_position.distance_to(player.global_position)
	if dist <= attack_range:
		_enter_state(State.ATTACK)
	elif not _can_see_player() and alert_timer <= 0.0:
		_enter_state(State.ROAM)
	else:
		alert_timer -= delta


func _state_attack(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	attack_timer -= delta

	if not player:
		_enter_state(State.ROAM)
		return

	_face_target(player.global_position)

	if attack_timer <= 0.0:
		_do_attack()
		attack_timer = attack_cooldown

	var dist := global_position.distance_to(player.global_position)
	if dist > attack_range:
		_enter_state(State.CHASE)


# ── Attack ────────────────────────────────────

func _do_attack() -> void:
	emit_signal("player_hit")


# ── Transitions ───────────────────────────────

func _enter_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.ALERT:
			alert_timer = alert_linger
		State.DEAD:
			_die()


func _die() -> void:
	set_physics_process(false)
	$CollisionShape3D.disabled = true
	await get_tree().create_timer(2.5).timeout
	queue_free()


# ── Perception ────────────────────────────────

func _can_see_player() -> bool:
	if not player or not is_instance_valid(player):
		return false

	var to_player := player.global_position - global_position
	var dist      := to_player.length()

	if dist > sight_range:
		return false

	var forward   := -global_transform.basis.z
	var angle_deg := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle_deg > sight_fov_deg * 0.5:
		return false

	var space  := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 1.0
	var target := player.global_position + Vector3.UP * 1.0
	var query  := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result and result.collider != player:
		return false

	return true


# ── Movement ──────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0


func _move_toward(world_pos: Vector3, speed: float) -> void:
	nav_agent.target_position = world_pos
	_move_toward_nav(speed)


func _move_toward_nav(speed: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		return
	var next     := nav_agent.get_next_path_position()
	var dir      := (next - global_position).normalized()
	velocity.x    = dir.x * speed
	velocity.z    = dir.z * speed
	var flat_dir := Vector3(dir.x, 0, dir.z).normalized()
	_face_direction(flat_dir)


func _face_target(world_pos: Vector3) -> void:
	var dir := (world_pos - global_position)
	dir.y = 0
	if dir.length_squared() > 0.001:
		_face_direction(dir.normalized())


func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() < 0.001:
		return
	var target_basis := Basis.looking_at(dir, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_basis, 0.15)


func _random_roam_point() -> Vector3:
	var angle  := randf() * TAU
	var radius := randf_range(2.0, roam_radius)
	return spawn_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	
