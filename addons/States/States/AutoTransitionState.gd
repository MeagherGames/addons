class_name AutoTransitionState extends State

@export_group("Auto Transition", "auto_transition_")
@export var auto_transition_context:Node = null
@export var auto_transition_expression:String = "" :
    set(value):
        auto_transition_expression = value
        _update_expression()

var _expression:Expression = Expression.new()
var _expression_is_valid:bool = false
var _is_active:bool = false

func enter():
    _is_active = true

func exit():
    _is_active = false

func _enable():
	if get_parent() is State:
		set_physics_process(false)
	else:
		set_physics_process(true)
		_internal_enter()

func _disable():
	set_physics_process(false)
	_internal_exit()

func _update_expression():
    if _expression.parse(auto_transition_expression) != OK:
        _expression_is_valid = false
        printerr(_expression.get_error_text())
        return
    _expression_is_valid = true
    
func _auto_transition():
    if (
        _is_active or
        not _expression_is_valid or
        not is_inside_tree() or
        auto_transition_context == null or
        not auto_transition_context.is_inside_tree() or
        auto_transition_expression == ""
    ):
        return
    
    if _expression.execute([], auto_transition_context):
        request_transition()

func _ready():
    super._ready()
    _auto_transition()

func _process(delta:float):
    _auto_transition()
    if _is_active:
        _internal_update(delta)