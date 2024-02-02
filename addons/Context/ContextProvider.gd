@tool
class_name ContextProvider extends Node

@export var value:Node :
	set(val): _context.value = val
	get: return _context.value if _context else null

var _context:Context = Context.new()

func _enter_tree():
	set_meta(Context.META_KEY, weakref(_context))
		
