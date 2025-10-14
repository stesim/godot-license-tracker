@tool
class_name PrepareShowcase
extends EditorScript


func _run() -> void:
	var window := EditorInterface.get_base_control().get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1648, 1098)
