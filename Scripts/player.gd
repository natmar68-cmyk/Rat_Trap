extends CharacterBody3D

# Movement
const SPEED = 10.0
const SPRINT_SPEED = 20.0
const JUMP_VELOCITY = 7.0
const GRAVITY = 20.0

# Mouse look
const MOUSE_SENSITIVITY = 0.002
const PITCH_LIMIT = deg_to_rad(89)

# Stamina
const STAMINA_MAX = 100.0
const STAMINA_DRAIN = 25.0
const STAMINA_REGEN = 15.0
var stamina := STAMINA_MAX
var exhausted := false  # locked out of sprinting until full regen

@onready var head: Node3D = $Head
@onready var fp_camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $MeshInstance3D
@onready var stamina_bar: ProgressBar = $CanvasLayer/Control/ProgressBar

var tp_camera: Camera3D = null
var is_first_person := true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var spring_arm = head.get_node_or_null("SpringArm3D")
	if spring_arm:
		tp_camera = spring_arm.get_node_or_null("Camera3D")
	fp_camera.make_current()
	body_mesh.visible = false
	stamina_bar.max_value = STAMINA_MAX
	stamina_bar.value = stamina

func _input(event: InputEvent) -> void:
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

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Stamina
	var can_sprint = Input.is_action_pressed("sprint") and stamina > 0 and not exhausted
	if can_sprint:
		stamina = max(stamina - STAMINA_DRAIN * delta, 0)
		if stamina == 0:
			exhausted = true  # hit zero, lock sprint until fully refilled
	else:
		stamina = min(stamina + STAMINA_REGEN * delta, STAMINA_MAX)
		if exhausted and stamina == STAMINA_MAX:
			exhausted = false  # fully refilled, can sprint again

	stamina_bar.value = stamina

	# Movement
	var speed = SPRINT_SPEED if can_sprint else SPEED
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		move_and_slide()
