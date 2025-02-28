SUBSYSTEM_DEF(codex)
	name = "Codex"
	flags = SS_NO_FIRE
	init_order = INIT_ORDER_CODEX
	var/list/entries_by_path = list()
	var/list/entries_by_string = list()
	var/list/index_file = list()
	var/list/search_cache = list()
	var/list/entry_cache = list()

/datum/controller/subsystem/codex/Initialize()

	// Create general hardcoded entries.
	for(var/ctype in typesof(/datum/codex_entry))
		var/datum/codex_entry/centry = ctype
		if(initial(centry.display_name) || initial(centry.associated_paths) || initial(centry.associated_strings))
			centry = new centry()
			for(var/associated_path in centry.associated_paths)
				entries_by_path[associated_path] = centry
			for(var/associated_string in centry.associated_strings)
				entries_by_string[associated_string] = centry
			if(centry.display_name)
				entries_by_string[centry.display_name] = centry

	// Create categorized entries.
	for(var/ctype in subtypesof(/datum/codex_category))
		var/datum/codex_category/cat = new ctype
		cat.Initialize()
		qdel(cat)

	// Create the index file for later use.
	for(var/thing in SScodex.entries_by_path)
		var/datum/codex_entry/entry = SScodex.entries_by_path[thing]
		index_file[entry.display_name] = entry
	for(var/thing in SScodex.entries_by_string)
		var/datum/codex_entry/entry = SScodex.entries_by_string[thing]
		index_file[entry.display_name] = entry
	index_file = sortTim(index_file, cmp=/proc/cmp_text_asc)
	return ..()

/datum/controller/subsystem/codex/proc/get_codex_entry(datum/codex_entry/entry)
	if(!initialized)
		return
	var/searching = "\ref[entry]"
	if(isatom(entry))
		var/atom/entity = entry
		if(entity.get_specific_codex_entry())
			entry_cache[searching] = entity.get_specific_codex_entry()
		else if(entries_by_string[lowertext(entity.name)])
			entry_cache[searching] = entries_by_string[lowertext(entity.name)]
		else if(entries_by_path[entity.type])
			entry_cache[searching] = entries_by_path[entity.type]
		return entry_cache[searching]

	if(!entry_cache[searching])
		if(istype(entry))
			entry_cache[searching] = entry
		else
			entry_cache[searching] = FALSE
			if(ispath(entry))
				entry_cache[searching] = entries_by_path[entry]

	return entry_cache[searching]

/datum/controller/subsystem/codex/proc/present_codex_entry(mob/presenting_to, datum/codex_entry/entry)
	if(entry && istype(presenting_to) && presenting_to.client)
		var/list/dat = list()
		if(entry.mechanics_text)
			dat += "<h3>OOC Information</h3>"
			dat += "<font color='#9ebcd8'>[entry.mechanics_text]</font>"
		if(entry.lore_text)
			dat += "<h3>Lore Information</h3>"
			dat += "<font color='#abdb9b'>[entry.lore_text]</font>"
		var/datum/browser/popup = new(presenting_to, "codex", "Codex - [entry.display_name]")
		popup.set_content(jointext(dat, null))
		popup.open()

/datum/controller/subsystem/codex/proc/retrieve_entries_for_string(searching)

	if(!initialized)
		return list()

	searching = sanitize(lowertext(trim(searching)))
	if(!searching)
		return list()
	if(!search_cache[searching])
		var/list/results
		if(entries_by_string[searching])
			results = list(entries_by_string[searching])
		else
			results = list()
			for(var/entry_title in entries_by_string)
				var/datum/codex_entry/entry = entries_by_string[entry_title]
				if(findtext_char(entry.display_name, searching) || \
					findtext_char(entry.lore_text, searching) || \
					findtext_char(entry.mechanics_text, searching) || \
					findtext_char(entry.antag_text, searching))
					results |= entry
		search_cache[searching] = dd_sortedObjectList(results)
	return search_cache[searching]


/datum/controller/subsystem/codex/can_interact(mob/user)
	return TRUE


/datum/controller/subsystem/codex/Topic(href, href_list)
	. = ..()
	if(.)
		return
	if(href_list["show_examined_info"] && href_list["show_to"])
		var/atom/showing_atom = locate(href_list["show_examined_info"])
		var/mob/showing_mob = locate(href_list["show_to"]) in GLOB.mob_list
		if(QDELETED(showing_atom) || QDELETED(showing_mob))
			return
		var/entry = get_codex_entry(showing_atom)
		if(entry && showing_mob.can_use_codex())
			present_codex_entry(showing_mob, entry)
			return TRUE
