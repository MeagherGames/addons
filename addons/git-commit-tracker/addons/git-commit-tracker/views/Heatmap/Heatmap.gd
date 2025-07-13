@tool
extends MarginContainer

signal refresh()

func set_commits(commits: Array[Dictionary]):
	%WeekHeatmap.set_commits(commits)
	%Calendar.set_commits(commits)
	%RefreshButton.disabled = false


func _on_calendar_button_toggled(toggled_on: bool) -> void:
	%Calendar.visible = toggled_on


func _on_refresh_button_pressed() -> void:
	%RefreshButton.disabled = true
	refresh.emit()
