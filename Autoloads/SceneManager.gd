extends Node

# Bacon and Games on YouTube: https://www.youtube.com/watch?v=2uYaoQj_6o0

const LEVEL_H:int = 144
const LEVEL_W:int = 240
const VERSION:String = "1.0"	# version number for SceneManager+

signal content_finished_loading(content)
signal zelda_content_finished_loading(content)
signal content_invalid(content_path:String)
signal content_failed_to_load(content_path:String)


var loading_screen:LoadingScreen
var _loading_screen_scene:PackedScene = preload("res://Menus/loading_screen.tscn")
var _transition:String
var _content_path:String
var _load_progress_timer:Timer

func _ready() -> void:
	content_invalid.connect(on_content_invalid)
	content_failed_to_load.connect(on_content_failed_to_load)
	content_finished_loading.connect(on_content_finished_loading)
	zelda_content_finished_loading.connect(on_zelda_content_finished_loading)

func load_new_scene(content_path:String, transition_type:String="fade_to_black") -> void:
	_transition = transition_type
	# add loading screen
	loading_screen = _loading_screen_scene.instantiate() as LoadingScreen
	get_tree().root.add_child(loading_screen)
	loading_screen.start_transition(transition_type)
	_load_content(content_path)
	
func load_level_zelda(content_path:String) -> void:
	_transition = "zelda"
	_load_content(content_path)
	
func _load_content(content_path:String) -> void:
	
	# zelda transition doesn't use a loading screen - personal preference
	if loading_screen != null:
		await loading_screen.transition_in_complete
		
	_content_path = content_path
	var loader = ResourceLoader.load_threaded_request(content_path)
	if not ResourceLoader.exists(content_path) or loader == null:
		content_invalid.emit(content_path)
		return 		
	
	_load_progress_timer = Timer.new()
	_load_progress_timer.wait_time = 0.1
	_load_progress_timer.timeout.connect(monitor_load_status)
	get_tree().root.add_child(_load_progress_timer)
	_load_progress_timer.start()

# checks in on loading status - this can also be done with a while loop, but I found that ran too fast
# and ended up skipping over the loading display. 
func monitor_load_status() -> void:
	var load_progress = []
	var load_status = ResourceLoader.load_threaded_get_status(_content_path, load_progress)

	match load_status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			content_invalid.emit(_content_path)
			_load_progress_timer.stop()
			return
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if loading_screen != null:
				loading_screen.update_bar(load_progress[0] * 100) # 0.1
		ResourceLoader.THREAD_LOAD_FAILED:
			content_failed_to_load.emit(_content_path)
			_load_progress_timer.stop()
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_load_progress_timer.stop()
			_load_progress_timer.queue_free()
			if _transition == "zelda":
				zelda_content_finished_loading.emit(ResourceLoader.load_threaded_get(_content_path).instantiate())
			else:
				content_finished_loading.emit(ResourceLoader.load_threaded_get(_content_path).instantiate())
			return # this last return isn't necessary but I like how the 3 dead ends stand out as similar

func on_content_failed_to_load(path:String) -> void:
	printerr("error: Failed to load resource: '%s'" % [path])	

func on_content_invalid(path:String) -> void:
	printerr("error: Cannot load resource: '%s'" % [path])
	
func on_content_finished_loading(content) -> void:
	var outgoing_scene = get_tree().current_scene
	
	# If we're moving between Levels, pass LevelDataHandoff here
	var incoming_data:LevelDataHandoff
	if  get_tree().current_scene is Level:
		incoming_data = get_tree().current_scene.data as LevelDataHandoff
	
	if content is Level:
		content.data = incoming_data

	# Remove the old scene
	outgoing_scene.queue_free()
	
	# Add and set the new scene to current
	get_tree().root.call_deferred("add_child",content)
	get_tree().set_deferred("current_scene",content)
	
	# probably not necssary since we split our content_finished_loading but it won't hurt to have an extra check
	if loading_screen != null:
		loading_screen.finish_transition()
		# e.g. will be skipped if we're loading a menu instead of a game level
		if content is Level:
			content.init_player_location()
		# wait for LoadingScreen's transition to finish playing
		await loading_screen.anim_player.animation_finished
		loading_screen = null
		# samesies^
		if content is Level:
			content.enter_level()
				
# load in a level, does NOT use the loading screen (which comes with tradeoffs)
func on_zelda_content_finished_loading(content) -> void:
	var outgoing_scene = get_tree().current_scene
	# If we're moving between Levels, pass LevelDataHandoff here
	
	var incoming_data:LevelDataHandoff
	if  get_tree().current_scene is Level:
		incoming_data = get_tree().current_scene.data as LevelDataHandoff
	
	if content is Level:
		content.data = incoming_data
		
	# some might do this with a camera, I did it by moving the content	
		
	# slide new level in
	content.position.x = incoming_data.move_dir.x * LEVEL_W
	content.position.y = incoming_data.move_dir.y * LEVEL_H
	var tween_in:Tween = get_tree().create_tween()
	tween_in.tween_property(content, "position", Vector2.ZERO, 1).set_trans(Tween.TRANS_SINE)
	
	# slide old level out
	var tween_out:Tween = get_tree().create_tween()
	var vector_off_screen:Vector2 = Vector2.ZERO
	vector_off_screen.x = -incoming_data.move_dir.x * LEVEL_W
	vector_off_screen.y = -incoming_data.move_dir.y * LEVEL_H
	tween_out.tween_property(outgoing_scene, "position", vector_off_screen, 1).set_trans(Tween.TRANS_SINE)
	
	# add new scene to the tree - (Note: could be loaded into a container instead)
	get_tree().root.call_deferred("add_child",content)
	
	# once the tweens are done, do some cleanup
	await tween_in.finished
	
	# skipped if not a Level
	if content is Level:
		content.init_player_location()
		content.enter_level()
	
	# Remove the old scene
	outgoing_scene.queue_free()
	# Add and set the new scene to current - so we can get its data obj next time we move between Levels
	get_tree().current_scene = content
