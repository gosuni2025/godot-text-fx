extends Node

signal loaded(world: Node)
var main_scene := ""
@onready var loading: CanvasLayer = $LoadingScreen
var _loading := false
var _finishing := false

func _ready() -> void:
	main_scene = resolve_scene()
	loading.retry.pressed.connect(_begin_load)
	# Let the loading scene draw before requesting the world and its dependencies.
	_begin_load.call_deferred()

func _begin_load() -> void:
	if _loading or _finishing: return
	loading.retry.hide()
	loading.progress.show()
	loading.update_stage("resources", 0.0, "Loading scene resources...")
	var error := ResourceLoader.load_threaded_request(main_scene)
	if error != OK:
		loading.show_failure()
		return
	_loading = true

func _process(_delta: float) -> void:
	if not _loading: return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(main_scene, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				loading.update_stage("resources", float(progress[0]) * 0.65, "Loading scene resources...")
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading = false
			_finishing = true
			_enter_world()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading = false
			loading.show_failure()

func _enter_world() -> void:
	loading.update_stage("scene", 0.65, "Constructing the scene...")
	await _draw_loading()
	var packed := ResourceLoader.load_threaded_get(main_scene) as PackedScene
	if packed == null:
		_finishing = false
		loading.show_failure()
		return
	var world := packed.instantiate()
	configure_world(world)
	loading.update_stage("systems", 0.72, "Initializing game systems...")
	await _draw_loading()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	loading.update_stage("graphics", 0.80, "Preparing lighting and effects...")
	await _draw_loading()
	if await prepare_world(world) != OK:
		world.queue_free()
		get_tree().current_scene = self
		_finishing = false
		loading.show_failure()
		return
	loading.update_stage("frame", 0.99, "Displaying the first frame...")
	# Keep the cover through the world's first frame; never add an artificial delay.
	await _draw_loading()
	finish_world(world)
	loading.complete()
	loaded.emit(world)
	queue_free()

func _report_warmup(detail: Dictionary) -> void:
	loading.update_warmup(detail)

func _draw_loading() -> void:
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw

# Override these hooks in a game adapter. Scene loading/retry remains shared.
func resolve_scene() -> String:
	return preload("res://addons/game_base/project_config.gd").current().game_scene

func configure_world(_world: Node) -> void:
	pass

func prepare_world(world: Node) -> Error:
	var config = preload("res://addons/game_base/project_config.gd").current()
	if config.warmup_script.is_empty(): return OK
	var preparation = load(config.warmup_script)
	if preparation == null or not preparation.has_method("prepare"): return ERR_INVALID_DATA
	return await preparation.prepare(world, _report_warmup)

func finish_world(_world: Node) -> void:
	pass
