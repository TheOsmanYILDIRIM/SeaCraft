class_name SeaCraftManualBeehaveTree
extends BeehaveTree

# SeaCraft ticks Beehave explicitly from AiDecisionScheduler. Attaching the tree
# to the actor gives it normal Node ownership so tests/runtime do not leak orphan
# nodes, while this override avoids Beehave's optional runtime debugger hooks.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)
