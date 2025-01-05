@tool
extends Node2D

const EDITOR_META_KEY := "__project_clear_color"
const PROJECT_SETTING := "rendering/environment/defaults/default_clear_color"

@export_color_no_alpha var color:Color = Color.BLACK : set = _set_color

func _set_color(value:Color) -> void:
    color = value
    _unset()
    if is_visible_in_tree():
        if Engine.is_editor_hint():
            set_meta(
                EDITOR_META_KEY,
                ProjectSettings.get_setting(PROJECT_SETTING, color)
            )
            ProjectSettings.set_setting(PROJECT_SETTING, value)
        RenderingServer.set_default_clear_color(value)

func _unset() -> void:
    if Engine.is_editor_hint() and has_meta(EDITOR_META_KEY):
        var prev_color = get_meta(EDITOR_META_KEY, color)
        ProjectSettings.set_setting(PROJECT_SETTING, prev_color)
        remove_meta(EDITOR_META_KEY)
        
    var project_clear_color = ProjectSettings.get_setting(PROJECT_SETTING, color)
    RenderingServer.set_default_clear_color(project_clear_color)

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_ENTER_TREE, NOTIFICATION_ENTER_CANVAS, NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_EDITOR_POST_SAVE:
            if is_visible_in_tree(): _set_color(color)
            else: _unset()
        NOTIFICATION_EXIT_TREE, NOTIFICATION_EXIT_CANVAS, NOTIFICATION_EDITOR_PRE_SAVE:
            _unset()
        _:
            pass
    

