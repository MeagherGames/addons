@tool
extends MarginContainer

signal refresh()

func set_commit_data(commit_data: Dictionary):
	%WeekHeatmap.set_commits(commit_data.get("commits", []))
	%Calendar.set_commit_data(commit_data)
	%RefreshButton.disabled = false


func _on_calendar_button_toggled(toggled_on: bool) -> void:
	%Calendar.visible = toggled_on


func _on_refresh_button_pressed() -> void:
	%RefreshButton.disabled = true
	refresh.emit()
