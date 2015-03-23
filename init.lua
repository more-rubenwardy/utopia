print("Utopia!")

-- Some Terminology:
--  > Cell - a 16 by 16 area in the road grid
--  > Plot - an area of land owned. Can extend multiple cells, and is moved all together.
-- Note: if a plot extends over one cell, it owns the roads in between as well.
--       The players can then delete the roads and continue with their houses.

uto = {
	_sections = {}
}
local ground_level = 3

function uto.init()
	local city = uto.add_section("city",{})
	local plot = city:create_plot("singleplayer")
	plot.alloc = uto.quick_allocate(city,plot)
	os.execute("mkdir \"" .. minetest.get_worldpath() .. "/utopia\"")
end

function uto.add_section(name,data)
	data.name = name
	data.create_plot = uto.create_plot
	if not data.x then
		data.x = 0
	end
	if not data.z then
		data.z = 0
	end
	if not data._plots then
		data._plots = {}
	end
	table.insert(uto._sections,data)
	return data
end

function uto.cellmin(x,z)
	return {x=x*20+2, y=-50, z=z*20+2}
end

function uto.cellmax(x,z)
	return {x=x*20+17, y=50, z=z*20+17}
end

function uto.cell_from_pos(x,z)
	local modx = x % 20
	local mody = x % 20
	
	if (modx < 2 or modx > 17 or mody < 2 or mody > 17) then
		return nil
	end

	return {x=math.floor(x/20),z=math.floor(z/20)}
end

function uto.plot_from_pos(x,z)
	for i,section in ipairs(uto._sections) do
		if (section._plots) then
			for j,plot in ipairs(section._plots) do
				if (plot.alloc) then
					if (
						plot.alloc[1]*20+2 <= x and plot.alloc[3]*20+17 >= x and
						plot.alloc[2]*20+2 <= z and plot.alloc[4]*20+17 >= z
					)then
						return plot
					end
				end
			end
		end
	end
end

function uto.plot_from_cell(x,z)
	for i,section in ipairs(uto._sections) do
		if (section._plots) then
			for j,plot in ipairs(section._plots) do
				if (plot.alloc) then
					if (plot.alloc[1] <= x and plot.alloc[3] >= x and plot.alloc[2] <= z and plot.alloc[4] >= z)then
						return plot
					end
				end
			end
		end
	end
end

function uto.create_plot(section,owner)
	local id = #section._plots + 1
	local plot = {
		id = id,
		extent = {1,1},
		home = {0,0,0},
		owner = owner,
		name = owner.."'s plot",
		size = {
			x = 2,
			z = 1
		}
	}
	table.insert(section._plots,plot)
	return plot
end

function uto.save(section,id)
	local result, count = worldedit.serialize(pos1, pos2)
	local path = minetest.get_worldpath() .. "/utopia"
	local filename = path .. "/" .. section.name .. "_"..id..".we"
	filename = filename:gsub("\"", "\\\""):gsub("\\", "\\\\") --escape any nasty characters
	os.execute("mkdir \"" .. path .. "\"") --create directory if it does not already exist
	local file, err = io.open(filename, "wb")
	file:write(result)
	file:flush()
	file:close()
end

minetest.register_on_generated(function(minp, maxp, blockseed)
	if (minp.y <= ground_level and maxp.y >= ground_level) then
		local x = minp.x
		while (x <= maxp.x) do
			local z = minp.z
			while (z <= maxp.z) do
				local modx = x % 20
				local modz = z % 20
				if (modx >= 18 or modx < 2 or modz >= 18 or modz < 2) then
					minetest.set_node({x=x,y=ground_level,z=z},{name="default:stone"})			
				end
				z = z + 1
			end
			x = x + 1
		end
	end
end)

--[[minetest.after(5,function()
	for x=0, 10 do
		local p = uto.cellmin(x,0)
		minetest.set_node({x=p.x,y=3,z=p.z},{name="wool:red"})
		local q = uto.cellmax(x,0)
		minetest.set_node({x=q.x,y=3,z=q.z},{name="wool:red"})
	end
end)]]--

function uto.check_alloc(section)
	if (section and section._plots) then
		for j,plot in ipairs(section._plots) do
			if (not plot.alloc) then
				
			end
		end
	end
end

function uto.quick_allocate(section,plot)
	local x = 0
	local z = 0
	local c = 0
	while (1) do
		c = c + 1
		if (c > 1000) then
			local id = nil
			if plot then id = plot.id end
			if id == nil then id = "<unknown-id>" end
			print("[UTOPIA] Error allocating plot "..id..", maximum looping reached in quick_allocate()")
			uto.suggest_full_alloc = true
			return false
		end
		local blocked = false
		for ix = 0, plot.size.x-1 do
			for iz = 0, plot.size.z-1 do
				if (uto.plot_from_cell(section.x + x + ix,section.z + z + iz)~=nil) then
					blocked = true
					break
				end	
			end
			if blocked then
				break
			end
		end
		if not blocked then
			break
		end		
		if z == 0 and x > 0 then
			z = x + 1
			x = 0
		elseif z==0 and x == 0 then
			x = 0
			z = z + 1
		elseif x >= z then
			z = z - 1
		else
			x = x + 1
		end
	end
	return {x,z,x+plot.size.x-1,z+plot.size.z-1}
end

uto.init()

minetest.register_chatcommand("plot",{
	description = "Plot managing from the Utopia mod. /plot help",
	func = function(name, param)
		if not name then
			return
		end
		
		if param == "" then
			print("Finding player")
			local player = minetest.get_player_by_name(name)
			if player then
				local pos = player:getpos()
				local cell = uto.cell_from_pos(pos.x,pos.z)
				if cell then
					local plot = uto.plot_from_cell(cell.x,cell.z)
					if plot then
						local cname = ""
						if plot.name then
							cname = plot.name
						end
						minetest.chat_send_player(name,"You are in cell ("..cell.x..", "..cell.z.."), '"..cname.."', owned by "..plot.owner)
					else
						minetest.chat_send_player(name,"You are in cell ("..cell.x..", "..cell.z..")")
					end
				else
					minetest.chat_send_player(name,"You are in no man's land")
				end
			end
		elseif param == "list" then	
			print("Listing plots")
			for i,section in ipairs(uto._sections) do
				minetest.chat_send_player(name,section.name..":")
				if (section._plots) then
					for j,plot in ipairs(section._plots) do
						local pn = j
						if (plot.name) then
							pn = plot.name
						end
						if (plot.alloc) then
							minetest.chat_send_player(name,
								"- "..pn.." (Allocated at: "..
								plot.alloc[1]..", "..
								plot.alloc[2]..", "..
								plot.alloc[3]..", "..
								plot.alloc[4]..")"
							)
						else
							minetest.chat_send_player(name,"- "..pn)
						end
					end
				end
			end
		else
			if param ~= "help" then
				minetest.chat_send_player(name,"Unknown command for plot managing from the Utopia mod.")
			else
				minetest.chat_send_player(name,"Plot managing from the Utopia mod.")
			end			
			minetest.chat_send_player(name,"/plot - current plot information")
			minetest.chat_send_player(name,"/plot list - list all plots")
			minetest.chat_send_player(name,"/plot extend - extend this plot by one in the current direction (todo)")
			minetest.chat_send_player(name,"/plot add <username> - allow a user to build in this plot (todo)")
			minetest.chat_send_player(name,"/plot remove <username> - revoke a user from building on this plot (todo)")
			minetest.chat_send_player(name,"/plot help - this screen")
			return			
		end
	end
})

minetest.is_protected = function(pos, name)
	local plot = uto.plot_from_pos(pos.x,pos.z)
	if plot and plot.owner == name then
		return false
	end	
	return true
end

