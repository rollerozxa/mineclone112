mcl_mapgen_core = {}
local registered_generators = {}

local lvm, nodes, param2 = 0, 0, 0
local lvm_used = false
local lvm_buffer = {}

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

--
-- Aliases for map generator outputs
--

minetest.register_alias("mapgen_stone", "mcl_core:stone")
minetest.register_alias("mapgen_water_source", "mcl_core:water_source")
minetest.register_alias("mapgen_river_water_source", "mclx_core:river_water_source")

dofile(modpath.."/api.lua")
dofile(modpath.."/ores.lua")

local mg_name = minetest.get_mapgen_setting("mg_name")
local superflat = mg_name == "flat" and minetest.get_mapgen_setting("mcl_superflat_classic") == "true"

-- Content IDs
local c_bedrock = minetest.get_content_id("mcl_core:bedrock")
local c_void = minetest.get_content_id("mcl_core:void")
local c_lava = minetest.get_content_id("mcl_core:lava_source")
local c_nether_lava = minetest.get_content_id("mcl_nether:nether_lava_source")
local c_realm_barrier = minetest.get_content_id("mcl_core:realm_barrier")
local c_air = minetest.CONTENT_AIR

local mg_flags = minetest.settings:get_flags("mg_flags")

-- Inform other mods of dungeon setting for MCL2-style dungeons
mcl_vars.mg_dungeons = mg_flags.dungeons and not superflat

-- Disable builtin dungeons, we provide our own dungeons
mg_flags.dungeons = false

if superflat then
	-- Enforce superflat-like mapgen: no caves, decor, lakes and hills
	mg_flags.caves = false
	mg_flags.decorations = false
	minetest.set_mapgen_setting("mgflat_spflags", "nolakes,nohills", true)
end

if mg_name == "v7" then
	minetest.set_mapgen_setting("mgv7_cavern_threshold", "0.20", true)
	mg_flags.caverns = true
elseif mg_name == "valleys" then
	minetest.set_mapgen_setting("mgvalleys_cavern_threshold", "0.20", true)
	mg_flags.caverns = true
elseif mg_name == "carpathian" then
	minetest.set_mapgen_setting("mgcarpathian_cavern_threshold", "0.20", true)
	mg_flags.caverns = true
elseif mg_name == "v5" then
	minetest.set_mapgen_setting("mgv5_cavern_threshold", "0.20", true)
	mg_flags.caverns = true
elseif mg_name == "fractal" then
	minetest.set_mapgen_setting("mgfractal_cavern_threshold", "0.20", true)
	mg_flags.caverns = true
end



local mg_flags_str = ""
for k,v in pairs(mg_flags) do
	if v == false then
		k = "no" .. k
	end
	mg_flags_str = mg_flags_str .. k .. ","
end
if string.len(mg_flags_str) > 0 then
	mg_flags_str = string.sub(mg_flags_str, 1, string.len(mg_flags_str)-1)
end
minetest.set_mapgen_setting("mg_flags", mg_flags_str, true)

local function between(x, y, z) -- x is between y and z (inclusive)
    return y <= x and x <= z
end

local function in_cube(tpos,wpos1,wpos2)
	local xmax=wpos2.x
	local xmin=wpos1.x

	local ymax=wpos2.y
	local ymin=wpos1.y

	local zmax=wpos2.z
	local zmin=wpos1.z
	if wpos1.x > wpos2.x then
		xmax=wpos1.x
		xmin=wpos2.x
	end
	if wpos1.y > wpos2.y then
		ymax=wpos1.y
		ymin=wpos2.y
	end
	if wpos1.z > wpos2.z then
		zmax=wpos1.z
		zmin=wpos2.z
	end
	if between(tpos.x,xmin,xmax) and between(tpos.y,ymin,ymax) and between(tpos.z,zmin,zmax) then
		return true
	end
	return false
end

-- Helper function for converting a MC probability to MT, with
-- regards to MapBlocks.
-- Some MC generated structures are generated on per-chunk
-- probability.
-- The MC probability is 1/x per Minecraft chunk (16??16).

-- x: The MC probability is 1/x.
-- minp, maxp: MapBlock limits
-- returns: Probability (1/return_value) for a single MT mapblock
local function minecraft_chunk_probability(x, minp, maxp)
	-- 256 is the MC chunk height
	return x * (((maxp.x-minp.x+1)*(maxp.z-minp.z+1)) / 256)
end

-- Takes x and z coordinates and minp and maxp of a generated chunk
-- (in on_generated callback) and returns a biomemap index)
-- Inverse function of biomemap_to_xz
local function xz_to_biomemap_index(x, z, minp, maxp)
	local xwidth = maxp.x - minp.x + 1
	local zwidth = maxp.z - minp.z + 1
	local minix = x % xwidth
	local miniz = z % zwidth

	return (minix + miniz * zwidth) + 1
end


-- Generate basic layer-based nodes: void, bedrock, realm barrier, lava seas, etc.
-- Also perform some basic node replacements.

local bedrock_check
if mcl_vars.mg_bedrock_is_rough then
	function bedrock_check(pos, _, pr)
		local y = pos.y
		-- Bedrock layers with increasing levels of roughness, until a perfecly flat bedrock later at the bottom layer
		-- This code assumes a bedrock height of 5 layers.

		local diff = mcl_vars.mg_bedrock_overworld_max - y -- Overworld bedrock
		local ndiff1 = mcl_vars.mg_bedrock_nether_bottom_max - y -- Nether bedrock, bottom
		local ndiff2 = mcl_vars.mg_bedrock_nether_top_max - y -- Nether bedrock, ceiling

		local top
		if diff == 0 or ndiff1 == 0 or ndiff2 == 4 then
			-- 50% bedrock chance
			top = 2
		elseif diff == 1 or ndiff1 == 1 or ndiff2 == 3 then
			-- 66.666...%
			top = 3
		elseif diff == 2 or ndiff1 == 2 or ndiff2 == 2 then
			-- 75%
			top = 4
		elseif diff == 3 or ndiff1 == 3 or ndiff2 == 1 then
			-- 90%
			top = 10
		elseif diff == 4 or ndiff1 == 4 or ndiff2 == 0 then
			-- 100%
			return true
		else
			-- Not in bedrock layer
			return false
		end

		return pr:next(1, top) <= top-1
	end
end


-- Helper function to set all nodes in the layers between min and max.
-- content_id: Node to set
-- check: optional.
--	If content_id, node will be set only if it is equal to check.
--	If function(pos_to_check, content_id_at_this_pos), will set node only if returns true.
-- min, max: Minimum and maximum Y levels of the layers to set
-- minp, maxp: minp, maxp of the on_generated
-- lvm_used: Set to true if any node in this on_generated has been set before.
--
-- returns true if any node was set and lvm_used otherwise
local function set_layers(data, area, content_id, check, min, max, minp, maxp, lvm_used, pr)
	if (maxp.y >= min and minp.y <= max) then
		for y = math.max(min, minp.y), math.min(max, maxp.y) do
			for x = minp.x, maxp.x do
				for z = minp.z, maxp.z do
					local p_pos = area:index(x, y, z)
					if check then
						if type(check) == "function" and check({x=x,y=y,z=z}, data[p_pos], pr) then
							data[p_pos] = content_id
							lvm_used = true
						elseif check == data[p_pos] then
							data[p_pos] = content_id
							lvm_used = true
						end
					else
						data[p_pos] = content_id
						lvm_used = true
					end
				end
			end
		end
	end
	return lvm_used
end

local function set_palette(minp,maxp,data2,area,biomemap,nodes)
	-- Flat area at y=0 to read biome 3 times faster than 5.3.0.get_biome_data(pos).biome: 43us vs 125us per iteration:
	if not biomemap then return end
	local aream = VoxelArea:new({MinEdge={x=minp.x, y=0, z=minp.z}, MaxEdge={x=maxp.x, y=0, z=maxp.z}})
	local nodes = minetest.find_nodes_in_area(minp, maxp, nodes)
	for n=1, #nodes do
		local n = nodes[n]
		local p_pos = area:index(n.x, n.y, n.z)
		local b_pos = aream:index(n.x, 0, n.z)
		local bn = minetest.get_biome_name(biomemap[b_pos])
		if bn then
			local biome = minetest.registered_biomes[bn]
			if biome and biome._mcl_biome_type and biome._mcl_grass_palette_index then
				data2[p_pos] = biome._mcl_grass_palette_index
				lvm_used = true
			end
		end
	end
	return lvm_used
end

-- Below the bedrock, generate air/void
local function world_structure(vm, data, data2, emin, emax, area, minp, maxp, blockseed)
	local biomemap --ymin, ymax
	local lvm_used = false
	local pr = PseudoRandom(blockseed)

	-- The Void below the Nether:
	lvm_used = set_layers(data, area, c_void         , nil, mcl_vars.mapgen_edge_min                     , mcl_vars.mg_nether_min                     -1, minp, maxp, lvm_used, pr)

	-- [[ THE NETHER:					mcl_vars.mg_nether_min			       mcl_vars.mg_nether_max							]]

	-- The Air on the Nether roof, https://git.minetest.land/MineClone2/MineClone2/issues/1186
	lvm_used = set_layers(data, area, c_air		 , nil, mcl_vars.mg_nether_max			   +1, mcl_vars.mg_nether_max + 128                 , minp, maxp, lvm_used, pr)
	-- The Void above the Nether below the End:
	lvm_used = set_layers(data, area, c_void         , nil, mcl_vars.mg_nether_max + 128               +1, mcl_vars.mg_end_min                        -1, minp, maxp, lvm_used, pr)

	-- [[ THE END:						mcl_vars.mg_end_min			       mcl_vars.mg_end_max							]]

	-- The Void above the End below the Realm barrier:
	lvm_used = set_layers(data, area, c_void         , nil, mcl_vars.mg_end_max                        +1, mcl_vars.mg_realm_barrier_overworld_end_min-1, minp, maxp, lvm_used, pr)
	-- Realm barrier between the Overworld void and the End
	lvm_used = set_layers(data, area, c_realm_barrier, nil, mcl_vars.mg_realm_barrier_overworld_end_min  , mcl_vars.mg_realm_barrier_overworld_end_max  , minp, maxp, lvm_used, pr)
	-- The Void above Realm barrier below the Overworld:
	lvm_used = set_layers(data, area, c_void         , nil, mcl_vars.mg_realm_barrier_overworld_end_max+1, mcl_vars.mg_overworld_min                  -1, minp, maxp, lvm_used, pr)


	if mg_name ~= "singlenode" then
		-- Bedrock
		lvm_used = set_layers(data, area, c_bedrock, bedrock_check, mcl_vars.mg_bedrock_overworld_min, mcl_vars.mg_bedrock_overworld_max, minp, maxp, lvm_used, pr)
		lvm_used = set_layers(data, area, c_bedrock, bedrock_check, mcl_vars.mg_bedrock_nether_bottom_min, mcl_vars.mg_bedrock_nether_bottom_max, minp, maxp, lvm_used, pr)
		lvm_used = set_layers(data, area, c_bedrock, bedrock_check, mcl_vars.mg_bedrock_nether_top_min, mcl_vars.mg_bedrock_nether_top_max, minp, maxp, lvm_used, pr)

		-- Flat Nether
		if mg_name == "flat" then
			lvm_used = set_layers(data, area, c_air, nil, mcl_vars.mg_flat_nether_floor, mcl_vars.mg_flat_nether_ceiling, minp, maxp, lvm_used, pr)
		end

		-- Big lava seas by replacing air below a certain height
		if mcl_vars.mg_lava then
			lvm_used = set_layers(data, area, c_lava, c_air, mcl_vars.mg_overworld_min, mcl_vars.mg_lava_overworld_max, minp, maxp, lvm_used, pr)
			lvm_used = set_layers(data, area, c_nether_lava, c_air, mcl_vars.mg_nether_min, mcl_vars.mg_lava_nether_max, minp, maxp, lvm_used, pr)
		end
	end
	local deco = false
	local ores = false
	if minp.y >  mcl_vars.mg_nether_deco_max - 64 and maxp.y <  mcl_vars.mg_nether_max + 128 then
		deco = {min=mcl_vars.mg_nether_deco_max,max=mcl_vars.mg_nether_max}
	end
	if minp.y <  mcl_vars.mg_nether_min + 10 or maxp.y <  mcl_vars.mg_nether_min + 60 then
		deco = {min=mcl_vars.mg_nether_min - 10,max=mcl_vars.mg_nether_min + 20}
		ores = {min=mcl_vars.mg_nether_min - 10,max=mcl_vars.mg_nether_min + 20}
	end
	return lvm_used, lvm_used, deco, ores
end

local function block_fixes(vm, data, data2, emin, emax, area, minp, maxp, blockseed)
	local biomemap = minetest.get_mapgen_object("biomemap")
	local lvm_used = false
	local pr = PseudoRandom(blockseed)
	if minp.y <= mcl_vars.mg_overworld_max and maxp.y >= mcl_vars.mg_overworld_min then
		-- Set param2 (=color) of nodes which use the grass colour palette.
		lvm_used = set_palette(minp,maxp,data2,area,biomemap,{"mcl_core:dirt_with_grass", "mcl_flowers:tallgrass", "mcl_flowers:double_grass", "mcl_flowers:double_grass_top", "mcl_flowers:fern", "mcl_flowers:double_fern", "mcl_flowers:double_fern_top", "mcl_core:reeds", "mcl_core:dirt_with_grass_snow"})
	end
	return lvm_used
end


-- End block fixes:
local function end_basic(vm, data, data2, emin, emax, area, minp, maxp, blockseed)
	if maxp.y < mcl_vars.mg_end_min or minp.y > mcl_vars.mg_end_max then return end
	local biomemap --ymin, ymax
	local lvm_used = false
	local pr = PseudoRandom(blockseed)
	local nodes

	nodes = minetest.find_nodes_in_area(emin, emax, {"mcl_core:water_source"})
	if #nodes > 0 then
		lvm_used = true
		for _,n in pairs(nodes) do
			data[area:index(n.x, n.y, n.z)] = c_air
		end
	end

	return true, false
end


mcl_mapgen_core.register_generator("world_structure", world_structure, nil, 1, true)
mcl_mapgen_core.register_generator("end_fixes", end_basic, function(minp,maxp)
	if maxp.y < mcl_vars.mg_end_min or minp.y > mcl_vars.mg_end_max then return end
end, 9999, true)

if mg_name ~= "singlenode" then
	mcl_mapgen_core.register_generator("block_fixes", block_fixes, nil, 9999, true)
end

-- This should be moved to mcl_structures eventually if the dependencies can be sorted out.
mcl_mapgen_core.register_generator("structures",nil, function(minp, maxp, blockseed)
	local gennotify = minetest.get_mapgen_object("gennotify")
	local has_struct = {}
	local has = false
	local poshash = minetest.hash_node_position(minp)
	for _,struct in pairs(mcl_structures.registered_structures) do
		local pr = PseudoRandom(blockseed + 42)
		if struct.deco_id then
			for _, pos in pairs(gennotify["decoration#"..struct.deco_id] or {}) do
				local realpos = vector.offset(pos,0,1,0)
				minetest.remove_node(realpos)
				minetest.fix_light(vector.offset(pos,-1,-1,-1),vector.offset(pos,1,3,1))
				if struct.chunk_probability == nil or (not has and pr:next(1,struct.chunk_probability) == 1 ) then
					mcl_structures.place_structure(realpos,struct,pr,blockseed)
					has=true
				end
			end
		elseif struct.static_pos then
			for _,p in pairs(struct.static_pos) do
				if in_cube(p,minp,maxp) then
					mcl_structures.place_structure(p,struct,pr,blockseed)
				end
			end
		end
	end
	return false, false, false
end, 100, true)

minetest.register_lbm({
	label = "Fix grass palette indexes",
	name = "mcl_mapgen_core:fix_grass_palette_indexes",
	nodenames = {"mcl_core:dirt_with_grass", "mcl_flowers:tallgrass", "mcl_flowers:double_grass", "mcl_flowers:double_grass_top", "mcl_flowers:fern", "mcl_flowers:double_fern", "mcl_flowers:double_fern_top", "mcl_core:reeds", "mcl_core:dirt_with_grass_snow"},
	run_at_every_load = true,
	action = function(pos, node)
		if mg_name ~= "singlenode" then
			local biome_data = minetest.get_biome_data(pos)
			local biome = biome_data.biome
			local biome_name = minetest.get_biome_name(biome)
			local reg_biome = minetest.registered_biomes[biome_name]
			if node.param2 ~= reg_biome._mcl_grass_palette_index then
				node.param2 = reg_biome._mcl_grass_palette_index
				minetest.set_node(pos, node)
			end
		end
	end,
})
