@tool
extends Node2D

const PROJECT_SETTING := "rendering/environment/defaults/default_clear_color"
const PREV_PROJECT_SETTING := "rendering/environment/defaults/fallback_clear_color"

@export_color_no_alpha var color: Color = Color.BLACK: set = _set_color

func _set_color(value: Color) -> void:
	color = value
	_unset()
	if is_visible_in_tree():
		if not ProjectSettings.has_setting(PREV_PROJECT_SETTING):
			var current_color = ProjectSettings.get_setting(PROJECT_SETTING, Color.BLACK)
			ProjectSettings.set_setting(PREV_PROJECT_SETTING, current_color)
		ProjectSettings.set_setting(PROJECT_SETTING, value)
		RenderingServer.set_default_clear_color(value)

func _unset() -> void:
	if ProjectSettings.has_setting(PREV_PROJECT_SETTING):
		var original_color = ProjectSettings.get_setting(PREV_PROJECT_SETTING)
		ProjectSettings.set_setting(PROJECT_SETTING, original_color)
		
	var project_clear_color = ProjectSettings.get_setting(PROJECT_SETTING, color)
	RenderingServer.set_default_clear_color(project_clear_color)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_ENTER_CANVAS, NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_EDITOR_POST_SAVE:
			if is_visible_in_tree(): _set_color(color)
			else: _unset()
		NOTIFICATION_EXIT_TREE, NOTIFICATION_EXIT_CANVAS, NOTIFICATION_EDITOR_PRE_SAVE:
			_unset()
