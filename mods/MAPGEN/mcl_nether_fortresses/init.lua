local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)
local modpath = minetest.get_modpath(modname)
local peaceful = minetest.settings:get_bool("only_peaceful_mobs", false)

local BLAZE_SPAWNER_MAX_LIGHT = 11

mcl_structures.register_structure("nether_outpost",{
	place_on = {"mcl_nether:netherrack","mcl_nether:soul_sand"},
	fill_ratio = 0.01,
	chunk_probability = 900,
	flags = "all_floors",
	biomes = {"Nether","SoulsandValley"},
	sidelen = 24,
	solid_ground = true,
	make_foundation = true,
	y_min = mcl_vars.mg_lava_nether_max - 1,
	y_max = mcl_vars.mg_nether_max - 30,
	filenames = { modpath.."/schematics/mcl_nether_fortresses_nether_outpost.mts" },
	y_offset = 0,
	after_place = function(pos)
		local sp = minetest.find_nodes_in_area(pos,vector.offset(pos,0,20,0),{"mcl_mobspawners:spawner"})
		if not sp[1] then return end
		mcl_mobspawners.setup_spawner(sp[1], "mobs_mc:blaze", 0, BLAZE_SPAWNER_MAX_LIGHT, 10, 8, 0)
	end
})
local nbridges = {
		modpath.."/schematics/mcl_nether_fortresses_nether_bridge_1.mts",
		modpath.."/schematics/mcl_nether_fortresses_nether_bridge_2.mts",
		modpath.."/schematics/mcl_nether_fortresses_nether_bridge_3.mts",
		modpath.."/schematics/mcl_nether_fortresses_nether_bridge_4.mts",
}
mcl_structures.register_structure("nether_bridge",{
	place_on = {"mcl_nether:nether_lava_source","mcl_nether:netherrack","mcl_nether:soul_sand","mcl_core:bedrock"},
	fill_ratio = 0.01,
	chunk_probability = 500,
	flags = "all_floors",
	sidelen = 38,
	solid_ground = false,
	make_foundation = false,
	y_min = mcl_vars.mg_nether_min - 4,
	y_max = mcl_vars.mg_lava_nether_max - 20,
	filenames = nbridges,
	y_offset = function(pr) return pr:next(15,20) end,
	after_place = function(pos,def,pr)
		local p1 = vector.offset(pos,-14,0,-14)
		local p2 = vector.offset(pos,14,24,14)
		mcl_structures.spawn_mobs("mobs_mc:witherskeleton",{},p1,p2,pr,5)
	end
})

mcl_structures.register_structure("nether_outpost_with_bridges",{
	place_on = {"mcl_nether:netherrack","mcl_nether:soul_sand","mcl_nether:nether_lava_source"},
	fill_ratio = 0.01,
	chunk_probability = 1300,
	flags = "all_floors",
	biomes = {"Nether","SoulsandValley"},
	sidelen = 24,
	solid_ground = true,
	make_foundation = true,
	y_min = mcl_vars.mg_lava_nether_max - 1,
	y_max = mcl_vars.mg_nether_max - 30,
	filenames = { modpath.."/schematics/mcl_nether_fortresses_nether_outpost.mts" },
	daughters = {{
		files = { nbridges[1] },
			pos = vector.new(0,-2,-24),
			rot = 180,
		},
		{
		files = { nbridges[1] },
			pos = vector.new(0,-2,24),
			rot = 0,
		},
		{
		files = { nbridges[1] },
			pos = vector.new(-24,-2,0),
			rot = 270,
		},
		{
		files = { nbridges[1] },
			pos = vector.new(24,-2,0),
			rot = 90,
		},
	},
	after_place = function(pos,def,pr)
		local sp = minetest.find_nodes_in_area(pos,vector.offset(pos,0,20,0),{"mcl_mobspawners:spawner"})
		if not sp[1] then return end
		mcl_mobspawners.setup_spawner(sp[1], "mobs_mc:blaze", 0, BLAZE_SPAWNER_MAX_LIGHT, 10, 8, 0)

		local legs = minetest.find_nodes_in_area(vector.offset(pos,-45,-2,-45),vector.offset(pos,45,0,45), "mcl_nether:nether_brick")
		local bricks = {}
		for _,leg in pairs(legs) do
			while minetest.get_item_group(mcl_vars.get_node(vector.offset(leg,0,-1,0), true, 333333).name, "solid") == 0 do
				leg = vector.offset(leg,0,-1,0)
				table.insert(bricks,leg)
			end
		end
		minetest.bulk_set_node(bricks, {name = "mcl_nether:nether_brick", param2 = 2})

		local p1 = vector.offset(pos,-45,13,-45)
		local p2 = vector.offset(pos,45,13,45)
		mcl_structures.spawn_mobs("mobs_mc:witherskeleton",{},p1,p2,pr,5)
	end
},true)

--[[mcl_structures.register_structure_spawn({
	name = "mobs_mc:witherskeleton",
	y_min = mcl_vars.mg_lava_nether_max,
	y_max = mcl_vars.mg_nether_max,
	chance = 15,
	interval = 60,
	limit = 4,
	spawnon = { },
})]]
