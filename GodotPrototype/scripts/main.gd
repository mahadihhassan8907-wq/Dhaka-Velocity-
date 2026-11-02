extends Node3D

var player: CharacterBody3D
var car: CharacterBody3D
var car_paint: MeshInstance3D
var paint_index := 0
var suv_visual: Node3D
var suv_paint: MeshInstance3D
var selected_suv := false
var sport_spoiler: Node3D
var spoiler_enabled := true
var nitro_pressed := false
var nitro_energy := 3.0
var drift_pressed := false
var sport_rims: Array[MeshInstance3D] = []
var suv_rims: Array[MeshInstance3D] = []
var rim_index := 0
var rim_colors: Array[Color] = [Color(0.78, 0.82, 0.88), Color(0.12, 0.14, 0.18), Color(0.82, 0.48, 0.16), Color(0.25, 0.72, 0.68)]
var rim_names: Array[String] = ["SILVER", "GRAPHITE", "BRONZE", "TEAL"]
var current_paint_color := Color(0.88, 0.12, 0.08)
var finish_index := 1
var finish_names: Array[String] = ["MATTE", "GLOSS", "METALLIC"]
var paint_colors: Array[Color] = [Color(0.88, 0.12, 0.08), Color(0.08, 0.32, 0.92), Color(0.95, 0.68, 0.08), Color(0.08, 0.62, 0.34)]
var paint_names: Array[String] = ["RED", "BLUE", "GOLD", "GREEN"]
var camera: Camera3D
var driving := false
var move_dir := Vector2.ZERO
var steer_input := 0.0
var throttle_input := 0.0
var brake_pressed := false
var speed := 0.0
var status_label: Label
var mission_label: Label
var checkpoint: Node3D
var checkpoint_tag: Label3D
var mission_index := 0
var mission_complete := false
var mission_points: Array[Vector3] = [
	Vector3(0, 0.18, -39),
	Vector3(0, 0.18, 39),
	Vector3(-39, 0.18, 0)
]
var mission_names: Array[String] = ["FIRST DRIVE", "NORTH GATE", "WEST AVENUE"]
var traffic_cars: Array[Node3D] = []
var brake_lamps: Array[MeshInstance3D] = []
var camera_base_fov := 70.0
var drift_intensity := 0.0
var collision_feedback_timer := 0.0
var steering_visual := 0.0

func _ready() -> void:
	_build_city()
	_build_player()
	_build_car()
	_build_traffic()
	_build_checkpoint()
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
	car_paint = _box(car, Vector3(2.0, 0.7, 3.8), Vector3.ZERO, paint_colors[paint_index])
	_box(car, Vector3(1.55, 0.65, 1.7), Vector3(0, 0.62, -0.25), Color(0.12, 0.22, 0.30))
	sport_spoiler = Node3D.new()
	sport_spoiler.name = "RearSpoiler"
	car.add_child(sport_spoiler)
	_box(sport_spoiler, Vector3(1.9, 0.10, 0.34), Vector3(0, 0.66, 1.72), Color(0.06, 0.07, 0.09))
	for spoiler_x in [-0.68, 0.68]:
		_box(sport_spoiler, Vector3(0.08, 0.34, 0.08), Vector3(spoiler_x, 0.48, 1.62), Color(0.08, 0.09, 0.11))
	for x in [-1.02, 1.02]:
		for z in [-1.2, 1.2]:
			_box(car, Vector3(0.25, 0.55, 0.7), Vector3(x, -0.25, z), Color(0.04, 0.04, 0.05))
			var sport_rim := _make_rim(car, x, z)
			sport_rims.append(sport_rim)
	_make_vehicle_lights(car)
	var car_collision := CollisionShape3D.new()
	var car_shape := BoxShape3D.new()
	car_shape.size = Vector3(1.85, 0.8, 3.55)
	car_collision.shape = car_shape
	car.add_child(car_collision)
	suv_visual = Node3D.new()
	suv_visual.name = "MetroSUV"
	car.add_child(suv_visual)
	suv_paint = _box(suv_visual, Vector3(2.0, 0.95, 3.8), Vector3(0, 0.12, 0), paint_colors[paint_index])
	_box(suv_visual, Vector3(1.7, 0.82, 2.15), Vector3(0, 0.92, -0.15), Color(0.10, 0.20, 0.28))
	for x in [-1.02, 1.02]:
		for z in [-1.2, 1.2]:
			_box(suv_visual, Vector3(0.25, 0.55, 0.7), Vector3(x, -0.25, z), Color(0.04, 0.04, 0.05))
			var suv_rim := _make_rim(suv_visual, x, z)
			suv_rims.append(suv_rim)
	_make_vehicle_lights(suv_visual)
	suv_visual.visible = false



func _make_vehicle_lights(parent: Node3D) -> void:
	for x in [-0.68, 0.68]:
		var head := _box(parent, Vector3(0.42, 0.16, 0.06), Vector3(x, 0.12, -1.93), Color(1.0, 0.88, 0.58))
		var head_material := _mat(Color(1.0, 0.88, 0.58))
		head_material.emission_enabled = true
		head_material.emission = Color(1.0, 0.78, 0.38)
		head_material.emission_energy_multiplier = 0.7
		head.material_override = head_material
		var tail := _box(parent, Vector3(0.42, 0.18, 0.07), Vector3(x, 0.12, 1.93), Color(0.42, 0.025, 0.02))
		var tail_material := _mat(Color(0.42, 0.025, 0.02))
		tail_material.emission_enabled = true
		tail_material.emission = Color(0.8, 0.015, 0.01)
		tail_material.emission_energy_multiplier = 0.35
		tail.material_override = tail_material
		brake_lamps.append(tail)

func _update_brake_lights(active: bool) -> void:
	for lamp in brake_lamps:
		var material := lamp.material_override as StandardMaterial3D
		if material:
			material.emission_energy_multiplier = 2.2 if active else 0.35

func _make_rim(parent: Node3D, side: float, depth: float) -> MeshInstance3D:
	var rim := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.22
	cylinder.bottom_radius = 0.22
	cylinder.height = 0.10
	rim.mesh = cylinder
	rim.position = Vector3(side * 1.17, -0.25, depth)
	rim.rotation.z = PI / 2.0
	rim.material_override = _mat(rim_colors[rim_index])
	parent.add_child(rim)
	return rim

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


func _build_checkpoint() -> void:
	checkpoint = Node3D.new()
	checkpoint.name = "FirstMissionCheckpoint"
	checkpoint.position = mission_points[mission_index]
	add_child(checkpoint)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12
	torus.outer_radius = 1.7
	ring.mesh = torus
	ring.material_override = _mat(Color(0.12, 0.95, 0.72))
	ring.rotation_degrees.x = 90
	checkpoint.add_child(ring)
	var beacon := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.08
	cylinder.bottom_radius = 0.08
	cylinder.height = 3.0
	beacon.mesh = cylinder
	beacon.position.y = 1.5
	beacon.material_override = _mat(Color(0.12, 0.95, 0.72, 0.35))
	checkpoint.add_child(beacon)
	checkpoint_tag = Label3D.new()
	checkpoint_tag.text = mission_names[mission_index]
	checkpoint_tag.position = Vector3(0, 3.2, 0)
	checkpoint_tag.font_size = 32
	checkpoint_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	checkpoint.add_child(checkpoint_tag)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 7, 11)
	camera.current = true
	camera.fov = 70
	add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := GridContainer.new()
	panel.columns = 4
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -116
	panel.offset_bottom = -8
	panel.offset_left = 8
	panel.offset_right = -8
	panel.add_theme_constant_override("h_separation", 6)
	panel.add_theme_constant_override("v_separation", 4)
	layer.add_child(panel)
	var left := _make_button("◀", 52)
	var forward := _make_button("GO", 52)
	var back := _make_button("REV", 52)
	var right := _make_button("▶", 52)
	var brake := _make_button("BRAKE", 64)
	var enter := _make_button("ENTER", 72)
	var nitro := _make_button("NITRO", 64)
	var drift := _make_button("DRIFT", 64)
	for button in [left, forward, back, right, brake, drift, nitro, enter]:
		button.custom_minimum_size = Vector2(0, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	nitro.button_down.connect(func(): nitro_pressed = true)
	nitro.button_up.connect(func(): nitro_pressed = false)
	drift.button_down.connect(func(): drift_pressed = true)
	drift.button_up.connect(func(): drift_pressed = false)
	var garage_panel := VBoxContainer.new()
	garage_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	garage_panel.position = Vector2(-142, 42)
	garage_panel.size = Vector2(132, 250)
	garage_panel.add_theme_constant_override("separation", 5)
	layer.add_child(garage_panel)
	var paint := _make_button("PAINT", 128)
	var next_car := _make_button("NEXT CAR", 128)
	var silver := _make_button("SILVER", 128)
	var finish := _make_button("FINISH: GLOSS", 128)
	var rims := _make_button("RIMS: SILVER", 128)
	var spoiler := _make_button("SPOILER: ON", 128)
	var mix_color := ColorPickerButton.new()
	mix_color.text = "MIX COLOR"
	mix_color.custom_minimum_size = Vector2(128, 54)
	mix_color.color = Color(0.25, 0.55, 0.9)
	mix_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mix_color.add_theme_font_size_override("font_size", 15)
	garage_panel.add_child(paint)
	garage_panel.add_child(next_car)
	garage_panel.add_child(silver)
	garage_panel.add_child(finish)
	garage_panel.add_child(mix_color)
	garage_panel.add_child(rims)
	garage_panel.add_child(spoiler)
	paint.pressed.connect(_cycle_car_paint)
	next_car.pressed.connect(_cycle_vehicle_model)
	silver.pressed.connect(_apply_silver_paint)
	finish.pressed.connect(_cycle_paint_finish)
	mix_color.color_changed.connect(_apply_custom_car_color)
	rims.pressed.connect(_cycle_rim_color)
	spoiler.pressed.connect(_toggle_spoiler)
	mission_label = Label.new()
	mission_label.text = "CITY TOUR 01/03  •  Reach FIRST DRIVE"
	mission_label.position = Vector2(12, 38)
	mission_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(mission_label)
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

func _cycle_car_paint() -> void:
	if not driving and player.global_position.distance_to(car.global_position) > 5.5:
		status_label.text = "Move closer to the red car to use the paint shop"
		return
	paint_index = (paint_index + 1) % paint_colors.size()
	current_paint_color = paint_colors[paint_index]
	_refresh_car_paint()
	status_label.text = "GARAGE  •  Car color changed to %s" % paint_names[paint_index]

func _apply_custom_car_color(color: Color) -> void:
	if not driving and player.global_position.distance_to(car.global_position) > 5.5:
		status_label.text = "Move closer to your car to mix a custom paint color"
		return
	current_paint_color = color
	_refresh_car_paint()
	status_label.text = "GARAGE  •  Custom mixed paint applied"

func _apply_silver_paint() -> void:
	if not driving and player.global_position.distance_to(car.global_position) > 5.5:
		status_label.text = "Move closer to your car to use the silver finish"
		return
	current_paint_color = Color(0.72, 0.76, 0.80)
	finish_index = 2
	_refresh_car_paint()
	status_label.text = "GARAGE  •  Metallic silver finish applied"
func _refresh_car_paint() -> void:
	var metallic_values: Array[float] = [0.0, 0.25, 0.92]
	var roughness_values: Array[float] = [0.88, 0.22, 0.16]
	for body_mesh in [car_paint, suv_paint]:
		var material := _mat(current_paint_color)
		material.metallic = metallic_values[finish_index]
		material.roughness = roughness_values[finish_index]
		body_mesh.material_override = material

func _cycle_paint_finish() -> void:
	if not driving and player.global_position.distance_to(car.global_position) > 5.5:
		status_label.text = "Move closer to your car to change the paint finish"
		return
	finish_index = (finish_index + 1) % finish_names.size()
	_refresh_car_paint()
	status_label.text = "GARAGE  •  %s finish applied" % finish_names[finish_index]
func _cycle_rim_color() -> void:
	if not driving and player.global_position.distance_to(car.global_position) > 5.5:
		status_label.text = "Move closer to your car to customize the rims"
		return
	rim_index = (rim_index + 1) % rim_colors.size()
	for rim in sport_rims + suv_rims:
		var material := _mat(rim_colors[rim_index])
		material.metallic = 0.82
		material.roughness = 0.24
		rim.material_override = material
	status_label.text = "GARAGE  •  %s alloy rims fitted" % rim_names[rim_index]

func _toggle_spoiler() -> void:
	if selected_suv:
		status_label.text = "Spoiler customization is available on the Velocity Sport"
		return
	spoiler_enabled = not spoiler_enabled
	sport_spoiler.visible = spoiler_enabled
	status_label.text = "GARAGE  •  Rear spoiler %s" % ("installed" if spoiler_enabled else "removed")

func _cycle_vehicle_model() -> void:
	if driving:
		status_label.text = "Exit the car before switching models"
		return
	if player.global_position.distance_to(car.global_position) > 6.5:
		status_label.text = "Move closer to the garage to switch vehicles"
		return
	selected_suv = not selected_suv
	suv_visual.visible = selected_suv
	car_paint.visible = not selected_suv
	status_label.text = "GARAGE  •  Selected %s" % ("CITY SUV" if selected_suv else "VELOCITY SPORT")

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

func _advance_city_tour() -> void:
	mission_index += 1
	if mission_index >= mission_points.size():
		mission_complete = true
		mission_label.text = "CITY TOUR COMPLETE  •  3/3 checkpoints reached"
		status_label.text = "Excellent driving! City Tour completed."
		checkpoint.visible = false
		return
	checkpoint.global_position = mission_points[mission_index]
	checkpoint_tag.text = mission_names[mission_index]
	mission_label.text = "CITY TOUR %02d/03  •  Reach %s" % [mission_index + 1, mission_names[mission_index]]
	status_label.text = "Checkpoint %d/3 reached! Next destination marked." % mission_index

func _process(delta: float) -> void:
	if not mission_complete:
		var actor_position := car.global_position if driving else player.global_position
		if actor_position.distance_to(checkpoint.global_position) < 3.2:
			_advance_city_tour()
		else:
			checkpoint.rotate_y(delta * 0.8)
	for i in range(traffic_cars.size()):
		var traffic := traffic_cars[i]
		traffic.position.z += (5.0 + float(i % 2) * 1.5) * delta * (1.0 if i % 2 == 0 else -1.0)
		if traffic.position.z > 48.0:
			traffic.position.z = -48.0
		elif traffic.position.z < -48.0:
			traffic.position.z = 48.0

func _physics_process(delta: float) -> void:
	if driving:
		var using_nitro := nitro_pressed and throttle_input > 0.0 and nitro_energy > 0.0 and not brake_pressed
		if using_nitro:
			nitro_energy = maxf(0.0, nitro_energy - delta)
		elif not nitro_pressed:
			nitro_energy = minf(3.0, nitro_energy + delta * 0.22)
		_update_brake_lights(brake_pressed or (throttle_input < 0.0 and speed > 0.5))
		var target_speed := 0.0 if brake_pressed else (24.0 if using_nitro else 16.0) if throttle_input > 0.0 else throttle_input * 8.0
		var acceleration := 28.0 if brake_pressed else (16.0 if using_nitro else 10.0) if throttle_input != 0.0 else 15.0
		var traffic_blocked := false
		for traffic in traffic_cars:
			var relative := traffic.global_position - car.global_position
			if relative.length() < 2.7:
				traffic_blocked = true
				break
		if traffic_blocked:
			speed = move_toward(speed, 0.0, 34.0 * delta)
			collision_feedback_timer = 0.7
		else:
			speed = move_toward(speed, target_speed, acceleration * delta)
		if collision_feedback_timer > 0.0:
			collision_feedback_timer = maxf(0.0, collision_feedback_timer - delta)
		var steering_strength := clampf(absf(speed) / 4.0, 0.0, 1.0)
		var steering_rate := 1.75 if drift_pressed else 1.25
		steering_visual = move_toward(steering_visual, steer_input, delta * 5.0)
		car.rotate_y(-steering_visual * steering_strength * delta * steering_rate * signf(speed))
		drift_intensity = move_toward(drift_intensity, 1.0 if drift_pressed and absf(speed) > 5.0 and absf(steer_input) > 0.1 else 0.0, delta * 2.8)
		var forward_velocity := -car.global_basis.z * speed
		var drift_slide := car.global_basis.x * steer_input * absf(speed) * 0.34 * drift_intensity
		car.velocity = forward_velocity + drift_slide
		car.move_and_slide()
		if collision_feedback_timer > 0.0:
			status_label.text = "TRAFFIC ALERT  •  Slow down!"
		elif drift_pressed:
			status_label.text = "DRIFTING  •  %d km/h" % int(absf(speed) * 3.6)
		else:
			status_label.text = "DRIVING  •  %d km/h  •  NITRO %.1fs" % [int(absf(speed) * 3.6), nitro_energy]
	else:
		_update_brake_lights(false)
		var direction := Vector3(move_dir.x, 0, move_dir.y)
		player.velocity.x = direction.x * 5.0
		player.velocity.z = direction.z * 5.0
		player.velocity.y -= 20.0 * delta
		player.move_and_slide()
	var target_fov := camera_base_fov + (clampf(absf(speed) / 24.0, 0.0, 1.0) * 7.0 if driving else 0.0) + (3.0 if driving and nitro_pressed and nitro_energy > 0.0 else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 3.0 * delta)
	var target := car.global_position if driving else player.global_position
	var follow_offset := car.global_basis.z * 10.0 + Vector3(0, 5.5, 0) if driving else Vector3(0, 7, 11)
	camera.global_position = camera.global_position.lerp(target + follow_offset, 4.5 * delta)
	camera.look_at(target + Vector3(0, 1, 0), Vector3.UP)
