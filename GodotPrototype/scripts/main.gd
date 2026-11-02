extends Node3D

var player: CharacterBody3D
var car: CharacterBody3D
var camera: Camera3D
var driving := false
var move_dir := Vector2.ZERO
var drive_dir := Vector2.ZERO
var speed := 0.0
var status_label: Label

func _ready() -> void:
	_build_city()
	_build_player()
	_build_car()
	_build_camera()
	_build_ui()

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _build_city() -> void:
	_box(self, Vector3(100, 0.3, 100), Vector3(0, -0.2, 0), Color(0.20, 0.42, 0.25))
	_box(self, Vector3(12, 0.08, 100), Vector3(0, 0.0, 0), Color(0.12, 0.13, 0.15))
	_box(self, Vector3(100, 0.08, 12), Vector3(0, 0.01, 0), Color(0.12, 0.13, 0.15))
	for x in [-28, -16, 16, 28]:
		for z in [-28, -16, 16, 28]:
			var h := 5.0 + float(abs(x + z) % 9)
			_box(self, Vector3(8, h, 8), Vector3(x, h / 2.0, z), Color(0.42, 0.48, 0.55))
			_box(self, Vector3(8.2, 0.35, 8.2), Vector3(x, h + 0.12, z), Color(0.20, 0.28, 0.36))
	_box(self, Vector3(1, 0.03, 90), Vector3(-3, 0.06, 0), Color(0.9, 0.82, 0.25))
	_box(self, Vector3(1, 0.03, 90), Vector3(3, 0.06, 0), Color(0.9, 0.82, 0.25))

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(-5, 1, 5)
	add_child(player)
	var body := CapsuleMesh.new()
	body.radius = 0.42
	body.height = 1.8
	var visual := MeshInstance3D.new()
	visual.mesh = body
	visual.material_override = _mat(Color(0.12, 0.55, 0.95))
	player.add_child(visual)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	shape.shape = capsule
	player.add_child(shape)

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "Velocity"
	car.position = Vector3(0, 0.75, 5)
	add_child(car)
	_box(car, Vector3(2.0, 0.7, 3.8), Vector3(0, 0, 0), Color(0.88, 0.12, 0.08))
	_box(car, Vector3(1.55, 0.65, 1.7), Vector3(0, 0.62, -0.25), Color(0.12, 0.22, 0.30))
	for x in [-1.02, 1.02]:
		for z in [-1.2, 1.2]:
			var wheel := _box(car, Vector3(0.25, 0.55, 0.7), Vector3(x, -0.25, z), Color(0.04, 0.04, 0.05))
			wheel.rotation.z = PI / 2.0

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 7, 11)
	camera.current = true
	add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := HBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -90
	panel.offset_bottom = -12
	panel.offset_left = 12
	panel.offset_right = -12
	panel.add_theme_constant_override("separation", 12)
	layer.add_child(panel)
	var left := _make_button("◀")
	var forward := _make_button("▲")
	var back := _make_button("▼")
	var right := _make_button("▶")
	var enter := _make_button("ENTER / EXIT")
	for b in [left, forward, back, right, enter]:
		panel.add_child(b)
	left.button_down.connect(func(): _set_move(Vector2(-1, move_dir.y)))
	left.button_up.connect(func(): _set_move(Vector2(0, move_dir.y)))
	right.button_down.connect(func(): _set_move(Vector2(1, move_dir.y)))
	right.button_up.connect(func(): _set_move(Vector2(0, move_dir.y)))
	forward.button_down.connect(func(): _set_move(Vector2(move_dir.x, -1)))
	forward.button_up.connect(func(): _set_move(Vector2(move_dir.x, 0)))
	back.button_down.connect(func(): _set_move(Vector2(move_dir.x, 1)))
	back.button_up.connect(func(): _set_move(Vector2(move_dir.x, 0)))
	enter.pressed.connect(_toggle_vehicle)
	status_label = Label.new()
	status_label.text = "DHAKA VELOCITY  •  Walk to the red car and tap ENTER"
	status_label.position = Vector2(18, 18)
	status_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(status_label)

func _make_button(caption: String) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(90, 62)
	b.add_theme_font_size_override("font_size", 18)
	return b

func _set_move(v: Vector2) -> void:
	move_dir = v.normalized()

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

func _physics_process(delta: float) -> void:
	if driving:
		var throttle := -move_dir.y
		speed = move_toward(speed, throttle * 14.0, 18.0 * delta)
		car.rotate_y(-move_dir.x * delta * 1.8)
		car.velocity = -car.global_basis.z * speed
		car.move_and_slide()
	else:
		var direction := Vector3(move_dir.x, 0, move_dir.y)
		player.velocity.x = direction.x * 5.0
		player.velocity.z = direction.z * 5.0
		player.velocity.y -= 20.0 * delta
		player.move_and_slide()
	var target := car.global_position if driving else player.global_position
	var desired := target + Vector3(0, 7, 11)
	camera.global_position = camera.global_position.lerp(desired, 5.0 * delta)
	camera.look_at(target + Vector3(0, 1, 0), Vector3.UP)
