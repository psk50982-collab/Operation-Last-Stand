extends CanvasLayer


func _on_health_updated(health: float):
	$Health.text = "%d%%" % roundi(health)

func _on_ammo_updated(current: int, reserve: int, capacity: int):
	$Ammo.text = "AMMO %02d / %02d    RESERVE %03d" % [current, capacity, reserve]

func _on_reload_state_updated(is_reloading: bool):
	$Reload.visible = is_reloading
