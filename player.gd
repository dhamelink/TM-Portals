extends CharacterBody3D

var speed
const WALK_SPEED = 3.0
const SPRINT_SPEED = 6.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.007

#variables for head bobbing
const BOB_FREQ = 0.05
const BOB_AMP = 0.06
var t_bob = 0.0

#FOV Variables
var base_fov = 75.0
const FOV_CHANGE = 1.4

# Coyote timer variables
var was_on_floor = false
@onready var coyote_timer = $CoyoteTimer

@onready var head = $Head
@onready var camera = $Head/PlayerCamera

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Multiply by relative x because mouse movement on the x axis is translated as rotation on the y axis
		head.rotate_y(-event.relative.x * SENSITIVITY)
		# Inverse applies to the x axis
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		# Clamp limits rotation of the camera to avoid it doing full rotations
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if Input.is_key_pressed(KEY_R):
		self.global_position.x = 0
		self.global_position.y = 2
		self.global_position.z = 0
		velocity.x = 0
		velocity.z = 0
		velocity.y = 0
		
	
	var is_on_floor_now = is_on_floor()
	# START COYOTE TIMER: If we were on floor last frame but aren't now (and didn't jump)
	if was_on_floor and not is_on_floor_now and velocity.y <= 0:
		coyote_timer.start()
	

	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor_now or not coyote_timer.is_stopped():
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop() # Reset timer so they can't double jump
	
	was_on_floor = is_on_floor_now
	
	# Handle sprint
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 9.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 9.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.5)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.5)
	
	
	
	#Head bob		(delta is how much time has passed since last frame)
	t_bob += delta + velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	#FOV change with speed
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var velocity_clamped = clamp(horizontal_velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = base_fov + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	
	move_and_slide()
	
	

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	
#git test
