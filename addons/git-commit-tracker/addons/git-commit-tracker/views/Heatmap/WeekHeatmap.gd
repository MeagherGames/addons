@tool
extends HBoxContainer

const EMOJIS = ["❄️", "🔹", "🔸", "🔥"]
const INFO_EMOJI = "📅"
const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

var day_commits = []
var current_day_index: int

@onready var label: RichTextLabel = $Days

func set_commits(commits: Array[Dictionary]):
	_process_commits(commits)
	_update_heatmap()

func _process_commits(commits: Array[Dictionary]):
	current_day_index = Time.get_datetime_dict_from_system().weekday
	day_commits.clear()
	day_commits.resize(DAYS.size())
	for i in DAYS.size():
		day_commits[i] = []
	
	for commit in commits:
		var day_index = DAYS.find(commit.day)
		if day_index == -1:
			continue
		day_commits[day_index].append(commit)

func _update_heatmap():
	var heatmap = _generate_heatmap_text()
	label.text = heatmap

func _generate_heatmap_text():
	var sorted_commits = []
	for commits in day_commits:
		sorted_commits.append(commits.size())
	sorted_commits.sort()

	var scale_size = EMOJIS.size() - 1
	var heatmap_parts = []

	heatmap_parts.append("[table=7]")

	for day_index in DAYS.size():
		var commits = day_commits[day_index]
		var commit_count = commits.size()
		var messages = [
			"%d commits" % commits.size()
		]

		var commit_rank = sorted_commits.find(commit_count)
		var commit_score = float(commit_rank) / (DAYS.size() - 1)

		var intensity: int = floor(commit_score * scale_size)
		var part = "%s%s" % [DAYS[day_index][0], EMOJIS[intensity]]
		part = "[hint=\"%s\"]%s[/hint]" % ["\n".join(messages), part]
		if day_index == current_day_index:
			part = "[cell bg=#8883]%s[/cell]" % part
		else:
			part = "[cell]%s[/cell]" % part
		
		heatmap_parts.append(part)

	heatmap_parts.append("[/table]")

	return " ".join(heatmap_parts)