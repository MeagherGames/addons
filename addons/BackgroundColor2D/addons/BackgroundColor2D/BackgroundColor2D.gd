@tool
extends Node2D

const EDITOR_META_KEY := "__project_clear_color"
const PROJECT_SETTING := "rendering/environment/defaults/default_clear_color"

static var _project_clear_color:Color
static var _color_is_overridden:bool = false

@export_color_no_alpha var color:Color = Color.BLACK : set = _set_color

func _set_color(value:Color) -> void:
    color = value
    _unset()
    if is_visible_in_tree():
        if Engine.is_editor_hint():
            if not _color_is_overridden:
                _project_clear_color = ProjectSettings.get_setting(PROJECT_SETTING, color)
                _color_is_overridden = true
            ProjectSettings.set_setting(PROJECT_SETTING, value)
        RenderingServer.set_default_clear_color(value)

func _unset() -> void:
    if Engine.is_editor_hint() and _color_is_overridden:
        ProjectSettings.set_setting(PROJECT_SETTING, _project_clear_color)
        _color_is_overridden = false
        
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
    
