extends CharacterBody3D

# Movement
const SPEED = 10.0
const SPRINT_SPEED = 20.0
const JUMP_VELOCITY = 10.0
const GRAVITY = 25.0
# Mouse look
const MOUSE_SENSITIVITY = 0.002
const PITCH_LIMIT = deg_to_rad(89)
# Stamina
const STAMINA_MAX = 100.0
const STAMINA_DRAIN = 20.0
const STAMINA_REGEN = 20.0
# Climbing
const CLIMB_SPEED = 6.0
const CLIMB_DETECT_DIST = 1.2
const VAULT_BOOST = 8.0
const MESH_TILT_SPEED = 8.0
const CAM_TILT_SPEED = 5.0

var stamina := STAMINA_MAX
var exhausted := false
var is_climbing := false
var climb_normal := Vector3.ZERO

@onready var head: Node3D = $Head
@onready var fp_camera: Camera3D = $Head/Camera3D
@onready var rat_mesh: Node3D = $Rat
@onready var stamina_bar: ProgressBar = $CanvasLayer/Control/ProgressBar
@onready var vignette: ColorRect = $CanvasLayer/Control/Vignette
@onready var climb_prompt: Label = $CanvasLayer/Control/ClimbPrompt

var tp_camera: Camera3D = null
var is_first_person := true

var target_head_pitch := 0.0
var override_head_pitch := false

func _ready() -> void:
	AudioManager.play_game_music()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var spring_arm = head.get_node_or_null("SpringArm3D")
	if spring_arm:
		tp_camera = spring_arm.get_node_or_null("Camera3D")
	fp_camera.make_current()
	rat_mesh.visible = false
	stamina_bar.max_value = STAMINA_MAX
	stamina_bar.value = stamina
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.z_index = 10
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
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

	climb_prompt.text = "Press 'E' to Climb"
	climb_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	climb_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	climb_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	climb_prompt.position.y -= 80
	climb_prompt.visible = false
	climb_prompt.add_theme_font_size_override("font_size", 18)

	_connect_enemies()

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_camera"):
		if tp_camera == null:
			print("No third person camera found! Check your scene tree.")
			return
		is_first_person = !is_first_person
		if is_first_person:
			fp_camera.make_current()
			rat_mesh.visible = false
		else:
			tp_camera.make_current()
			rat_mesh.visible = true

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		if not override_head_pitch:
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			head.rotation.x = clamp(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if Input.is_action_just_pressed("interact"):
		if is_climbing:
			_exit_climb()
		else:
			_try_enter_climb()

func _physics_process(delta: float) -> void:
	if is_climbing:
		_process_climbing(delta)
	else:
		_process_normal(delta)
	_update_mesh_rotation(delta)
	_update_camera_tilt(delta)
	_update_climb_prompt()
	_debug_climb()   # ← add this temporarily
	if is_climbing:
		print("works")
# ── Normal movement ────────────────────────────────────────────────────────────

func _process_normal(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var can_sprint := Input.is_action_pressed("sprint") and stamina > 0 and not exhausted and Input.is_action_pressed("move_forward")
	if can_sprint:
		stamina = max(stamina - STAMINA_DRAIN * delta, 0)
		if stamina == 0:
			exhausted = true
	else:
		stamina = min(stamina + STAMINA_REGEN * delta, STAMINA_MAX)
		if exhausted and stamina == STAMINA_MAX:
			exhausted = false
	stamina_bar.value = stamina
	_update_vignette(delta)

	var speed := SPRINT_SPEED if can_sprint else SPEED
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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

# ── Climbing ───────────────────────────────────────────────────────────────────

func _try_enter_climb() -> void:
	var result: Dictionary = _get_nearby_climbable()
	if result.is_empty():
		return

	climb_normal = result["normal"]

	if abs(climb_normal.dot(Vector3.UP)) > 0.9:
		return

	is_climbing = true
	velocity = Vector3.ZERO

	var flat_normal := Vector3(climb_normal.x, 0, climb_normal.z).normalized()
	var angle := Vector3.FORWARD.signed_angle_to(-flat_normal, Vector3.UP)
	rotation.y = angle

	target_head_pitch = PI / 2.0
	override_head_pitch = true

func _exit_climb() -> void:
	is_climbing = false
	climb_normal = Vector3.ZERO
	velocity = Vector3.ZERO
	target_head_pitch = 0.0
	override_head_pitch = false

func _process_climbing(delta: float) -> void:
	var into_wall := -climb_normal * 3.0
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wall_right := Vector3.UP.cross(climb_normal).normalized()

	var moving_up := input_dir.y < 0.0
	if moving_up and _can_vault_over():
		_do_vault()
		return

	var can_climb_sprint := Input.is_action_pressed("sprint") and stamina > 0 and not exhausted and input_dir.length() > 0.0
	var current_climb_speed := CLIMB_SPEED * 2.0 if can_climb_sprint else CLIMB_SPEED

	if can_climb_sprint:
		stamina = max(stamina - STAMINA_DRAIN * delta, 0)
		if stamina == 0:
			exhausted = true
	else:
		stamina = min(stamina + STAMINA_REGEN * 0.5 * delta, STAMINA_MAX)
		if exhausted and stamina == STAMINA_MAX:
			exhausted = false
	stamina_bar.value = stamina
	_update_vignette(delta)

	var move := (wall_right * input_dir.x + Vector3.UP * -input_dir.y) * current_climb_speed
	velocity.x = move.x + into_wall.x
	velocity.y = move.y
	velocity.z = move.z + into_wall.z

	if Input.is_action_just_pressed("jump"):
		_exit_climb()
		velocity = climb_normal * 5.0
		velocity.y = JUMP_VELOCITY
		move_and_slide()
		return

	move_and_slide()

	if _get_nearby_climbable().is_empty() or is_on_floor():
		_exit_climb()

func _can_vault_over() -> bool:
	var space := get_world_3d().direct_space_state

	var chest_origin := global_position + Vector3.UP * 0.5
	var chest_target := chest_origin + (-climb_normal) * CLIMB_DETECT_DIST
	var chest_query := PhysicsRayQueryParameters3D.create(chest_origin, chest_target)
	chest_query.exclude = [self]
	var chest_hit: Dictionary = space.intersect_ray(chest_query)

	var over_origin := global_position + Vector3.UP * 1.8 + (-climb_normal) * 0.8
	var over_target := over_origin + Vector3.UP * 0.5
	var over_query := PhysicsRayQueryParameters3D.create(over_origin, over_target)
	over_query.exclude = [self]
	var over_hit: Dictionary = space.intersect_ray(over_query)

	return chest_hit.is_empty() and over_hit.is_empty()

func _do_vault() -> void:
	var saved_normal := climb_normal
	_exit_climb()
	velocity.y = VAULT_BOOST
	velocity += -saved_normal * SPEED

func _get_nearby_climbable() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var ray_origin := global_position + Vector3.UP * 0.5
	var probe_dirs: Array[Vector3] = [
		-global_transform.basis.z,
		global_transform.basis.z,
		global_transform.basis.x,
		-global_transform.basis.x,
	]
	for dir in probe_dirs:
		var excluded := [self]
		var end := ray_origin + dir * CLIMB_DETECT_DIST
		# Keep casting, skipping non-climbable blockers
		for i in range(8):
			var query := PhysicsRayQueryParameters3D.create(ray_origin, end)
			query.exclude = excluded
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty():
				break
			var collider = hit["collider"]
			if collider is Node and collider.is_in_group("climbable"):
				return {"normal": hit["normal"], "position": hit["position"]}
			# Not climbable — exclude it and try again
			excluded.append(collider)
	return {}
# ── Climb prompt ───────────────────────────────────────────────────────────────

func _update_climb_prompt() -> void:
	if is_climbing:
		climb_prompt.visible = false
		return
	climb_prompt.visible = not _get_nearby_climbable().is_empty()

# ── Mesh rotation ──────────────────────────────────────────────────────────────

func _update_mesh_rotation(delta: float) -> void:
	var target_basis: Basis
	if is_climbing:
		var world_up := climb_normal
		var world_fwd := Vector3.UP
		if abs(world_up.dot(world_fwd)) > 0.99:
			world_fwd = Vector3.FORWARD
		var world_right := world_fwd.cross(world_up).normalized()
		world_fwd = world_up.cross(world_right).normalized()
		var global_target := Basis(world_right, world_up, -world_fwd)
		target_basis = global_transform.basis.inverse() * global_target
	else:
		# Rotate 180° around Y so the mesh faces forward (away from the camera)
		target_basis = Basis(Vector3.UP, PI)

	var current_quat := Quaternion(rat_mesh.transform.basis.orthonormalized())
	var target_quat := Quaternion(target_basis.orthonormalized())
	var new_quat := current_quat.slerp(target_quat, clamp(MESH_TILT_SPEED * delta, 0.0, 1.0))
	rat_mesh.transform.basis = Basis(new_quat)

# ── Camera tilt ────────────────────────────────────────────────────────────────

func _update_camera_tilt(delta: float) -> void:
	if not override_head_pitch:
		return
	head.rotation.x = lerp(head.rotation.x, target_head_pitch, clamp(CAM_TILT_SPEED * delta, 0.0, 1.0))

# ── Vignette & enemies ─────────────────────────────────────────────────────────

func _update_vignette(delta: float) -> void:
	var mat := vignette.material as ShaderMaterial
	if mat == null:
		return
	var raw = mat.get_shader_parameter("intensity")
	var current: float = raw if raw != null else 0.0
	var target: float
	if exhausted:
		var pulse := (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
		target = lerp(0.05, 0.25, pulse)
	else:
		target = 0.0
	var new_intensity := move_toward(current, target, delta * 3.0)
	mat.set_shader_parameter("intensity", new_intensity)

func _connect_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.player_hit.is_connected(_on_player_hit):
			enemy.player_hit.connect(_on_player_hit)

func _on_player_hit() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/death_screen.tscn")

func _debug_climb() -> void:
	var space := get_world_3d().direct_space_state
	var ray_origin := global_position + Vector3.UP * 0.5
	var probe_dirs: Array[Vector3] = [
		-global_transform.basis.z,
		global_transform.basis.z,
		global_transform.basis.x,
		-global_transform.basis.x,
	]
	for dir in probe_dirs:
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin,
			ray_origin + dir * CLIMB_DETECT_DIST
		)
		query.exclude = [self]
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var collider = hit["collider"]
			print("RAY HIT: ", collider.name, " | groups: ", collider.get_groups())
