tool
extends Node

signal loading_finished

const TIME_MAX = 150 # msec

var total_count: int
var current_count: int

var models_dict: Dictionary = {}
var files: Array = []
var loaders: Array = []
var current_loader: ResourceInteractiveLoader = null

var progress_group: Array


func _exit_tree() -> void:
	clear()


func _ready() -> void:
	set_process(false)
	progress_group = get_tree().get_nodes_in_group("3D2SS.ProgressBar")


func _process(_delta: float) -> void:
	if loaders.size() == 0:
		finish_loading()
		return

	var t = OS.get_ticks_msec()
	while OS.get_ticks_msec() < t + TIME_MAX:
		if current_loader != null:
			var err: int = current_loader.poll()
			if err == ERR_FILE_EOF: # Finished loading
				var resource: Resource = current_loader.get_resource()
				var model: Spatial
				if resource is PackedScene:
					model = resource.instance() as Spatial
				elif resource is Mesh:
					model = MeshInstance.new()
					model.mesh = resource
				models_dict[resource.resource_path] = model
				current_count += current_loader.get_stage_count()
				current_loader = null
			elif err == OK:
				var progress: float = float(current_count + current_loader.get_stage()) / float(total_count)
				update_progress(progress)
			else: # error during loading
				printerr("Error while loading model [%d]" % err)
				current_loader = null
		elif loaders.size() != 0:
			current_loader = loaders.pop_front()
		else:
			# Nothing to be done
			update_progress(1.0)
			break


func load_models(files_: PoolStringArray) -> void:
	files = files_
	current_count = 0
	total_count = 0
	for model_path in files:
		if models_dict.has(model_path):
			continue
		elif ResourceLoader.has_cached(model_path):
			models_dict[model_path] = (load(model_path) as PackedScene).instance()
		else:
			var loader: ResourceInteractiveLoader = ResourceLoader.load_interactive(model_path, "PackedScene")
			total_count += loader.get_stage_count()
			loaders.append(loader)
	set_process(true)


func finish_loading() -> void:
	set_process(false)
	update_progress(0.0)
	emit_signal("loading_finished")


func update_progress(value: float) -> void:
	for progress in progress_group:
		(progress as ProgressBar).value = value


func clear() -> void:
	for model_path in models_dict:
		models_dict[model_path].free()
	models_dict = {}


func select(id: int) -> void:
	var file: String = files[id]
	var model: Spatial = models_dict[file]
	for node in get_tree().get_nodes_in_group("3D2SS.ModelData"):
		node.show_model(model)
