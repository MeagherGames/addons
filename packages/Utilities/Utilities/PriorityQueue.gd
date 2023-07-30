extends RefCounted
class_name PriorityQueue

class HeapItem extends RefCounted:
	var priority:float
	var value:Variant

	func _init(p, v):
		priority = p
		value = v

var heap:Array[HeapItem] = []
var is_max:bool = false

@warning_ignore("shadowed_variable")
func _init(is_max:bool = false):
	self.is_max = is_max

@warning_ignore("integer_division")
func parent(idx:int) -> int:
	return (idx - 1) / 2

func left_child(idx:int) -> int:
	return 2 * idx + 1

func right_child(idx:int) -> int:
	return 2 * idx + 2

func swap(idx1:int, idx2:int) -> void:
	var temp = heap[idx1]
	heap[idx1] = heap[idx2]
	heap[idx2] = temp

func push(priority:float, value:Variant) -> void:
	var item = HeapItem.new(priority, value)
	heap.append(item)
	var idx = heap.size() - 1
	if is_max:
		while idx != 0 and heap[parent(idx)].priority < heap[idx].priority:
			swap(parent(idx), idx)
			idx = parent(idx)
	else:
		while idx != 0 and heap[parent(idx)].priority > heap[idx].priority:
			swap(parent(idx), idx)
			idx = parent(idx)

func pop() -> Variant:
	if heap.size() == 0:
		return null
	elif heap.size() == 1:
		var root = heap[0]
		heap.remove_at(0)
		
		return root.value

	var root = heap[0]
	heap[0] = heap[heap.size() - 1]
	heap.remove_at(heap.size() - 1)
	heapify(0)

	return root.value

func peek() -> Variant:
	if heap.size() == 0:
		return null
	return heap[0].value

func peek_priority() -> float:
	if heap.size() == 0:
		return 0
	return heap[0].priority

func size() -> int:
	return heap.size()

func clear() -> void:
	heap.clear()

func is_empty() -> bool:
	return heap.is_empty()

func heapify(idx:int) -> void:
	var left = left_child(idx)
	var right = right_child(idx)
	var smallest_largest = idx

	if is_max:
		if left < heap.size() and heap[left].priority > heap[smallest_largest].priority:
			smallest_largest = left
		if right < heap.size() and heap[right].priority > heap[smallest_largest].priority:
			smallest_largest = right
	else:
		if left < heap.size() and heap[left].priority < heap[smallest_largest].priority:
			smallest_largest = left
		if right < heap.size() and heap[right].priority < heap[smallest_largest].priority:
			smallest_largest = right

	if smallest_largest != idx:
		swap(smallest_largest, idx)
		heapify(smallest_largest)
