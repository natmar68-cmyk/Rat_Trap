extends CharacterBody3D

# Movement
const SPEED = 10.0
const SPRINT_SPEED = 16.0
const JUMP_VELOCITY = 3.0
const GRAVITY = 20.0

# Mouse look
const MOUSE_SENSITIVITY = 0.002
const PITCH_LIMIT = deg_to_rad(89)

@onready var head: Node3D = $Head
@onready var fp_camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $MeshInstance3D

var tp_camera: Camera3D = null
var is_first_person := true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Safely find the third person camera
	var spring_arm = head.get_node_or_null("SpringArm3D")
	if spring_arm:
		tp_camera = spring_arm.get_node_or_null("Camera3D")

	fp_camera.make_current()
	body_mesh.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Toggle first/third person
	if Input.is_action_just_pressed("toggle_camera"):
		if tp_camera == null:
			print("No third person camera found! Check your scene tree.")
			return
		is_first_person = !is_first_person
		if is_first_person:
			fp_camera.make_current()
			body_mesh.visible = false
		else:
			tp_camera.make_current()
			body_mesh.visible = true

	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

	# Toggle mouse capture
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _handle_movement(delta: float) -> void:
	var speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
