class_name Context extends RefCounted

const META_KEY = "context_cache"

var value: Variant = null
var _name:String = ""

@warning_ignore("shadowed_variable")
func _init(name:String = "", value:Variant = null):
	_name = name
	self.value = value


static func _set_cached_context(scope:Node, context:Context) -> void:
	if not scope.has_meta(META_KEY):
		scope.set_meta(META_KEY, {})
	var contexts = scope.get_meta(META_KEY) as Dictionary
	contexts[context._name] = weakref(context)
	# if scope or any of it's ancestors are exiting, remove the cached context
	scope.tree_exiting.connect(func(): _remove_cached_context(scope, context._name), CONNECT_ONE_SHOT)


@warning_ignore("shadowed_variable")
static func _remove_cached_context(scope:Node, name:String) -> void:
	if scope.has_meta(META_KEY):
		var contexts = scope.get_meta(META_KEY) as Dictionary
		contexts.erase(name)
		if contexts.is_empty():
			scope.remove_meta(META_KEY)


@warning_ignore("shadowed_variable")
static func _get_cached_context(scope:Node, name:String) -> Context:
	if scope.has_meta(META_KEY):
		var contexts = scope.get_meta(META_KEY) as Dictionary
		var ref:WeakRef = contexts.get(name)
		if ref and ref.get_ref():
			return ref.get_ref()
		else:
			_remove_cached_context(scope, name)
	return null


@warning_ignore("shadowed_variable")
static func _find_context(scope:Node, name:String) -> Context:
	var node = scope
	while node != null:
		if node.has_meta(META_KEY):
			# if this node has a cached context, use it
			# otherwise continue searching up the tree
			var context:Context = _get_cached_context(node, name)
			if context != null:
				return context
		node = node.get_parent()
	return null


@warning_ignore("shadowed_variable")
static func getValue(scope:Node, name:String) -> Variant:
	var cached_context:Context = _get_cached_context(scope, name)
	if cached_context != null:
		return cached_context.value

	var context:Context = _find_context(scope, name)
	if context != null:
		_set_cached_context(scope, context)
		return context.value
	return null


class Binding extends RefCounted:
	var _ref:WeakRef = weakref(null)
	var _name:String = ""
	var value:Variant = null :
		get:
			var scope:Node = _ref.get_ref()
			if scope:
				return Context.getValue(scope, _name)
			return null

	@warning_ignore("shadowed_variable")
	func _init(scope:Node = null, name:String = ""):
		_name = name
		_ref = weakref(scope)

	func is_valid() -> bool:
		var scope:Node = _ref.get_ref()
		if scope == null:
			return false
		if Context._find_context(scope, _name) == null:
			return false
		return true


@warning_ignore("shadowed_variable")
static func use(scope:Node, name:String) -> Binding:
	# Convenience function to create a Binding
	return Binding.new(scope, name)

@warning_ignore("shadowed_variable")
func attach(scope:Node) -> void:
	Context._set_cached_context(scope, self)
