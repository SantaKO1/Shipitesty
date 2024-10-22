/obj/overmap
	// [CELADON-EDIT] - OVERMAP ICON
	// icon = 'icons/misc/overmap.dmi' // CELADON-EDIT - ORIGINAL
	icon = 'mod_celadon/_storge_icons/icons/overmap/overmap.dmi'
	// [/CELADON-EDIT]
	// [CELADON-ADD] - OVERMAP ICON - Это вагабонд насрал
	glide_size = 32
	// [/CELADON-ADD]
	///~~If we need to render a map for cameras and helms for this object~~ basically can you look at and use this as a ship or station.
	var/render_map = FALSE
	/// The parent overmap datum for this overmap token that has all of the actual functionality.
	var/datum/overmap/parent
	// Stuff needed to render the map
	var/map_name
	var/atom/movable/screen/map_view/cam_screen
	var/atom/movable/screen/plane_master/lighting/cam_plane_master
	var/atom/movable/screen/background/cam_background

	// [CELADON-ADD] - OVERMAP ICON - Это вагабонд насрал
	var/obj/token_visuals/move_vec
	var/obj/token_visuals/ship_image
	var/obj/token_visuals/torpedo_image

/obj/token_visuals
	glide_size = 32
	// [/CELADON-ADD]

/obj/overmap/rendered
	render_map = TRUE

/obj/overmap/Initialize(mapload, new_parent)
	. = ..()
	parent = new_parent
	name = parent.name
	icon_state = parent.token_icon_state
	if(render_map)	// Initialize map objects
		// [CELADON-ADD] - OVERMAP ICON - Это вагабонд насрал
		if(istype(parent, /datum/overmap/ship/controlled))
			if(!move_vec)
				move_vec = new (loc)
				move_vec.icon = 'mod_celadon/_storge_icons/icons/overmap/overmap.dmi'
				move_vec.icon_state = "movement_vector"
				move_vec.layer = move_vec.layer+1
			if(!ship_image)
				ship_image = new (loc)
				ship_image.icon = 'mod_celadon/_storge_icons/icons/overmap/overmap.dmi'
				ship_image.icon_state = "ship"
				ship_image.layer = ship_image.layer+2
			if(!torpedo_image)
				torpedo_image = new (loc)
				torpedo_image.icon = 'mod_celadon/_storge_icons/icons/overmap/overmap.dmi'
				torpedo_image.icon_state = "torpedo"
				torpedo_image.layer = torpedo_image.layer+3
		// [/CELADON-ADD]
		map_name = "overmap_[REF(src)]_map"
		cam_screen = new
		cam_screen.name = "screen"
		cam_screen.assigned_map = map_name
		cam_screen.del_on_map_removal = FALSE
		cam_screen.screen_loc = "[map_name]:1,1"
		cam_plane_master = new
		cam_plane_master.name = "plane_master"
		cam_plane_master.assigned_map = map_name
		cam_plane_master.del_on_map_removal = FALSE
		cam_plane_master.screen_loc = "[map_name]:CENTER"
		cam_background = new
		cam_background.assigned_map = map_name
		cam_background.del_on_map_removal = FALSE
		update_screen()
	update_appearance()

/obj/overmap/Destroy(force)
	if(!QDELETED(parent))
		stack_trace("attempted to qdel a token that still has a parent")
		return QDEL_HINT_LETMELIVE
	if(render_map)
		QDEL_NULL(cam_screen)
		QDEL_NULL(cam_plane_master)
		QDEL_NULL(cam_background)
	// [CELADON-ADD] - OVERMAP ICON - Это вагабонд насрал
	if(torpedo_image)
		QDEL_NULL(torpedo_image)
	if(ship_image)
		QDEL_NULL(ship_image)
	if(move_vec)
		QDEL_NULL(move_vec)
	// [/CELADON-ADD]
	return ..()

/obj/overmap/attack_ghost(mob/user)
	. = ..()
	var/turf/jump_to_turf = parent.get_jump_to_turf()
	if(!jump_to_turf)
		return
	user.abstract_move(jump_to_turf)

/obj/overmap/vv_edit_var(var_name, var_value)
	switch(var_name)
		if(NAMEOF(src, render_map))
			if(!render_map && var_value)
				map_name = "overmap_[REF(src)]_map"
				cam_screen = new
				cam_screen.name = "screen"
				cam_screen.assigned_map = map_name
				cam_screen.del_on_map_removal = FALSE
				cam_screen.screen_loc = "[map_name]:1,1"
				cam_plane_master = new
				cam_plane_master.name = "plane_master"
				cam_plane_master.assigned_map = map_name
				cam_plane_master.del_on_map_removal = FALSE
				cam_plane_master.screen_loc = "[map_name]:CENTER"
				cam_background = new
				cam_background.assigned_map = map_name
				cam_background.del_on_map_removal = FALSE
				update_screen()
			else if(render_map && !var_value)
				QDEL_NULL(cam_screen)
				QDEL_NULL(cam_plane_master)
				QDEL_NULL(cam_background)
		if(NAMEOF(src, x))
			return parent.overmap_move(var_value, parent.y)
		if(NAMEOF(src, y))
			return parent.overmap_move(parent.x, var_value)
		if(NAMEOF(src, name))
			parent.Rename(var_value)
			return TRUE
	return ..()
/**
 * Updates the screen object, which is displayed on all connected helms
 */
/obj/overmap/proc/update_screen()
	if(render_map)
		var/list/visible_turfs = list()
		// [CELADON-EDIT] - OVERMAP SENSOR - Это вагабонд насрал
		// for(var/turf/T in view(4, get_turf(src)))
		for(var/turf/T in view(parent.sensor_range, get_turf(src)))
		// [/CELADON-EDIT]
			visible_turfs += T

		var/list/bbox = get_bbox_of_atoms(visible_turfs)
		var/size_x = bbox[3] - bbox[1] + 1
		var/size_y = bbox[4] - bbox[2] + 1

		cam_screen?.vis_contents = visible_turfs
		cam_background.icon_state = "clear"
		cam_background.fill_rect(1, 1, size_x, size_y)
		return TRUE
