extends Node
## Reads progression from its existing owners and records completed mentor visits.

const MENTORS: Array[StringName] = [&"commander", &"engineer", &"botanist"]


func _ready() -> void:
	EventBus.dialogue_ended.connect(_record_mentor)


func _record_mentor(id: StringName) -> void:
	if id in MENTORS:
		GameState.set_flag(StringName("mentor_" + String(id)))


func entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var d := MissionDirector
	_add(list, "Create your astronaut", "Choose a name and suit in the recruitment screen.", GameState.get_flag(&"astronaut_created"))
	if not GameState.get_flag(&"astronaut_created"):
		return list

	_add(list, "Explore the academy", "Find the briefing board, training bench and plant lab.", GameState.get_flag(&"academy_explored"))
	var mentors_met := 0
	for mentor in MENTORS:
		if GameState.get_flag(StringName("mentor_" + String(mentor))):
			mentors_met += 1
	_add(list, "Speak with the mentors (%d/3)" % mentors_met, "Find Okafor, Rivera and Tanaka in the academy.", mentors_met == 3)
	if d.stage >= d.Stage.TRAINING:
		_add(list, "Find Engineer Rivera", "Visit the east training workshop and talk to Rivera.", GameState.get_flag(&"mentor_engineer"))
	if GameState.get_flag(&"mentor_engineer") or d.can_graduate():
		_add(list, "Power Console training", "Postpone a load and keep the battery above empty.", d.can_graduate())
		_add(list, "Earn your certification", "Pass the training scenario to earn the certificate.", d.can_graduate())
	if d.can_graduate():
		_add(list, "Graduate and travel to the outpost", "Take the marked hatch on the academy's northeast wall.", GameState.get_flag(&"outpost_visited"))
	if GameState.get_flag(&"outpost_visited"):
		_add(list, "Check outpost power", "Use the station in the west power room.", d.power_checked)
		_add(list, "Check the greenhouse", "Inspect the grow lights in the east greenhouse.", d.greenhouse_checked)
	if d.stage >= d.Stage.ALERT:
		var alert_help := "Follow the amber arrows north and use the shelter station."
		if d.stage == d.Stage.DEBRIEF and not d.reached_shelter:
			alert_help = "The crew missed shelter. Retry from the debrief to try again."
		_add(list, "Respond to the space weather alert", alert_help, d.reached_shelter)
	return list


func _add(list: Array[Dictionary], title: String, description: String, done: bool) -> void:
	list.append({"title": title, "description": description, "done": done})

