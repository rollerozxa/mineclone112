local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

local S = minetest.get_translator(minetest.get_current_modname())

-- mcl_itemframes API
dofile(modpath .. "/item_frames_API.lua")

-- actual api initialization.
mcl_itemframes.create_base_definitions()

-- necessary to maintain compatibility amongst older versions.
mcl_itemframes.backwards_compatibility()

-- Define the standard frames.
mcl_itemframes.create_custom_frame("false", "item_frame", false,
		"mcl_itemframes_item_frame.png", mcl_colors.WHITE, "Can hold an item.",
		"Item Frame", "")

-- Register the base frame's recipes.
-- was going to make it a specialized function, but minetest refuses to play nice.
minetest.register_craft({
	output = "mcl_itemframes:item_frame",
	recipe = {
		{ "mcl_core:stick", "mcl_core:stick", "mcl_core:stick" },
		{ "mcl_core:stick", "mcl_mobitems:leather", "mcl_core:stick" },
		{ "mcl_core:stick", "mcl_core:stick", "mcl_core:stick" },
	}
})

mcl_itemframes.custom_register_lbm()
