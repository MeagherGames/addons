class_name Context extends RefCounted

const META_KEY = "context_cache"

var value: Variant = null

@warning_ignore("shadowed_variable")
func _init(value:Variant = null):
	self.value = value

static func _set_cached_context(scope:Node, context:Context) -> void:
	scope.set_meta(META_KEY, weakref(context))
	# if scope or any of it's ancestors are exiting, remove the cached context
	scope.tree_exiting.connect(func(): scope.remove_meta(META_KEY), CONNECT_ONE_SHOT)


static func _get_cached_context(scope:Node) -> Context:
	if scope.has_meta(META_KEY):
		var ref:WeakRef = scope.get_meta(META_KEY)
		if ref and ref.get_ref():
			return ref.get_ref()
		else:
			scope.remove_meta(META_KEY)
	return null


static func _find_context(scope:Node) -> Context:
	var node = scope
	while node != null:
		if node.has_meta(META_KEY):
			# if this node has a cached context, use it
			# otherwise continue searching up the tree
			var context:Context = _get_cached_context(node)
			if context != null:
				return context
		node = node.get_parent()
	return null


static func getValue(scope:Node) -> Variant:
	var cached_context:Context = _get_cached_context(scope)
	if cached_context != null:
		return cached_context.value

	var context:Context = _find_context(scope)
	if context != null:
		_set_cached_context(scope, context)
		return context.value
	return null


class Binding extends RefCounted:
	var _ref:WeakRef = weakref(null)
	var value:Variant = null :
		get:
			var scope:Node = _ref.get_ref()
			if scope:
				return Context.getValue(scope)
			return null

	@warning_ignore("shadowed_variable")
	func _init(scope:Node = null):
		_ref = weakref(scope)


static func bind(scope:Node) -> Binding:
	# Convenience function to create a Binding
	return Binding.new(scope)