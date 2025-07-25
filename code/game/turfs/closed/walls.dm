#define MAX_DENT_DECALS 15
#define LEANING_OFFSET 11

/turf/closed/wall
	name = "wall"
	desc = "A huge chunk of iron used to separate rooms."
	icon = 'icons/turf/walls/wall.dmi'
	icon_state = "wall-0"
	base_icon_state = "wall"
	explosive_resistance = 1

	thermal_conductivity = WALL_HEAT_TRANSFER_COEFFICIENT
	heat_capacity = 62500 //a little over 5 cm thick , 62500 for 1 m by 2.5 m by 0.25 m iron wall. also indicates the temperature at wich the wall will melt (currently only able to melt with H/E pipes)

	baseturfs = /turf/open/floor/plating

	flags_ricochet = RICOCHET_HARD

	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WALLS + SMOOTH_GROUP_CLOSED_TURFS
	canSmoothWith = SMOOTH_GROUP_WALLS

	rcd_memory = RCD_MEMORY_WALL
	///bool on whether this wall can be chiselled into
	var/can_engrave = TRUE
	///lower numbers are harder. Used to determine the probability of a hulk smashing through.
	var/hardness = 40
	var/slicing_duration = 100  //default time taken to slice the wall
	var/sheet_type = /obj/item/stack/sheet/iron
	var/scrap_type = /obj/item/stack/scrap/plating
	var/sheet_amount = 2
	var/girder_type = /obj/structure/girder
	/// A turf that will replace this turf when this turf is destroyed
	var/decon_type

	var/list/dent_decals

	//Monkestation edit start
	max_integrity = 300
	damage_deflection = 22 // big chunk of solid metal
	uses_integrity = TRUE
	armor_type = /datum/armor/wall

/datum/armor/wall
	melee = 60
	bullet = 60
	laser = 60
	energy = 0
	bomb = 0
	bio = 0
	acid = 50
	wound = 0
//Monkestation edit end


/turf/closed/wall/MouseDrop_T(mob/living/carbon/carbon_mob, mob/user)
	..()
	if(carbon_mob != user)
		return
	if(carbon_mob.is_leaning == TRUE)
		return
	if(carbon_mob.pulledby)
		return
	if(!carbon_mob.density)
		return
	var/turf/checked_turf = get_step(carbon_mob, turn(carbon_mob.dir, 180))
	if(checked_turf == src)
		carbon_mob.start_leaning(src)

/mob/living/carbon/proc/start_leaning(obj/wall)

	switch(dir)
		if(SOUTH)
			pixel_y += LEANING_OFFSET
		if(NORTH)
			pixel_y += -LEANING_OFFSET
		if(WEST)
			pixel_x += LEANING_OFFSET
		if(EAST)
			pixel_x += -LEANING_OFFSET

	ADD_TRAIT(src, TRAIT_UNDENSE, LEANING_TRAIT)
	ADD_TRAIT(src, TRAIT_EXPANDED_FOV, LEANING_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_LEG_AID, LEANING_TRAIT)
	visible_message(span_notice("[src] leans against \the [wall]!"), \
						span_notice("You lean against \the [wall]!"))
	RegisterSignals(src, list(COMSIG_MOB_CLIENT_PRE_MOVE, COMSIG_HUMAN_DISARM_HIT, COMSIG_LIVING_GET_PULLED, COMSIG_MOVABLE_TELEPORTING, COMSIG_LIVING_RESIST), PROC_REF(stop_leaning))
	RegisterSignal(src, COMSIG_ATOM_DIR_CHANGE, PROC_REF(stop_leaning_dir))
	update_fov()
	is_leaning = TRUE
	update_limbless_locomotion()

/mob/living/carbon/proc/stop_leaning_dir(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(new_dir != old_dir)
		stop_leaning()

/mob/living/carbon/proc/stop_leaning()
	SIGNAL_HANDLER
	UnregisterSignal(src, list(COMSIG_MOB_CLIENT_PRE_MOVE, COMSIG_HUMAN_DISARM_HIT, COMSIG_LIVING_GET_PULLED, COMSIG_MOVABLE_TELEPORTING, COMSIG_ATOM_DIR_CHANGE, COMSIG_LIVING_RESIST))
	is_leaning = FALSE
	pixel_y = base_pixel_y + body_position_pixel_x_offset
	pixel_x = base_pixel_y + body_position_pixel_y_offset
	REMOVE_TRAIT(src, TRAIT_UNDENSE, LEANING_TRAIT)
	REMOVE_TRAIT(src, TRAIT_EXPANDED_FOV, LEANING_TRAIT)
	REMOVE_TRAIT(src, TRAIT_NO_LEG_AID, LEANING_TRAIT)
	update_fov()

/turf/closed/wall/Initialize(mapload)
	. = ..()
	if(!can_engrave)
		ADD_TRAIT(src, TRAIT_NOT_ENGRAVABLE, INNATE_TRAIT)
	if(is_station_level(z))
		GLOB.station_turfs += src
	if(smoothing_flags & SMOOTH_DIAGONAL_CORNERS && fixed_underlay) //Set underlays for the diagonal walls.
		var/mutable_appearance/underlay_appearance = mutable_appearance(layer = TURF_LAYER, offset_spokesman = src, plane = FLOOR_PLANE)
		if(fixed_underlay["space"])
			generate_space_underlay(underlay_appearance, src)
		else
			underlay_appearance.icon = fixed_underlay["icon"]
			underlay_appearance.icon_state = fixed_underlay["icon_state"]
		fixed_underlay = string_assoc_list(fixed_underlay)
		underlays += underlay_appearance

	//monkestation edit start
	if(SSstation_coloring.wall_trims)
		trim_color = SSstation_coloring.get_default_color()

/turf/closed/wall/Destroy()
	if(is_station_level(z))
		GLOB.station_turfs -= src
	return ..()


/turf/closed/wall/examine(mob/user)
	. += ..()
	. += deconstruction_hints(user)

//monkestation edit start
/turf/closed/wall/take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	. = ..()
	if(.) // add a dent if it took damage
		add_dent(WALL_DENT_HIT)

/turf/closed/wall/attacked_by(obj/item/attacking_item, mob/living/user)
	if(!uses_integrity)
		CRASH("attacked_by() was called on an wall that doesn't use integrity!")

	if(!attacking_item.force)
		return

	var/damage = take_damage(attacking_item.force * attacking_item.demolition_mod, attacking_item.damtype, MELEE, TRUE, armour_penetration = attacking_item.armour_penetration)
	//only witnesses close by and the victim see a hit message.
	user.visible_message(span_danger("[user] hits [src] with [attacking_item][damage ? "." : ", without leaving a mark!"]"), \
		span_danger("You hit [src] with [attacking_item][damage ? "." : ", without leaving a mark!"]"), null, COMBAT_MESSAGE_RANGE)
	log_combat(user, src, "attacked", attacking_item)

/turf/closed/wall/run_atom_armor(damage_amount, damage_type, damage_flag, attack_dir, armour_penetration)
	if(damage_amount < damage_deflection && (damage_type in list(MELEE, BULLET, LASER, ENERGY)))
		return 0 // absolutely no bypassing damage deflection by using projectiles
	return ..()

/turf/closed/wall/atom_destruction(damage_flag)
	. = ..()
	if(damage_flag == MELEE)
		playsound(src, 'sound/effects/meteorimpact.ogg', 50, TRUE) //Otherwise there's no sound for hitting the wall, since it's just dismantled
	dismantle_wall(TRUE, TRUE)
//monkestation edit end

/turf/closed/wall/proc/deconstruction_hints(mob/user)
	return span_notice("The outer plating is <b>welded</b> firmly in place.")

/turf/closed/wall/attack_tk()
	return

/turf/closed/wall/proc/dismantle_wall(devastated = FALSE, explode = FALSE)
	if(devastated)
		devastate_wall()
	else
		playsound(src, 'sound/items/welder.ogg', 100, TRUE)
		var/newgirder = break_wall()
		if(newgirder) //maybe we don't /want/ a girder!
			transfer_fingerprints_to(newgirder)

	for(var/obj/O in src.contents) //Eject contents!
		if(istype(O, /obj/structure/sign/poster))
			var/obj/structure/sign/poster/P = O
			INVOKE_ASYNC(P, TYPE_PROC_REF(/obj/structure/sign/poster, roll_and_drop), src)
	if(decon_type)
		ChangeTurf(decon_type, flags = CHANGETURF_INHERIT_AIR)
	else
		ScrapeAway()
	QUEUE_SMOOTH_NEIGHBORS(src)

/turf/closed/wall/proc/break_wall()
	var/area/space/shipbreak/A = get_area(src)
	if(istype(A)) //if we are actually in the shipbreaking zone...
		new scrap_type(src, sheet_amount)
	else
		new sheet_type(src, sheet_amount)
	if(girder_type)
		return new girder_type(src)

/turf/closed/wall/proc/devastate_wall()
	var/area/space/shipbreak/A = get_area(src)
	if(istype(A))
		new scrap_type(src, sheet_amount)
	else
		new sheet_type(src, sheet_amount)
	if(girder_type)
		new /obj/item/stack/sheet/iron(src)

/turf/closed/wall/ex_act(severity, target)
	if(target == src)
		dismantle_wall(TRUE, TRUE) //monkestation edit
		return

	switch(severity)
		if(EXPLODE_DEVASTATE)
			//SN src = null
			var/turf/NT = ScrapeAway()
			NT.contents_explosion(severity, target)
			return
		if(EXPLODE_HEAVY)
			dismantle_wall(prob(50), TRUE)
		if(EXPLODE_LIGHT)
			take_damage(150, BRUTE, BOMB) // less kaboom monkestation edit
	if(!density)
		..()


/turf/closed/wall/blob_act(obj/structure/blob/B)
	//monkestation edit start
	take_damage(400, BRUTE, MELEE, FALSE)
	playsound(src, 'sound/effects/meteorimpact.ogg', 100, 1)
	//monkestation edit end

/turf/closed/wall/attack_paw(mob/living/user, list/modifiers)
	user.changeNext_move(CLICK_CD_MELEE)
	return attack_hand(user, modifiers)

/turf/closed/wall/attack_hulk(mob/living/carbon/user)
	..()
	var/obj/item/bodypart/arm = user.hand_bodyparts[user.active_hand_index]
	if(!arm)
		return
	if(arm.bodypart_disabled)
		return
	//monkestation edit start
	user.say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!" ), forced = "hulk")
	take_damage(400, BRUTE, MELEE, FALSE)
	playsound(src, 'sound/effects/bang.ogg', 50, 1)
	to_chat(user, span_notice("You punch the wall."))
	hulk_recoil(arm, user)
	return TRUE
	//monkestation edit end

/**
 *Deals damage back to the hulk's arm.
 *
 *When a hulk manages to break a wall using their hulk smash, this deals back damage to the arm used.
 *This is in its own proc just to be easily overridden by other wall types. Default allows for three
 *smashed walls per arm. Also, we use CANT_WOUND here because wounds are random. Wounds are applied
 *by hulk code based on arm damage and checked when we call break_an_arm().
 *Arguments:
 **arg1 is the arm to deal damage to.
 **arg2 is the hulk
 */
/turf/closed/wall/proc/hulk_recoil(obj/item/bodypart/arm, mob/living/carbon/human/hulkman, damage = 20)
	arm.receive_damage(brute = damage, blocked = 0, wound_bonus = CANT_WOUND)
	var/datum/mutation/hulk/smasher = locate(/datum/mutation/hulk) in hulkman.dna.mutations
	if(!smasher || !damage) //sanity check but also snow and wood walls deal no recoil damage, so no arm breaky
		return
	smasher.break_an_arm(arm)

/turf/closed/wall/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return
	user.changeNext_move(CLICK_CD_MELEE)
	to_chat(user, span_notice("You push the wall but nothing happens!"))
	playsound(src, 'sound/weapons/genhit.ogg', 25, TRUE)
	add_fingerprint(user)

/turf/closed/wall/attackby(obj/item/attacking_item, mob/user, params) //monkestation edit
	user.changeNext_move(CLICK_CD_MELEE)
	if (!ISADVANCEDTOOLUSER(user))
		to_chat(user, span_warning("You don't have the dexterity to do this!"))
		return

	//get the user's location
	if(!isturf(user.loc))
		return //can't do this stuff whilst inside objects and such

	add_fingerprint(user)

	//the istype cascade has been spread among various procs for easy overriding
	if(try_clean(attacking_item, user) || try_wallmount(attacking_item, user) || try_decon(attacking_item, user)) //monkestation edit
		return

	return ..() || (attacking_item.attack_atom(src, user))

/turf/closed/wall/proc/try_clean(obj/item/W, mob/living/user, turf/T)
	if(!(user.istate & ISTATE_HARM)) //monkestation edit
		return FALSE

	//monkestation edit start
	if(W.tool_behaviour == TOOL_WELDER)
		if(!W.tool_start_check(user, amount=0))
			to_chat(user, span_warning("You need more fuel to repair [src]!"))
			return TRUE

		if(atom_integrity >= max_integrity)
			if(LAZYLEN(dent_decals))
				to_chat(user, span_notice("You begin fixing dents on the wall..."))
				if(W.use_tool(src, user, 0, volume=100))
					if(iswallturf(src))
						to_chat(user, span_notice("You fix some dents on the wall."))
						cut_overlay(dent_decals)
						dent_decals.Cut()
			else
				to_chat(user, span_warning("[src] is intact!"))
			return TRUE

		to_chat(user, span_notice("You begin repairing [src]..."))
		if(W.use_tool(src, user, 3 SECONDS, volume=100))
			update_integrity(max_integrity)
			to_chat(user, span_notice("You repair [src]."))
			cut_overlay(dent_decals)
			dent_decals.Cut()
			return TRUE
		return TRUE
	//monkestation edit end
	return FALSE

/turf/closed/wall/proc/try_wallmount(obj/item/W, mob/user)
	//check for wall mounted frames
	if(istype(W, /obj/item/wallframe))
		var/obj/item/wallframe/F = W
		if(F.try_build(src, user))
			F.attach(src, user)
			return TRUE
		return FALSE
	//Poster stuff
	else if(istype(W, /obj/item/poster) && Adjacent(user)) //no tk memes.
		return place_poster(W,user)

	return FALSE

/turf/closed/wall/proc/try_decon(obj/item/I, mob/user)
	if(I.tool_behaviour == TOOL_WELDER)
		if(!I.tool_start_check(user, amount=0))
			return FALSE

		to_chat(user, span_notice("You begin slicing through the outer plating..."))
		if(I.use_tool(src, user, slicing_duration, volume=100))
			if(iswallturf(src))
				to_chat(user, span_notice("You remove the outer plating."))
				dismantle_wall()
			return TRUE

	return FALSE

/turf/closed/wall/singularity_pull(S, current_size)
	. = ..()
	//monkestation edit start
	if(current_size >= STAGE_FIVE)
		take_damage(300, armour_penetration=100) // LORD SINGULOTH CARES NOT FOR YOUR "ARMOR"
	else if(current_size == STAGE_FOUR)
		take_damage(150, armour_penetration=100)
	//monkestation edit end

/* //MONKESTATION REMOVAL: Deprecated, obselete old code proc
/turf/closed/wall/proc/wall_singularity_pull(current_size)
	if(current_size >= STAGE_FIVE)
		if(prob(50))
			dismantle_wall()
		return
	if(current_size == STAGE_FOUR)
		if(prob(30))
			dismantle_wall()
*/

/turf/closed/wall/narsie_act(force, ignore_mobs, probability = 20)
	. = ..()
	if(.)
		ChangeTurf(/turf/closed/wall/mineral/cult)

/turf/closed/wall/get_dumping_location()
	return null

/turf/closed/wall/acid_act(acidpwr, acid_volume)
	if(get_explosive_block() >= 2)
		acidpwr = min(acidpwr, 50) //we reduce the power so strong walls never get melted.
	return ..()

/turf/closed/wall/acid_melt()
	dismantle_wall(1)

/turf/closed/wall/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	switch(the_rcd.mode)
		if(RCD_DECONSTRUCT)
			return list("mode" = RCD_DECONSTRUCT, "delay" = 4 SECONDS, "cost" = 26)
		if(RCD_WALLFRAME)
			return list("mode" = RCD_WALLFRAME, "delay" = 1 SECONDS, "cost" = 8)
	return FALSE

/turf/closed/wall/rcd_act(mob/user, obj/item/construction/rcd/the_rcd, passed_mode)
	switch(passed_mode)
		if(RCD_WALLFRAME)
			var/obj/item/wallframe/new_wallmount = new the_rcd.wallframe_type(user.drop_location())
			if(!try_wallmount(new_wallmount, user, src))
				qdel(new_wallmount)
				return FALSE
			return TRUE
		if(RCD_DECONSTRUCT)
			to_chat(user, span_notice("You deconstruct the wall."))
			ScrapeAway()
			return TRUE
	return FALSE

//monkestation edit start
/turf/proc/add_dent(denttype, x=rand(-8, 8), y=rand(-8, 8)) // this only exists because turf code is terrible, monkestation
	return

/turf/closed/wall/add_dent(denttype, x=rand(-8, 8), y=rand(-8, 8))
//monkestation edit end
	if(LAZYLEN(dent_decals) >= MAX_DENT_DECALS)
		return

	var/mutable_appearance/decal = mutable_appearance('icons/effects/effects.dmi', "", BULLET_HOLE_LAYER)
	switch(denttype)
		if(WALL_DENT_SHOT)
			decal.icon_state = "bullet_hole"
		if(WALL_DENT_HIT)
			decal.icon_state = "impact[rand(1, 3)]"

	decal.pixel_x = x
	decal.pixel_y = y

	if(LAZYLEN(dent_decals))
		cut_overlay(dent_decals)
		dent_decals += decal
	else
		dent_decals = list(decal)

	add_overlay(dent_decals)

/turf/closed/wall/rust_heretic_act()
	if(HAS_TRAIT(src, TRAIT_RUSTY))
		ScrapeAway()
		return
	if(prob(70))
		new /obj/effect/temp_visual/glowing_rune(src)
	return ..()

/turf/closed/wall/metal_foam_base
	girder_type = /obj/structure/foamedmetal

/turf/closed/wall/Bumped(atom/movable/bumped_atom)
	. = ..()
	SEND_SIGNAL(bumped_atom, COMSIG_LIVING_WALL_BUMP, src)

/turf/closed/wall/Exited(atom/movable/gone, direction)
	. = ..()
	SEND_SIGNAL(gone, COMSIG_LIVING_WALL_EXITED, src)

#undef MAX_DENT_DECALS
#undef LEANING_OFFSET
