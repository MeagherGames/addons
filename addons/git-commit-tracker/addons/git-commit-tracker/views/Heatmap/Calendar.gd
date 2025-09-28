@tool
extends RichTextLabel

# ascii dots for if you have committed on that day
# small white dot for no commits
const EMOJIS = {
	no_commit = "•",
	has_commit = "🔸",
	streak = "[color=orange]🔥[/color]",
	top_streak = "[wave][color=red]❤️‍🔥[/color][/wave]"
}
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

class CalendarDay extends RefCounted:
	var date: Dictionary
	var timestamp: int = -1
	var commits: Array[Dictionary] = []
	var messages: Array = []
	var is_streak: bool = false
	var is_largest_streak: bool = false

	func _init(date: Dictionary) -> void:
		self.date = date
		self.timestamp = Time.get_unix_time_from_datetime_dict(date)

	func add_commit(commit: Dictionary) -> void:
		commits.append(commit)
		messages.append(
			"[%s] %s: %s" % [
				Time.get_datetime_string_from_datetime_dict(commit.date, true),
				commit.author,
				commit.message
			]
		)

class CalendarWeek extends RefCounted:
	var date: Dictionary
	var days: Array[CalendarDay] = []
	var first_week_of_the_month: bool = false
	var month_name: String = ""

	func _init(date: Dictionary) -> void:
		self.date = date
		for i in range(7):
			var timestamp = Time.get_unix_time_from_datetime_dict(date) + i * 86400
			var day_date = Time.get_date_dict_from_unix_time(timestamp)
			if day_date.day == 1:
				first_week_of_the_month = true
				month_name = MONTHS[day_date.month - 1]
			days.append(CalendarDay.new(day_date))

	func add_commit(commit: Dictionary) -> void:
		var weekday = commit.date.weekday
		var day: CalendarDay = days[weekday]
		day.add_commit(commit)

class CalendarData extends RefCounted:
	var weeks: Array[CalendarWeek] = []

	func _init(first_date: Dictionary = {}, last_date: Dictionary = {}) -> void:
		if not first_date.is_empty() and not last_date.is_empty():
			# fill weeks between first_date and last_date
			var end_week = get_week_of_year(last_date)
			var current_week = get_week_of_year(first_date)
			var current_timestamp = Time.get_unix_time_from_datetime_dict(first_date) - first_date.weekday * 86400
			var current_date = Time.get_date_dict_from_unix_time(current_timestamp)
			while current_week.year <= end_week.year and current_week.week <= end_week.week:
				var week = CalendarWeek.new(current_date.duplicate())
				weeks.append(week)
				var timestamp = Time.get_unix_time_from_datetime_dict(current_date) + 7 * 86400
				current_date = Time.get_date_dict_from_unix_time(timestamp)

				current_week = get_week_of_year(current_date)

	func add_commit(commit: Dictionary) -> void:
		var week_of_year = get_week_of_year(commit.date)
		# find or create the week, place the week in the correct order
		var week: CalendarWeek = null
		for w in weeks:
			var other_week_of_year = get_week_of_year(w.date)
			if week_of_year.week == other_week_of_year.week and week_of_year.year == other_week_of_year.year:
				week = w
				break
		if week == null:
			var start_of_week = Time.get_date_dict_from_unix_time(
				Time.get_unix_time_from_datetime_dict(commit.date) - commit.date.weekday * 86400
			)
			week = CalendarWeek.new(start_of_week)
			weeks.append(week)
		week.add_commit(commit)

	func sort() -> void:
		weeks.sort_custom(_sort_weeks)

	func _sort_weeks(week_a: CalendarWeek, week_b: CalendarWeek) -> bool:
		var a = get_week_of_year(week_a.date)
		var b = get_week_of_year(week_b.date)
		if a.year == b.year:
			return a.week < b.week
		return a.year < b.year
	
	static func get_week_of_year(datetime: Dictionary) -> Dictionary[String, int]:
		var DAYS_IN_MONTHS = get_days_in_months(datetime.year)
		var start_day_of_year = get_start_day_of_year(datetime.year)
		var day_of_year = datetime.day
		for i in range(datetime.month - 1):
			day_of_year += DAYS_IN_MONTHS[i]
		var week_of_year = ceil((day_of_year + start_day_of_year) / 7.0)
		var year = datetime.year
		if week_of_year > 52:
			week_of_year = 1
			year += 1
		return {
			"week": week_of_year,
			"month": datetime.month,
			"year": year
		}
	
	static func is_leap_year(year: int) -> bool:
		return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

	static func get_days_in_months(year: int) -> Array:
		var DAYS_IN_MONTHS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
		if is_leap_year(year):
			DAYS_IN_MONTHS[1] = 29
		return DAYS_IN_MONTHS

	static func get_start_day_of_year(year: int) -> int:
		# Zeller's Congruence algorithm to find the day of the week for January 1st
		var q = 1
		var m = 13 # January is treated as the 13th month of the previous year
		var K = (year - 1) % 100
		var J = (year - 1) / 100
		var h = (q + int((13 * (m + 1)) / 5) + K + int(K / 4) + int(J / 4) - 2 * J) % 7
		return ((h + 5) % 7) + 1 # Adjust to make Sunday = 0, Monday = 1, ..., Saturday = 6

class CalendarDayIterator extends RefCounted:
	var data: CalendarData
	var week_index: int = 0
	var day_index: int = 0

	func _init(data: CalendarData) -> void:
		self.data = data

	func should_continue() -> bool:
		return week_index < data.weeks.size()

	func _iter_init(_iter):
		week_index = 0
		day_index = 0
		return should_continue()
	
	func _iter_next(_iter):
		day_index += 1
		if day_index >= 7:
			day_index = 0
			week_index += 1
		return should_continue()
	
	func _iter_get(_iter):
		return data.weeks[week_index].days[day_index]

var data: CalendarData = null

func _sum(arr: Array[float]) -> float:
	var sum = 0
	for i in arr:
		sum += i
	return sum

func set_commit_data(commit_data: Dictionary) -> void:
	_process_commits(commit_data)
	_process_streaks(3)
	_update_calendar()
	pass

func _process_commits(commit_data: Dictionary):
	var current_date = Time.get_date_dict_from_system()
	var first_commit_date = commit_data.get("first_commit_date", current_date)
	var last_commit_date = commit_data.get("last_commit_date", current_date)

	# I don't think current_date can ever be less than first_commit_date,
	if Time.get_unix_time_from_datetime_dict(current_date) < Time.get_unix_time_from_datetime_dict(first_commit_date):
		first_commit_date = current_date
	if Time.get_unix_time_from_datetime_dict(current_date) > Time.get_unix_time_from_datetime_dict(last_commit_date):
		last_commit_date = current_date
	
	data = CalendarData.new(first_commit_date, last_commit_date)
	for commit in commit_data.get("commits", []):
		data.add_commit(commit)
	data.sort()

func _process_streaks(minimum_streak_length: int) -> void:
	if data == null:
		return
	var iterator = CalendarDayIterator.new(data)
	var streak: Array[CalendarDay] = []
	var largest_streak: Array[CalendarDay] = []
	for day in iterator:
		if day.commits.size() > 0:
			streak.append(day)
		else:
			if streak.size() >= minimum_streak_length:
				for s in streak:
					s.is_streak = true
				if streak.size() > largest_streak.size():
					largest_streak = streak.duplicate()
			streak.clear()
	if streak.size() >= minimum_streak_length:
		for s in streak:
			s.is_streak = true
	for s in largest_streak:
		s.is_largest_streak = true

func _update_calendar():
	var lines = []
	var current_time = Time.get_date_dict_from_system()
	current_time.hour = 0
	current_time.minute = 0
	current_time.second = 0
	current_time = Time.get_unix_time_from_datetime_dict(current_time)

	lines.append("[table=8]")
	for day in ["", "S", "M", "T", "W", "T", "F", "S"]:
		lines.append("[cell]%s[/cell]" % day)

	for week in data.weeks:
		if week.first_week_of_the_month:
			var month_name = week.month_name
			if week.date.month == 1:
				month_name = "[u]%s[/u]" % month_name
			lines.append("[cell]%s[/cell]" % month_name)
		else:
			lines.append("[cell][/cell]")
		
		for day in week.days:
			var emoji = EMOJIS.no_commit
			if day.commits.size() > 0:
				emoji = EMOJIS.has_commit
			if day.is_streak:
				emoji = EMOJIS.streak
			if day.is_largest_streak:
				emoji = EMOJIS.top_streak

			var part = emoji

			if day.commits.size() > 0:
				part = "[hint=\"%s\"]%s[/hint]" % ["\n".join(day.messages), part]

			var cell_options = ""
			if day.timestamp == current_time:
				cell_options = "border=#fff4"
			if day.timestamp > current_time:
				part = "[color=#fff2]%s[/color]" % part
			
			if day.date.day == 1:
				part = "[cell bg=#8883 %s]%s[/cell]" % [cell_options, part]
			else:
				part = "[cell bg=#0000,#6661 %s]%s[/cell]" % [cell_options, part]
			
			lines.append(part)

	lines.append("[/table]")
	text = "\n".join(lines)