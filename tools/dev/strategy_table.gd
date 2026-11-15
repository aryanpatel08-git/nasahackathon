extends Node
## Developer check: plays the simulation for every strategy and prints the outcomes,
## so the mission report's ratings can be tuned against real numbers.

func _ready() -> void:
	var D := MissionDirector
	print("rover green shelter late | outside expo battMin LSok shutoffs crops science")
	for rover in [0, 1]:
		for green in [0, 1]:
			for choice in [0, 1, 2, -1]:
				for late in [1, 3, 6]:
					if choice == -1 and late != 6:
						continue
					D.begin_mission()
					ResourceSim.set_load_enabled(&"rover", rover == 1)
					ResourceSim.set_greenhouse_conservation(green == 1)
					for i in int(D.config["shift_hours_before_alert"]):
						ResourceSim.advance_hour()
					ResourceSim.sep_active = true
					var total := int(D.config["storm_hours"])
					var outside := total if choice == -1 else mini(late, total)
					for i in outside:
						ResourceSim.advance_hour()
					if choice != -1:
						ResourceSim.crew_sheltered = true
						ResourceSim.set_load_enabled(&"rover", false)
						ResourceSim.set_load_enabled(&"greenhouse", true)
						ResourceSim.set_load_enabled(&"science", choice == 1)
						ResourceSim.set_greenhouse_conservation(choice != 0)
						for i in total - outside:
							ResourceSim.advance_hour()
					print("%5d %5d %7d %4d | %7d %4.1f %7.1f %2d/%2d %8d %5d %7d" % [rover, green, choice, late, outside,
						ResourceSim.exposure_log, ResourceSim.battery_min, ResourceSim.life_support_ok_hours, ResourceSim.hours_run,
						ResourceSim.emergency_shutoffs, int(ResourceSim.crop_health), ResourceSim.science_points])
	get_tree().quit()
