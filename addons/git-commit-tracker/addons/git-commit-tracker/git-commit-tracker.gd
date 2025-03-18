@tool
extends EditorPlugin


const Git = preload("res://addons/git-commit-tracker/git.gd")
const HeatmapScene = preload("res://addons/git-commit-tracker/views/Heatmap/Heatmap.tscn")

const emoji_scale = ["❄️", "🔹", "🔸", "🔥"]

var display: Control

func _enter_tree():
	display = HeatmapScene.instantiate()
	display.connect("refresh", _refresh)
	add_control_to_container(CONTAINER_INSPECTOR_BOTTOM, display)
	_refresh()

func _exit_tree():
	remove_control_from_container(CONTAINER_INSPECTOR_BOTTOM, display)
	display.queue_free()

func _refresh():
	var commits = Git.get_commits()
	display.set_commits(commits)