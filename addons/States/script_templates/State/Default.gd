extends State

# A State is a piece of logic that only runs when it is active.
# State uses the pause mode to control when the state is active.
# You can process with _process and _physics_process while the state is active.

func _ready() -> void:
    enabled.connect(_enabled) # When the state is entered or made active.
    disabled.connect(_disabled) # When the state is exited or made inactive.

func _enabled():
    pass

func _disabled():
    pass
