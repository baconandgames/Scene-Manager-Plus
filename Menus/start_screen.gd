class_name StartScreen extends Control

# Note, in a larger project I'd probably have an Autoload with all the level paths saved
# in a Dictionary so that if the paths change you only have to change them in one place
# When attempting to load a Scene, you can set up a helper function that checks the string
# against keys in your dictionary, if a key is found, return the path, otherwise just load
# the path given - which allows you to load from keys or full paths... but for this exmample I kept it simpler

# These 4 lines are not covered in the initial video. They've been added here just to make it easier for you
# to differentiate versions. I had not intended to provide updates so this feature was skipped in original code.
@onready var version_num: Label = %VersionNum
func _ready() -> void:
	version_num.text = "v%s" % SceneManager.VERSION
	print(">>> You are working with SceneManager+ version: v%s" % SceneManager.VERSION)

func _on_button_button_up() -> void:
	SceneManager.load_new_scene("res://Gameplay/Levels/level1.tscn","wipe_to_right")
	
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		SceneManager.load_new_scene("res://Gameplay/Levels/level1.tscn","wipe_to_right")
