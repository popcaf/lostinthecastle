extends CanvasLayer


@onready var bar: ProgressBar = $Margin/VBox/HBox/HealthBar
@onready var label: Label = $Margin/VBox/HBox/Label

var player: Node = null


func _ready() -> void:
	call_deferred("_bind_player")


func _bind_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_signal("hitpoints_changed"):
		player.hitpoints_changed.connect(_on_hitpoints_changed)
	if "max_hitpoints" in player and "hitpoints" in player:
		_on_hitpoints_changed(player.hitpoints, player.max_hitpoints)


func _on_hitpoints_changed(current: int, max_value: int) -> void:
	bar.max_value = max_value
	bar.value = current
	label.text = "%d / %d" % [max(current, 0), max_value]
