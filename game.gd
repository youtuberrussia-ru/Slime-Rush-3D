extends Node3D

const LANE_WIDTH = 2.5
const SPEED_START = 12.0
const SAVE_PATH = "user://slime_rush.save"

var player: CharacterBody3D
var camera: Camera3D
var track: Node3D
var obstacles: Array[Node3D] = []
var coins: Array[Node3D] = []

var score := 0
var best_score := 0
var money := 0
var speed := SPEED_START
var lane := 1
var game_over := false
var jump_timer := 0.0
var spawn_timer := 0.0

var ui: CanvasLayer
var score_label: Label
var money_label: Label
var message_label: Label

var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	load_game()
	create_world()
	create_player()
	create_camera()
	create_ui()
	start_game()

func create_world():
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.75, 0.9)
	environment.ambient_light_energy = 0.8
	world.environment = environment
	add_child(world)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.3
	add_child(sun)

	track = Node3D.new()
	add_child(track)

	for i in range(30):
		var tile = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(7.5, 0.2, 5)
		tile.mesh = mesh
		tile.position = Vector3(0, -0.2, -i * 5)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.35, 0.19)
		tile.material_override = mat
		track.add_child(tile)

	for x in [-1.25, 1.25]:
		var line = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.045, 0.03, 150)
		line.mesh = mesh
		line.position = Vector3(x, -0.08, -70)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.9, 0.7)
		line.material_override = mat
		track.add_child(line)

func create_player():
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.65, 0)
	add_child(player)

	var body = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.65
	mesh.height = 1.3
	body.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.95, 0.35)
	mat.roughness = 0.3
	body.material_override = mat
	player.add_child(body)

	var face = MeshInstance3D.new()
	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.09
	eye_mesh.height = 0.18
	face.mesh = eye_mesh
	face.position = Vector3(-0.22, 0.15, -0.55)
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color.BLACK
	face.material_override = eye_mat
	player.add_child(face)

func create_camera():
	camera = Camera3D.new()
	camera.position = Vector3(0, 5, 9)
	camera.rotation_degrees = Vector3(-20, 0, 0)
	camera.current = true
	add_child(camera)

func create_ui():
	ui = CanvasLayer.new()
	add_child(ui)

	score_label = Label.new()
	score_label.position = Vector2(25, 25)
	score_label.add_theme_font_size_override("font_size", 30)
	ui.add_child(score_label)

	money_label = Label.new()
	money_label.position = Vector2(25, 70)
	money_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(money_label)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 32)
	ui.add_child(message_label)

	var left = make_button("◀", Vector2(25, 1080))
	left.pressed.connect(func(): change_lane(-1))

	var right = make_button("▶", Vector2(570, 1080))
	right.pressed.connect(func(): change_lane(1))

	var jump = make_button("JUMP", Vector2(270, 1080))
	jump.pressed.connect(jump_player)

func make_button(text_value: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text_value
	b.position = pos
	b.size = Vector2(120, 90)
	b.add_theme_font_size_override("font_size", 25)
	ui.add_child(b)
	return b

func start_game():
	score = 0
	speed = SPEED_START
	game_over = false
	spawn_timer = 1.0
	message_label.text = ""
	for item in obstacles:
		item.queue_free()
	for item in coins:
		item.queue_free()
	obstacles.clear()
	coins.clear()
	player.position = Vector3(0, 0.65, 0)
	lane = 1

func change_lane(direction: int):
	if game_over:
		return
	lane = clampi(lane + direction, 0, 2)

func jump_player():
	if game_over:
		return
	if player.position.y < 0.8:
		player.velocity.y = 9.0

func _process(delta):
	if game_over:
		return

	speed += delta * 0.08
	score += int(delta * 10)
	score_label.text = "SCORE: " + str(score)
	money_label.text = "COINS: " + str(money)

	var target_x = (lane - 1) * LANE_WIDTH
	player.position.x = lerpf(player.position.x, target_x, delta * 10)

	if player.position.y > 0.65 or player.velocity.y > 0:
		player.velocity.y -= 22.0 * delta
		player.position.y += player.velocity.y * delta
		if player.position.y < 0.65:
			player.position.y = 0.65
			player.velocity.y = 0

	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_obstacle()
		spawn_timer = rng.randf_range(0.8, 1.4)

	move_objects(delta)
	check_collisions()

func spawn_obstacle():
	var obstacle = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.3, 1.3, 1.3)
	obstacle.mesh = mesh
	obstacle.position = Vector3(
		(rng.randi_range(0, 2) - 1) * LANE_WIDTH,
		0.65,
		-65
	)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.15, 0.12)
	obstacle.material_override = mat
	add_child(obstacle)
	obstacles.append(obstacle)

	if rng.randf() > 0.35:
		var coin = MeshInstance3D.new()
		var coin_mesh = CylinderMesh.new()
		coin_mesh.top_radius = 0.35
		coin_mesh.bottom_radius = 0.35
		coin_mesh.height = 0.12
		coin.mesh = coin_mesh
		coin.position = Vector3(
			(rng.randi_range(0, 2) - 1) * LANE_WIDTH,
			1.1,
			-65
		)
		var gold = StandardMaterial3D.new()
		gold.albedo_color = Color(1, 0.75, 0.05)
		gold.metallic = 0.7
		coin.material_override = gold
		add_child(coin)
		coins.append(coin)

func move_objects(delta):
	for item in obstacles:
		item.position.z += speed * delta
	for item in coins:
		item.position.z += speed * delta
		item.rotation.y += delta * 4

func check_collisions():
	for item in obstacles:
		if item.position.distance_to(player.position) < 1.15:
			end_game()
			return

	for item in coins:
		if item.position.distance_to(player.position) < 1.2:
			money += 1
			item.queue_free()
			coins.erase(item)
			break

func end_game():
	game_over = true
	best_score = maxi(best_score, score)
	save_game()
	message_label.text = "GAME OVER\nScore: " + str(score) + "\nBest: " + str(best_score)

	var restart = make_button("RESTART", Vector2(270, 900))
	restart.pressed.connect(func():
		restart.queue_free()
		start_game()
	)

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({
			"best": best_score,
			"money": money
		})

func load_game():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			best_score = data.get("best", 0)
			money = data.get("money", 0)
