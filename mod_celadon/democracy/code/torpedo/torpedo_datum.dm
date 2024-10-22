/**
 * # Overmap ships
 *
 * Basically, any overmap object that is capable of moving by itself.
 *
 */

/obj/torpedotrail
	icon = 'mod_celadon/_storge_icons/icons/overmap/overmap.dmi'
	icon_state = "torpedo_trail"
	alpha = 200
	glide_size = 32

/datum/overmap/torpedo/proc/clear_trails()
	if(trails[1])
		QDEL_NULL(trails[1])
	if(trails[2])
		QDEL_NULL(trails[2])
	if(trails[3])
		QDEL_NULL(trails[3])

/datum/overmap/torpedo/proc/hide_trails()
	if(trails[1])
		trails[1].alpha = 0
	if(trails[2])
		trails[2].alpha = 0
	if(trails[3])
		trails[3].alpha = 0

/datum/overmap/torpedo/proc/update_trails(var/obj/torpedotrail/newtrail)
	if(trails[1])
		trails[1].alpha = 128
		if(trails[2])
			trails[2].alpha = 64
			if(trails[3])
				var/obj/first_trail = trails[3]
				trails[3] = trails[2]
				trails[2] = trails[1]
				first_trail.alpha = 200
				first_trail.forceMove(token.loc)
				first_trail.pixel_w = last_anim["x"]
				first_trail.pixel_z = last_anim["y"]
				var/matrix/M = matrix()
				M.Turn(bow_heading)
				first_trail.transform = M
				trails[1] = first_trail
			else
				trails[3] = trails[2]
				trails[2] = trails[1]
				var/obj/torpedotrail/S = new(token.loc)
				S.pixel_w = last_anim["x"]
				S.pixel_z = last_anim["y"]
				var/matrix/M = matrix()
				M.Turn(bow_heading)
				S.transform = M
				trails[1] = S

		else
			trails[2] = trails[1]
			var/obj/torpedotrail/S = new(token.loc)
			S.pixel_w = last_anim["x"]
			S.pixel_z = last_anim["y"]
			var/matrix/M = matrix()
			M.Turn(bow_heading)
			S.transform = M
			trails[1] = S

	else
		var/obj/torpedotrail/S = new(token.loc)
		S.pixel_w = last_anim["x"]
		S.pixel_z = last_anim["y"]
		var/matrix/M = matrix()
		M.Turn(bow_heading)
		S.transform = M
		trails[1] = S

/datum/overmap/torpedo
	name = "torpedo"
	char_rep = "|"
	token_icon_state = "torpedo"
	///Max possible speed (1 tile per tick / 600 tiles per minute)
	var/static/max_speed = 1
	///Minimum speed. Any lower is rounded down. (0.01 tiles per minute)
	var/static/min_speed = 1/(100 MINUTES)

	///The current speed in x direction in grid squares per minute
	var/speed_x = 0
	///The current speed in y direction in grid squares per minute
	var/speed_y = 0
	///The direction being accelerated in
	var/burn_direction = BURN_NONE
	///Percentage of thruster power being used
	var/burn_percentage = 50

	///For bay overmap
	var/x_pixels_moved = 0
	var/y_pixels_moved = 0

	var/list/position_to_move = list("x" = 0, "y" = 0)
	var/list/last_anim = list("x" = 0, "y" = 0)
	var/list/vector_to_add = list("x" = 0, "y" = 0)

	// var/list/arpa = list()

	var/bow_heading = 0
	var/rotating = 0
	var/rotation_velocity = 0


	var/skiptickfortrail = 0
	var/list/trails = list(1 = null,
							2 = null,
							3 = null)

/datum/overmap/torpedo/Initialize(position, ...)
	. = ..()
	if(docked_to)
		position_to_move["x"] = docked_to.x
		position_to_move["y"] = docked_to.y
	else
		position_to_move["x"] = x
		position_to_move["y"] = y
	if(docked_to)
		RegisterSignal(docked_to, COMSIG_OVERMAP_MOVED, PROC_REF(on_docked_to_moved))

/datum/overmap/torpedo/Destroy()
	clear_trails()
	return ..()

/datum/overmap/torpedo/complete_dock(datum/overmap/dock_target, datum/docking_ticket/ticket)
	. = ..()
	// override prevents runtime on controlled ship init due to docking after initializing at a position
	RegisterSignal(dock_target, COMSIG_OVERMAP_MOVED, PROC_REF(on_docked_to_moved), override = TRUE)

/datum/overmap/torpedo/complete_undock()
	UnregisterSignal(docked_to, COMSIG_OVERMAP_MOVED)
	. = ..()

/datum/overmap/torpedo/Undock(force = FALSE)
	. = ..()
	if(istype(/datum/overmap/torpedo, docked_to))
		var/datum/overmap/torpedo/old_dock = docked_to
		adjust_speed(old_dock.speed_x, old_dock.speed_y)

/datum/overmap/torpedo/proc/on_docked_to_moved()
	token.update_screen()

/**
 * Change the speed in any direction.
 * * n_x - Speed in the X direction to change
 * * n_y - Speed in the Y direction to change
 */

/datum/overmap/torpedo/proc/adjust_speed(n_x, n_y)
	if(QDELING(src) || docked_to)
		return

	speed_x = min(max_speed, speed_x + n_x)
	speed_y = min(max_speed, speed_y + n_y)

	if(speed_x < min_speed && speed_x > -min_speed)
		speed_x = 0
	if(speed_y < min_speed && speed_y > -min_speed)
		speed_y = 0

	speed_x = speed_x+vector_to_add["x"]
	speed_y = speed_y+vector_to_add["y"]
	vector_to_add["x"] = 0
	vector_to_add["y"] = 0

	update_visuals()

	if(token)
		var/matrix/M = matrix()
		M.Scale(1, get_speed()/3)
		M.Turn(get_alt_heading())
		if(token.move_vec)
			token.move_vec.transform = M

/**
 * Called by [/datum/overmap/ship/proc/adjust_speed], this continually moves the ship according to its speed
 */

/datum/overmap/torpedo/proc/not_tick_move(var/xmov, var/ymov)
	if(QDELING(src))
		return
	overmap_move(x + xmov, y + ymov)
	update_visuals()
	if(token)
		token.update_screen()
		if(token.ship_image)
			token.ship_image.forceMove(token.loc)
		if(token.move_vec)
			token.move_vec.forceMove(token.loc)

/**
 * Returns whether or not the ship is moving in any direction.
 */

/datum/overmap/torpedo/proc/is_still()
	return !speed_x && !speed_y

/**
 * Returns the total speed in all directions.
 *
 * The equation for acceleration is as follows:
 * 60 SECONDS / (1 / ([ship's speed] / ([ship's mass] * 100)))
 */

/datum/overmap/torpedo/proc/get_speed()
	if(is_still())
		return 0
	return 60 SECONDS * MAGNITUDE(speed_x, speed_y) //It's per tick, which is 0.1 seconds

/datum/overmap/torpedo/proc/get_alt_heading()
	. = 0
	var/stuff = -arctan(speed_x, speed_y)
	stuff = stuff+90
	if(stuff >= 360)
		stuff = stuff-360
	if(stuff < 0)
		stuff = stuff+360
	. = stuff
// [/CELADON-ADD]

/datum/overmap/torpedo/proc/get_heading()
	. = NONE
	if(speed_x)
		if(speed_x > 0)
			. |= EAST
		else
			. |= WEST
	if(speed_y)
		if(speed_y > 0)
			. |= NORTH
		else
			. |= SOUTH

/**
 * Updates the visuals of the ship based on heading and whether or not it's moving.
 */

/datum/overmap/torpedo/proc/update_visuals()
	var/direction = get_heading()
	if(direction & EAST)
		char_rep = ">"
	else if(direction & WEST)
		char_rep = "<"
	else if(direction & NORTH)
		char_rep = "^"
	else if(direction & SOUTH)
		char_rep = "v"
	if(direction)
		token.dir = NORTH
