class_name AutoTransitionState extends State

enum UpdateMode {
	IDLE,
	PHYSICS,
	MANUAL
}

@export var context:Node = null
@export var expression:String = "" :
	set(value):
		expression = value
		_update_expression()
@export var update_mode:UpdateMode = UpdateMode.IDLE

var _expression:Expression = Expression.new()
var _expression_is_valid:bool = false

func _set_enabled(value:bool):
	if is_enabled == value:
		return
	
	is_enabled = value
	process_mode = PROCESS_MODE_ALWAYS
	for child in get_children():
		if child is State:
			child.is_enabled = value

func _update_expression():
	if _expression.parse(expression) != OK:
		_expression_is_valid = false
		printerr(_expression.get_error_text())
		return
	_expression_is_valid = true
	
func test_transition():
	if (
		not _expression_is_valid or
		not is_inside_tree() or
		context == null or
		not context.is_inside_tree() or
		expression == ""
	):
		return
	if context and context.is_node_ready():
		if _expression.execute([], context):
			request_transition()

func _on_child_added(child):
	if child is State:
		child.is_enabled = is_active()

func _notification(what):
	if what == NOTIFICATION_READY:
		test_transition()
		if update_mode == UpdateMode.IDLE:
			set_process(true)
		elif update_mode == UpdateMode.PHYSICS:
			set_physics_process(true)
	
	if what == NOTIFICATION_ENTER_TREE:
		child_entered_tree.connect(_on_child_added)
	if what == NOTIFICATION_EXIT_TREE:
		child_entered_tree.disconnect(_on_child_added)

	if (
		(what == NOTIFICATION_PROCESS and update_mode == UpdateMode.IDLE) or
		(what == NOTIFICATION_PHYSICS_PROCESS and update_mode == UpdateMode.PHYSICS)
	):
		test_transition()
