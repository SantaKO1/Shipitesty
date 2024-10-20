/**
 * # Overmap ships
 *
 * Basically, any overmap object that is capable of moving by itself.
 *
 */

/datum/overmap/torpedo
	name = "torpedo"
	char_rep = "|"
	token_icon_state = "torpedo"
	///Timer ID of the looping movement timer
	var/movement_callback_id
	///Max possible speed (1 tile per tick / 600 tiles per minute)
	var/static/max_speed = 1
	///Minimum speed. Any lower is rounded down. (0.01 tiles per minute)
	var/static/min_speed = 1/(100 MINUTES)

	///The current speed in x direction in grid squares per minute
	var/speed_x = 0
	///The current speed in y direction in grid squares per minute
	var/speed_y = 0
