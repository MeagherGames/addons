class_name WeightTable extends Resource

@export var data:Dictionary
@warning_ignore("shadowed_global_identifier")
@export var seed:int = -1 :
    set(value):
        seed = value
        if value < 0:
            _rng.randomize()
        else:
            _rng.seed = seed
        

var _rng:RandomNumberGenerator = RandomNumberGenerator.new()

func roll_value() -> Variant:
    var total_weight = 0
    for weight in data.values():
        total_weight += weight
    var random_weight = _rng.randf() * total_weight
    var weight_sum = 0
    for value in data:
        weight_sum += data[value]
        if random_weight < weight_sum:
            return value
    return null