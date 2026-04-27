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
const STAMINA_DRAIN = 20.0
const STAMINA_REGEN = 20.0
var stamina := STAMINA_MAX
var exhausted := false

@onready var head: Node3D = $Head
@onready var fp_camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $MeshInstance3D
@onready var stamina_bar: ProgressBar = $CanvasLayer/Control/ProgressBar
@onready var vignette: ColorRect = $CanvasLayer/Control/Vignette

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
	# Vignette setup
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
			exhausted = true
	else:
		stamina = min(stamina + STAMINA_REGEN * delta, STAMINA_MAX)
		if exhausted and stamina == STAMINA_MAX:
			exhausted = false
	stamina_bar.value = stamina
	# Vignette
	_update_vignette(delta)
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
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		move_and_slide()

func _update_vignette(delta: float) -> void:
	var mat := vignette.material as ShaderMaterial
	if mat == null:
		return
	var raw = mat.get_shader_parameter("intensity")
	var current: float = raw if raw != null else 0.0
	var target: float
	if exhausted:
		var pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
		target = lerp(0.05, 0.25, pulse)
	else:
		target = 0.0
	var new_intensity := move_toward(current, target, delta * 3.0)
	mat.set_shader_parameter("intensity", new_intensity)
