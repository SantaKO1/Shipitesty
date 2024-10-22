/**
 * # Simulated overmap torpedo
 *
 * A torpedo that corresponds to an actual ship.
 *
 * Can be docked to any other overmap datum that has a valid docking process.
 */
/datum/overmap/tropedo/controlled
	token_type = /obj/overmap/rendered
	dock_time = 10 SECONDS

	///Cooldown until the ship can be renamed again
	COOLDOWN_DECLARE(rename_cooldown)

	///Whether objects on the ship require an ID with ship access granted
	var/unique_ship_access = FALSE

	/// The shipkey for this ship
	var/obj/item/key/ship/shipkey
	/// All torpedos connected to this ship
	var/list/obj/machinery/computer/torpedo/torpedos = list()

	///Stations the ship has been blacklisted from landing at, associative station = reason
	var/list/blacklisted = list()
