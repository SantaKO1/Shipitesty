// Ship guns states
#define GUN_STATE_OFF 0
#define GUN_STATE_CHARGING 1
#define GUN_STATE_FIRING 2
#define GUN_STATE_OVERHEAT 3
#define GUN_CHARGE_DELAY (30 SECONDS)
#define GUN_IONIZED_TIME (3 MINUTES)

// Ship protection states
#define PROTECTION_STATE_OFF 0
#define PROTECTION_STATE_ACTIVE 1

/obj/machinery/computer/battle_console
	name = "battle helm console"
	desc = "Used to start warcrime's."
	icon_screen = "forensic"
	icon_keyboard = "security_key"
	circuit = /obj/item/circuitboard/computer/shuttle/battle_console
	light_color = COLOR_DARK_RED
	clicksound = null

	/// The ship we reside on for ease of access
	var/datum/overmap/ship/controlled/current_ship as current_ship
	/// All ships nearby current ship
	var/list/controlled_ships
	/// All torpedos in use
	var/list/torpedos = list()
	/// Current torpedo in use
	var/torpedo
	/// All users currently using this
	var/list/concurrent_users = list()
	/// Is this console view only? I.E. cant dock/etc
	var/viewer = FALSE
	/// When are we allowed to use guns
	var/fire_allowed
	/// Current state of our guns
	var/fire_state = GUN_STATE_OFF
	///holding jump timer ID
	var/fire_timer
	///is the AI allowed to control this battle console
	var/allow_ai_control = FALSE

/obj/machinery/computer/battle_console/retro
	icon = 'icons/obj/machines/retro_computer.dmi'
	icon_state = "computer-retro"
	deconpath = /obj/structure/frame/computer/retro

/obj/machinery/computer/battle_console/solgov
	icon = 'icons/obj/machines/retro_computer.dmi'
	icon_state = "computer-solgov"
	deconpath = /obj/structure/frame/computer/solgov

/datum/config_entry/number/warcrime_wait
	default = 1 HOURS

/obj/machinery/computer/battle_console/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()
	if(!viewer)
		SSpoints_of_interest.make_point_of_interest(src)
	fire_allowed = world.time + CONFIG_GET(number/warcrime_wait)

/obj/machinery/computer/battle_console/Destroy()
	. = ..()
	SStgui.close_uis(src)
	ASSERT(length(concurrent_users) == 0)
	SSpoints_of_interest.remove_point_of_interest(src)
	if(current_ship)
		current_ship.battle_consoles -= src

/obj/machinery/computer/battle_console/proc/check_states(inline = FALSE)
	if(fire_allowed < 0)
		say("WARCRIME-3000 systems offline. Please contact your administrator.")
		return
	if(current_ship.docked_to || current_ship.docking)
		say("WARCRIME-3000 systems won't work when user docking.")
		return
	if(world.time < fire_allowed)
		var/fire_wait = DisplayTimeText(fire_allowed - world.time)
		say("WARCRIME-3000 systems is currently recharging. ETA: [fire_wait].")
		return
	if(fire_state != GUN_STATE_OFF && !inline)
		return // This exists to prefent Href exploits
	return TRUE

/obj/machinery/computer/battle_console/proc/fire_options()
	say("fire options")

/obj/machinery/computer/battle_console/proc/cancel_fire()
	say("Systems to use guns of WARCRIME-3000 get denied!")

/**
 * This proc manually rechecks that the battle console is connected to a proper ship
 */
/obj/machinery/computer/battle_console/proc/reload_ship()
	var/obj/docking_port/mobile/port = SSshuttle.get_containing_shuttle(src)
	if(port?.current_ship)
		if(current_ship && current_ship != port.current_ship)
			current_ship.battle_consoles -= src
		current_ship = port.current_ship
		current_ship.battle_consoles |= src


/*
/obj/machinery/computer/helm/connect_to_shuttle(obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	if(current_ship && current_ship != port.current_ship)
		current_ship.helms -= src
	current_ship = port.current_ship
	current_ship.helms |= src

/obj/machinery/computer/helm/ui_interact(mob/living/user, datum/tgui/ui)
	// Update UI
	if(!current_ship && !reload_ship())
		return

	if(isliving(user) && !viewer && check_keylock())
		return

	if(!current_ship.shipkey && istype(user) && Adjacent(user) && !viewer)
		say("Generated new shipkey, do not lose it!")
		var/key = new /obj/item/key/ship(get_turf(src), current_ship)
		user.put_in_hands(key)
		return

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		var/user_ref = REF(user)
		var/is_living = isliving(user)
		// Ghosts shouldn't count towards concurrent users, which produces
		// an audible terminal_on click.
		if(is_living)
			concurrent_users += user_ref
		// Turn on the console
		if(length(concurrent_users) == 1 && is_living)
			playsound(src, 'sound/machines/terminal_on.ogg', 25, FALSE)
			use_power(active_power_usage)
		// Register map objects
		if(current_ship)
			user.client.register_map_obj(current_ship.token.cam_screen)
			user.client.register_map_obj(current_ship.token.cam_plane_master)
			user.client.register_map_obj(current_ship.token.cam_background)
			current_ship.token.update_screen()

		// Open UI
		ui = new(user, src, "HelmConsole", name)
		ui.open()

/obj/machinery/computer/helm/ui_data(mob/user)
	. = list()
	if(!current_ship)
		return

	.["calibrating"] = calibrating
	.["arpa_ships"] = list()
	var/list/arpobjects = current_ship.check_proximity()
	var/arpdequeue_pointer = 0
	while (arpdequeue_pointer++ < arpobjects.len)
		var/datum/overmap/ship/controlled/object = arpobjects[arpdequeue_pointer]
		if(!istype(object, /datum/overmap/ship/controlled)) //Not an overmap object, ignore this
			continue

		var/list/cpa_list = calculate_cpa(current_ship, object, TRUE)
		var/list/other_data = list(
			name = object.name,
			brg = cpa_list["brg"],
			cpa = cpa_list["cpa"],
			tcpa = cpa_list["tcpa"]
		)
		.["arpa_ships"] += list(other_data)
	.["otherInfo"] = list()
	var/list/objects = current_ship.get_nearby_overmap_objects()
	var/dequeue_pointer = 0
	while (dequeue_pointer++ < objects.len)
		var/datum/overmap/ship/controlled/object = objects[dequeue_pointer]
		if(!istype(object, /datum/overmap)) //Not an overmap object, ignore this
			continue

		var/available_dock = FALSE

		//Even if its full or incompatible with us, it should still show up.
		if(object in SSovermap.overmap_container[current_ship.x][current_ship.y])
			available_dock = TRUE

		//Detect any ships in this location we can dock to
		if(istype(object))
			for(var/obj/docking_port/stationary/docking_port as anything in object.shuttle_port.docking_points)
				if(current_ship.shuttle_port.check_dock(docking_port, silent = TRUE))
					available_dock = TRUE
					break

		objects |= object.contents

		if(!available_dock)
			continue

		var/list/other_data = list(
			name = object.name,
			ref = REF(object)
		)
		.["otherInfo"] += list(other_data)

	.["x"] = current_ship.x || current_ship.docked_to.x
	.["y"] = current_ship.y || current_ship.docked_to.y
	.["docking"] = current_ship.docking
	.["docked"] = current_ship.docked_to
	.["course"] = "[current_ship.get_alt_heading()]°"
	.["heading"] = "[current_ship.bow_heading]°"
	.["speed"] = current_ship.get_speed()
	.["eta"] = current_ship.get_eta()
	.["estThrust"] = current_ship.est_thrust
	.["engineInfo"] = list()
	.["aiControls"] = allow_ai_control
	.["burnDirection"] = current_ship.burn_direction
	.["burnPercentage"] = current_ship.burn_percentage
	.["rotating"] = current_ship.rotating
	for(var/datum/weakref/engine in current_ship.shuttle_port.engine_list)
		var/obj/machinery/power/shuttle/engine/real_engine = engine.resolve()
		if(!real_engine)
			current_ship.shuttle_port.engine_list -= engine
			continue
		var/list/engine_data
		if(!real_engine.thruster_active)
			engine_data = list(
				name = real_engine.name,
				fuel = 0,
				maxFuel = 100,
				enabled = real_engine.enabled,
				ref = REF(engine)
			)
		else
			engine_data = list(
				name = real_engine.name,
				fuel = real_engine.return_fuel(),
				maxFuel = real_engine.return_fuel_cap(),
				enabled = real_engine.enabled,
				ref = REF(engine)
			)
		.["engineInfo"] += list(engine_data)

/obj/machinery/computer/helm/ui_static_data(mob/user)
	. = list()
	.["isViewer"] = viewer || (!allow_ai_control && issilicon(user))
	.["mapRef"] = current_ship.token.map_name
	.["shipInfo"] = list(
		name = current_ship.name,
		class = current_ship.source_template?.name,
		mass = current_ship.shuttle_port.turf_count,
		sensor_range = current_ship.sensor_range
	)
	.["canFly"] = TRUE
	.["aiUser"] = issilicon(user)

/obj/machinery/computer/helm/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(viewer)
		return
	if(!current_ship)
		return
	if(check_keylock())
		return
	. = TRUE

	switch(action) // Universal topics
		if("sensor_increase")
			current_ship.sensor_range = min(5, current_ship.sensor_range+1)
			update_static_data(usr, ui)
			current_ship.token.update_screen()
			return
		if("sensor_decrease")
			current_ship.sensor_range = max(1, current_ship.sensor_range-1)
			update_static_data(usr, ui)
			current_ship.token.update_screen()
			return
		if("rename_ship")
			var/new_name = params["newName"]
			if(!new_name)
				return
			new_name = trim(new_name)
			if (!length(new_name) || new_name == current_ship.name)
				return
			if(!reject_bad_text(new_name, MAX_CHARTER_LEN))
				say("Error: Replacement designation rejected by system.")
				return
			if(!current_ship.Rename(new_name))
				say("Error: [COOLDOWN_TIMELEFT(current_ship, rename_cooldown)/10] seconds until ship designation can be changed.")
			update_static_data(usr, ui)
			return
		if("reload_ship")
			reload_ship()
			update_static_data(usr, ui)
			return
		if("reload_engines")
			current_ship.refresh_engines()
			return
		if("toggle_ai_control")
			if(issilicon(usr))
				to_chat(usr, "<span class='warning'>You are unable to toggle AI controls.</span>")
				return
			allow_ai_control = !allow_ai_control
			say(allow_ai_control ? "AI Control has been enabled." : "AI Control is now disabled.")
			return
		// [Celadon-ADD] - Signal S.O.S. - mod_celadon\wideband\code\signal.dm
		if("send_sos")
			if(!current_ship.SendSos(name = "[current_ship.name]", x = "[current_ship.x || current_ship.docked_to.x]", y = "[current_ship.y || current_ship.docked_to.y]"))
				if(COOLDOWN_TIMELEFT(current_ship, sendsos_cooldown)/10 != 0)
					say("Error: [COOLDOWN_TIMELEFT(current_ship, sendsos_cooldown)/10] секунд до заряда сигнала S.O.S.")
				return
			current_ship.SendSos(name = "[current_ship.name]", x = "[current_ship.x || current_ship.docked_to.x]", y = "[current_ship.y || current_ship.docked_to.y]")
			return
		// [/Celadon-ADD]
	if(jump_state != JUMP_STATE_OFF)
		say("Bluespace Jump in progress. Controls suspended.")
		return

	if(!current_ship.docked_to && !current_ship.docking)
		switch(action)
			if("rotate_left")
				if(current_ship.rotating == -1)
					current_ship.rotating = 0
					current_ship.rotation_velocity = 0
				else
					current_ship.rotating = -1
				return
			if("rotate_right")
				if(current_ship.rotating == 1)
					current_ship.rotating = 0
					current_ship.rotation_velocity = 0
				else
					current_ship.rotating = 1
				return
			if("act_overmap")
				if(SSshuttle.jump_mode > BS_JUMP_CALLED)
					to_chat(usr, "<span class='warning'>Cannot dock due to bluespace jump preperations!</span>")
					return
				var/datum/overmap/to_act = locate(params["ship_to_act"]) in current_ship.get_nearby_overmap_objects(include_docked = TRUE)
				say(current_ship.Dock(to_act))
				return
			if("toggle_engine")
				var/datum/weakref/engine = locate(params["engine"]) in current_ship.shuttle_port.engine_list
				var/obj/machinery/power/shuttle/engine/real_engine = engine.resolve()
				if(!real_engine)
					current_ship.shuttle_port.engine_list -= engine
					return
				real_engine.enabled = !real_engine.enabled
				real_engine.update_icon_state()
				current_ship.refresh_engines()
				return
			if("change_burn_percentage")
				var/new_percentage = clamp(text2num(params["percentage"]), 1, 100)
				current_ship.burn_percentage = new_percentage
				return
			if("change_heading")
				var/new_direction = text2num(params["dir"])
				if(new_direction == current_ship.burn_direction)
					current_ship.change_heading(BURN_NONE)
					return
				current_ship.change_heading(new_direction)
				return
			if("stop")
				if(current_ship.burn_direction == BURN_NONE)
					current_ship.change_heading(BURN_STOP)
					return
				current_ship.change_heading(BURN_NONE)
				return
			if("bluespace_jump")
				if(calibrating)
					cancel_jump()
					return
				else
					if(tgui_alert(usr, "Do you want to bluespace jump? Your ship and everything on it will be removed from the round.", "Jump Confirmation", list("Yes", "No")) != "Yes")
						return
					calibrate_jump()
					return
			if("dock_empty")
				current_ship.dock_in_empty_space(usr)
				return
	else if(current_ship.docked_to)
		if(action == "undock")
			current_ship.calculate_avg_fuel()
			if(current_ship.avg_fuel_amnt < 25 && tgui_alert(usr, "Ship only has ~[round(current_ship.avg_fuel_amnt)]% fuel remaining! Are you sure you want to undock?", name, list("Yes", "No")) != "Yes")
				return
			current_ship.Undock()

/obj/machinery/computer/helm/ui_close(mob/user)
	var/user_ref = REF(user)
	var/is_living = isliving(user)
	// Living creature or not, we remove you anyway.
	concurrent_users -= user_ref
	// Unregister map objects
	if(current_ship)
		user.client?.clear_map(current_ship.token.map_name)
		if(current_ship.burn_direction > BURN_NONE && !length(concurrent_users) && !viewer) // If accelerating with nobody else to stop it
			say("Pilot absence detected, engaging acceleration safeties.")
			current_ship.change_heading(BURN_NONE)

	// Turn off the console
	if(!length(concurrent_users) && is_living)
		playsound(src, 'sound/machines/terminal_off.ogg', 25, FALSE)
		use_power(0)

/obj/machinery/computer/helm/attackby(obj/item/key, mob/living/user, params)
	if(istype(key, /obj/item/clothing/accessory/medal/gold/captain))
		var/obj/item/clothing/accessory/medal/gold/captain/medal = key
		key = medal.shipkey

	if(!istype(key, /obj/item/key/ship))
		return ..()

	current_ship?.attempt_key_usage(user, key, src)
	return TRUE

/// Checks if this helm is locked, or for the key being destroyed. Returns TRUE if locked.
/obj/machinery/computer/helm/proc/check_keylock(silent=FALSE)
	if(!current_ship.helm_locked)
		return FALSE
	if(!current_ship.shipkey)
		current_ship.helm_locked = FALSE
		return FALSE
	if(IsAdminAdvancedProcCall())
		return FALSE
	if(issilicon(usr) && allow_ai_control)
		return FALSE
	if(!silent)
		say("[src] is currently locked; please insert your key to continue.")
		playsound(src, 'sound/machines/buzz-two.ogg')
	return TRUE
*/
#undef GUN_STATE_OFF
#undef GUN_STATE_CHARGING
#undef GUN_STATE_FIRING
#undef GUN_STATE_OVERHEAT
#undef GUN_CHARGE_DELAY
#undef GUN_IONIZED_TIME

#undef PROTECTION_STATE_OFF
#undef PROTECTION_STATE_ACTIVE
