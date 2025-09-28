@tool
extends RefCounted

const seperator = ",\t"
const JSON_GIT_PRETTY_FORMAT = "%ad,\t%s,\t%H,\t%an"
const JSON_GIT_DATE_FORMAT = "%a,\t%Y-%m-%dT%H:%M:%S"
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

static func get_commit_data() -> Dictionary:
	var output = []
	var exit_code = OS.execute("git", [
		"log",
		"-n", str(MAX_NUM_COMMITS),
		"--pretty=format:" + JSON_GIT_PRETTY_FORMAT,
		"--date=format:" + JSON_GIT_DATE_FORMAT
	], output, true)

	if exit_code != 0:
		printerr("Failed to get git log", output)
		return {}

	var commits: Array[Dictionary] = []
	var first_commit_date: Dictionary = {}
	var last_commit_date: Dictionary = {}
	for line in output:
		var parts = []
		if "\n" in line:
			# might be a single line with \n or multiple lines with \r\n
			parts += Array(line.split("\n"))
		else:
			parts.append(line)
		
		for part in parts:
			var commit_data = part.split(seperator)
			var commit = {
				"day": commit_data[0].strip_edges(),
				"date": commit_data[1].strip_edges(),
				"message": commit_data[2].strip_edges(),
				"sha": commit_data[3].strip_edges(),
				"author": commit_data[4].strip_edges(),
			}
			if commit:
				var timestamp = Time.get_unix_time_from_datetime_string(commit.date)
				commit.date = Time.get_datetime_dict_from_datetime_string(commit.date, true)
				commits.append(commit)
				if first_commit_date.is_empty() or timestamp < Time.get_unix_time_from_datetime_dict(first_commit_date):
					first_commit_date = commit.date
				if last_commit_date.is_empty() or timestamp > Time.get_unix_time_from_datetime_dict(last_commit_date):
					last_commit_date = commit.date

	return {
		"commits": commits,
		"first_commit_date": first_commit_date,
		"last_commit_date": last_commit_date,
	}
