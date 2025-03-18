@tool
extends RichTextLabel

# ascii dots for if you have committed on that day
# small white dot for no commits
const EMOJIS = {
	false: "•",
	true: "🔸"
}
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var week_data: Dictionary = {}

func _sum(arr: Array[float]) -> float:
	var sum = 0
	for i in arr:
		sum += i
	return sum

func _is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

func _get_days_in_months(year: int) -> Array:
	var DAYS_IN_MONTHS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if _is_leap_year(year):
		DAYS_IN_MONTHS[1] = 29
	return DAYS_IN_MONTHS

func _get_start_day_of_year(year: int) -> int:
	# Zeller's Congruence algorithm to find the day of the week for January 1st
	var q = 1
	var m = 13 # January is treated as the 13th month of the previous year
	var K = (year - 1) % 100
	var J = (year - 1) / 100
	var h = (q + int((13 * (m + 1)) / 5) + K + int(K / 4) + int(J / 4) - 2 * J) % 7
	return ((h + 5) % 7) + 1 # Adjust to make Sunday = 0, Monday = 1, ..., Saturday = 6

func _get_week_of_year(datetime: Dictionary) -> int:
	var DAYS_IN_MONTHS = _get_days_in_months(datetime.year)
	var start_day_of_year = _get_start_day_of_year(datetime.year)
	var day_of_year = datetime.day
	for i in range(datetime.month - 1):
		day_of_year += DAYS_IN_MONTHS[i]
	var week_of_year = ceil((day_of_year + start_day_of_year) / 7.0)
	return week_of_year

func _get_date_from_week_weekday(week: int, weekday: int, year: int) -> Dictionary:
	var DAYS_IN_MONTHS = _get_days_in_months(year)
	var start_day_of_year = _get_start_day_of_year(year)
	var total_days_in_year = 0
	for days in DAYS_IN_MONTHS:
		total_days_in_year += days
	var day_of_year = (week - 1) * 7 + weekday - start_day_of_year

	# Handle transition to the previous year
	if day_of_year < 0:
		year -= 1
		DAYS_IN_MONTHS = _get_days_in_months(year)
		total_days_in_year = 0
		for days in DAYS_IN_MONTHS:
			total_days_in_year += days
		day_of_year += total_days_in_year

	# Handle transition to the next year
	if day_of_year >= total_days_in_year:
		day_of_year -= total_days_in_year
		year += 1
		DAYS_IN_MONTHS = _get_days_in_months(year)

	var month = 0
	while day_of_year >= DAYS_IN_MONTHS[month]:
		day_of_year -= DAYS_IN_MONTHS[month]
		month += 1

	return {"year": year, "month": month + 1, "day": day_of_year + 1}

func set_commits(commits: Array[Dictionary]):
	_process_commits(commits)
	_update_calendar()

func _fill_week(week: int, year: int):
	if not week_data.has(week):
		week_data[week] = []
		for i in range(7):
			var datetime = _get_date_from_week_weekday(week, i, year)
			week_data[week].append({
				"week": week,
				"weekday": i,
				"day": datetime.day,
				"month": datetime.month,
				"timestamp": Time.get_unix_time_from_datetime_string("%d-%d-%d" % [datetime.year, datetime.month, datetime.day]),
				"commits": 0,
				"is_streak": false,
				"messages": []
			})

func _process_commits(commits: Array[Dictionary]):
	week_data.clear()
	
	var last_week = -1
	for commit in commits:
		var week = _get_week_of_year(commit.date)
		if last_week == -1:
			last_week = week
		for i in range(last_week, week + 1):
			_fill_week(i, commit.date.year)
		last_week = week

		var weekday = commit.date.weekday
		var activity = week_data[week][weekday]
		activity.commits += 1
		activity.messages.append(
			"[%s] %s: %s" % [
				Time.get_datetime_string_from_datetime_dict(commit.date, true),
				commit.author,
				commit.message
			]
		)
		if commit.is_streak:
			activity.is_streak = true

func _update_calendar():
	var lines = []
	var values = week_data.values()
	var current_time = Time.get_date_dict_from_system()
	current_time.hour = 0
	current_time.minute = 0
	current_time.second = 0
	current_time = Time.get_unix_time_from_datetime_dict(current_time)

	lines.append("[table=8]")
	for day in ["", "S", "M", "T", "W", "T", "F", "S"]:
		lines.append("[cell]%s[/cell]" % day)

	var streak = [] # part = "[color=orange]🔥[/color]"
	var largest_streak = 0
	var largest_streak_start_index = INF
	var largest_streak_end_index = - INF
	for week in values:
		var month_index = lines.size()
		lines.append("[cell][/cell]")
		
		for day in week:
			var part = EMOJIS[day.commits > 0]

			if day.commits > 0:
				part = "[hint=\"%s\"]%s[/hint]" % ["\n".join(day.messages), part]

			if day.day == 1:
				lines[month_index] = "[cell]%s[/cell]" % MONTHS[day.month - 1]
			if day.timestamp == current_time:
				part = "[pulse]%s[/pulse]" % part
			if day.timestamp > current_time:
				part = "[color=#fff2]%s[/color]" % part
			
			if day.is_streak:
				streak.append([part, lines.size(), day.day == 1])
				lines.append("_")
			else:
				var streak_size = streak.size()
				var is_valid_streak = streak_size > 3
				var streak_start = INF
				var streak_end = - INF
				for streak_data in streak:
					var streak_part = streak_data[0]
					var streak_index = streak_data[1]
					if is_valid_streak:
						streak_start = min(streak_start, streak_index)
						streak_end = max(streak_end, streak_index)
						# replace the emoji with a streak emoji
						streak_part = streak_part.replace(EMOJIS[true], "[color=orange]🔥[/color]")
					lines[streak_index] = "[cell bg=#0000,#6661]%s[/cell]" % streak_part
				streak.clear()
				if day.day == 1:
					lines.append("[cell bg=#8883]%s[/cell]" % part)
				else:
					lines.append("[cell bg=#0000,#6661]%s[/cell]" % part)

				if is_finite(streak_start) and is_finite(streak_end) and streak_size >= largest_streak:
					largest_streak = streak_size
					largest_streak_start_index = streak_start
					largest_streak_end_index = streak_end
	
	if is_finite(largest_streak_start_index) and is_finite(largest_streak_end_index):
		for i in range(largest_streak_start_index, largest_streak_end_index + 1):
			# make them [wave] to make them stand out
			lines[i] = lines[i].replace("[color=orange]🔥[/color]", "[wave][color=red]❤️‍🔥[/color][/wave]")

	lines.append("[/table]")
	text = "\n".join(lines)