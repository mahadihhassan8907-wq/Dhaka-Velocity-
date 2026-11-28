extends Node3D

# Each button independently hit-tests every screen touch in viewport coordinates.
# This avoids relying on Godot's single-control GUI touch capture for simultaneous buttons.
class MultiTouchButton extends Button:
	var active_touch_id := -1

	func _ready() -> void:
		# Handle touch input manually so Godot's native GUI path cannot double-activate this button.
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
			# One finger can own this button at a time. Other fingers may still use other controls.
			if inside and active_touch_id == -1:
				active_touch_id = touch_id
				set_pressed_no_signal(true)
				emit_signal("button_down")
		elif touch_id == active_touch_id:
			active_touch_id = -1
			set_pressed_no_signal(false)
			emit_signal("button_up")
			# Activate only once, and only if the owning finger is released inside the button.
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
	time_of_day = fposmod(time_of_day + delta / 900.0, 1.0)
	_update_day_night_visuals()
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

var city_material_cache: Dictionary = {}
var city_box_mesh_cache: Dictionary = {}
var city_tank_mesh: CylinderMesh
var city_tank_lid_mesh: CylinderMesh
var city_tank_pipe_mesh: CylinderMesh
var city_streetlight_pole_mesh: CylinderMesh
var city_sun: DirectionalLight3D
var city_environment: Environment
var time_of_day := 0.36
var day_night_button: Button

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
var last_vehicle_toggle_msec := -1000
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
var pedestrians: Array[Dictionary] = []
var interactive_shop_created := false
var shop_door_pivot: Node3D
var shop_entrance_position := Vector3.ZERO
var shop_counter_position := Vector3.ZERO
var shop_door_open := false
var shop_interaction_button: Button
var shop_purchase_button: Button
var cash_balance := 250
var water_bottles := 0
var wallet_label: Label
var stamina_label: Label
var shop_drink_button: Button
var stamina := 100.0
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
var pause_menu_panel: PanelContainer
var cheat_codes_button: Button
var cheat_codes_enabled := false
var character_home_positions: Array[Vector3] = [Vector3(-112, 0, -112), Vector3(112, 0, -112), Vector3(-112, 0, 112)]
var character_home_names: Array[String] = ["MARCUS' FAMILY HOME", "FELIX' CITY APARTMENT", "DAMIAN'S RIVERSIDE HOUSE"]
var character_home_nodes: Array[Node3D] = []
var character_world_positions: Array[Vector3] = [Vector3(-5, 1, 5), Vector3(112, 1.2, -119.5), Vector3(-112, 1.2, 104.5)]
var character_cash: Array[int] = [250, 180, 320]
var personal_mission_marker: MeshInstance3D
var character_autosave_timer := 0.0
var character_mission_steps: Array[int] = [0, 0, 0]
var character_mission_active: Array[bool] = [false, false, false]
var character_mission_completed: Array[int] = [0, 0, 0]
var life_menu_panel: PanelContainer
var life_character_label: Label
var life_profile_label: Label
var life_mission_label: Label
var life_track_button: Button
var home_rest_button: Button

func _ready() -> void:
	_load_saved_settings()
	_build_city()
	_build_character_homes()
	_build_player()
	_build_car()
	_build_traffic()
	_build_pedestrians()
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
	cash_balance = maxi(0, int(config.get_value("economy", "cash", cash_balance)))
	if config.has_section_key("characters", "cash_balances"):
		var saved_cash: Array = config.get_value("characters", "cash_balances", [])
		for i in range(mini(3, saved_cash.size())):
			character_cash[i] = maxi(0, int(saved_cash[i]))
		cash_balance = character_cash[character_index]
	else:
		character_cash[character_index] = cash_balance
	water_bottles = maxi(0, int(config.get_value("economy", "water_bottles", water_bottles)))
	cheat_codes_enabled = bool(config.get_value("gameplay", "cheat_codes_enabled", cheat_codes_enabled))
	time_of_day = clampf(float(config.get_value("world", "time_of_day", time_of_day)), 0.0, 1.0)
	var saved_positions: Array = config.get_value("characters", "world_positions", [])
	for i in range(mini(3, saved_positions.size())):
		if typeof(saved_positions[i]) == TYPE_VECTOR3:
			character_world_positions[i] = saved_positions[i]
	var saved_steps: Array = config.get_value("story", "mission_steps", [])
	var saved_active: Array = config.get_value("story", "mission_active", [])
	var saved_completed: Array = config.get_value("story", "mission_completed", [])
	for i in range(3):
		if i < saved_steps.size():
			character_mission_steps[i] = clampi(int(saved_steps[i]), 0, 3)
		if i < saved_active.size():
			character_mission_active[i] = bool(saved_active[i]) and character_mission_steps[i] < 3
		if i < saved_completed.size():
			character_mission_completed[i] = clampi(int(saved_completed[i]), 0, 3)

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
	if is_instance_valid(player):
		character_world_positions[character_index] = player.global_position
	config.set_value("characters", "world_positions", character_world_positions)
	character_cash[character_index] = cash_balance
	config.set_value("characters", "cash_balances", character_cash)
	config.set_value("economy", "cash", cash_balance)
	config.set_value("economy", "water_bottles", water_bottles)
	config.set_value("gameplay", "cheat_codes_enabled", cheat_codes_enabled)
	config.set_value("world", "time_of_day", time_of_day)
	config.set_value("story", "mission_steps", character_mission_steps)
	config.set_value("story", "mission_active", character_mission_active)
	config.set_value("story", "mission_completed", character_mission_completed)
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


func _city_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if city_material_cache.has(key):
		return city_material_cache[key] as StandardMaterial3D
	var material := _mat(color)
	city_material_cache[key] = material
	return material


func _city_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_key := str(size)
	var mesh := city_box_mesh_cache.get(mesh_key) as BoxMesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		city_box_mesh_cache[mesh_key] = mesh
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _city_material(color)
	parent.add_child(node)
	return node


func _city_solid_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	_city_box(body, size, Vector3.ZERO, color)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _build_city() -> void:
	# First open-world district: a 260 m x 260 m connected street grid.
	# Buildings use simple shared gameplay geometry for the mobile prototype;
	# detailed interiors, NPC routines and streamed districts come in later phases.
	_city_solid_box(self, Vector3(260.0, 0.3, 260.0), Vector3(0.0, -0.2, 0.0), Color(0.20, 0.42, 0.25))

	var road_coordinates: Array[float] = [-96.0, -48.0, 0.0, 48.0, 96.0]
	for road_coordinate in road_coordinates:
		var road_width := 16.0 if is_zero_approx(road_coordinate) else 11.0
		_city_solid_box(self, Vector3(road_width, 0.08, 260.0), Vector3(road_coordinate, 0.0, 0.0), Color(0.105, 0.115, 0.13))
		_city_solid_box(self, Vector3(260.0, 0.08, road_width), Vector3(0.0, 0.01, road_coordinate), Color(0.105, 0.115, 0.13))

		# Sidewalks and pale curb edges run along both sides of every road.
		var sidewalk_offset := road_width * 0.5 + 1.5
		for side in [-1.0, 1.0]:
			_city_solid_box(self, Vector3(2.4, 0.16, 260.0), Vector3(road_coordinate + side * sidewalk_offset, 0.04, 0.0), Color(0.48, 0.50, 0.51))
			_city_solid_box(self, Vector3(260.0, 0.16, 2.4), Vector3(0.0, 0.04, road_coordinate + side * sidewalk_offset), Color(0.48, 0.50, 0.51))
			_city_box(self, Vector3(0.14, 0.10, 260.0), Vector3(road_coordinate + side * (road_width * 0.5 + 0.12), 0.10, 0.0), Color(0.78, 0.78, 0.72))
			_city_box(self, Vector3(260.0, 0.10, 0.14), Vector3(0.0, 0.10, road_coordinate + side * (road_width * 0.5 + 0.12)), Color(0.78, 0.78, 0.72))

	# Broken centre markings make the roads readable without filling the scene with detail.
	for road_coordinate in road_coordinates:
		for segment in range(-118, 119, 14):
			if abs(segment) % 48 < 9:
				continue
			_city_box(self, Vector3(0.16, 0.025, 4.2), Vector3(road_coordinate, 0.058, float(segment)), Color(0.92, 0.82, 0.38))
			_city_box(self, Vector3(4.2, 0.025, 0.16), Vector3(float(segment), 0.058, road_coordinate), Color(0.92, 0.82, 0.38))

	# Clearly marked enterable shop near the player's starting area.
	_build_city_building(Vector3(-15.0, 0.0, 15.0), 13.0, 13.0, 18.0, Color(0.18, 0.38, 0.43), true)

	# Populate the blocks around the central starting intersection.
	# The centre stays open so the player, starter car and first checkpoints remain clear.
	var block_centres: Array[float] = [-72.0, -24.0, 24.0, 72.0]
	var facade_palette: Array[Color] = [
		Color(0.55, 0.57, 0.59),
		Color(0.68, 0.58, 0.46),
		Color(0.43, 0.51, 0.59),
		Color(0.70, 0.68, 0.61),
		Color(0.49, 0.55, 0.48),
		Color(0.62, 0.49, 0.43)
	]
	for block_x in block_centres:
		for block_z in block_centres:
			if absf(block_x) < 30.0 and absf(block_z) < 30.0:
				continue
			var block_seed: int = abs(int(block_x * 3.0 + block_z * 5.0))
			var first_height := 12.0 + float((block_seed * 7) % 19)
			var second_height := 10.0 + float((block_seed * 11 + 5) % 17)
			var first_color: Color = facade_palette[block_seed % facade_palette.size()]
			var second_color: Color = facade_palette[(block_seed + 3) % facade_palette.size()]
			_build_city_building(Vector3(block_x - 7.0, 0.0, block_z - 7.0), 13.0, 13.0, first_height, first_color, block_seed % 3 == 0)
			_build_city_building(Vector3(block_x + 7.0, 0.0, block_z + 7.0), 13.0, 13.0, second_height, second_color, block_seed % 4 == 0)

	# Simple street furniture on the main avenues; these are visual landmarks for navigation.
	for street_position in [-96.0, -48.0, 48.0, 96.0]:
		_build_city_streetlight(Vector3(-10.5, 0.0, street_position))
		_build_city_streetlight(Vector3(10.5, 0.0, street_position))
		_build_city_streetlight(Vector3(street_position, 0.0, -10.5))
		_build_city_streetlight(Vector3(street_position, 0.0, 10.5))

	city_sun = DirectionalLight3D.new()
	city_sun.name = "DhakaSunAndMoon"
	city_sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	city_sun.light_energy = 1.2
	city_sun.shadow_enabled = true
	add_child(city_sun)
	var environment_node := WorldEnvironment.new()
	city_environment = Environment.new()
	city_environment.background_mode = Environment.BG_SKY
	city_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	city_environment.ambient_light_color = Color(0.55, 0.62, 0.72)
	city_environment.ambient_light_energy = 0.8
	city_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	city_environment.ambient_light_sky_contribution = 0.35
	environment_node.environment = city_environment
	add_child(environment_node)
	_update_day_night_visuals()


func _build_city_building(world_position: Vector3, width: float, depth: float, height: float, facade_color: Color, is_shop: bool) -> void:
	var building := StaticBody3D.new()
	building.name = "Shop_Building" if is_shop else "City_Building"
	building.position = world_position
	add_child(building)
	if is_shop and not interactive_shop_created:
		interactive_shop_created = true
		_build_enterable_shop_structure(building, width, depth, height, facade_color)
		return

	var collision := CollisionShape3D.new()
	var collision_shape := BoxShape3D.new()
	collision_shape.size = Vector3(width, height, depth)
	collision.position.y = height * 0.5
	collision.shape = collision_shape
	building.add_child(collision)

	_city_box(building, Vector3(width, height, depth), Vector3(0.0, height * 0.5, 0.0), facade_color)
	_city_box(building, Vector3(width + 0.35, 0.42, depth + 0.35), Vector3(0.0, height + 0.21, 0.0), Color(0.22, 0.25, 0.29))
	_build_rooftop_water_tank(building, width, depth, height)

	# Repeated front windows create a readable multi-storey facade.
	var floors := maxi(2, int(floor((height - 1.0) / 3.2)))
	for floor_index in range(floors):
		var window_y := 2.2 + float(floor_index) * 3.0
		if window_y > height - 1.0:
			continue
		for window_index in range(3):
			var window_x := -width * 0.32 + float(window_index) * width * 0.32
			var glass := _city_box(building, Vector3(1.45, 1.35, 0.10), Vector3(window_x, window_y, -depth * 0.5 - 0.06), Color(0.10, 0.22, 0.31))
			var glass_material := glass.material_override as StandardMaterial3D
			if glass_material:
				glass_material.metallic = 0.25
				glass_material.roughness = 0.2

	# A visible entrance is a future hook for the reusable interior/door interaction system.
	_city_box(building, Vector3(1.55, 2.45, 0.12), Vector3(0.0, 1.23, -depth * 0.5 - 0.09), Color(0.16, 0.12, 0.09))
	if is_shop:
		_city_box(building, Vector3(width * 0.72, 0.75, 0.18), Vector3(0.0, 3.15, -depth * 0.5 - 0.10), Color(0.12, 0.34, 0.43))
		_city_box(building, Vector3(width * 0.78, 0.16, 0.35), Vector3(0.0, 2.55, -depth * 0.5 - 0.18), Color(0.86, 0.56, 0.20))



func _build_rooftop_water_tank(building: StaticBody3D, width: float, depth: float, height: float) -> void:
	# Dhaka-inspired rooftop water tank: lightweight visual geometry with no extra physics.
	var tank_x := -width * 0.22
	var tank_z := depth * 0.12
	var roof_y := height + 0.42
	var support_material := _city_material(Color(0.24, 0.27, 0.29))
	var tank_material := _city_material(Color(0.075, 0.19, 0.22))
	tank_material.roughness = 0.48
	var lid_material := _city_material(Color(0.16, 0.27, 0.29))
	lid_material.roughness = 0.38
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_city_box(building, Vector3(0.12, 0.92, 0.12), Vector3(tank_x + x_side * 0.68, roof_y + 0.46, tank_z + z_side * 0.68), Color(0.24, 0.27, 0.29))
	if city_tank_mesh == null:
		city_tank_mesh = CylinderMesh.new()
		city_tank_mesh.top_radius = 0.92
		city_tank_mesh.bottom_radius = 0.92
		city_tank_mesh.height = 1.58
	var tank := MeshInstance3D.new()
	tank.name = "Rooftop_Water_Tank"
	tank.mesh = city_tank_mesh
	tank.position = Vector3(tank_x, roof_y + 1.42, tank_z)
	tank.material_override = tank_material
	building.add_child(tank)
	if city_tank_lid_mesh == null:
		city_tank_lid_mesh = CylinderMesh.new()
		city_tank_lid_mesh.top_radius = 0.98
		city_tank_lid_mesh.bottom_radius = 0.98
		city_tank_lid_mesh.height = 0.12
	var lid := MeshInstance3D.new()
	lid.mesh = city_tank_lid_mesh
	lid.position = Vector3(tank_x, roof_y + 2.25, tank_z)
	lid.material_override = lid_material
	building.add_child(lid)
	# A short outlet pipe makes the rooftop silhouette less box-like.
	if city_tank_pipe_mesh == null:
		city_tank_pipe_mesh = CylinderMesh.new()
		city_tank_pipe_mesh.top_radius = 0.055
		city_tank_pipe_mesh.bottom_radius = 0.055
		city_tank_pipe_mesh.height = 0.72
	var pipe := MeshInstance3D.new()
	pipe.mesh = city_tank_pipe_mesh
	pipe.rotation.x = PI * 0.5
	pipe.position = Vector3(tank_x, roof_y + 0.98, tank_z - 0.94)
	pipe.material_override = support_material
	building.add_child(pipe)


func _build_enterable_shop_structure(building: StaticBody3D, width: float, depth: float, height: float, facade_color: Color) -> void:
	# First true interior vertical slice: open doorway, walkable floor, walls and shop fixtures.
	var wall_height := 3.4
	var wall_thickness := 0.35
	var door_width := 2.0
	var front_z := -depth * 0.5
	shop_entrance_position = building.to_global(Vector3(0.0, 0.0, front_z - 0.9))
	shop_counter_position = building.to_global(Vector3(0.0, 0.0, -2.8))
	_solid_box(building, Vector3(width, 0.22, depth), Vector3(0.0, 0.0, 0.0), Color(0.34, 0.31, 0.27))
	_solid_box(building, Vector3(wall_thickness, wall_height, depth), Vector3(-width * 0.5, wall_height * 0.5, 0.0), facade_color)
	_solid_box(building, Vector3(wall_thickness, wall_height, depth), Vector3(width * 0.5, wall_height * 0.5, 0.0), facade_color)
	_solid_box(building, Vector3(width, wall_height, wall_thickness), Vector3(0.0, wall_height * 0.5, depth * 0.5), facade_color)
	var side_width := (width - door_width) * 0.5
	_solid_box(building, Vector3(side_width, wall_height, wall_thickness), Vector3(-(door_width + side_width) * 0.5, wall_height * 0.5, front_z), facade_color)
	_solid_box(building, Vector3(side_width, wall_height, wall_thickness), Vector3((door_width + side_width) * 0.5, wall_height * 0.5, front_z), facade_color)
	_solid_box(building, Vector3(door_width, 0.9, wall_thickness), Vector3(0.0, wall_height - 0.45, front_z), facade_color)
	# Upper building mass preserves the skyline while leaving a usable ground-floor interior.
	var upper_height := maxf(1.0, height - wall_height)
	_solid_box(building, Vector3(width, upper_height, depth), Vector3(0.0, wall_height + upper_height * 0.5, 0.0), facade_color)
	_solid_box(building, Vector3(width + 0.35, 0.42, depth + 0.35), Vector3(0.0, height + 0.21, 0.0), Color(0.22, 0.25, 0.29))
	# High-contrast sign makes the one enterable shop easy to identify.
	var shop_sign := Label3D.new()
	shop_sign.text = "OPEN SHOP"
	shop_sign.font_size = 64
	shop_sign.position = Vector3(0.0, 3.0, front_z - 0.25)
	shop_sign.modulate = Color(1.0, 0.78, 0.18)
	shop_sign.outline_size = 12
	shop_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	building.add_child(shop_sign)
	# Door pivots from its left edge and swings inward when opened.
	shop_door_pivot = Node3D.new()
	shop_door_pivot.position = Vector3(-door_width * 0.5, 0.0, front_z - 0.12)
	building.add_child(shop_door_pivot)
	var door_body := StaticBody3D.new()
	shop_door_pivot.add_child(door_body)
	_box(door_body, Vector3(door_width, 2.4, 0.16), Vector3(door_width * 0.5, 1.2, 0.0), Color(0.20, 0.12, 0.07))
	var door_collision := CollisionShape3D.new()
	var door_shape := BoxShape3D.new()
	door_shape.size = Vector3(door_width, 2.4, 0.16)
	door_collision.shape = door_shape
	door_collision.position = Vector3(door_width * 0.5, 1.2, 0.0)
	door_body.add_child(door_collision)
	# Basic interior fixtures make the shop visibly usable rather than an empty shell.
	_box(building, Vector3(3.8, 1.05, 0.85), Vector3(0.0, 0.62, -1.6), Color(0.34, 0.20, 0.11))
	_box(building, Vector3(3.9, 1.7, 0.55), Vector3(-4.35, 1.0, 1.0), Color(0.25, 0.29, 0.32))
	_box(building, Vector3(3.9, 1.7, 0.55), Vector3(4.35, 1.0, 1.0), Color(0.25, 0.29, 0.32))
	_box(building, Vector3(0.9, 0.7, 0.65), Vector3(0.0, 1.0, -2.0), Color(0.12, 0.32, 0.38))
	_box(building, Vector3(1.0, 0.08, 0.72), Vector3(0.0, 1.38, -2.0), Color(0.12, 0.16, 0.18))
	# A simple shopkeeper stands behind the counter as a recognizable interior character.
	var shopkeeper := Node3D.new()
	shopkeeper.name = "Shopkeeper"
	shopkeeper.position = Vector3(0.0, 0.0, 0.35)
	building.add_child(shopkeeper)
	_character_capsule(shopkeeper, 0.28, 0.92, Vector3(0.0, 1.18, 0.0), Color(0.18, 0.32, 0.52))
	_character_sphere(shopkeeper, 0.19, Vector3(0.0, 1.82, 0.0), Color(0.66, 0.48, 0.34))
	_character_capsule(shopkeeper, 0.085, 0.62, Vector3(-0.34, 1.20, 0.0), Color(0.18, 0.32, 0.52))
	_character_capsule(shopkeeper, 0.085, 0.62, Vector3(0.34, 1.20, 0.0), Color(0.18, 0.32, 0.52))
	var shop_light := OmniLight3D.new()
	shop_light.position = Vector3(0.0, 3.0, -1.0)
	shop_light.light_color = Color(1.0, 0.82, 0.58)
	shop_light.light_energy = 1.35
	shop_light.omni_range = 9.0
	building.add_child(shop_light)
	# Small, colorful stock on both shelves makes the shop feel stocked and readable.
	var product_colors: Array[Color] = [
		Color(0.12, 0.58, 0.88), Color(0.88, 0.24, 0.16),
		Color(0.92, 0.72, 0.12), Color(0.20, 0.68, 0.34)
	]
	for shelf_x in [-4.35, 4.35]:
		for product_index in range(4):
			var product_x := shelf_x - 1.35 + float(product_index) * 0.9
			var product_color: Color = product_colors[product_index]
			_box(building, Vector3(0.48, 0.48, 0.34), Vector3(product_x, 2.08, 0.72), product_color)
			_box(building, Vector3(0.52, 0.08, 0.38), Vector3(product_x, 2.36, 0.72), Color(0.88, 0.88, 0.82))
	_box(building, Vector3(width + 0.35, 0.42, depth + 0.35), Vector3(0.0, height + 0.21, 0.0), Color(0.22, 0.25, 0.29))


func _build_character_homes() -> void:
	# Three persistent personal homes. Open front entrances let the player walk inside.
	var facade_colors: Array[Color] = [Color(0.64, 0.48, 0.36), Color(0.36, 0.48, 0.60), Color(0.48, 0.56, 0.40)]
	var trim_colors: Array[Color] = [Color(0.22, 0.13, 0.09), Color(0.12, 0.18, 0.25), Color(0.17, 0.22, 0.14)]
	for i in range(3):
		var home := Node3D.new()
		home.name = "Home_" + character_names[i]
		home.position = character_home_positions[i]
		add_child(home)
		character_home_nodes.append(home)
		var facade: Color = facade_colors[i]
		var trim: Color = trim_colors[i]
		_solid_box(home, Vector3(10.0, 0.22, 8.0), Vector3(0, 0.11, 0), Color(0.34, 0.32, 0.28))
		_solid_box(home, Vector3(10.0, 3.2, 0.28), Vector3(0, 1.72, 3.86), facade)
		_solid_box(home, Vector3(0.28, 3.2, 8.0), Vector3(-4.86, 1.72, 0), facade)
		_solid_box(home, Vector3(0.28, 3.2, 8.0), Vector3(4.86, 1.72, 0), facade)
		_solid_box(home, Vector3(3.65, 3.2, 0.28), Vector3(-3.12, 1.72, -3.86), facade)
		_solid_box(home, Vector3(3.65, 3.2, 0.28), Vector3(3.12, 1.72, -3.86), facade)
		_solid_box(home, Vector3(10.0, 0.28, 8.0), Vector3(0, 3.36, 0), trim)
		_box(home, Vector3(1.6, 2.8, 0.12), Vector3(0, 1.48, -3.98), trim)
		_box(home, Vector3(1.35, 2.45, 0.08), Vector3(0, 1.42, -4.06), Color(0.42, 0.25, 0.14))
		_box(home, Vector3(1.5, 0.12, 0.12), Vector3(0, 2.75, -4.08), Color(0.85, 0.72, 0.42))
		for side in [-1.0, 1.0]:
			_box(home, Vector3(1.35, 1.15, 0.10), Vector3(side * 3.1, 2.0, -4.04), Color(0.30, 0.58, 0.72))
			_box(home, Vector3(1.48, 0.12, 0.16), Vector3(side * 3.1, 2.0, -4.12), trim)
			_box(home, Vector3(0.12, 1.28, 0.16), Vector3(side * 3.1, 2.0, -4.12), trim)
		_box(home, Vector3(2.3, 0.48, 1.2), Vector3(-2.7, 0.42, 1.9), Color(0.25, 0.20, 0.17) if i == 0 else Color(0.18, 0.22, 0.28))
		_box(home, Vector3(2.0, 0.18, 1.0), Vector3(2.5, 0.72, 1.6), Color(0.46, 0.34, 0.22))
		_box(home, Vector3(1.35, 0.18, 0.75), Vector3(2.5, 0.9, 1.6), Color(0.72, 0.66, 0.54))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 2.8, 0)
		lamp.light_color = Color(1.0, 0.78, 0.52) if i != 1 else Color(0.70, 0.82, 1.0)
		lamp.light_energy = 0.55
		lamp.omni_range = 8.0
		home.add_child(lamp)
		var sign := Label3D.new()
		sign.text = character_home_names[i]
		sign.position = Vector3(0, 4.2, -4.6)
		sign.font_size = 30
		sign.modulate = Color(1.0, 0.88, 0.55)
		home.add_child(sign)
		var marker_mesh := CylinderMesh.new()
		marker_mesh.top_radius = 1.5
		marker_mesh.bottom_radius = 1.5
		marker_mesh.height = 0.06
		var marker := MeshInstance3D.new()
		marker.mesh = marker_mesh
		marker.position = Vector3(0, 0.04, -7.0)
		marker.material_override = _mat(Color(0.12, 0.78, 0.55, 0.65))
		home.add_child(marker)


func _build_city_streetlight(world_position: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.position = world_position
	add_child(lamp)
	if city_streetlight_pole_mesh == null:
		city_streetlight_pole_mesh = CylinderMesh.new()
		city_streetlight_pole_mesh.top_radius = 0.07
		city_streetlight_pole_mesh.bottom_radius = 0.11
		city_streetlight_pole_mesh.height = 5.2
	var pole := MeshInstance3D.new()
	pole.mesh = city_streetlight_pole_mesh
	pole.position.y = 2.6
	pole.material_override = _city_material(Color(0.16, 0.18, 0.20))
	lamp.add_child(pole)
	_city_box(lamp, Vector3(0.95, 0.16, 0.42), Vector3(0.34, 5.12, 0.0), Color(0.90, 0.82, 0.56))


func _build_pedestrians() -> void:
	# Lightweight ambient pedestrians establish everyday city life on the sidewalks.
	var pedestrian_specs: Array[Dictionary] = [
		{"position": Vector3(-9.5, 0.0, -34.0), "axis": Vector3(0.0, 0.0, 1.0), "min": -43.0, "max": -19.0, "speed": 1.15, "jacket": Color(0.16, 0.38, 0.68), "pants": Color(0.12, 0.14, 0.18)},
		{"position": Vector3(9.5, 0.0, 34.0), "axis": Vector3(0.0, 0.0, -1.0), "min": 19.0, "max": 43.0, "speed": 1.05, "jacket": Color(0.62, 0.25, 0.16), "pants": Color(0.18, 0.19, 0.22)},
		{"position": Vector3(-34.0, 0.0, 9.5), "axis": Vector3(1.0, 0.0, 0.0), "min": -43.0, "max": -19.0, "speed": 1.0, "jacket": Color(0.18, 0.48, 0.32), "pants": Color(0.14, 0.16, 0.19)},
		{"position": Vector3(34.0, 0.0, -9.5), "axis": Vector3(-1.0, 0.0, 0.0), "min": 19.0, "max": 43.0, "speed": 1.2, "jacket": Color(0.58, 0.48, 0.20), "pants": Color(0.15, 0.17, 0.20)},
		{"position": Vector3(-57.5, 0.0, -34.0), "axis": Vector3(0.0, 0.0, 1.0), "min": -43.0, "max": -19.0, "speed": 0.95, "jacket": Color(0.48, 0.24, 0.50), "pants": Color(0.13, 0.15, 0.18)},
		{"position": Vector3(57.5, 0.0, 34.0), "axis": Vector3(0.0, 0.0, -1.0), "min": 19.0, "max": 43.0, "speed": 1.1, "jacket": Color(0.20, 0.46, 0.54), "pants": Color(0.16, 0.16, 0.17)}
	]
	for spec in pedestrian_specs:
		var pedestrian := CharacterBody3D.new()
		pedestrian.name = "City_Pedestrian"
		pedestrian.position = spec["position"]
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.28
		capsule.height = 1.75
		collision.shape = capsule
		collision.position.y = 0.88
		pedestrian.add_child(collision)
		add_child(pedestrian)
		_character_capsule(pedestrian, 0.25, 0.82, Vector3(0.0, 1.18, 0.0), spec["jacket"])
		_character_sphere(pedestrian, 0.18, Vector3(0.0, 1.76, 0.0), Color(0.72, 0.55, 0.40))
		var left_leg := _character_capsule(pedestrian, 0.115, 0.72, Vector3(-0.13, 0.48, 0.0), spec["pants"])
		var right_leg := _character_capsule(pedestrian, 0.115, 0.72, Vector3(0.13, 0.48, 0.0), spec["pants"])
		_character_capsule(pedestrian, 0.09, 0.62, Vector3(-0.31, 1.18, 0.0), spec["jacket"])
		_character_capsule(pedestrian, 0.09, 0.62, Vector3(0.31, 1.18, 0.0), spec["jacket"])
		pedestrians.append({
			"body": pedestrian,
			"axis": spec["axis"],
			"min": spec["min"],
			"max": spec["max"],
			"speed": spec["speed"],
			"left_leg": left_leg,
			"right_leg": right_leg
		})


func _move_pedestrians(delta: float) -> void:
	var walk_time := float(Time.get_ticks_msec()) * 0.001
	for pedestrian in pedestrians:
		var body := pedestrian["body"] as CharacterBody3D
		var axis: Vector3 = pedestrian["axis"]
		var coordinate := body.position.x if absf(axis.x) > 0.5 else body.position.z
		if coordinate >= float(pedestrian["max"]):
			if absf(axis.x) > 0.5:
				body.position.x = float(pedestrian["max"])
			else:
				body.position.z = float(pedestrian["max"])
			axis = -axis
		elif coordinate <= float(pedestrian["min"]):
			if absf(axis.x) > 0.5:
				body.position.x = float(pedestrian["min"])
			else:
				body.position.z = float(pedestrian["min"])
			axis = -axis
		pedestrian["axis"] = axis
		var walk_speed := float(pedestrian["speed"])
		body.velocity = axis * walk_speed
		body.move_and_slide()
		var phase := sin(walk_time * walk_speed * 5.0) * 0.42
		(pedestrian["left_leg"] as MeshInstance3D).rotation.x = phase
		(pedestrian["right_leg"] as MeshInstance3D).rotation.x = -phase


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
	player.position = character_world_positions[character_index]
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
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
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
	shop_interaction_button = _make_button("OPEN SHOP", 112)
	shop_interaction_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	shop_interaction_button.position = Vector2(-178, -220)
	shop_interaction_button.size = Vector2(156, 48)
	shop_interaction_button.custom_minimum_size = Vector2(156, 48)
	layer.add_child(shop_interaction_button)
	shop_interaction_button.visible = false
	shop_interaction_button.pressed.connect(_toggle_shop_door)
	shop_purchase_button = _make_button("BUY WATER $20", 156)
	shop_purchase_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	shop_purchase_button.position = Vector2(-178, -278)
	shop_purchase_button.size = Vector2(156, 48)
	shop_purchase_button.custom_minimum_size = Vector2(156, 48)
	layer.add_child(shop_purchase_button)
	shop_purchase_button.visible = false
	shop_purchase_button.pressed.connect(_buy_shop_water)
	shop_drink_button = _make_button("DRINK WATER", 156)
	shop_drink_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	shop_drink_button.position = Vector2(-178, -336)
	shop_drink_button.size = Vector2(156, 48)
	shop_drink_button.custom_minimum_size = Vector2(156, 48)
	layer.add_child(shop_drink_button)
	shop_drink_button.visible = false
	shop_drink_button.pressed.connect(_drink_shop_water)
	home_rest_button = _make_button("REST / SAVE", 156)
	home_rest_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	home_rest_button.position = Vector2(-178, -394)
	home_rest_button.size = Vector2(156, 48)
	home_rest_button.custom_minimum_size = Vector2(156, 48)
	layer.add_child(home_rest_button)
	home_rest_button.visible = false
	home_rest_button.pressed.connect(_rest_at_home)
	on_foot_buttons = [move_joystick, run_button, jump_button]
	mission_label = Label.new()
	mission_label.text = "FREE ROAM  •  %s's Dhaka" % character_names[character_index]
	mission_label.position = Vector2(12, 38)
	mission_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(mission_label)
	status_label = Label.new()
	status_label.text = "DHAKA VELOCITY  •  Walk to the red car and tap ENTER"
	status_label.position = Vector2(12, 12)
	status_label.add_theme_font_size_override("font_size", 17)
	layer.add_child(status_label)
	wallet_label = Label.new()
	wallet_label.text = _get_wallet_text()
	wallet_label.position = Vector2(12, 62)
	wallet_label.add_theme_font_size_override("font_size", 16)
	wallet_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
	layer.add_child(wallet_label)
	stamina_label = Label.new()
	stamina_label.text = "STAMINA  100%"
	stamina_label.position = Vector2(12, 86)
	stamina_label.add_theme_font_size_override("font_size", 15)
	stamina_label.add_theme_color_override("font_color", Color(0.48, 0.92, 0.68))
	layer.add_child(stamina_label)
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
	_build_pause_menu(layer)
	_build_life_menu(layer)


func _build_pause_menu(layer: CanvasLayer) -> void:
	var pause_button := _make_button("PAUSE", 104)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-116, 8)
	pause_button.size = Vector2(108, 40)
	pause_button.custom_minimum_size = Vector2(108, 40)
	layer.add_child(pause_button)
	pause_button.pressed.connect(_toggle_pause_menu)

	pause_menu_panel = PanelContainer.new()
	pause_menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_menu_panel.position = Vector2(-165, -145)
	pause_menu_panel.size = Vector2(330, 290)
	pause_menu_panel.custom_minimum_size = Vector2(330, 290)
	pause_menu_panel.visible = false
	pause_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(pause_menu_panel)

	var menu_content := VBoxContainer.new()
	menu_content.add_theme_constant_override("separation", 12)
	pause_menu_panel.add_child(menu_content)
	var title := Label.new()
	title.text = "GAME PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	menu_content.add_child(title)

	var resume_button := _make_button("RESUME GAME", 280)
	menu_content.add_child(resume_button)
	resume_button.pressed.connect(_toggle_pause_menu)

	cheat_codes_button = _make_button("CHEAT CODES: OFF", 280)
	menu_content.add_child(cheat_codes_button)
	cheat_codes_button.pressed.connect(_toggle_cheat_codes)

	var cheat_info := Label.new()
	cheat_info.text = "Allow or block cheat-code use in Story Mode."
	cheat_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cheat_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_content.add_child(cheat_info)

	day_night_button = _make_button("SKIP TO NIGHT", 280)
	menu_content.add_child(day_night_button)
	day_night_button.pressed.connect(_toggle_day_night)

	var close_button := _make_button("CLOSE MENU", 280)
	menu_content.add_child(close_button)
	close_button.pressed.connect(_toggle_pause_menu)
	_update_cheat_codes_button()


func _build_life_menu(layer: CanvasLayer) -> void:
	var life_button := _make_button("LIFE / MISSIONS", 148)
	life_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	life_button.position = Vector2(12, 112)
	life_button.size = Vector2(148, 42)
	life_button.custom_minimum_size = Vector2(148, 42)
	layer.add_child(life_button)
	life_button.pressed.connect(_toggle_life_menu)
	life_menu_panel = PanelContainer.new()
	life_menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	life_menu_panel.position = Vector2(-180, -170)
	life_menu_panel.size = Vector2(360, 340)
	life_menu_panel.custom_minimum_size = Vector2(360, 340)
	life_menu_panel.visible = false
	life_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(life_menu_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	life_menu_panel.add_child(content)
	var heading := Label.new()
	heading.text = "PERSONAL LIFE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	content.add_child(heading)
	life_character_label = Label.new()
	life_character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	life_character_label.add_theme_font_size_override("font_size", 18)
	content.add_child(life_character_label)
	life_profile_label = Label.new()
	life_profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	life_profile_label.custom_minimum_size.y = 48
	content.add_child(life_profile_label)
	life_mission_label = Label.new()
	life_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	life_mission_label.custom_minimum_size.y = 78
	content.add_child(life_mission_label)
	var home_button := _make_button("GO TO MY HOME", 300)
	content.add_child(home_button)
	home_button.pressed.connect(_go_to_character_home)
	life_track_button = _make_button("START PERSONAL MISSION", 300)
	content.add_child(life_track_button)
	life_track_button.pressed.connect(_toggle_personal_mission)
	var close_button := _make_button("CLOSE", 300)
	content.add_child(close_button)
	close_button.pressed.connect(_toggle_life_menu)
	_update_life_menu()
	personal_mission_marker = MeshInstance3D.new()
	personal_mission_marker.name = "PersonalMissionBeacon"
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 1.45
	beacon_mesh.bottom_radius = 1.45
	beacon_mesh.height = 0.12
	personal_mission_marker.mesh = beacon_mesh
	personal_mission_marker.material_override = _mat(Color(1.0, 0.72, 0.12))
	personal_mission_marker.visible = false
	add_child(personal_mission_marker)


func _toggle_life_menu() -> void:
	if driving:
		status_label.text = "Exit the vehicle before opening Personal Life"
		return
	life_menu_panel.visible = not life_menu_panel.visible
	_update_life_menu()


func _get_character_profile(index: int) -> String:
	match index:
		0:
			return "Family man • protects his neighbourhood • steady driver"
		1:
			return "Ambitious street racer • quick on foot • chasing a new start"
		_:
			return "Independent fixer • lives by his own rules • tough and patient"


func _get_personal_missions(index: int) -> Array[Dictionary]:
	match index:
		0:
			return [
				{"title": "A FAMILY FAVOUR", "detail": "Visit the local shop and collect a family parcel.", "target": Vector3(-15, 0, 15), "reward": 120},
				{"title": "NORTH SIDE DELIVERY", "detail": "Take the parcel to the north avenue meeting point.", "target": Vector3(0, 0, -96), "reward": 180},
				{"title": "BACK HOME", "detail": "Return home and check that your family is safe.", "target": character_home_positions[0] + Vector3(0, 0, -7.5), "reward": 250}
			]
		1:
			return [
				{"title": "RACER'S CALL", "detail": "Meet your racing contact at the central junction.", "target": Vector3(0, 0, 0), "reward": 140},
				{"title": "TEST RUN", "detail": "Drive or travel to the east avenue checkpoint.", "target": Vector3(96, 0, 0), "reward": 220},
				{"title": "COOL DOWN", "detail": "Head back to your city apartment.", "target": character_home_positions[1] + Vector3(0, 0, -7.5), "reward": 280}
			]
		_:
			return [
				{"title": "OLD DEBT", "detail": "Find the contact on the west side of the district.", "target": Vector3(-96, 0, 0), "reward": 160},
				{"title": "QUIET PICKUP", "detail": "Reach the south avenue and collect the hidden package.", "target": Vector3(0, 0, 96), "reward": 240},
				{"title": "SAFE HOUSE", "detail": "Return to your own house to finish the job.", "target": character_home_positions[2] + Vector3(0, 0, -7.5), "reward": 320}


func _update_life_menu() -> void:
	if not is_instance_valid(life_character_label):
		return
	var index := character_index
	var missions := _get_personal_missions(index)
	var step := character_mission_steps[index]
	life_character_label.text = character_names[index] + "  •  " + character_home_names[index]
	life_profile_label.text = _get_character_profile(index) + "\nPersonal funds: $%d" % cash_balance
	if step >= missions.size():
		life_mission_label.text = "STORY ARC COMPLETE  •  %d/3 personal missions finished" % character_mission_completed[index]
		life_track_button.text = "PERSONAL STORY COMPLETE"
		life_track_button.disabled = true
	else:
		var mission: Dictionary = missions[step]
		life_mission_label.text = "%s\n%s\nProgress: %d/3" % [mission["title"], mission["detail"], character_mission_completed[index]]
		life_track_button.disabled = false
		life_track_button.text = "STOP TRACKING" if character_mission_active[index] else "START PERSONAL MISSION"


func _rest_at_home() -> void:
	if driving:
		return
	if player.global_position.distance_to(character_home_positions[character_index]) >= 9.0:
		status_label.text = "Move inside your own home to rest"
		return
	stamina = 100.0
	if is_instance_valid(stamina_label):
		stamina_label.text = "STAMINA  100%"
	status_label.text = "HOME  •  Rested and progress saved"
	_save_game_settings()


func _go_to_character_home() -> void:
	if driving:
		status_label.text = "Exit the car before travelling home"
		return
	player.global_position = character_home_positions[character_index] + Vector3(0, 1.2, -7.5)
	player.velocity = Vector3.ZERO
	camera_yaw = 0.0
	status_label.text = "HOME  •  Arrived at %s" % character_home_names[character_index]
	life_menu_panel.visible = false
	_save_game_settings()


func _toggle_personal_mission() -> void:
	var index := character_index
	if character_mission_steps[index] >= 3:
		return
	character_mission_active[index] = not character_mission_active[index]
	if character_mission_active[index]:
		var mission: Dictionary = _get_personal_missions(index)[character_mission_steps[index]]
		var beacon_target: Vector3 = mission["target"]
		status_label.text = "PERSONAL MISSION  •  %s" % mission["title"]
		mission_label.text = "%s  •  %s" % [character_names[index], mission["detail"]]
		personal_mission_marker.global_position = Vector3(beacon_target.x, 0.18, beacon_target.z)
		personal_mission_marker.visible = true
	else:
		personal_mission_marker.visible = false
		status_label.text = "Personal mission tracking paused"
		mission_label.text = "FREE ROAM  •  %s's Dhaka" % character_names[index]
	_update_life_menu()
	_save_game_settings()


func _update_personal_life() -> void:
	var index := character_index
	if not character_mission_active[index] or character_mission_steps[index] >= 3:
		return
	var mission: Dictionary = _get_personal_missions(index)[character_mission_steps[index]]
	var target: Vector3 = mission["target"]
	if is_instance_valid(personal_mission_marker):
		personal_mission_marker.global_position = Vector3(target.x, 0.18, target.z)
		personal_mission_marker.visible = true
	# Personal story destinations can now be reached on foot or while driving.
	var mission_actor_position: Vector3 = car.global_position if driving and is_instance_valid(car) else player.global_position
	if mission_actor_position.distance_to(target) <= 5.5:
		var reward := int(mission["reward"])
		character_mission_steps[index] += 1
		character_mission_completed[index] += 1
		character_mission_active[index] = false
		if is_instance_valid(personal_mission_marker):
			personal_mission_marker.visible = false
		cash_balance += reward
		_refresh_wallet()
		status_label.text = "MISSION COMPLETE  •  %s  •  +$%d" % [mission["title"], reward]
		mission_label.text = "%s  •  PERSONAL STORY %d/3" % [character_names[index], character_mission_completed[index]]
		_update_life_menu()
		_save_game_settings()


func _toggle_pause_menu() -> void:
	var opening := not pause_menu_panel.visible
	pause_menu_panel.visible = opening
	get_tree().paused = opening
	if opening:
		steer_input = 0.0
		throttle_input = 0.0
		move_dir = Vector2.ZERO
		brake_pressed = false
		nitro_pressed = false
		drift_pressed = false
		if engine_audio and engine_audio.playing:
			engine_audio.stop()



func _toggle_day_night() -> void:
	time_of_day = 0.78 if time_of_day < 0.5 else 0.32
	_update_day_night_visuals()
	_update_day_night_button()
	_save_game_settings()
	if is_instance_valid(status_label):
		status_label.text = "WORLD TIME  •  %s" % _get_time_of_day_name()

func _get_time_of_day_name() -> String:
	if time_of_day < 0.22 or time_of_day >= 0.78:
		return "NIGHT"
	if time_of_day < 0.32 or time_of_day >= 0.68:
		return "SUNRISE / SUNSET"
	return "DAY"

func _update_day_night_button() -> void:
	if is_instance_valid(day_night_button):
		day_night_button.text = "SKIP TO NIGHT" if time_of_day < 0.5 else "SKIP TO DAY"

func _update_day_night_visuals() -> void:
	if not is_instance_valid(city_sun) or city_environment == null:
		return
	var angle := time_of_day * TAU - PI * 0.5
	var daylight := clampf(sin(angle) * 1.8 + 0.15, 0.06, 1.0)
	var night_factor := 1.0 - daylight
	city_sun.rotation_degrees = Vector3(-90.0 + time_of_day * 360.0, -30.0, 0.0)
	city_sun.light_energy = lerpf(0.12, 1.25, daylight)
	city_sun.light_color = Color(1.0, 0.72, 0.48).lerp(Color(1.0, 0.96, 0.86), daylight)
	city_environment.ambient_light_color = Color(0.12, 0.17, 0.30).lerp(Color(0.62, 0.68, 0.76), daylight)
	city_environment.ambient_light_energy = lerpf(0.28, 0.88, daylight)
	city_environment.ambient_light_sky_contribution = lerpf(0.12, 0.38, daylight)
	if is_instance_valid(day_night_button):
		_update_day_night_button()

func _toggle_cheat_codes() -> void:
	cheat_codes_enabled = not cheat_codes_enabled
	_update_cheat_codes_button()
	_save_game_settings()
	if is_instance_valid(status_label):
		status_label.text = "CHEAT CODES  •  %s" % ("ENABLED" if cheat_codes_enabled else "DISABLED")


func _update_cheat_codes_button() -> void:
	if is_instance_valid(cheat_codes_button):
		cheat_codes_button.text = "CHEAT CODES: ON" if cheat_codes_enabled else "CHEAT CODES: OFF"


func _get_wallet_text() -> String:
	return "WALLET  $%d    WATER  x%d" % [cash_balance, water_bottles]

func _refresh_wallet() -> void:
	if is_instance_valid(wallet_label):
		wallet_label.text = _get_wallet_text()

func _buy_shop_water() -> void:
	if cash_balance < 20:
			status_label.text = "SHOP  •  Not enough cash"
		return
	cash_balance -= 20
	water_bottles += 1
	_refresh_wallet()
	_save_game_settings()
	shop_purchase_button.text = "BUY WATER $20"
	status_label.text = "PURCHASED WATER  •  Bottles: %d  •  Cash: $%d" % [water_bottles, cash_balance]


func _drink_shop_water() -> void:
	if water_bottles <= 0:
		status_label.text = "INVENTORY  •  No water bottles"
		return
	water_bottles -= 1
	stamina = minf(100.0, stamina + 45.0)
	_refresh_wallet()
	stamina_label.text = "STAMINA  %d%%" % int(stamina)
	_save_game_settings()
	status_label.text = "DRANK WATER  •  Stamina restored"

func _toggle_shop_door() -> void:
	if not is_instance_valid(shop_door_pivot):
		return
	shop_door_open = not shop_door_open
	shop_door_pivot.rotation.y = -1.45 if shop_door_open else 0.0
	shop_interaction_button.text = "CLOSE SHOP" if shop_door_open else "OPEN SHOP"
	status_label.text = "SHOP OPEN  •  Walk inside" if shop_door_open else "SHOP CLOSED"


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
	character_world_positions[character_index] = player.global_position
	character_cash[character_index] = cash_balance
	character_index = (character_index + 1) % character_names.size()
	cash_balance = character_cash[character_index]
	_refresh_wallet()
	player.global_position = character_world_positions[character_index]
	player.velocity = Vector3.ZERO
	camera_yaw = 0.0
	for index in range(character_visuals.size()):
		character_visuals[index].visible = index == character_index
	character_button.text = "CHAR: " + character_names[character_index]
	status_label.text = "Switched to %s  •  Personal home and story updated" % character_names[character_index]
	mission_label.text = "FREE ROAM  •  %s's Dhaka" % character_names[character_index]
	_update_life_menu()
	if character_mission_active[character_index]:
		var active_mission: Dictionary = _get_personal_missions(character_index)[character_mission_steps[character_index]]
		var active_target: Vector3 = active_mission["target"]
		mission_label.text = "%s  •  %s" % [character_names[character_index], active_mission["detail"]]
		personal_mission_marker.global_position = Vector3(active_target.x, 0.18, active_target.z)
		personal_mission_marker.visible = true
	else:
		personal_mission_marker.visible = false
	_save_game_settings()

func _toggle_vehicle() -> void:
	# Ignore duplicate touch/click activations arriving within the same short input burst.
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_vehicle_toggle_msec < 450:
		return
	last_vehicle_toggle_msec = now_msec

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
		cash_balance += 100
		_refresh_wallet()
		_save_game_settings()
		mission_label.text = "CITY TOUR COMPLETE  •  3/3 checkpoints reached"
		status_label.text = "CITY TOUR COMPLETE  •  $100 reward added to wallet!"
		checkpoint.visible = false
		return
	checkpoint.global_position = mission_points[mission_index]
	checkpoint_tag.text = mission_names[mission_index]
	mission_label.text = "CITY TOUR %02d/03  •  Reach %s" % [mission_index + 1, mission_names[mission_index]]
	status_label.text = "Checkpoint %d/3 reached! Next destination marked." % mission_index

func _input(event: InputEvent) -> void:
	# Keep camera gestures inside the unobstructed central area. The right side contains
	# Garage/Zoom controls and the lower band contains driving, ENTER, and character controls.
	var viewport_size := get_viewport().get_visible_rect().size
	var camera_area_right := viewport_size.x - 190.0
	var camera_area_bottom := viewport_size.y - 190.0

	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < camera_area_right and event.position.y < camera_area_bottom:
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
					camera_zoom = clampf(camera_zoom - (new_distance - camera_pinch_distance) * 0.0055, 0.25, 2.5)
				camera_pinch_distance = new_distance
			elif camera_dragging and event.index == camera_touch_index:
				_rotate_orbit_camera(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			camera_dragging = event.position.x < camera_area_right and event.position.y < camera_area_bottom
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
	camera_zoom = clampf(camera_zoom - 0.18, 0.25, 2.5)

func _zoom_out() -> void:
	camera_zoom = clampf(camera_zoom + 0.18, 0.25, 2.5)

func _process(delta: float) -> void:
	if not driving and is_instance_valid(shop_door_pivot) and is_instance_valid(shop_interaction_button):
		var shop_distance := player.global_position.distance_to(shop_entrance_position)
		shop_interaction_button.visible = shop_distance < 4.8
		shop_interaction_button.text = "OPEN SHOP" if not shop_door_open else "CLOSE SHOP"
		var counter_distance := player.global_position.distance_to(shop_counter_position)
		shop_purchase_button.visible = shop_door_open and counter_distance < 3.0
	else:
		if is_instance_valid(shop_interaction_button):
			shop_interaction_button.visible = false
		if is_instance_valid(shop_purchase_button):
			shop_purchase_button.visible = false
	if is_instance_valid(shop_drink_button):
		shop_drink_button.visible = not driving and water_bottles > 0
	if is_instance_valid(home_rest_button):
		home_rest_button.visible = not driving and player.global_position.distance_to(character_home_positions[character_index]) < 9.0
	_update_personal_life()
	character_autosave_timer += delta
	if character_autosave_timer >= 15.0 and is_instance_valid(player):
		character_autosave_timer = 0.0
		character_world_positions[character_index] = player.global_position
		_save_game_settings()
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
	_move_pedestrians(delta)
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
		if run_pressed and move_dir.length() > 0.1 and stamina > 0.0:
			stamina = maxf(0.0, stamina - 22.0 * delta)
		else:
			stamina = minf(100.0, stamina + 12.0 * delta)
		if is_instance_valid(stamina_label):
			stamina_label.text = "STAMINA  %d%%" % int(stamina)
		var base_walk_speed := [4.5, 5.0, 4.2][character_index]
		var sprint_speed := [7.0, 8.0, 7.5][character_index]
		var walk_speed := sprint_speed if run_pressed and stamina > 0.0 else base_walk_speed
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