extends Node3D

# Each button independently hit-tests every screen touch in viewport coordinates.
# This avoids relying on Godot's single-control GUI touch capture for simultaneous buttons.
class MultiTouchButton extends Button:
	var active_touches: Dictionary = {}

	func _ready() -> void:
		# Touches are handled manually in _input; ignore native GUI handling to prevent a second press signal.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_process_input(true)

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree() or not (event is InputEventScreenTouch):
			return
		var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var inside := Rect2(Vector2.ZERO, size).has_point(local_position)
		var touch_id: int = event.index
		if event.pressed:
			if inside and not active_touches.has(touch_id):
				active_touches[touch_id] = true
				if active_touches.size() == 1:
					set_pressed_no_signal(true)
					emit_signal("button_down")
		elif active_touches.has(touch_id):
			active_touches.erase(touch_id)
			if active_touches.is_empty():
				set_pressed_no_signal(false)
				emit_signal("button_up")
			if inside:
				emit_signal("pressed")

class VirtualSteeringWheel extends Control:
	signal steering_changed(value: float)
	var steering_value := 0.0
	var dragging := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			dragging = event.pressed
			if dragging:
				_update_steering(event.position.x)
			else:
				accept_event()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				_update_steering(event.position.x)
		elif event is InputEventScreenDrag or (event is InputEventMouseMotion and dragging):
			_update_steering(event.position.x)

	func _update_steering(pointer_x: float) -> void:
		steering_value = clampf((pointer_x / maxf(size.x, 1.0) - 0.5) * 2.0, -1.0, 1.0)
		steering_changed.emit(steering_value)
		queue_redraw()

	func _process(delta: float) -> void:
		if not dragging and absf(steering_value) > 0.01:
			steering_value = move_toward(steering_value, 0.0, delta * 2.8)
			steering_changed.emit(steering_value)
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.43
		draw_circle(center, radius, Color(0.035, 0.045, 0.06, 0.78))
		draw_arc(center, radius, 0.0, TAU, 64, Color(0.82, 0.86, 0.92), 7.0, true)
		draw_set_transform(center, steering_value * 0.85, Vector2.ONE)
		draw_line(Vector2(0, -radius * 0.88), Vector2.ZERO, Color(0.9, 0.92, 0.96), 8.0, true)
		draw_line(Vector2(-radius * 0.78, radius * 0.35), Vector2.ZERO, Color(0.9, 0.92, 0.96), 8.0, true)
		draw_line(Vector2(radius * 0.78, radius * 0.35), Vector2.ZERO, Color(0.9, 0.92, 0.96), 8.0, true)
		draw_circle(Vector2.ZERO, radius * 0.16, Color(0.16, 0.2, 0.26))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

class VirtualMoveJoystick extends Control:
	signal direction_changed(value: Vector2)
	var direction := Vector2.ZERO
	var active := false
	var touch_id := -1
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and not active:
				active = true
				touch_id = event.index
				_update_direction(event.position)
			elif not event.pressed and event.index == touch_id:
				active = false
				touch_id = -1
				direction = Vector2.ZERO
				direction_changed.emit(direction)
				queue_redraw()
		elif event is InputEventScreenDrag and active and event.index == touch_id:
			_update_direction(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			active = event.pressed
			if active:
				_update_direction(event.position)
			else:
				direction = Vector2.ZERO
				direction_changed.emit(direction)
				queue_redraw()
		elif event is InputEventMouseMotion and active:
			_update_direction(event.position)
	func _update_direction(pointer: Vector2) -> void:
		var offset := pointer - size * 0.5
		var limit := minf(size.x, size.y) * 0.38
		direction = (offset / maxf(limit, 1.0)).limit_length(1.0)
		if direction.length() < 0.12:
			direction = Vector2.ZERO
		direction_changed.emit(direction)
		queue_redraw()
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		draw_circle(center, radius, Color(0.025, 0.045, 0.065, 0.58))
		draw_arc(center, radius, 0.0, TAU, 64, Color(0.82, 0.9, 0.96, 0.8), 3.0, true)
		draw_circle(center + direction * radius * 0.58, radius * 0.34, Color(0.22, 0.72, 0.9, 0.82))

var player: CharacterBody3D
var car: CharacterBody3D
var enter_exit_button: Button
var car_paint: MeshInstance3D
var paint_index := 0
var suv_visual: Node3D
var sport_model: Node3D
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
var camera_yaw := 0.0
var camera_pitch := 0.48
var camera_dragging := false
var camera_touch_index := -1
var camera_touch_positions: Dictionary = {}
var camera_pinch_distance := 0.0
var camera_drag_sensitivity := 0.0011
var camera_zoom := 1.0
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
var reverse_lamps: Array[MeshInstance3D] = []
var headlight_nodes: Array[SpotLight3D] = []
var headlamp_meshes: Array[MeshInstance3D] = []
var headlights_enabled := true
var camera_base_fov := 70.0
var drift_intensity := 0.0
var collision_feedback_timer := 0.0
var steering_visual := 0.0
var turn_signal_lamps: Array[MeshInstance3D] = []
var signal_blink_timer := 0.0
var steering_mode := 0 # 0 = buttons, 1 = virtual wheel
var steering_wheel: VirtualSteeringWheel
var steering_buttons: Array[Button] = []
var steering_mode_button: Button
var sport_wheel_pivots: Array[Node3D] = []
var suv_wheel_pivots: Array[Node3D] = []
var wheel_roll := 0.0
var engine_audio: AudioStreamPlayer
var horn_audio: AudioStreamPlayer
var horn_pressed := false
var move_joystick: VirtualMoveJoystick
var on_foot_buttons: Array[Control] = []
var vehicle_buttons: Array[Control] = []
var run_pressed := false
var jump_requested := false
var character_index := 0
var character_names: Array[String] = ["MARCUS", "FELIX", "DAMIAN"]
var character_visuals: Array[Node3D] = []
var character_button: Button

func _ready() -> void:
	_load_saved_settings()
	_build_city()
	_build_player()
	_build_car()
	_build_traffic()
	_build_checkpoint()
	_build_camera()
	_build_ui()
	_build_vehicle_audio()
	steering_mode_button.text = "STEER: WHEEL" if steering_mode == 1 else "STEER: BUTTONS"
	steering_wheel.visible = steering_mode == 1
	for button in steering_buttons:
		button.visible = steering_mode == 0
	for light in headlight_nodes:
		light.visible = headlights_enabled
	for lamp in headlamp_meshes:
		var lamp_material := lamp.material_override as StandardMaterial3D
		if lamp_material:
			lamp_material.emission_energy_multiplier = 0.7 if headlights_enabled else 0.0
	_update_control_visibility()

func _load_saved_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://dhaka_velocity.cfg") != OK:
		return
	paint_index = clampi(int(config.get_value("garage", "paint_index", paint_index)), 0, paint_colors.size() - 1)
	current_paint_color = config.get_value("garage", "paint_color", paint_colors[paint_index])
	finish_index = clampi(int(config.get_value("garage", "finish_index", finish_index)), 0, finish_names.size() - 1)
	rim_index = clampi(int(config.get_value("garage", "rim_index", rim_index)), 0, rim_colors.size() - 1)
	selected_suv = bool(config.get_value("garage", "selected_suv", selected_suv))
	spoiler_enabled = bool(config.get_value("garage", "spoiler_enabled", spoiler_enabled))
	headlights_enabled = bool(config.get_value("garage", "headlights_enabled", headlights_enabled))
	steering_mode = clampi(int(config.get_value("controls", "steering_mode", steering_mode)), 0, 1)
	character_index = clampi(int(config.get_value("characters", "selected", character_index)), 0, 2)

func _save_game_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("garage", "paint_index", paint_index)
	config.set_value("garage", "paint_color", current_paint_color)
	config.set_value("garage", "finish_index", finish_index)
	config.set_value("garage", "rim_index", rim_index)
	config.set_value("garage", "selected_suv", selected_suv)
	config.set_value("garage", "spoiler_enabled", spoiler_enabled)
	config.set_value("garage", "headlights_enabled", headlights_enabled)
	config.set_value("controls", "steering_mode", steering_mode)
	config.set_value("characters", "selected", character_index)
	var error := config.save("user://dhaka_velocity.cfg")
	if error != OK:
		push_warning("Could not save Dhaka Velocity settings: %s" % error_string(error))

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

	# Raised sidewalks and curb strips around the two crossing roads.
	for side in [-1.0, 1.0]:
		_solid_box(self, Vector3(2.0, 0.16, 100.0), Vector3(side * 7.1, 0.04, 0.0), Color(0.48, 0.50, 0.51))
		_solid_box(self, Vector3(100.0, 0.16, 2.0), Vector3(0.0, 0.04, side * 7.1), Color(0.48, 0.50, 0.51))
		_box(self, Vector3(0.16, 0.12, 100.0), Vector3(side * 6.05, 0.10, 0.0), Color(0.78, 0.78, 0.72))
		_box(self, Vector3(100.0, 0.12, 0.16), Vector3(0.0, 0.10, side * 6.05), Color(0.78, 0.78, 0.72))

	# Low-poly roadside trees and planted green islands.
	for side in [-1.0, 1.0]:
		for z in [-43.0, -31.0, -19.0, 19.0, 31.0, 43.0]:
			var tree := Node3D.new()
			tree.position = Vector3(side * 10.5, 0.0, z)
			add_child(tree)
			var trunk := MeshInstance3D.new()
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius = 0.16
			trunk_mesh.bottom_radius = 0.23
			trunk_mesh.height = 2.1
			trunk.mesh = trunk_mesh
			trunk.position.y = 1.05
			trunk.material_override = _mat(Color(0.25, 0.14, 0.08))
			tree.add_child(trunk)
			for crown in [Vector3(0.0, 2.45, 0.0), Vector3(-0.34, 2.25, 0.05), Vector3(0.32, 2.28, -0.08)]:
				var leaves := MeshInstance3D.new()
				var leaf_mesh := SphereMesh.new()
				leaf_mesh.radius = 0.82
				leaf_mesh.height = 1.35
				leaves.mesh = leaf_mesh
				leaves.position = crown
				leaves.material_override = _mat(Color(0.12, 0.34, 0.17))
				tree.add_child(leaves)
			_box(self, Vector3(2.0, 0.05, 2.0), Vector3(side * 10.5, 0.03, z), Color(0.18, 0.36, 0.19))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_SKY
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.55, 0.62, 0.72)
	world.ambient_light_energy = 0.8
	world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.ambient_light_sky_contribution = 0.35
	environment.environment = world
	add_child(environment)

func _character_capsule(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.material_override = _mat(color)
	parent.add_child(part)
	return part

func _character_sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.material_override = _mat(color)
	parent.add_child(part)
	return part

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(-5, 1, 5)
	add_child(player)

	# Marcus: first visual pass of the approved black-jacket outfit.
	# The capsule remains the invisible gameplay collision body.
	var visual := Node3D.new()
	visual.name = "Marcus_Visual"
	player.add_child(visual)

	var skin := Color(0.66, 0.43, 0.30)
	var jacket := Color(0.035, 0.045, 0.06)
	var pants := Color(0.025, 0.03, 0.04)
	var shirt := Color(0.88, 0.89, 0.86)
	var shoes := Color(0.055, 0.06, 0.07)
	var hair := Color(0.018, 0.016, 0.014)

	# Legs and shoes
	_character_capsule(visual, 0.145, 0.78, Vector3(-0.17, -0.55, 0.0), pants)
	_character_capsule(visual, 0.145, 0.78, Vector3(0.17, -0.55, 0.0), pants)
	_box(visual, Vector3(0.25, 0.14, 0.38), Vector3(-0.17, -0.96, -0.075), shoes)
	_box(visual, Vector3(0.25, 0.14, 0.38), Vector3(0.17, -0.96, -0.075), shoes)

	# Jacket torso, white T-shirt panel, and jacket lapel accents
	_box(visual, Vector3(0.62, 0.72, 0.34), Vector3(0.0, 0.25, 0.0), jacket)
	_box(visual, Vector3(0.27, 0.57, 0.025), Vector3(0.0, 0.25, -0.177), shirt)
	_box(visual, Vector3(0.12, 0.48, 0.035), Vector3(-0.19, 0.28, -0.19), Color(0.08, 0.09, 0.11))
	_box(visual, Vector3(0.12, 0.48, 0.035), Vector3(0.19, 0.28, -0.19), Color(0.08, 0.09, 0.11))

	# Arms, hands, neck, and head
	_character_capsule(visual, 0.115, 0.70, Vector3(-0.40, 0.22, 0.0), jacket)
	_character_capsule(visual, 0.115, 0.70, Vector3(0.40, 0.22, 0.0), jacket)
	_character_sphere(visual, 0.12, Vector3(-0.40, -0.18, 0.0), skin)
	_character_sphere(visual, 0.12, Vector3(0.40, -0.18, 0.0), skin)
	_character_capsule(visual, 0.095, 0.22, Vector3(0.0, 0.68, 0.0), skin)
	_character_sphere(visual, 0.235, Vector3(0.0, 0.98, -0.015), skin)

	# Neat dark hairstyle and simple facial features
	_character_sphere(visual, 0.238, Vector3(0.0, 1.105, 0.015), hair)
	_box(visual, Vector3(0.43, 0.12, 0.30), Vector3(0.0, 1.12, -0.005), hair)
	_character_sphere(visual, 0.035, Vector3(-0.085, 1.005, -0.215), Color(0.07, 0.055, 0.045))
	_character_sphere(visual, 0.035, Vector3(0.085, 1.005, -0.215), Color(0.07, 0.055, 0.045))
	_box(visual, Vector3(0.10, 0.045, 0.07), Vector3(0.0, 0.925, -0.225), skin)
	_box(visual, Vector3(0.18, 0.035, 0.035), Vector3(0.0, 0.855, -0.225), hair)

	# Three playable character placeholders share the same controls and abilities.
	# Detailed human models and animations are intentionally deferred until the graphics phase.
	character_visuals.append(visual)
	var felix_visual := visual.duplicate() as Node3D
	felix_visual.name = "Felix_Visual"
	player.add_child(felix_visual)
	_apply_character_palette(felix_visual, Color(0.10, 0.20, 0.34), Color(0.055, 0.065, 0.08))
	character_visuals.append(felix_visual)
	var damian_visual := visual.duplicate() as Node3D
	damian_visual.name = "Damian_Visual"
	player.add_child(damian_visual)
	_apply_character_palette(damian_visual, Color(0.16, 0.20, 0.12), Color(0.10, 0.105, 0.095))
	character_visuals.append(damian_visual)
	for index in range(character_visuals.size()):
		character_visuals[index].visible = index == character_index

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.32
	capsule_shape.height = 1.9
	collision.shape = capsule_shape
	player.add_child(collision)

func _apply_character_palette(root: Node3D, jacket_color: Color, pants_color: Color) -> void:
	var base_jacket := Color(0.035, 0.045, 0.06)
	var base_pants := Color(0.025, 0.03, 0.04)
	for part in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_part := part as MeshInstance3D
		var old_material := mesh_part.material_override as StandardMaterial3D
		if old_material == null:
			continue
		if old_material.albedo_color.is_equal_approx(base_jacket):
			var new_material := _mat(jacket_color)
			mesh_part.material_override = new_material
		elif old_material.albedo_color.is_equal_approx(base_pants):
			mesh_part.material_override = _mat(pants_color)

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "Velocity"
	car.position = Vector3(0, 0.53, 5)
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
			var wheel_pivot := Node3D.new()
			wheel_pivot.position = Vector3(x, -0.25, z)
			car.add_child(wheel_pivot)
			var tire := MeshInstance3D.new()
			var tire_mesh := CylinderMesh.new()
			tire_mesh.top_radius = 0.36
			tire_mesh.bottom_radius = 0.36
			tire_mesh.height = 0.24
			tire.mesh = tire_mesh
			tire.rotation.z = PI / 2.0
			tire.material_override = _mat(Color(0.025, 0.028, 0.032))
			wheel_pivot.add_child(tire)
			var sport_rim := _make_rim(wheel_pivot, signf(x), 0.0)
			sport_rims.append(sport_rim)
			sport_wheel_pivots.append(wheel_pivot)
	_make_vehicle_lights(car)
	_add_car_detail_package(car, false)
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
			var wheel_pivot := Node3D.new()
			wheel_pivot.position = Vector3(x, -0.25, z)
			suv_visual.add_child(wheel_pivot)
			var tire := MeshInstance3D.new()
			var tire_mesh := CylinderMesh.new()
			tire_mesh.top_radius = 0.36
			tire_mesh.bottom_radius = 0.36
			tire_mesh.height = 0.24
			tire.mesh = tire_mesh
			tire.rotation.z = PI / 2.0
			tire.material_override = _mat(Color(0.025, 0.028, 0.032))
			wheel_pivot.add_child(tire)
			var suv_rim := _make_rim(wheel_pivot, signf(x), 0.0)
			suv_rims.append(suv_rim)
			suv_wheel_pivots.append(wheel_pivot)
	_make_vehicle_lights(suv_visual)
	_add_car_detail_package(suv_visual, true)
	suv_visual.visible = selected_suv
	car_paint.visible = not selected_suv
	_refresh_car_paint()
	for rim in sport_rims + suv_rims:
		var rim_material := _mat(rim_colors[rim_index])
		rim_material.metallic = 0.82
		rim_material.roughness = 0.24
		rim.material_override = rim_material
	sport_spoiler.visible = spoiler_enabled
	# Replace the procedural sport-car visuals only when the detailed GLB is bundled.
	var sport_model_path := "res://Assets/DhakaVelocity_Super3D_SportSedan.glb"
	if ResourceLoader.exists(sport_model_path):
		var sport_scene := load(sport_model_path) as PackedScene
		if sport_scene != null:
			sport_model = sport_scene.instantiate() as Node3D
			sport_model.name = "Super3DSportSedan"
			car.add_child(sport_model)
			sport_model.position = Vector3.ZERO
			sport_model.visible = not selected_suv
			# Keep the physics collider and alternate SUV; hide only old sport-car visuals.
			for old_visual in car.get_children():
				if old_visual == sport_model or old_visual == suv_visual or old_visual is CollisionShape3D:
					continue
				if old_visual is Node3D:
					old_visual.visible = false
		else:
			push_warning("Detailed sport car GLB could not be instantiated; using procedural visuals.")
	else:
		push_warning("Detailed sport car GLB is not bundled yet; using procedural visuals.")


func _add_car_detail_package(parent: Node3D, is_suv: bool) -> void:
	var glass := Color(0.045, 0.095, 0.13)
	var trim := Color(0.035, 0.04, 0.045)
	var chrome := Color(0.62, 0.68, 0.72)
	var red := Color(0.82, 0.035, 0.025)
	var cabin_height := 0.92 if is_suv else 0.78
	var cabin_length := 1.0 if is_suv else 0.78
	# Front windshield and rear glass.
	var windshield := _box(parent, Vector3(1.38, 0.055, 0.62 if is_suv else 0.52), Vector3(0.0, cabin_height, -0.88), glass)
	windshield.rotation.x = -0.42
	var rear_glass := _box(parent, Vector3(1.30, 0.055, 0.42), Vector3(0.0, cabin_height, 0.78), glass)
	rear_glass.rotation.x = 0.38
	# Side windows, mirrors, door handles and lower side skirts.
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(0.035, 0.42 if is_suv else 0.32, 0.78 if is_suv else 0.62), Vector3(side * 0.79, cabin_height, -0.12), glass)
		_box(parent, Vector3(0.20, 0.10, 0.22), Vector3(side * 1.02, 0.58, -0.78), trim)
		_box(parent, Vector3(0.07, 0.07, 0.24), Vector3(side * 1.015, 0.22, 0.25), chrome)
		_box(parent, Vector3(0.10, 0.16, 2.45), Vector3(side * 0.96, -0.25, 0.0), trim)
	# Front grille, bumper, rear bumper, exhaust tips and tail lamps.
	_box(parent, Vector3(0.92, 0.20, 0.075), Vector3(0.0, -0.12, -1.94), trim)
	for line_y in [-0.18, -0.12, -0.06]:
		_box(parent, Vector3(0.72, 0.018, 0.02), Vector3(0.0, line_y, -2.0), chrome)
	_box(parent, Vector3(1.88, 0.16, 0.18), Vector3(0.0, -0.30, -1.88), trim)
	_box(parent, Vector3(1.88, 0.16, 0.18), Vector3(0.0, -0.30, 1.88), trim)
	for side in [-1.0, 1.0]:
		var tail := _box(parent, Vector3(0.42, 0.16, 0.07), Vector3(side * 0.68, 0.12, 1.94), red)
		var tail_material := _mat(red)
		tail_material.emission_enabled = true
		tail_material.emission = red
		tail_material.emission_energy_multiplier = 0.45
		tail.material_override = tail_material
		var exhaust := _box(parent, Vector3(0.18, 0.10, 0.18), Vector3(side * 0.62, -0.27, 1.98), chrome)
		exhaust.material_override = _mat(chrome)
	# Subtle roof panel and hood creases add body definition.
	_box(parent, Vector3(0.72, 0.025, 0.72), Vector3(0.0, cabin_height + 0.27, 0.02), trim)
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(0.035, 0.018, 0.72), Vector3(side * 0.56, 0.37, -1.28), chrome)

func _make_tone_wav(frequency: float, duration: float, engine_tone: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var frames := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(sample_rate)
		var envelope := 1.0 if engine_tone else (1.0 - float(i) / float(frames))
		var fundamental := sin(TAU * frequency * t)
		var harmonic := sin(TAU * frequency * 2.02 * t) * (0.22 if engine_tone else 0.12)
		var low := sin(TAU * frequency * 0.5 * t) * (0.18 if engine_tone else 0.0)
		var sample := clampf((fundamental * 0.52 + harmonic + low) * envelope * 0.32, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	if engine_tone:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
	return stream

func _build_vehicle_audio() -> void:
	engine_audio = AudioStreamPlayer.new()
	engine_audio.name = "ProceduralEngineAudio"
	engine_audio.stream = _make_tone_wav(82.0, 0.5, true)
	engine_audio.volume_db = -19.0
	add_child(engine_audio)
	horn_audio = AudioStreamPlayer.new()
	horn_audio.name = "ProceduralHornAudio"
	horn_audio.stream = _make_tone_wav(440.0, 0.32, false)
	horn_audio.volume_db = -8.0
	add_child(horn_audio)

func _press_horn() -> void:
	if not driving:
		return
	horn_pressed = true
	if horn_audio and not horn_audio.playing:
		horn_audio.play()

func _release_horn() -> void:
	horn_pressed = false
	if horn_audio and horn_audio.playing:
		horn_audio.stop()

func _update_wheel_visuals(delta: float) -> void:
	wheel_roll = fposmod(wheel_roll + speed * delta / 0.34, TAU)
	var pivots := sport_wheel_pivots if not selected_suv else suv_wheel_pivots
	for index in range(pivots.size()):
		var pivot := pivots[index]
		pivot.rotation.x = wheel_roll
		pivot.rotation.y = steering_visual * 0.42 if pivot.position.z < 0.0 else 0.0
		var spring := sin(wheel_roll * 0.5 + float(index % 2) * PI) * minf(absf(speed) / 30.0, 1.0) * 0.025
		pivot.position.y = -0.25 + spring

func _make_vehicle_lights(parent: Node3D) -> void:
	for x in [-0.68, 0.68]:
		var head := _box(parent, Vector3(0.42, 0.16, 0.06), Vector3(x, 0.12, -1.93), Color(1.0, 0.88, 0.58))
		var head_material := _mat(Color(1.0, 0.88, 0.58))
		head_material.emission_enabled = true
		head_material.emission = Color(1.0, 0.78, 0.38)
		head_material.emission_energy_multiplier = 0.7
		head.material_override = head_material
		headlamp_meshes.append(head)
		var headlight := SpotLight3D.new()
		headlight.position = Vector3(x * 0.72, 0.16, -1.72)
		headlight.light_color = Color(1.0, 0.86, 0.62)
		headlight.light_energy = 2.2
		headlight.spot_range = 24.0
		headlight.spot_angle = 34.0
		headlight.shadow_enabled = false
		parent.add_child(headlight)
		headlight_nodes.append(headlight)
		var reverse_lamp := _box(parent, Vector3(0.22, 0.12, 0.06), Vector3(x, 0.12, 1.94), Color(0.8, 0.82, 0.78))
		var reverse_material := _mat(Color(0.8, 0.82, 0.78))
		reverse_material.emission_enabled = true
		reverse_material.emission = Color(0.8, 0.82, 0.78)
		reverse_material.emission_energy_multiplier = 0.0
		reverse_lamp.material_override = reverse_material
		reverse_lamps.append(reverse_lamp)
		var tail := _box(parent, Vector3(0.42, 0.18, 0.07), Vector3(x, 0.12, 1.93), Color(0.42, 0.025, 0.02))
		var tail_material := _mat(Color(0.42, 0.025, 0.02))
		tail_material.emission_enabled = true
		tail_material.emission = Color(0.8, 0.015, 0.01)
		tail_material.emission_energy_multiplier = 0.35
		tail.material_override = tail_material
		brake_lamps.append(tail)
		for lamp_z in [-1.94, 1.94]:
			var indicator := _box(parent, Vector3(0.14, 0.12, 0.07), Vector3(x * 0.78, 0.12, lamp_z), Color(0.95, 0.42, 0.04))
			var indicator_material := _mat(Color(0.95, 0.42, 0.04))
			indicator_material.emission_enabled = true
			indicator_material.emission = Color(1.0, 0.32, 0.015)
			indicator_material.emission_energy_multiplier = 0.0
			indicator.material_override = indicator_material
			turn_signal_lamps.append(indicator)

func _update_reverse_lights(active: bool) -> void:
	for lamp in reverse_lamps:
		var material := lamp.material_override as StandardMaterial3D
		if material:
			material.albedo_color = Color(0.8, 0.82, 0.78) if active else Color(0.16, 0.17, 0.18)
			material.emission_energy_multiplier = 1.5 if active else 0.0

func _toggle_headlights() -> void:
	headlights_enabled = not headlights_enabled
	for light in headlight_nodes:
		light.visible = headlights_enabled
	for lamp in headlamp_meshes:
		var material := lamp.material_override as StandardMaterial3D
		if material:
			material.emission_energy_multiplier = 0.7 if headlights_enabled else 0.0
	status_label.text = "LIGHTS  •  %s" % ("ON" if headlights_enabled else "OFF")
	_save_game_settings()

func _update_turn_signals(delta: float) -> void:
	signal_blink_timer += delta
	var steering_active := absf(steer_input) > 0.25 and absf(speed) > 1.0
	var blink_on := fposmod(signal_blink_timer, 0.8) < 0.4
	for index in range(turn_signal_lamps.size()):
		var lamp := turn_signal_lamps[index]
		var is_left_side := lamp.position.x < 0.0
		var selected_side := (steer_input < -0.25 and is_left_side) or (steer_input > 0.25 and not is_left_side)
		var material := lamp.material_override as StandardMaterial3D
		if material:
			material.emission_energy_multiplier = 2.0 if steering_active and selected_side and blink_on else 0.0

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
	rim.position = Vector3(side * 0.13, 0.0, depth)
	rim.rotation.z = PI / 2.0
	rim.material_override = _mat(rim_colors[rim_index])
	parent.add_child(rim)
	return rim

func _build_traffic() -> void:
	for i in range(4):
		var traffic := AnimatableBody3D.new()
		traffic.name = "Traffic_%d" % i
		traffic.position = Vector3(-2.0 if i % 2 == 0 else 2.0, 0.55, -30.0 + float(i) * 18.0)
		add_child(traffic)
		var paint: Color = [Color(0.12, 0.42, 0.82), Color(0.82, 0.72, 0.18), Color(0.82, 0.82, 0.78), Color(0.16, 0.58, 0.38)][i]
		_box(traffic, Vector3(1.65, 0.62, 3.0), Vector3.ZERO, paint)
		var traffic_collision := CollisionShape3D.new()
		var traffic_shape := BoxShape3D.new()
		traffic_shape.size = Vector3(1.7, 0.8, 3.1)
		traffic_collision.shape = traffic_shape
		traffic.add_child(traffic_collision)
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
	panel.columns = 3
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -170
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
	# Keep enter/exit on the same multi-touch button class as the other mobile controls.
	var enter := _make_button("ENTER", 112)
	enter.custom_minimum_size = Vector2(112, 58)
	enter.size = Vector2(112, 58)
	enter.focus_mode = Control.FOCUS_NONE
	# The custom touch handler owns this button; native GUI handling would double-toggle it.
	enter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enter.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	enter.position = Vector2(-126, -236)
	enter_exit_button = enter
	var nitro := _make_button("NITRO", 64)
	var drift := _make_button("DRIFT", 64)
	var horn := _make_button("HORN", 64)
	for button in [left, forward, back, right, brake, drift, nitro, horn]:
		button.custom_minimum_size = Vector2(0, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(button)
	layer.add_child(enter)
	vehicle_buttons = [left, forward, back, right, brake, drift, nitro, horn]
	steering_buttons = [left, right]
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
	horn.button_down.connect(_press_horn)
	horn.button_up.connect(_release_horn)
	var garage_scroll := ScrollContainer.new()
	garage_scroll.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	garage_scroll.position = Vector2(-174, 42)
	garage_scroll.size = Vector2(166, 330)
	garage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(garage_scroll)
	var garage_panel := VBoxContainer.new()
	garage_panel.custom_minimum_size = Vector2(154, 0)
	garage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garage_panel.add_theme_constant_override("separation", 4)
	garage_scroll.add_child(garage_panel)
	steering_mode_button = _make_button("STEER: BUTTONS", 140)
	steering_mode_button.custom_minimum_size.y = 42
	garage_panel.add_child(steering_mode_button)
	steering_mode_button.pressed.connect(_toggle_steering_mode)
	character_button = _make_button("CHAR: " + character_names[character_index], 128)
	character_button.custom_minimum_size.y = 42
	garage_panel.add_child(character_button)
	character_button.pressed.connect(_cycle_character)
	var paint := _make_button("PAINT", 128)
	var next_car := _make_button("NEXT CAR", 128)
	var silver := _make_button("SILVER", 128)
	var finish := _make_button("FINISH: GLOSS", 128)
	var rims := _make_button("RIMS: SILVER", 128)
	var spoiler := _make_button("SPOILER: ON", 128)
	var lights := _make_button("LIGHTS: ON", 128)
	var mix_color := ColorPickerButton.new()
	mix_color.text = "MIX COLOR"
	mix_color.custom_minimum_size = Vector2(128, 46)
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
	garage_panel.add_child(lights)
	paint.pressed.connect(_cycle_car_paint)
	next_car.pressed.connect(_cycle_vehicle_model)
	silver.pressed.connect(_apply_silver_paint)
	finish.pressed.connect(_cycle_paint_finish)
	mix_color.color_changed.connect(_apply_custom_car_color)
	rims.pressed.connect(_cycle_rim_color)
	spoiler.pressed.connect(_toggle_spoiler)
	lights.pressed.connect(_toggle_headlights)
	steering_wheel = VirtualSteeringWheel.new()
	steering_wheel.name = "VirtualSteeringWheel"
	steering_wheel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	steering_wheel.position = Vector2(18, -300)
	steering_wheel.size = Vector2(184, 184)
	steering_wheel.steering_changed.connect(_set_wheel_steering)
	layer.add_child(steering_wheel)
	steering_wheel.visible = false
	move_joystick = VirtualMoveJoystick.new()
	move_joystick.name = "OnFootMoveJoystick"
	move_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	move_joystick.position = Vector2(18, -190)
	move_joystick.size = Vector2(156, 156)
	move_joystick.direction_changed.connect(_set_move)
	layer.add_child(move_joystick)
	var run_button := _make_button("RUN", 76)
	run_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	run_button.position = Vector2(-178, -154)
	run_button.size = Vector2(72, 54)
	run_button.custom_minimum_size = Vector2(72, 54)
	layer.add_child(run_button)
	run_button.button_down.connect(func(): run_pressed = true)
	run_button.button_up.connect(func(): run_pressed = false)
	var jump_button := _make_button("JUMP", 76)
	jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_button.position = Vector2(-94, -154)
	jump_button.size = Vector2(72, 54)
	jump_button.custom_minimum_size = Vector2(72, 54)
	layer.add_child(jump_button)
	jump_button.pressed.connect(func(): jump_requested = true)
	on_foot_buttons = [move_joystick, run_button, jump_button]
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
	# Separate on-screen camera zoom controls
	var zoom_controls := HBoxContainer.new()
	zoom_controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	zoom_controls.position = Vector2(-116, 52)
	zoom_controls.size = Vector2(108, 48)
	zoom_controls.add_theme_constant_override("separation", 6)
	layer.add_child(zoom_controls)
	var zoom_in_button := _make_button("+", 50)
	var zoom_out_button := _make_button("−", 50)
	zoom_in_button.custom_minimum_size = Vector2(50, 48)
	zoom_out_button.custom_minimum_size = Vector2(50, 48)
	zoom_controls.add_child(zoom_in_button)
	zoom_controls.add_child(zoom_out_button)
	zoom_in_button.pressed.connect(_zoom_in)
	zoom_out_button.pressed.connect(_zoom_out)

func _toggle_steering_mode() -> void:
	steering_mode = 1 - steering_mode
	var use_wheel := steering_mode == 1
	for button in steering_buttons:
		button.visible = not use_wheel
	steering_wheel.visible = use_wheel
	steering_mode_button.text = "STEER: WHEEL" if use_wheel else "STEER: BUTTONS"
	steer_input = 0.0
	steering_visual = 0.0
	status_label.text = "Steering mode: %s" % ("Virtual wheel" if use_wheel else "Left/right buttons")
	_save_game_settings()

func _set_wheel_steering(value: float) -> void:
	if steering_mode == 1:
		steer_input = value
		if not driving:
			_set_move(Vector2(value, move_dir.y))

func _make_button(caption: String, button_width: float) -> Button:
	var button := MultiTouchButton.new()
	button.text = caption
	button.custom_minimum_size = Vector2(button_width, 44)
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
	_save_game_settings()

func _apply_custom_car_color(color: Color) -> void:
	if not driving and player.global_position.distance_to(car.global_position) > 5.5:
		status_label.text = "Move closer to your car to mix a custom paint color"
		return
	current_paint_color = color
	_refresh_car_paint()
	status_label.text = "GARAGE  •  Custom mixed paint applied"
	_save_game_settings()

func _apply_silver_paint() -> void:
	if not driving and player.global_position.distance_to(car.global_position) > 5.5:
		status_label.text = "Move closer to your car to use the silver finish"
		return
	current_paint_color = Color(0.72, 0.76, 0.80)
	finish_index = 2
	_refresh_car_paint()
	status_label.text = "GARAGE  •  Metallic silver finish applied"
	_save_game_settings()
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
	_save_game_settings()
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
	_save_game_settings()

func _toggle_spoiler() -> void:
	if selected_suv:
		status_label.text = "Spoiler customization is available on the Velocity Sport"
		return
	spoiler_enabled = not spoiler_enabled
	sport_spoiler.visible = spoiler_enabled
	status_label.text = "GARAGE  •  Rear spoiler %s" % ("installed" if spoiler_enabled else "removed")
	_save_game_settings()

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
	if is_instance_valid(sport_model):
		sport_model.visible = not selected_suv
	status_label.text = "GARAGE  •  Selected %s" % ("CITY SUV" if selected_suv else "VELOCITY SPORT")
	_save_game_settings()

func _update_control_visibility() -> void:
	for control in vehicle_buttons:
		control.visible = driving
	for control in on_foot_buttons:
		control.visible = not driving
	if steering_mode_button:
		steering_mode_button.visible = driving
	if character_button:
		character_button.visible = not driving
	if steering_wheel:
		steering_wheel.visible = driving and steering_mode == 1
	for button in steering_buttons:
		button.visible = driving and steering_mode == 0

func _cycle_character() -> void:
	if driving:
		return
	character_index = (character_index + 1) % character_names.size()
	for index in range(character_visuals.size()):
		character_visuals[index].visible = index == character_index
	character_button.text = "CHAR: " + character_names[character_index]
	status_label.text = "Selected character: %s  •  Same abilities and controls" % character_names[character_index]
	_save_game_settings()

func _toggle_vehicle() -> void:
	if driving:
		driving = false
		speed = 0.0
		throttle_input = 0.0
		steer_input = 0.0
		steering_visual = 0.0
		move_dir = Vector2.ZERO
		run_pressed = false
		jump_requested = false
		horn_pressed = false
		brake_pressed = false
		nitro_pressed = false
		drift_pressed = false
		if engine_audio and engine_audio.playing:
			engine_audio.stop()
		if horn_audio and horn_audio.playing:
			horn_audio.stop()
		player.global_position = car.global_position + Vector3(2.2, 0.4, 0)
		player.visible = true
		if enter_exit_button:
			enter_exit_button.text = "ENTER"
		status_label.text = "On foot • Walk to the car and tap ENTER"
	else:
		# Entering is always allowed from the on-foot state; avoid a distance gate
		# that can strand the player when touch movement or camera direction differs.
		driving = true
		if enter_exit_button:
			enter_exit_button.text = "EXIT"
		camera_yaw = 0.0
		player.visible = false
		if engine_audio and not engine_audio.playing:
			engine_audio.play()
		status_label.text = "Driving • Use arrows, ENTER to exit"

	_update_control_visibility()

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

func _input(event: InputEvent) -> void:
	# Reserve the lower part of the screen for driving buttons and other UI.
	var viewport_size := get_viewport().get_visible_rect().size
	var ui_top := viewport_size.y - 190.0

	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.y < ui_top:
				camera_touch_positions[event.index] = event.position
				if camera_touch_positions.size() == 1:
					camera_dragging = true
					camera_touch_index = event.index
				elif camera_touch_positions.size() == 2:
					camera_dragging = false
					camera_pinch_distance = _get_camera_pinch_distance()
		else:
			camera_touch_positions.erase(event.index)
			if camera_touch_positions.size() >= 2:
				camera_pinch_distance = _get_camera_pinch_distance()
			elif camera_touch_positions.size() == 1:
				camera_touch_index = int(camera_touch_positions.keys()[0])
				camera_dragging = true
			else:
				camera_dragging = false
				camera_touch_index = -1
				camera_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		if camera_touch_positions.has(event.index):
			camera_touch_positions[event.index] = event.position
			if camera_touch_positions.size() >= 2:
				var new_distance := _get_camera_pinch_distance()
				if camera_pinch_distance > 0.0:
					camera_zoom = clampf(camera_zoom - (new_distance - camera_pinch_distance) * 0.003, 0.55, 1.7)
				camera_pinch_distance = new_distance
			elif camera_dragging and event.index == camera_touch_index:
				_rotate_orbit_camera(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			camera_dragging = event.position.y < ui_top
		else:
			camera_dragging = false
	elif event is InputEventMouseMotion and camera_dragging:
		_rotate_orbit_camera(event.relative)

func _get_camera_pinch_distance() -> float:
	if camera_touch_positions.size() < 2:
		return 0.0
	var points: Array = camera_touch_positions.values()
	var first_point := Vector2(points[0])
	var second_point := Vector2(points[1])
	return first_point.distance_to(second_point)

func _rotate_orbit_camera(drag_delta: Vector2) -> void:
	camera_yaw -= drag_delta.x * camera_drag_sensitivity
	camera_pitch = clampf(camera_pitch + drag_delta.y * camera_drag_sensitivity, 0.15, 1.05)

func _zoom_in() -> void:
	camera_zoom = clampf(camera_zoom - 0.12, 0.55, 1.7)

func _zoom_out() -> void:
	camera_zoom = clampf(camera_zoom + 0.12, 0.55, 1.7)

func _process(delta: float) -> void:
	if not mission_complete:
		var actor_position := car.global_position if driving else player.global_position
		if actor_position.distance_to(checkpoint.global_position) < 3.2:
			_advance_city_tour()
		else:
			checkpoint.rotate_y(delta * 0.8)
func _move_traffic(delta: float) -> void:
	for i in range(traffic_cars.size()):
		var traffic := traffic_cars[i]
		var direction := 1.0 if i % 2 == 0 else -1.0
		traffic.position.z += (5.0 + float(i % 2) * 1.5) * delta * direction
		if traffic.position.z > 48.0:
			traffic.position.z = -48.0
		elif traffic.position.z < -48.0:
			traffic.position.z = 48.0

func _physics_process(delta: float) -> void:
	_move_traffic(delta)
	if driving:
		var using_nitro := nitro_pressed and throttle_input > 0.0 and nitro_energy > 0.0 and not brake_pressed
		if using_nitro:
			nitro_energy = maxf(0.0, nitro_energy - delta)
		elif not nitro_pressed:
			nitro_energy = minf(3.0, nitro_energy + delta * 0.22)
		if engine_audio and not engine_audio.playing:
			engine_audio.play()
		_update_brake_lights(brake_pressed or (throttle_input < 0.0 and speed > 0.5))
		_update_wheel_visuals(delta)
		if engine_audio:
			engine_audio.pitch_scale = 0.82 + clampf(absf(speed) / 22.0, 0.0, 1.0) * 0.95 + (0.18 if using_nitro else 0.0)
		_update_turn_signals(delta)
		_update_reverse_lights(throttle_input < 0.0 and absf(speed) < 5.0)
		var target_speed := 0.0 if brake_pressed else (24.0 if using_nitro else 16.0) if throttle_input > 0.0 else throttle_input * 8.0
		var acceleration := 28.0 if brake_pressed else (16.0 if using_nitro else 10.0) if throttle_input != 0.0 else 15.0
		var traffic_blocked := false
		for traffic in traffic_cars:
			var local_traffic := car.to_local(traffic.global_position)
			var approaching := local_traffic.z < -1.5 and local_traffic.z > -6.0
			if approaching and absf(local_traffic.x) < 2.35 and absf(speed) > 2.0:
				traffic_blocked = true
				break
		if traffic_blocked:
			speed = move_toward(speed, 0.0, 24.0 * delta)
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
		var impact_detected := false
		for collision_index in range(car.get_slide_collision_count()):
			var hit := car.get_slide_collision(collision_index)
			var collider := hit.get_collider()
			var horizontal_impact := absf(hit.get_normal().y) < 0.65
			if horizontal_impact and collider != null:
				var traffic_hit := collider is AnimatableBody3D and String(collider.name).begins_with("Traffic_")
				if traffic_hit:
					speed *= 0.25
					car.velocity = hit.get_normal() * 2.0
					collision_feedback_timer = 1.0
					impact_detected = true
					break
				elif absf(speed) > 2.0:
					speed *= 0.55
					collision_feedback_timer = 0.65
					impact_detected = true
					break
		if collision_feedback_timer > 0.0:
			status_label.text = "COLLISION  •  Vehicle impact detected!"
		elif traffic_blocked:
			status_label.text = "TRAFFIC AHEAD  •  Slow down!"
		elif drift_pressed:
			status_label.text = "DRIFTING  •  %d km/h" % int(absf(speed) * 3.6)
		else:
			status_label.text = "DRIVING  •  %d km/h  •  NITRO %.1fs" % [int(absf(speed) * 3.6), nitro_energy]
	else:
		if engine_audio and engine_audio.playing:
			engine_audio.stop()
		if horn_audio and horn_audio.playing:
			horn_audio.stop()
		_update_turn_signals(delta)
		_update_brake_lights(false)
		_update_reverse_lights(false)
		# Move relative to the orbit camera, as in a third-person mobile game.
		var camera_forward := -camera.global_basis.z
		camera_forward.y = 0.0
		camera_forward = camera_forward.normalized()
		var camera_right := camera.global_basis.x
		camera_right.y = 0.0
		camera_right = camera_right.normalized()
		var direction := camera_right * move_dir.x + camera_forward * -move_dir.y
		if direction.length_squared() > 1.0:
			direction = direction.normalized()
		var walk_speed := 7.0 if run_pressed else 4.5
		player.velocity.x = direction.x * walk_speed
		player.velocity.z = direction.z * walk_speed
		if direction.length_squared() > 0.001:
			var target_yaw := atan2(-direction.x, -direction.z)
			player.rotation.y = lerp_angle(player.rotation.y, target_yaw, minf(1.0, delta * 10.0))
		if jump_requested and player.is_on_floor():
			player.velocity.y = 7.2
		jump_requested = false
		player.velocity.y -= 20.0 * delta
		player.move_and_slide()
	var target_fov := camera_base_fov + (clampf(absf(speed) / 24.0, 0.0, 1.0) * 7.0 if driving else 0.0) + (3.0 if driving and nitro_pressed and nitro_energy > 0.0 else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 3.0 * delta)
	var target := car.global_position if driving else player.global_position
	var camera_distance := (11.0 if driving else 9.0) * camera_zoom
	var orbit_offset := Vector3(
		sin(camera_yaw) * cos(camera_pitch) * camera_distance,
		sin(camera_pitch) * camera_distance + (0.8 if driving else 0.0),
		cos(camera_yaw) * cos(camera_pitch) * camera_distance
	)
	# While driving, rotate the orbit offset with the vehicle so the camera
	# naturally follows behind the car as it turns. Touch orbit remains available.
	if driving:
		orbit_offset = orbit_offset.rotated(Vector3.UP, car.global_rotation.y)
	camera.global_position = camera.global_position.lerp(target + orbit_offset, 5.0 * delta)
	camera.look_at(target + Vector3(0, 1.0 if driving else 1.2, 0), Vector3.UP)