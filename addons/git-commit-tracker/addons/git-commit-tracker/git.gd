@tool
extends RefCounted

const JSON_GIT_PRETTY_FORMAT = "{%ad,\\\"message\\\":\\\"%s\\\", \\\"sha\\\":\\\"%H\\\", \\\"author\\\":\\\"%an\\\"}"
const JSON_GIT_DATE_FORMAT = "\\\"day\\\":\\\"%a\\\",\\\"date\\\":\\\"%Y-%m-%dT%H:%M:%S\\\""
const MAX_NUM_COMMITS = 1000

const DAYS = {
	"Sun": 0,
	"Mon": 1,
	"Tue": 2,
	"Wed": 3,
	"Thu": 4,
	"Fri": 5,
	"Sat": 6
}

static func sort_by_datetime(a: Dictionary, b: Dictionary) -> bool:
	var timestam_a = Time.get_unix_time_from_datetime_dict(a.date)
	var timestam_b = Time.get_unix_time_from_datetime_dict(b.date)
	return timestam_a < timestam_b

static func get_commits() -> Array[Dictionary]:
	var output = []
	var exit_code = OS.execute("git", [
		"log",
		"-n", str(MAX_NUM_COMMITS),
		"--pretty=format:" + JSON_GIT_PRETTY_FORMAT,
		"--date=format:" + JSON_GIT_DATE_FORMAT
	], output, true)

	if exit_code != 0:
		printerr("Failed to get git log", output)
		return []

	var json: Array[Dictionary] = []
	for line in output:
		var parts = []
		if "\n" in line:
			# might be a single line with \n or multiple lines with \r\n
			parts += Array(line.split("\n"))
		else:
			parts.append(line)
		
		for part in parts:
			var commit = JSON.parse_string(part)
			if commit:
				commit.date = Time.get_datetime_dict_from_datetime_string(commit.date, true)
				json.append(commit)

	json.sort_custom(sort_by_datetime) # Likely already sorted this way, but just in case
	for i in json.size():
		var commit = json[i]
		commit.is_streak = false
		if i > 0:
			var prev_commit = json[i - 1]
			var one_day = 86400 # 1 day in seconds
			var commit_datetime = commit.date.duplicate()
			var prev_commit_datetime = prev_commit.date.duplicate()
			# remove the time part of the datetime
			commit_datetime.hour = 0
			commit_datetime.minute = 0
			commit_datetime.second = 0
			prev_commit_datetime.hour = 0
			prev_commit_datetime.minute = 0
			prev_commit_datetime.second = 0
			# if the distance between the two commits is 1 day, then it's a streak
			var diff = Time.get_unix_time_from_datetime_dict(commit_datetime) - Time.get_unix_time_from_datetime_dict(prev_commit_datetime)
			if is_zero_approx(diff):
				# if the commits are on the same day, then
				continue
			if diff <= one_day:
				prev_commit.is_streak = true
				commit.is_streak = true
	
	return json
