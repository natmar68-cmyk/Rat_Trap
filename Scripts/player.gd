extends CharacterBody3D

# ── Constants ──────────────────────────────────────────────────────────────────

const SPEED           := 10.0
const SPRINT_SPEED    := 20.0
const JUMP_VELOCITY   := 10.0
const GRAVITY         := 25.0

const MOUSE_SENSITIVITY := 0.002
const PITCH_LIMIT       := deg_to_rad(89)

const STAMINA_MAX   := 100.0
const STAMINA_DRAIN := 20.0
const STAMINA_REGEN := 20.0

const CLIMB_SPEED        := 6.0
const CLIMB_DETECT_DIST  := 1.2
const VAULT_BOOST        := 8.0
const CLIMB_GRACE_TIME   := 0.3
const MESH_TILT_SPEED    := 8.0
const CAM_TILT_SPEED     := 5.0

# ── State ──────────────────────────────────────────────────────────────────────

var stamina           := STAMINA_MAX
var exhausted         := false
var was_sprinting     := false

var is_climbing       := false
var climb_normal      := Vector3.ZERO
var climb_grace_timer := 0.0

var is_first_person     := true
var target_head_pitch   := 0.0
var override_head_pitch := false

var captured := false
# ── Node refs ──────────────────────────────────────────────────────────────────

@onready var head         : Node3D      = $Head
@onready var fp_camera    : Camera3D    = $Head/SpringArm3D/Camera3D2
@onready var tp_camera    : Camera3D    = $Head/SpringArm3D/Camera3D
@onready var rat_mesh     : Node3D      = $Rat
@onready var stamina_bar  : ProgressBar = $CanvasLayer/Control/ProgressBar
@onready var vignette     : ColorRect   = $CanvasLayer/Control/Vignette
@onready var climb_prompt : Label       = $CanvasLayer/Control/ClimbPrompt

# ── Ready ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	AudioManager.play_game_music()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	fp_camera.make_current()
	rat_mesh.visible      = false
	stamina_bar.max_value = STAMINA_MAX
	stamina_bar.value     = stamina

	_setup_vignette()
	_setup_climb_prompt()
	_connect_enemies()

func _setup_vignette() -> void:
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.z_index      = 10
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat    := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	float vignette = smoothstep(0.6, 0.8, dist * 1.8);
	COLOR = vec4(1.0, 0.0, 0.0, clamp(vignette * intensity, 0.0, 0.6));
}
"""
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.0)
	vignette.material = mat

func _setup_climb_prompt() -> void:
	climb_prompt.text                 = "Press 'E' to Climb"
	climb_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	climb_prompt.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	climb_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	climb_prompt.position.y -= 80
	climb_prompt.visible    = false
	climb_prompt.add_theme_font_size_override("font_size", 18)

# ── Input ──────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	_handle_camera_toggle()
	_handle_mouse_look(event)
	_handle_cursor_lock()
	_handle_interact()

func _handle_camera_toggle() -> void:
	if not Input.is_action_just_pressed("toggle_camera"):
		return
	is_first_person = !is_first_person
	if is_first_person:
		fp_camera.make_current()
		rat_mesh.visible = false
	else:
		tp_camera.make_current()
		rat_mesh.visible = true
		head.rotation.x  = 0.0

func _handle_mouse_look(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		return
	rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
	if not override_head_pitch:
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

func _handle_cursor_lock() -> void:
	if not Input.is_action_just_pressed("ui_cancel"):
		return
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _handle_interact() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	if is_climbing:
		_exit_climb()
	else:
		_try_enter_climb()

# ── Physics process ────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if captured:
		return
	if is_climbing:
		_process_climbing(delta)
	else:
		_process_normal(delta)
	_update_mesh_rotation(delta)
	_update_camera_tilt(delta)
	_update_climb_prompt()

# ── Normal movement ────────────────────────────────────────────────────────────

func _process_normal(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Require any movement key + sprint, not just move_forward.
	# This also fixes sprint+jump: was_sprinting latches true as long as
	# wants_sprint is true, regardless of floor state.
	var wants_sprint := (
		Input.is_action_pressed("sprint")
		and input_dir.length() > 0.0
		and stamina > 0
		and not exhausted
	)

	if is_on_floor() or wants_sprint:
		was_sprinting = wants_sprint
	var sprinting := wants_sprint or (was_sprinting and not is_on_floor())

	_update_stamina(sprinting and is_on_floor(), delta)

	var speed     := SPRINT_SPEED if sprinting else SPEED
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()

# ── Stamina ────────────────────────────────────────────────────────────────────

func _update_stamina(draining: bool, delta: float, regen_rate: float = 1.0) -> void:
	if draining:
		stamina = max(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina == 0.0:
			exhausted = true
	else:
		stamina = min(stamina + STAMINA_REGEN * regen_rate * delta, STAMINA_MAX)
		if exhausted and stamina >= STAMINA_MAX:
			exhausted = false
	stamina_bar.value = stamina
	_update_vignette(delta)

# ── Climbing ───────────────────────────────────────────────────────────────────

func _get_nearby_climbable() -> Dictionary:
	var space      := get_world_3d().direct_space_state
	var yaw        := rotation.y
	var probe_dirs : Array[Vector3] = [
		Vector3(-sin(yaw), 0, -cos(yaw)),  # forward
		Vector3( sin(yaw), 0,  cos(yaw)),  # back
		Vector3( cos(yaw), 0, -sin(yaw)),  # right
		Vector3(-cos(yaw), 0,  sin(yaw)),  # left
	]
	var ray_origin := global_position + Vector3.UP * 0.3

	for dir in probe_dirs:
		var excluded : Array = [self]
		var end      := ray_origin + dir * CLIMB_DETECT_DIST
		for _i in range(8):
			var query := PhysicsRayQueryParameters3D.create(ray_origin, end)
			query.exclude = excluded
			var hit : Dictionary = space.intersect_ray(query)
			if hit.is_empty():
				break
			var collider = hit["collider"]
			if collider is Node and collider.is_in_group("climbable"):
				return {"normal": hit["normal"], "position": hit["position"]}
			excluded.append(collider)
	return {}

func _try_enter_climb() -> void:
	var result : Dictionary = _get_nearby_climbable()
	if result.is_empty():
		return
	climb_normal = result["normal"]
	if abs(climb_normal.dot(Vector3.UP)) > 0.9:
		return
	is_climbing         = true
	climb_grace_timer   = CLIMB_GRACE_TIME
	velocity            = Vector3.UP * 3.0 + (-climb_normal) * 2.0
	var flat_normal     := Vector3(climb_normal.x, 0, climb_normal.z).normalized()
	rotation.y          = Vector3.FORWARD.signed_angle_to(-flat_normal, Vector3.UP)
	target_head_pitch   = PI / 2.0
	override_head_pitch = true

func _exit_climb() -> void:
	is_climbing         = false
	climb_normal        = Vector3.ZERO
	velocity            = Vector3.ZERO
	target_head_pitch   = 0.0
	override_head_pitch = false

func _process_climbing(delta: float) -> void:
	var input_dir  := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wall_right := Vector3.UP.cross(climb_normal).normalized()

	if input_dir.y < 0.0 and _can_vault_over():
		_do_vault()
		return

	var climb_sprinting := (
		Input.is_action_pressed("sprint")
		and stamina > 0
		and not exhausted
		and input_dir.length() > 0.0
	)
	var current_climb_speed := CLIMB_SPEED * 2.0 if climb_sprinting else CLIMB_SPEED
	_update_stamina(climb_sprinting, delta, 0.5)

	var into_wall := -climb_normal * 3.0
	var move      := (wall_right * input_dir.x + Vector3.UP * -input_dir.y) * current_climb_speed
	velocity.x = move.x + into_wall.x
	velocity.y = move.y
	velocity.z = move.z + into_wall.z

	if Input.is_action_just_pressed("jump"):
		_exit_climb()
		velocity   = climb_normal * 5.0
		velocity.y = JUMP_VELOCITY
		move_and_slide()
		return

	move_and_slide()

	climb_grace_timer = max(climb_grace_timer - delta, 0.0)
	if _get_nearby_climbable().is_empty() or (is_on_floor() and climb_grace_timer <= 0.0):
		_exit_climb()

func _can_vault_over() -> bool:
	var space := get_world_3d().direct_space_state

	var chest_origin := global_position + Vector3.UP * 0.3
	var chest_query  := PhysicsRayQueryParameters3D.create(
		chest_origin, chest_origin + (-climb_normal) * CLIMB_DETECT_DIST
	)
	chest_query.exclude = [self]

	var over_origin := global_position + Vector3.UP * 1.8 + (-climb_normal) * 0.8
	var over_query  := PhysicsRayQueryParameters3D.create(over_origin, over_origin + Vector3.UP * 0.5)
	over_query.exclude = [self]

	return space.intersect_ray(chest_query).is_empty() and space.intersect_ray(over_query).is_empty()

func _do_vault() -> void:
	var saved_normal := climb_normal
	_exit_climb()
	velocity.y  = VAULT_BOOST
	velocity   += -saved_normal * SPEED

# ── Climb prompt ───────────────────────────────────────────────────────────────

func _update_climb_prompt() -> void:
	climb_prompt.visible = not is_climbing and not _get_nearby_climbable().is_empty()

# ── Mesh rotation ──────────────────────────────────────────────────────────────

func _update_mesh_rotation(delta: float) -> void:
	var target_basis : Basis
	if is_climbing:
		var mesh_up    := climb_normal
		var mesh_fwd   := -Vector3.UP if abs(mesh_up.dot(Vector3.UP)) <= 0.99 else Vector3.FORWARD
		var mesh_right := mesh_fwd.cross(mesh_up).normalized()
		mesh_fwd        = mesh_up.cross(mesh_right).normalized()
		target_basis    = global_transform.basis.inverse() * Basis(mesh_right, mesh_up, -mesh_fwd)
	else:
		target_basis = Basis(Vector3.UP, PI)

	var current_quat := Quaternion(rat_mesh.transform.basis.orthonormalized())
	var target_quat  := Quaternion(target_basis.orthonormalized())
	rat_mesh.transform.basis = Basis(current_quat.slerp(target_quat, clamp(MESH_TILT_SPEED * delta, 0.0, 1.0)))

# ── Camera tilt ────────────────────────────────────────────────────────────────

func _update_camera_tilt(delta: float) -> void:
	if not override_head_pitch or not is_first_person:
		return
	head.rotation.x = lerp(head.rotation.x, target_head_pitch, clamp(CAM_TILT_SPEED * delta, 0.0, 1.0))

# ── Vignette ───────────────────────────────────────────────────────────────────

func _update_vignette(delta: float) -> void:
	var mat := vignette.material as ShaderMaterial
	if mat == null:
		return
	var current : float = mat.get_shader_parameter("intensity") if mat.get_shader_parameter("intensity") != null else 0.0
	var target  : float
	if exhausted:
		target = lerp(0.05, 0.25, (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5)
	else:
		target = 0.0
	mat.set_shader_parameter("intensity", move_toward(current, target, delta * 3.0))

# ── Enemies ────────────────────────────────────────────────────────────────────

func _connect_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.player_hit.is_connected(_on_player_hit):
			enemy.player_hit.connect(_on_player_hit)

func _on_player_hit() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scenes/death_screen.tscn")
	
func capture():
	captured = true

	velocity = Vector3.ZERO

	# Disable collisions
	set_collision_layer(0)
	set_collision_mask(0)

	# Stop processing movement
	set_physics_process(false)
