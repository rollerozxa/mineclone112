local adjacents = {
	vector.new(1,0,0),
	vector.new(1,0,1),
	vector.new(1,0,-1),
	vector.new(-1,0,0),
	vector.new(-1,0,1),
	vector.new(-1,0,-1),
	vector.new(0,0,1),
	vector.new(0,0,-1),
	vector.new(0,-1,0)
}

local plane_adjacents = {
	vector.new(1,0,0),
	vector.new(-1,0,0),
	vector.new(0,0,1),
	vector.new(0,0,-1),
}

local function set_node_no_bedrock(pos,node)
	local n = minetest.get_node(pos)
	if n.name == "mcl_core:bedrock" then return end
	return minetest.set_node(pos,node)
end

local function airtower(pos,tbl,h)
	for i=1,h do
		table.insert(tbl,vector.offset(pos,0,i,0))
	end
end

local function makelake(pos,size,liquid,placein,border,pr,noair)
	local node_under = minetest.get_node(vector.offset(pos,0,-1,0))
	local p1 = vector.offset(pos,-size,-1,-size)
	local p2 = vector.offset(pos,size,-1,size)
	minetest.emerge_area(p1, p2, function(blockpos, action, calls_remaining, param)
		if calls_remaining ~= 0 then return end
		local nn = minetest.find_nodes_in_area(p1,p2,placein)
		table.sort(nn,function(a, b)
		   return vector.distance(vector.new(pos.x,0,pos.z), a) < vector.distance(vector.new(pos.x,0,pos.z), b)
		end)
		if not nn[1] then return end
		local y = pos.y - pr:next(1,2)
		local lq = {}
		local air = {}
		local r = pr:next(1,#nn)
		if r > #nn then return end
		for i=1,r do
			if nn[i].y == y then
				airtower(nn[i],air,55)
				table.insert(lq,nn[i])
			end
		end
		minetest.bulk_set_node(lq,{name=liquid})
		minetest.bulk_set_node(air,{name="air"})
		air = {}
		local br = {}
		for k,v in pairs(lq) do
			for kk,vv in pairs(adjacents) do
				local pp = vector.add(v,vv)
				local an = minetest.get_node(pp)
				local un = minetest.get_node(vector.offset(pp,0,1,0))
				if not border then
					if minetest.get_item_group(an.name,"solid") > 0 then
						border = an.name
					elseif minetest.get_item_group(minetest.get_node(nn[1]).name,"solid") > 0 then
						border = minetest.get_node_or_nil(nn[1]).name
					else
						border = "mcl_core:stone"
					end
					if border == nil or border == "mcl_core:dirt" then border = "mcl_core:dirt_with_grass" end
				end
				if not noair and an.name ~= liquid then
					table.insert(br,pp)
					if un.name ~= liquid then
						airtower(pp,air,55)
					end
				end
			end
		end
		minetest.bulk_set_node(br,{name=border})
		minetest.bulk_set_node(air,{name="air"})
		return true
	end)
	return true
end

local mushrooms = {"mcl_mushrooms:mushroom_brown","mcl_mushrooms:mushroom_red"}

local function get_fallen_tree_schematic(pos,pr)
	local tree = minetest.find_node_near(pos,15,{"group:tree"})
	if not tree then return end
	tree = minetest.get_node(tree).name
	local maxlen = 8
	local minlen = 2
	local vprob = 120
	local mprob = 160
	local len = pr:next(minlen,maxlen)
	local schem = {
		size = {x = len + 2, y = 2, z = 3},
		data = {
			{name = "air", prob=0},
			{name = "air", prob=0},
		}
	}
	for i = 1,len do
		table.insert(schem.data,{name = "mcl_core:vine",param2=4, prob=vprob})
	end
	table.insert(schem.data,{name = "air", prob=0})
	table.insert(schem.data,{name = "air", prob=0})
	for i = 1,len do
		table.insert(schem.data,{name = "air", prob=0})
	end

	table.insert(schem.data,{name = tree, param2 = 0})
	table.insert(schem.data,{name = "air", prob=0})
	for i = 1,len do
		table.insert(schem.data,{name = tree, param2 = 12})
	end
	table.insert(schem.data,{name = "air", prob=0})
	table.insert(schem.data,{name = "air", prob=0})
	for i = 1,len do
		table.insert(schem.data,{name =  mushrooms[pr:next(1,#mushrooms)], param2 = 12, prob=mprob})
	end

	table.insert(schem.data,{name = "air", prob=0})
	table.insert(schem.data,{name = "air", prob=0})
	for i = 1,len do
		table.insert(schem.data,{name = "mcl_core:vine",param2=5, prob=vprob})
	end
	table.insert(schem.data,{name = "air", prob=0})
	table.insert(schem.data,{name = "air", prob=0})
	for i = 1,len do
		table.insert(schem.data,{name = "air", prob=0})
	end

	return schem
end

mcl_structures.register_structure("fallen_tree",{
	place_on = {"group:grass_block"},
	terrain_feature = true,
	noise_params = {
		offset = 0.00018,
		scale = 0.01011,
		spread = {x = 250, y = 250, z = 250},
		seed = 24533,
		octaves = 3,
		persist = 0.66
	},
	flags = "place_center_x, place_center_z",
	sidelen = 18,
	solid_ground = true,
	y_max = mcl_vars.mg_overworld_max,
	y_min = minetest.get_mapgen_setting("water_level"),
	on_place = function(pos,def,pr)
		local air_p1 = vector.offset(pos,-def.sidelen/2,1,-def.sidelen/2)
		local air_p2 = vector.offset(pos,def.sidelen/2,1,def.sidelen/2)
		local air = minetest.find_nodes_in_area(air_p1,air_p2,{"air"})
		if #air < ( def.sidelen * def.sidelen ) / 2 then
			return false
		end
		return true
	end,
	place_func = function(pos,def,pr)
		local schem=get_fallen_tree_schematic(pos,pr)
		if not schem then return end
		return minetest.place_schematic(pos,schem,"random")
	end
})

mcl_structures.register_structure("lavapool",{
	place_on = {"group:sand", "group:dirt", "group:stone"},
	terrain_feature = true,
	noise_params = {
		offset = 0,
		scale = 0.0000022,
		spread = {x = 250, y = 250, z = 250},
		seed = 78375213,
		octaves = 3,
		persist = 0.001,
		flags = "absvalue",
	},
	flags = "place_center_x, place_center_z, force_placement",
	y_max = mcl_vars.mg_overworld_max,
	y_min = minetest.get_mapgen_setting("water_level"),
	place_func = function(pos,def,pr)
		return makelake(pos,5,"mcl_core:lava_source",{"group:material_stone", "group:sand", "group:dirt"},"mcl_core:stone",pr)
	end
})

mcl_structures.register_structure("water_lake",{
	place_on = {"group:dirt","group:stone"},
	terrain_feature = true,
	noise_params = {
		offset = 0,
		scale = 0.000032,
		spread = {x = 250, y = 250, z = 250},
		seed = 756641353,
		octaves = 3,
		persist = 0.001,
		flags = "absvalue",
	},
	flags = "place_center_x, place_center_z, force_placement",
	y_max = mcl_vars.mg_overworld_max,
	y_min = minetest.get_mapgen_setting("water_level"),
	place_func = function(pos,def,pr)
		return makelake(pos,5,"mcl_core:water_source",{"group:material_stone", "group:sand", "group:dirt","group:grass_block"},"mcl_core:dirt_with_grass",pr)
	end
})

