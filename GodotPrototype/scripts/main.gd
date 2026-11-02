extends Node3D

var player: CharacterBody3D
var car: CharacterBody3D
var camera: Camera3D
var driving := false
var move_dir := Vector2.ZERO
var steer_input := 0.0
var throttle_input := 0.0
var brake_pressed := false
var speed := 0.0
var status_label: Label
var traffic_cars: Array[Node3D] = []

func _ready() -> void:
	_build_city()
	_build_player()
	_build_car()
	_build_traffic()
	_build_camera()
	_build_ui()

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _solid_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	_box(body, size, Vector3.ZERO, color)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _build_city() -> void:
	_solid_box(self, Vector3(100, 0.3, 100), Vector3(0, -0.2, 0), Color(0.20, 0.42, 0.25))
	_solid_box(self, Vector3(12, 0.08, 100), Vector3(0, 0.0, 0), Color(0.12, 0.13, 0.15))
	_solid_box(self, Vector3(100, 0.08, 12), Vector3(0, 0.01, 0), Color(0.12, 0.13, 0.15))
	for x in [-28, -16, 16, 28]:
		for z in [-28, -16, 16, 28]:
			var height := 5.0 + float(abs(x + z) % 9)
			_solid_box(self, Vector3(8, height, 8), Vector3(x, height / 2.0, z), Color(0.42, 0.48, 0.55))
			_box(self, Vector3(8.2, 0.35, 8.2), Vector3(x, height + 0.12, z), Color(0.20, 0.28, 0.36))
	_box(self, Vector3(1, 0.03, 90), Vector3(-3, 0.06, 0), Color(0.9, 0.82, 0.25))
	_box(self, Vector3(1, 0.03, 90), Vector3(3, 0.06, 0), Color(0.9, 0.82, 0.25))
	for z in range(-42, 45, 6):
		_box(self, Vector3(0.18, 0.025, 2.5), Vector3(0, 0.065, z), Color(0.92, 0.92, 0.88))
	for x in [-9, 9]:
		for z in [-36, -18, 18, 36]:
			_solid_box(self, Vector3(0.25, 4.5, 0.25), Vector3(x, 2.25, z), Color(0.18, 0.20, 0.22))
			_box(self, Vector3(1.4, 0.18, 0.7), Vector3(x, 4.55, z), Color(0.95, 0.82, 0.42))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_SKY
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.55, 0.62, 0.72)
	world.ambient_light_energy = 0.65
	environment.environment = world
	add_child(environment)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(-5, 1, 5)
	add_child(player)
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.42
	capsule_mesh.height = 1.8
	var visual := MeshInstance3D.new()
	visual.mesh = capsule_mesh
	visual.material_override = _mat(Color(0.12, 0.55, 0.95))
	player.add_child(visual)
	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.42
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	player.add_child(collision)

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "Velocity"
	car.position = Vector3(0, 0.75, 5)
	add_child(car)
	_box(car, Vector3(2.0, 0.7, 3.8), Vector3.ZERO, Color(0.88, 0.12, 0.08))
	_box(car, Vector3(1.55, 0.65, 1.7), Vector3(0, 0.62, -0.25), Color(0.12, 0.22, 0.30))
	for x in [-1.02, 1.02]:
		for z in [-1.2, 1.2]:
			_box(car, Vector3(0.25, 0.55, 0.7), Vector3(x, -0.25, z), Color(0.04, 0.04, 0.05))
	var car_collision := CollisionShape3D.new()
	var car_shape := BoxShape3D.new()
	car_shape.size = Vector3(1.85, 0.8, 3.55)
	car_collision.shape = car_shape
	car.add_child(car_collision)


func _build_traffic() -> void:
	for i in range(4):
		var traffic := Node3D.new()
		traffic.name = "Traffic_%d" % i
		traffic.position = Vector3(-2.0 if i % 2 == 0 else 2.0, 0.55, -30.0 + float(i) * 18.0)
		add_child(traffic)
		var paint := [Color(0.12, 0.42, 0.82), Color(0.82, 0.72, 0.18), Color(0.82, 0.82, 0.78), Color(0.16, 0.58, 0.38)][i]
		_box(traffic, Vector3(1.65, 0.62, 3.0), Vector3.ZERO, paint)
		_box(traffic, Vector3(1.25, 0.48, 1.35), Vector3(0, 0.5, -0.15), Color(0.12, 0.20, 0.28))
		traffic_cars.append(traffic)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 7, 11)
	camera.current = true
	camera.fov = 70
	add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := HBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -82
	panel.offset_bottom = -8
	panel.offset_left = 8
	panel.offset_right = -8
	panel.add_theme_constant_override("separation", 5)
	layer.add_child(panel)
	var left := _make_button("◀", 52)
	var forward := _make_button("▲", 52)
	var back := _make_button("▼", 52)
	var right := _make_button("▶", 52)
	var brake := _make_button("BRAKE", 64)
	var enter := _make_button("ENTER", 72)
	for button in [left, forward, back, right, brake, enter]:
		panel.add_child(button)
	left.button_down.connect(_press_left)
	left.button_up.connect(_release_left)
	right.button_down.connect(_press_right)
	right.button_up.connect(_release_right)
	forward.button_down.connect(_press_forward)
	forward.button_up.connect(_release_forward)
	back.button_down.connect(_press_reverse)
	back.button_up.connect(_release_reverse)
	brake.button_down.connect(func(): brake_pressed = true)
	brake.button_up.connect(func(): brake_pressed = false)
	enter.pressed.connect(_toggle_vehicle)
	status_label = Label.new()
	status_label.text = "DHAKA VELOCITY  •  Walk to the red car and tap ENTER"
	status_label.position = Vector2(12, 12)
	status_label.add_theme_font_size_override("font_size", 17)
	layer.add_child(status_label)

func _make_button(caption: String, button_width: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(button_width, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	return button

func _set_move(value: Vector2) -> void:
	move_dir = value.normalized()

func _press_left() -> void:
	steer_input = -1.0
	_set_move(Vector2(-1, move_dir.y))

func _release_left() -> void:
	steer_input = 0.0
	_set_move(Vector2(0, move_dir.y))

func _press_right() -> void:
	steer_input = 1.0
	_set_move(Vector2(1, move_dir.y))

func _release_right() -> void:
	steer_input = 0.0
	_set_move(Vector2(0, move_dir.y))

func _press_forward() -> void:
	throttle_input = 1.0
	_set_move(Vector2(move_dir.x, -1))

func _release_forward() -> void:
	throttle_input = 0.0
	_set_move(Vector2(move_dir.x, 0))

func _press_reverse() -> void:
	throttle_input = -1.0
	_set_move(Vector2(move_dir.x, 1))

func _release_reverse() -> void:
	throttle_input = 0.0
	_set_move(Vector2(move_dir.x, 0))

func _toggle_vehicle() -> void:
	if driving:
		driving = false
		player.global_position = car.global_position + Vector3(2.2, 0.4, 0)
		player.visible = true
		status_label.text = "On foot • Walk to the car and tap ENTER"
	elif player.global_position.distance_to(car.global_position) < 4.0:
		driving = true
		player.visible = false
		status_label.text = "Driving • Use arrows, ENTER to exit"
	else:
		status_label.text = "Move closer to the red car first"

func _process(delta: float) -> void:
	for i in range(traffic_cars.size()):
		var traffic := traffic_cars[i]
		traffic.position.z += (5.0 + float(i % 2) * 1.5) * delta * (1.0 if i % 2 == 0 else -1.0)
		if traffic.position.z > 48.0:
			traffic.position.z = -48.0
		elif traffic.position.z < -48.0:
			traffic.position.z = 48.0

func _physics_process(delta: float) -> void:
	if driving:
		var target_speed := 0.0 if brake_pressed else (throttle_input * 16.0 if throttle_input > 0.0 else throttle_input * 8.0)
		var acceleration := 28.0 if brake_pressed else (10.0 if throttle_input != 0.0 else 15.0)
		speed = move_toward(speed, target_speed, acceleration * delta)
		var steering_strength := clampf(absf(speed) / 4.0, 0.0, 1.0)
		car.rotate_y(-steer_input * steering_strength * delta * 1.35 * signf(speed))
		car.velocity = -car.global_basis.z * speed
		car.move_and_slide()
		status_label.text = "DRIVING  •  %d km/h  •  BRAKE to stop" % int(absf(speed) * 3.6)
	else:
		var direction := Vector3(move_dir.x, 0, move_dir.y)
		player.velocity.x = direction.x * 5.0
		player.velocity.z = direction.z * 5.0
		player.velocity.y -= 20.0 * delta
		player.move_and_slide()
	var target := car.global_position if driving else player.global_position
	var follow_offset := car.global_basis.z * 10.0 + Vector3(0, 5.5, 0) if driving else Vector3(0, 7, 11)
	camera.global_position = camera.global_position.lerp(target + follow_offset, 4.5 * delta)
	camera.look_at(target + Vector3(0, 1, 0), Vector3.UP)
